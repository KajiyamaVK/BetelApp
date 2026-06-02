# MinIO Content Sync — Design Spec
**Date:** 2026-05-27  
**Status:** Awaiting approval

## Overview

Migrate BetelApp Flutter app from static bundled assets (`lessons.json` + local PDFs/MP3s) to a dynamic content delivery system backed by MinIO S3. On every app launch, the app checks for new or updated content, downloads only what changed, and stores everything locally in SQLite + device filesystem so the app works fully offline after the first sync.

---

## Goals

- App always reflects latest content published to MinIO
- Full offline support after first successful sync
- Files are never deleted from S3 — only logically superseded by new versions
- Audit trail for who uploaded/deleted each file (user IDs nullable now, populated when auth is added)
- Audio is optional per lesson; PDF is required
- Pull-to-refresh on Home triggers the same sync flow as startup

---

## Non-Goals

- Admin interface (future work)
- User authentication in the app
- Push notifications for new content

---

## MinIO Bucket Structure

**Bucket:** `betelapp-content` (public read, authenticated write)

```
betelapp-content/
├── manifest.json
└── lessons/
    ├── 1/
    │   ├── lesson_v1.pdf
    │   ├── lesson_v2.pdf       ← active
    │   ├── audio_v1.mp3        ← active
    └── 2/
        ├── lesson_v1.pdf       ← active
        └── audio_v1.mp3        ← active
```

Files are **never deleted** from S3. When a new version is uploaded, a new versioned file is written (`_v2`, `_v3`, etc.) and `manifest.json` is updated to point to it. The old file remains for audit purposes.

### manifest.json Schema

```json
{
  "version": 2,
  "updated_at": "2026-05-27T12:00:00Z",
  "lessons": [
    {
      "id": 1,
      "title": "Qual o Fim principal?",
      "pdf": {
        "active": "lessons/1/lesson_v2.pdf",
        "checksum": "md5hex",
        "history": [
          {
            "path": "lessons/1/lesson_v1.pdf",
            "checksum": "md5hex",
            "uploaded_at": "2026-05-20T10:00:00Z",
            "uploaded_by": null,
            "deleted_at": "2026-05-27T09:00:00Z",
            "deleted_by": null
          }
        ]
      },
      "audio": {
        "active": "lessons/1/audio_v1.mp3",
        "checksum": "md5hex",
        "required": false,
        "history": []
      }
    }
  ]
}
```

**Rules:**
- `pdf.active` is always set (PDF is required). If a lesson's PDF is logically deleted with no replacement, the lesson entry is removed from `manifest.json` entirely — but the file remains in S3.
- `audio.active` may be `null` (audio is optional).
- `uploaded_by` / `deleted_by` are `null` until the admin UI with user auth is built.
- The app only reads `active` paths — `history` is ignored by the app.

---

## SQLite Schema Changes

### New table: `lessons`

```sql
CREATE TABLE lessons (
  id               INTEGER PRIMARY KEY,
  title            TEXT NOT NULL,
  audio_local_path TEXT,
  audio_ext        TEXT,
  audio_checksum   TEXT,
  pdf_local_path   TEXT NOT NULL,
  pdf_checksum     TEXT NOT NULL,
  synced_at        INTEGER NOT NULL
);
```

### New table: `sync_meta`

```sql
CREATE TABLE sync_meta (
  id               INTEGER PRIMARY KEY DEFAULT 1,
  manifest_version INTEGER NOT NULL,
  last_sync_at     INTEGER NOT NULL
);
```

### Existing tables

`lesson_progress`, `favorites`, `flashcard_progress` — **unchanged**. They reference `lesson_id` which maps to `lessons.id`.

### Database migration

The app uses `sqflite` with manual version tracking. The current DB version will be bumped from `1` to `2`. The migration creates the two new tables. No data migration needed — existing progress/favorites rows are preserved.

---

## App Architecture

### New files

| File | Responsibility |
|------|---------------|
| `lib/data/services/remote_content_service.dart` | Fetches `manifest.json` and downloads individual files from MinIO |
| `lib/data/services/content_sync_service.dart` | Orchestrates sync: compares manifest vs SQLite, delegates downloads, updates DB |
| `lib/core/connectivity_service.dart` | Thin wrapper around `connectivity_plus` — exposes `isConnected` and a stream |

### Modified files

| File | Change |
|------|--------|
| `lib/core/database_helper.dart` | Add `lessons` + `sync_meta` tables, bump DB version to 2 |
| `lib/data/repositories/content_repository.dart` | Replace `rootBundle` JSON loading with `SELECT * FROM lessons` |
| `lib/presentation/screens/splash_screen.dart` | Run sync flow, show progress, handle no-internet on first boot |
| `lib/presentation/screens/home/home_screen.dart` | Add pull-to-refresh + offline banner + empty state for no-internet first boot |
| `lib/core/providers.dart` | Register new services as Riverpod providers |

---

## Sync Flow

### On splash (startup)

```
1. Check connectivity
   └─ No internet + SQLite empty (first boot)
      → navigate to Home with flag: firstBootOffline = true

2. Fetch manifest.json from MinIO
   └─ Error (timeout/network) + SQLite has data
      → navigate to Home with flag: offline = true

3. Compare manifest.version with sync_meta.manifest_version
   └─ Same version → navigate to Home immediately

4. For each lesson in manifest:
   a. If lesson not in SQLite → download pdf + audio (if present)
   b. If lesson in SQLite but checksum differs → download changed file(s)
   c. If lesson in SQLite and checksums match → skip

5. Update SQLite (lessons table + sync_meta)
6. Navigate to Home
```

Progress indicator on splash only shown when step 4 has work to do: "Baixando lição X de Y…"

Download respects connectivity type — if on mobile data, show a dialog: "Você está em dados móveis. Deseja baixar X MB?" (with the total size calculated from manifest). On WiFi, download silently.

### On pull-to-refresh (Home)

Runs steps 1–6 above. Shows a standard `RefreshIndicator`. If already up to date, completes immediately.

---

## UI States

### Home screen — lesson list

| State | UI |
|-------|----|
| First boot, no internet | Full-screen empty state: "Sem conexão com a internet" + "É necessário conexão para fazer o download do conteúdo" |
| Has data, offline | Subtle top banner: "Você está offline — o conteúdo pode estar desatualizado" |
| Has data, online, synced | Normal lesson list |
| Syncing (pull-to-refresh) | `RefreshIndicator` spinner |

### Música tab

- Songs from lessons whose PDF was removed (lesson deleted from manifest) **remain** in the Música tab — the audio file stays on device and in SQLite.
- A lesson with no audio simply shows no song entry.

---

## File Storage on Device

Files are stored under `getApplicationDocumentsDirectory()/betelsas/`:

```
betelsas/
├── lessons/
│   ├── 1/
│   │   ├── audio.mp3
│   │   └── lesson.pdf
│   └── 2/
│       └── lesson.pdf
```

Local paths stored in SQLite are **relative** (`lessons/1/audio.mp3`) and resolved at runtime with `path_provider`. This makes the path portable across OS-level app directory changes.

---

## Dependencies to Add

| Package | Purpose |
|---------|---------|
| `connectivity_plus` | Detect online/offline and connection type (WiFi vs mobile) |
| `http` (already used?) or `dio` | HTTP downloads with progress callbacks |

`dio` is preferred over `http` for download progress reporting needed in the splash indicator.

---

## Pre-Implementation: Migrate Existing Manifest

The current `manifest.json` in MinIO uses a flat structure (no `active`/`history`). Before implementation begins, the manifest must be regenerated in the new versioned format. A migration script will:

1. Read the current manifest
2. Wrap each file entry in `{ "active": "<path>", "checksum": "...", "history": [] }`
3. Rename existing files from `audio.mp3` → `audio_v1.mp3` and `lesson.pdf` → `lesson_v1.pdf`
4. Upload the new manifest and rename files in S3

This is a one-time operation done before the Flutter changes land.

---

## Out of Scope for This Iteration

- Removing the old `lessons.json` bundle (kept as reference, not used at runtime)
- Removing bundled PDF/audio assets (kept to avoid breaking existing installs during transition)
- Admin interface for publishing content
- User authentication / `uploaded_by` / `deleted_by` population
