# MinIO Content Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the BetelApp Flutter app from static bundled assets to a MinIO-backed content sync system that downloads lessons on startup, detects changes via checksums, and works fully offline after the first sync.

**Architecture:** A `ContentSyncService` orchestrates sync at startup (and on pull-to-refresh): it fetches `manifest.json` from MinIO via `RemoteContentService`, compares checksums against the SQLite `lessons` table, downloads only changed files to device storage, then updates SQLite. `ContentRepository` is rewritten to read from SQLite instead of the bundled JSON. The `Lesson` model is updated to carry local file paths.

**Tech Stack:** Flutter/Dart, sqflite, dio (new), connectivity_plus (new), path_provider (existing), Riverpod (existing)

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| **Create** | `lib/data/services/remote_content_service.dart` | Fetch manifest.json + download files from MinIO |
| **Create** | `lib/data/services/content_sync_service.dart` | Orchestrate sync: compare, download, update SQLite |
| **Create** | `lib/core/connectivity_service.dart` | Thin wrapper: isConnected, isMobileData |
| **Create** | `lib/data/models/manifest.dart` | Dart models for manifest.json deserialization |
| **Modify** | `lib/core/database_helper.dart` | Add lessons + sync_meta tables, bump version to 2 |
| **Modify** | `lib/data/models/lesson.dart` | Add localPdfPath, localAudioPath, audioExt fields |
| **Modify** | `lib/data/repositories/content_repository.dart` | Read from SQLite instead of bundled JSON |
| **Modify** | `lib/core/providers.dart` | Register new services |
| **Modify** | `lib/presentation/screens/splash_screen.dart` | Run sync, show progress, handle offline first boot |
| **Modify** | `lib/presentation/screens/home/home_screen.dart` | Pull-to-refresh, offline banner, empty state |
| **Modify** | `pubspec.yaml` | Add dio, connectivity_plus |
| **Script** | `scripts/migrate_manifest.sh` | One-time: rename S3 files to _v1, regenerate manifest |

---

## Task 0: Migrate MinIO manifest to versioned format

This is a one-time shell script that renames existing files in S3 from `audio.mp3` → `audio_v1.mp3` and `lesson.pdf` → `lesson_v1.pdf`, then regenerates `manifest.json` in the new schema with `active`/`history` fields.

**Files:**
- Create: `scripts/migrate_manifest.sh`

- [ ] **Step 1: Write the migration script**

Create `scripts/migrate_manifest.sh`:

```bash
#!/bin/bash
set -e

MC=/tmp/mc
BUCKET=homelab-minio/betelapp-content
BASE_URL="http://s3.kajiyama.com.br/betelapp-content"

# Configure mc alias if not already set
$MC alias set homelab-minio http://homelab:9000 admin "uHKOV@s@qIGFA8" 2>/dev/null || true

declare -A TITLES=(
  [1]="Qual o Fim principal?"
  [2]="Que regra deu Deus?"
  [3]="O que a escritura nos ensina?"
  [4]="Quem é Deus?"
  [5]="Será que existe mais de um Deus?"
  [6]="Quantas pessoas há na divindade?"
  [7]="Que são os Decretos de Deus?"
  [8]="Como Deus executa seus decretos?"
  [9]="Quais são as obras da criação?"
  [10]="Como criou Deus o homem?"
  [11]="Quais as obras da providência?"
  [12]="Que ato especial da providência?"
  [13]="Conservaram-se nossos primeiros pais?"
  [14]="O que é pecado?"
  [15]="Qual o primeiro pecado?"
  [16]="Caiu todo gênero humano em Adão?"
  [17]="Qual foi o Estado a que a queda reduziu o gênero humano?"
  [18]="Em que consiste o estado de miséria?"
  [19]="Qual miséria do estado que o homem caiu?"
  [20]="Deixou Deus todo o gênero humano perecer no estado de pecado e miséria?"
  [21]="Quem é o Redentor dos escolhidos de Deus?"
  [22]="Como Cristo se fez homem?"
  [23]="Que funções exerce Cristo como nosso Redentor?"
  [24]="Como exerce Cristo as funções de profeta?"
)

ENTRIES=""
for i in $(seq 1 24); do
  # Detect current audio extension
  if $MC ls "$BUCKET/lessons/$i/audio.mp3" &>/dev/null; then
    AUDIO_EXT="mp3"
  elif $MC ls "$BUCKET/lessons/$i/audio.wav" &>/dev/null; then
    AUDIO_EXT="wav"
  else
    AUDIO_EXT=""
  fi

  # Rename audio if exists
  if [ -n "$AUDIO_EXT" ]; then
    $MC cp "$BUCKET/lessons/$i/audio.$AUDIO_EXT" "$BUCKET/lessons/$i/audio_v1.$AUDIO_EXT" --quiet
    $MC rm "$BUCKET/lessons/$i/audio.$AUDIO_EXT" --quiet
    AUDIO_MD5=$(curl -s "$BASE_URL/lessons/$i/audio_v1.$AUDIO_EXT" | md5sum | cut -d' ' -f1)
    AUDIO_BLOCK="\"audio\": {
        \"active\": \"lessons/$i/audio_v1.$AUDIO_EXT\",
        \"ext\": \"$AUDIO_EXT\",
        \"checksum\": \"$AUDIO_MD5\",
        \"history\": []
      }"
  else
    AUDIO_BLOCK="\"audio\": null"
  fi

  # Rename pdf
  $MC cp "$BUCKET/lessons/$i/lesson.pdf" "$BUCKET/lessons/$i/lesson_v1.pdf" --quiet
  $MC rm "$BUCKET/lessons/$i/lesson.pdf" --quiet
  PDF_MD5=$(curl -s "$BASE_URL/lessons/$i/lesson_v1.pdf" | md5sum | cut -d' ' -f1)

  TITLE="${TITLES[$i]}"
  COMMA=""
  [ -n "$ENTRIES" ] && COMMA=","

  ENTRIES="${ENTRIES}${COMMA}
    {
      \"id\": $i,
      \"title\": \"$TITLE\",
      \"pdf\": {
        \"active\": \"lessons/$i/lesson_v1.pdf\",
        \"checksum\": \"$PDF_MD5\",
        \"history\": []
      },
      $AUDIO_BLOCK
    }"

  echo "✓ Lesson $i migrated"
done

MANIFEST="{
  \"version\": 1,
  \"updated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"lessons\": [${ENTRIES}
  ]
}"

echo "$MANIFEST" > /tmp/manifest_v2.json
$MC cp /tmp/manifest_v2.json "$BUCKET/manifest.json" --quiet
echo "✓ manifest.json updated to versioned format"
```

- [ ] **Step 2: Run the migration script**

```bash
chmod +x scripts/migrate_manifest.sh && bash scripts/migrate_manifest.sh
```

Expected output: 24 lines of `✓ Lesson N migrated` followed by `✓ manifest.json updated to versioned format`

- [ ] **Step 3: Verify the new manifest**

```bash
curl -s http://s3.kajiyama.com.br/betelapp-content/manifest.json | python3 -m json.tool | head -40
```

Expected: JSON with `version`, `updated_at`, and `lessons` array where each lesson has `pdf.active`, `pdf.checksum`, `pdf.history`, and `audio` fields.

- [ ] **Step 4: Commit**

```bash
git add scripts/migrate_manifest.sh
git commit -m "chore: add manifest migration script for versioned MinIO structure"
```

---

## Task 1: Add dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dio and connectivity_plus to pubspec.yaml**

In `pubspec.yaml`, under `dependencies:`, add:

```yaml
  dio: ^5.4.3
  connectivity_plus: ^6.0.3
```

- [ ] **Step 2: Install dependencies**

```bash
cd src/mobile && flutter pub get
```

Expected: `Got dependencies!` with no errors.

- [ ] **Step 3: Commit**

```bash
git add src/mobile/pubspec.yaml src/mobile/pubspec.lock
git commit -m "chore: add dio and connectivity_plus dependencies"
```

---

## Task 2: Database migration — add lessons and sync_meta tables

**Files:**
- Modify: `src/mobile/lib/core/database_helper.dart`
- Test: `src/mobile/test/core/database_helper_test.dart`

- [ ] **Step 1: Write the failing test**

Create `src/mobile/test/core/database_helper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelsas/core/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('database version is 2', () async {
    final db = await DatabaseHelper().database;
    expect(db.version, 2);
  });

  test('lessons table exists with correct columns', () async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery("PRAGMA table_info(lessons)");
    final columns = result.map((r) => r['name'] as String).toSet();
    expect(columns, containsAll([
      'id', 'title', 'audio_local_path', 'audio_ext',
      'audio_checksum', 'pdf_local_path', 'pdf_checksum', 'synced_at'
    ]));
  });

  test('sync_meta table exists with correct columns', () async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery("PRAGMA table_info(sync_meta)");
    final columns = result.map((r) => r['name'] as String).toSet();
    expect(columns, containsAll(['id', 'manifest_version', 'last_sync_at']));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd src/mobile && flutter test test/core/database_helper_test.dart -v
```

Expected: FAIL — version is 1, tables don't exist.

- [ ] **Step 3: Update database_helper.dart**

Replace `src/mobile/lib/core/database_helper.dart` entirely:

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'betel.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createOriginalTables(db);
    await _createSyncTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSyncTables(db);
    }
  }

  Future<void> _createOriginalTables(Database db) async {
    await db.execute('''
      CREATE TABLE lesson_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL UNIQUE,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 1,
        last_accessed INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE favorites (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        item_id TEXT NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE flashcard_progress (
        flashcard_id TEXT PRIMARY KEY,
        box INTEGER NOT NULL DEFAULT 0,
        next_review INTEGER NOT NULL,
        last_reviewed INTEGER
      )
    ''');
  }

  Future<void> _createSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lessons (
        id               INTEGER PRIMARY KEY,
        title            TEXT NOT NULL,
        audio_local_path TEXT,
        audio_ext        TEXT,
        audio_checksum   TEXT,
        pdf_local_path   TEXT NOT NULL,
        pdf_checksum     TEXT NOT NULL,
        synced_at        INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        id               INTEGER PRIMARY KEY DEFAULT 1,
        manifest_version INTEGER NOT NULL,
        last_sync_at     INTEGER NOT NULL
      )
    ''');
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd src/mobile && flutter test test/core/database_helper_test.dart -v
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/mobile/lib/core/database_helper.dart src/mobile/test/core/database_helper_test.dart
git commit -m "feat: add lessons and sync_meta tables, bump DB to version 2"
```

---

## Task 3: Manifest Dart models

**Files:**
- Create: `src/mobile/lib/data/models/manifest.dart`
- Test: `src/mobile/test/data/models/manifest_test.dart`

- [ ] **Step 1: Write the failing test**

Create `src/mobile/test/data/models/manifest_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:betelsas/data/models/manifest.dart';

const _sampleJson = '''
{
  "version": 1,
  "updated_at": "2026-05-27T12:00:00Z",
  "lessons": [
    {
      "id": 1,
      "title": "Qual o Fim principal?",
      "pdf": {
        "active": "lessons/1/lesson_v1.pdf",
        "checksum": "abc123",
        "history": []
      },
      "audio": {
        "active": "lessons/1/audio_v1.mp3",
        "ext": "mp3",
        "checksum": "def456",
        "history": []
      }
    },
    {
      "id": 2,
      "title": "Que regra deu Deus?",
      "pdf": {
        "active": "lessons/2/lesson_v1.pdf",
        "checksum": "ghi789",
        "history": []
      },
      "audio": null
    }
  ]
}
''';

void main() {
  test('parses manifest version and lesson count', () {
    final manifest = ContentManifest.fromJson(json.decode(_sampleJson));
    expect(manifest.version, 1);
    expect(manifest.lessons.length, 2);
  });

  test('parses lesson with audio', () {
    final manifest = ContentManifest.fromJson(json.decode(_sampleJson));
    final lesson = manifest.lessons[0];
    expect(lesson.id, 1);
    expect(lesson.title, 'Qual o Fim principal?');
    expect(lesson.pdf.active, 'lessons/1/lesson_v1.pdf');
    expect(lesson.pdf.checksum, 'abc123');
    expect(lesson.audio?.active, 'lessons/1/audio_v1.mp3');
    expect(lesson.audio?.ext, 'mp3');
  });

  test('parses lesson without audio', () {
    final manifest = ContentManifest.fromJson(json.decode(_sampleJson));
    final lesson = manifest.lessons[1];
    expect(lesson.audio, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd src/mobile && flutter test test/data/models/manifest_test.dart -v
```

Expected: FAIL — `ContentManifest` not found.

- [ ] **Step 3: Create manifest.dart**

Create `src/mobile/lib/data/models/manifest.dart`:

```dart
class ManifestFileEntry {
  final String active;
  final String checksum;
  final List<Map<String, dynamic>> history;

  ManifestFileEntry({
    required this.active,
    required this.checksum,
    required this.history,
  });

  factory ManifestFileEntry.fromJson(Map<String, dynamic> json) {
    return ManifestFileEntry(
      active: json['active'] as String,
      checksum: json['checksum'] as String,
      history: List<Map<String, dynamic>>.from(json['history'] ?? []),
    );
  }
}

class ManifestAudioEntry extends ManifestFileEntry {
  final String ext;

  ManifestAudioEntry({
    required super.active,
    required super.checksum,
    required super.history,
    required this.ext,
  });

  factory ManifestAudioEntry.fromJson(Map<String, dynamic> json) {
    return ManifestAudioEntry(
      active: json['active'] as String,
      checksum: json['checksum'] as String,
      history: List<Map<String, dynamic>>.from(json['history'] ?? []),
      ext: json['ext'] as String,
    );
  }
}

class ManifestLesson {
  final int id;
  final String title;
  final ManifestFileEntry pdf;
  final ManifestAudioEntry? audio;

  ManifestLesson({
    required this.id,
    required this.title,
    required this.pdf,
    this.audio,
  });

  factory ManifestLesson.fromJson(Map<String, dynamic> json) {
    return ManifestLesson(
      id: json['id'] as int,
      title: json['title'] as String,
      pdf: ManifestFileEntry.fromJson(json['pdf'] as Map<String, dynamic>),
      audio: json['audio'] != null
          ? ManifestAudioEntry.fromJson(json['audio'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ContentManifest {
  final int version;
  final String updatedAt;
  final List<ManifestLesson> lessons;

  ContentManifest({
    required this.version,
    required this.updatedAt,
    required this.lessons,
  });

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    return ContentManifest(
      version: json['version'] as int,
      updatedAt: json['updated_at'] as String,
      lessons: (json['lessons'] as List)
          .map((l) => ManifestLesson.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd src/mobile && flutter test test/data/models/manifest_test.dart -v
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/mobile/lib/data/models/manifest.dart src/mobile/test/data/models/manifest_test.dart
git commit -m "feat: add ContentManifest Dart models for MinIO manifest.json"
```

---

## Task 4: ConnectivityService

**Files:**
- Create: `src/mobile/lib/core/connectivity_service.dart`
- Test: `src/mobile/test/core/connectivity_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `src/mobile/test/core/connectivity_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:betelsas/core/connectivity_service.dart';

void main() {
  test('ConnectivityService can be instantiated', () {
    expect(() => ConnectivityService(), returnsNormally);
  });

  test('isConnected returns a bool', () async {
    final service = ConnectivityService();
    final result = await service.isConnected();
    expect(result, isA<bool>());
  });

  test('isMobileData returns a bool', () async {
    final service = ConnectivityService();
    final result = await service.isMobileData();
    expect(result, isA<bool>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd src/mobile && flutter test test/core/connectivity_service_test.dart -v
```

Expected: FAIL — `ConnectivityService` not found.

- [ ] **Step 3: Create connectivity_service.dart**

Create `src/mobile/lib/core/connectivity_service.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> isMobileData() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.wifi);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd src/mobile && flutter test test/core/connectivity_service_test.dart -v
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/mobile/lib/core/connectivity_service.dart src/mobile/test/core/connectivity_service_test.dart
git commit -m "feat: add ConnectivityService wrapper"
```

---

## Task 5: RemoteContentService

**Files:**
- Create: `src/mobile/lib/data/services/remote_content_service.dart`
- Test: `src/mobile/test/data/services/remote_content_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `src/mobile/test/data/services/remote_content_service_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:betelsas/data/services/remote_content_service.dart';
import 'package:betelsas/data/models/manifest.dart';

@GenerateMocks([Dio])
import 'remote_content_service_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late RemoteContentService service;

  setUp(() {
    mockDio = MockDio();
    service = RemoteContentService(dio: mockDio);
  });

  test('fetchManifest returns ContentManifest on success', () async {
    final fakeJson = {
      'version': 1,
      'updated_at': '2026-05-27T12:00:00Z',
      'lessons': [
        {
          'id': 1,
          'title': 'Test',
          'pdf': {'active': 'lessons/1/lesson_v1.pdf', 'checksum': 'abc', 'history': []},
          'audio': null,
        }
      ]
    };

    when(mockDio.get(any)).thenAnswer((_) async => Response(
          data: fakeJson,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    final manifest = await service.fetchManifest();
    expect(manifest.version, 1);
    expect(manifest.lessons.length, 1);
  });

  test('fetchManifest throws on network error', () async {
    when(mockDio.get(any)).thenThrow(DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.connectionTimeout,
    ));

    expect(() => service.fetchManifest(), throwsA(isA<RemoteContentException>()));
  });
}
```

- [ ] **Step 2: Generate mocks**

```bash
cd src/mobile && dart run build_runner build --delete-conflicting-outputs
```

Expected: generates `remote_content_service_test.mocks.dart`.

- [ ] **Step 3: Run test to verify it fails**

```bash
cd src/mobile && flutter test test/data/services/remote_content_service_test.dart -v
```

Expected: FAIL — `RemoteContentService` not found.

- [ ] **Step 4: Create remote_content_service.dart**

Create `src/mobile/lib/data/services/remote_content_service.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:betelsas/data/models/manifest.dart';

const _baseUrl = 'http://s3.kajiyama.com.br/betelapp-content';

class RemoteContentException implements Exception {
  final String message;
  RemoteContentException(this.message);
  @override
  String toString() => 'RemoteContentException: $message';
}

class RemoteContentService {
  final Dio _dio;

  RemoteContentService({Dio? dio}) : _dio = dio ?? Dio();

  Future<ContentManifest> fetchManifest() async {
    try {
      final response = await _dio.get('$_baseUrl/manifest.json');
      return ContentManifest.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw RemoteContentException('Failed to fetch manifest: ${e.message}');
    }
  }

  Future<void> downloadFile({
    required String remotePath,
    required String localPath,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      await _dio.download(
        '$_baseUrl/$remotePath',
        localPath,
        onReceiveProgress: onProgress,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );
    } on DioException catch (e) {
      throw RemoteContentException('Failed to download $remotePath: ${e.message}');
    }
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd src/mobile && flutter test test/data/services/remote_content_service_test.dart -v
```

Expected: All 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add src/mobile/lib/data/services/remote_content_service.dart src/mobile/test/data/services/remote_content_service_test.dart src/mobile/test/data/services/remote_content_service_test.mocks.dart
git commit -m "feat: add RemoteContentService for MinIO manifest and file downloads"
```

---

## Task 6: ContentSyncService

**Files:**
- Create: `src/mobile/lib/data/services/content_sync_service.dart`
- Test: `src/mobile/test/data/services/content_sync_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `src/mobile/test/data/services/content_sync_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/core/connectivity_service.dart';
import 'package:betelsas/data/services/remote_content_service.dart';
import 'package:betelsas/data/services/content_sync_service.dart';
import 'package:betelsas/data/models/manifest.dart';

@GenerateMocks([RemoteContentService, ConnectivityService, DatabaseHelper])
import 'content_sync_service_test.mocks.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late MockRemoteContentService mockRemote;
  late MockConnectivityService mockConnectivity;
  late MockDatabaseHelper mockDb;
  late ContentSyncService service;

  setUp(() {
    mockRemote = MockRemoteContentService();
    mockConnectivity = MockConnectivityService();
    mockDb = MockDatabaseHelper();
    service = ContentSyncService(
      remote: mockRemote,
      connectivity: mockConnectivity,
      dbHelper: mockDb,
    );
  });

  test('sync returns SyncResult.offline when no internet and db is empty', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => false);
    when(mockDb.database).thenAnswer((_) async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1,
          onCreate: (db, _) async => await db.execute(
              'CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)'));
      return db;
    });

    final result = await service.sync();
    expect(result, SyncResult.offlineFirstBoot);
  });

  test('sync returns SyncResult.offlineWithData when no internet and db has lessons', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => false);
    when(mockDb.database).thenAnswer((_) async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
        await db.execute('CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await db.insert('sync_meta', {'id': 1, 'manifest_version': 1, 'last_sync_at': 0});
      });
      return db;
    });

    final result = await service.sync();
    expect(result, SyncResult.offlineWithData);
  });

  test('sync returns SyncResult.upToDate when manifest version matches', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);
    when(mockRemote.fetchManifest()).thenAnswer((_) async => ContentManifest(
          version: 3,
          updatedAt: '2026-05-27T12:00:00Z',
          lessons: [],
        ));
    when(mockDb.database).thenAnswer((_) async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
        await db.execute('CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await db.insert('sync_meta', {'id': 1, 'manifest_version': 3, 'last_sync_at': 0});
      });
      return db;
    });

    final result = await service.sync();
    expect(result, SyncResult.upToDate);
  });
}
```

- [ ] **Step 2: Generate mocks**

```bash
cd src/mobile && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd src/mobile && flutter test test/data/services/content_sync_service_test.dart -v
```

Expected: FAIL — `ContentSyncService` not found.

- [ ] **Step 4: Create content_sync_service.dart**

Create `src/mobile/lib/data/services/content_sync_service.dart`:

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:betelsas/core/connectivity_service.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/data/models/manifest.dart';
import 'package:betelsas/data/services/remote_content_service.dart';

enum SyncResult {
  offlineFirstBoot,
  offlineWithData,
  upToDate,
  updated,
  error,
}

class SyncProgress {
  final int current;
  final int total;
  final String lessonTitle;
  SyncProgress(this.current, this.total, this.lessonTitle);
}

class ContentSyncService {
  final RemoteContentService _remote;
  final ConnectivityService _connectivity;
  final DatabaseHelper _dbHelper;

  ContentSyncService({
    required RemoteContentService remote,
    required ConnectivityService connectivity,
    required DatabaseHelper dbHelper,
  })  : _remote = remote,
        _connectivity = connectivity,
        _dbHelper = dbHelper;

  Future<SyncResult> sync({
    void Function(SyncProgress)? onProgress,
  }) async {
    final db = await _dbHelper.database;

    final connected = await _connectivity.isConnected();
    if (!connected) {
      final meta = await db.query('sync_meta', limit: 1);
      return meta.isEmpty ? SyncResult.offlineFirstBoot : SyncResult.offlineWithData;
    }

    late ContentManifest manifest;
    try {
      manifest = await _remote.fetchManifest();
    } catch (_) {
      final meta = await db.query('sync_meta', limit: 1);
      return meta.isEmpty ? SyncResult.offlineFirstBoot : SyncResult.offlineWithData;
    }

    final meta = await db.query('sync_meta', limit: 1);
    final localVersion = meta.isEmpty ? -1 : meta.first['manifest_version'] as int;
    if (localVersion == manifest.version) return SyncResult.upToDate;

    final docsDir = await getApplicationDocumentsDirectory();

    final lessonsToDownload = <ManifestLesson>[];
    for (final lesson in manifest.lessons) {
      final existing = await db.query('lessons',
          where: 'id = ?', whereArgs: [lesson.id], limit: 1);
      if (existing.isEmpty) {
        lessonsToDownload.add(lesson);
      } else {
        final row = existing.first;
        if (row['pdf_checksum'] != lesson.pdf.checksum ||
            row['audio_checksum'] != lesson.audio?.checksum) {
          lessonsToDownload.add(lesson);
        }
      }
    }

    int current = 0;
    for (final lesson in lessonsToDownload) {
      current++;
      onProgress?.call(SyncProgress(current, lessonsToDownload.length, lesson.title));

      final lessonDir = Directory(p.join(docsDir.path, 'betelsas', 'lessons', '${lesson.id}'));
      await lessonDir.create(recursive: true);

      final pdfLocalPath = p.join('betelsas', 'lessons', '${lesson.id}', 'lesson.pdf');
      await _remote.downloadFile(
        remotePath: lesson.pdf.active,
        localPath: p.join(docsDir.path, pdfLocalPath),
      );

      String? audioLocalPath;
      String? audioExt;
      if (lesson.audio != null) {
        audioExt = lesson.audio!.ext;
        audioLocalPath = p.join('betelsas', 'lessons', '${lesson.id}', 'audio.$audioExt');
        await _remote.downloadFile(
          remotePath: lesson.audio!.active,
          localPath: p.join(docsDir.path, audioLocalPath),
        );
      }

      await db.insert(
        'lessons',
        {
          'id': lesson.id,
          'title': lesson.title,
          'pdf_local_path': pdfLocalPath,
          'pdf_checksum': lesson.pdf.checksum,
          'audio_local_path': audioLocalPath,
          'audio_ext': audioExt,
          'audio_checksum': lesson.audio?.checksum,
          'synced_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }

    await db.insert(
      'sync_meta',
      {
        'id': 1,
        'manifest_version': manifest.version,
        'last_sync_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    return SyncResult.updated;
  }
}
```

Add the sqflite import at the top:
```dart
import 'package:sqflite/sqflite.dart' as sqflite;
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd src/mobile && flutter test test/data/services/content_sync_service_test.dart -v
```

Expected: All 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add src/mobile/lib/data/services/content_sync_service.dart src/mobile/test/data/services/content_sync_service_test.dart src/mobile/test/data/services/content_sync_service_test.mocks.dart
git commit -m "feat: add ContentSyncService with checksum-based sync logic"
```

---

## Task 7: Update Lesson model and ContentRepository

**Files:**
- Modify: `src/mobile/lib/data/models/lesson.dart`
- Modify: `src/mobile/lib/data/repositories/content_repository.dart`
- Test: `src/mobile/test/data/repositories/content_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Create `src/mobile/test/data/repositories/content_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/data/repositories/content_repository.dart';

@GenerateMocks([DatabaseHelper])
import 'content_repository_test.mocks.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late MockDatabaseHelper mockDb;
  late ContentRepository repo;

  setUp(() {
    mockDb = MockDatabaseHelper();
    repo = ContentRepository(dbHelper: mockDb);
  });

  test('loadLessons returns lessons from SQLite', () async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE lessons (
          id INTEGER PRIMARY KEY, title TEXT NOT NULL,
          audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT,
          pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL,
          synced_at INTEGER NOT NULL
        )
      ''');
      await db.insert('lessons', {
        'id': 1, 'title': 'Qual o Fim principal?',
        'pdf_local_path': 'betelsas/lessons/1/lesson.pdf',
        'pdf_checksum': 'abc',
        'audio_local_path': 'betelsas/lessons/1/audio.mp3',
        'audio_ext': 'mp3', 'audio_checksum': 'def',
        'synced_at': 0,
      });
    });
    when(mockDb.database).thenAnswer((_) async => db);

    final lessons = await repo.loadLessons();
    expect(lessons.length, 1);
    expect(lessons.first.id, 1);
    expect(lessons.first.title, 'Qual o Fim principal?');
    expect(lessons.first.localPdfPath, 'betelsas/lessons/1/lesson.pdf');
    expect(lessons.first.localAudioPath, 'betelsas/lessons/1/audio.mp3');
  });

  test('loadLessons returns empty list when no lessons in db', () async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE lessons (
          id INTEGER PRIMARY KEY, title TEXT NOT NULL,
          audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT,
          pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL,
          synced_at INTEGER NOT NULL
        )
      ''');
    });
    when(mockDb.database).thenAnswer((_) async => db);

    final lessons = await repo.loadLessons();
    expect(lessons, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd src/mobile && flutter test test/data/repositories/content_repository_test.dart -v
```

Expected: FAIL — `localPdfPath` not found on `Lesson`.

- [ ] **Step 3: Update Lesson model**

Replace `src/mobile/lib/data/models/lesson.dart`:

```dart
class Lesson {
  final int id;
  final String title;
  final String localPdfPath;
  final String? localAudioPath;
  final String? audioExt;

  Lesson({
    required this.id,
    required this.title,
    required this.localPdfPath,
    this.localAudioPath,
    this.audioExt,
  });

  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'] as int,
      title: map['title'] as String,
      localPdfPath: map['pdf_local_path'] as String,
      localAudioPath: map['audio_local_path'] as String?,
      audioExt: map['audio_ext'] as String?,
    );
  }
}
```

- [ ] **Step 4: Update ContentRepository**

Replace `src/mobile/lib/data/repositories/content_repository.dart`:

```dart
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/data/models/lesson.dart';

class ContentRepository {
  final DatabaseHelper _dbHelper;

  ContentRepository({required DatabaseHelper dbHelper}) : _dbHelper = dbHelper;

  Future<List<Lesson>> loadLessons() async {
    final db = await _dbHelper.database;
    final rows = await db.query('lessons', orderBy: 'id ASC');
    return rows.map(Lesson.fromMap).toList();
  }

  Future<List<Lesson>> loadLessonsWithAudio() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'lessons',
      where: 'audio_local_path IS NOT NULL',
      orderBy: 'id ASC',
    );
    return rows.map(Lesson.fromMap).toList();
  }
}
```

- [ ] **Step 5: Generate mocks and run tests**

```bash
cd src/mobile && dart run build_runner build --delete-conflicting-outputs && flutter test test/data/repositories/content_repository_test.dart -v
```

Expected: All 2 tests PASS.

- [ ] **Step 6: Fix compilation errors from Lesson model change**

The old `Lesson` model had `imageUrl`, `content`, `scriptureReference`, `pdfUrl`, `song`, `flashcards`. Run the full test suite to find compile errors:

```bash
cd src/mobile && flutter analyze
```

For each file that references removed fields, update it to use the new fields:
- `pdfUrl` → `localPdfPath` (resolve full path with `path_provider` at the call site)
- `song?.audioUrl` → `localAudioPath` (resolve full path at call site)
- `imageUrl`, `content`, `scriptureReference`, `flashcards` → remove from UI or replace with placeholder until new design is implemented

- [ ] **Step 7: Commit**

```bash
git add src/mobile/lib/data/models/lesson.dart src/mobile/lib/data/repositories/content_repository.dart src/mobile/test/data/repositories/content_repository_test.dart src/mobile/test/data/repositories/content_repository_test.mocks.dart
git commit -m "feat: rewrite Lesson model and ContentRepository to read from SQLite"
```

---

## Task 8: Register providers

**Files:**
- Modify: `src/mobile/lib/core/providers.dart`

- [ ] **Step 1: Update providers.dart**

Replace `src/mobile/lib/core/providers.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelsas/core/connectivity_service.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/data/repositories/content_repository.dart';
import 'package:betelsas/data/repositories/flashcard_repository.dart';
import 'package:betelsas/data/repositories/favorites_repository_impl.dart';
import 'package:betelsas/data/services/content_sync_service.dart';
import 'package:betelsas/data/services/remote_content_service.dart';
import 'package:betelsas/domain/repositories/favorites_repository.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper());

final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityService());

final remoteContentServiceProvider = Provider<RemoteContentService>((ref) => RemoteContentService(dio: Dio()));

final contentSyncServiceProvider = Provider<ContentSyncService>((ref) {
  return ContentSyncService(
    remote: ref.watch(remoteContentServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    dbHelper: ref.watch(databaseHelperProvider),
  );
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(dbHelper: ref.watch(databaseHelperProvider));
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepositoryImpl(ref.watch(databaseHelperProvider));
});

final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  return FlashcardRepository(ref.watch(contentRepositoryProvider), ref.watch(databaseHelperProvider));
});
```

- [ ] **Step 2: Verify no compile errors**

```bash
cd src/mobile && flutter analyze
```

Expected: No errors (warnings OK).

- [ ] **Step 3: Commit**

```bash
git add src/mobile/lib/core/providers.dart
git commit -m "feat: register ConnectivityService, RemoteContentService, ContentSyncService providers"
```

---

## Task 9: Update SplashScreen with sync flow

**Files:**
- Modify: `src/mobile/lib/presentation/screens/splash_screen.dart`

- [ ] **Step 1: Replace splash_screen.dart**

Replace `src/mobile/lib/presentation/screens/splash_screen.dart`:

```dart
import 'package:betelsas/data/services/content_sync_service.dart';
import 'package:betelsas/presentation/widgets/main_scaffold.dart';
import 'package:betelsas/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _runSync();
  }

  Future<void> _runSync() async {
    final syncService = ref.read(contentSyncServiceProvider);
    final connectivity = ref.read(connectivityServiceProvider);

    final isMobile = await connectivity.isMobileData();
    if (isMobile) {
      final shouldProceed = await _showMobileDataDialog();
      if (!shouldProceed) {
        _navigate(SyncResult.offlineWithData);
        return;
      }
    }

    final result = await syncService.sync(
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Baixando lição ${progress.current} de ${progress.total}…';
          });
        }
      },
    );

    if (mounted) _navigate(result);
  }

  Future<bool> _showMobileDataDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Dados Móveis'),
            content: const Text(
                'Você está em dados móveis. Deseja baixar o conteúdo agora?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Agora não'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Baixar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _navigate(SyncResult result) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainScaffold(syncResult: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/images/splash_screen_image.jpg',
              fit: BoxFit.contain,
            ),
          ),
          if (_statusMessage.isNotEmpty)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update MainScaffold to accept syncResult**

In `src/mobile/lib/presentation/widgets/main_scaffold.dart`, add a `syncResult` parameter and pass it down to `HomeScreen`. Find the constructor and add:

```dart
final SyncResult? syncResult;
const MainScaffold({super.key, this.syncResult});
```

Pass `syncResult` to `HomeScreen` when constructing it in the tab body.

- [ ] **Step 3: Verify no compile errors**

```bash
cd src/mobile && flutter analyze
```

- [ ] **Step 4: Commit**

```bash
git add src/mobile/lib/presentation/screens/splash_screen.dart src/mobile/lib/presentation/widgets/main_scaffold.dart
git commit -m "feat: update SplashScreen with sync flow and progress indicator"
```

---

## Task 10: Update HomeScreen — offline states and pull-to-refresh

**Files:**
- Modify: `src/mobile/lib/presentation/screens/home/home_screen.dart`
- Modify: `src/mobile/lib/presentation/screens/home/home_view_model.dart`

- [ ] **Step 1: Add syncResult param and offline banner to HomeScreen**

In `src/mobile/lib/presentation/screens/home/home_screen.dart`:

1. Add constructor param: `final SyncResult? syncResult;`
2. Wrap `CustomScrollView` in `RefreshIndicator` that calls `ref.refresh(homeViewModelProvider)`
3. Add offline banner below `BetelHeader` when `syncResult == SyncResult.offlineWithData`:

```dart
if (widget.syncResult == SyncResult.offlineWithData)
  Container(
    color: Colors.orange.shade100,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: const Row(
      children: [
        Icon(Icons.wifi_off, size: 16, color: Colors.orange),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Você está offline — o conteúdo pode estar desatualizado',
            style: TextStyle(fontSize: 12, color: Colors.orange),
          ),
        ),
      ],
    ),
  ),
```

4. Replace the `lessons.isEmpty` empty state to differentiate between no-internet first boot and genuinely empty:

```dart
data: (lessons) {
  if (lessons.isEmpty && widget.syncResult == SyncResult.offlineFirstBoot) {
    return const SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('Sem conexão com a internet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('�� necessário conexão para fazer o download do conteúdo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
  // ... existing lesson list rendering
},
```

- [ ] **Step 2: Wrap with RefreshIndicator**

In `home_screen.dart`, wrap the `CustomScrollView` with `RefreshIndicator`:

```dart
return RefreshIndicator(
  onRefresh: () async {
    final syncService = ref.read(contentSyncServiceProvider);
    await syncService.sync();
    ref.invalidate(homeViewModelProvider);
  },
  child: CustomScrollView(/* existing content */),
);
```

- [ ] **Step 3: Update home_view_model.dart to use ContentRepository from SQLite**

In `src/mobile/lib/presentation/screens/home/home_view_model.dart`, ensure `homeViewModelProvider` calls `contentRepository.loadLessons()` (it likely already does — verify the import resolves with the updated `ContentRepository` constructor that now requires `dbHelper`).

- [ ] **Step 4: Verify app compiles and runs**

```bash
cd src/mobile && flutter analyze && flutter run
```

Walk through:
1. First launch: sync runs, progress shows on splash, lessons appear on home
2. Pull down on home: RefreshIndicator fires, lessons refresh
3. Airplane mode + fresh install: home shows "Sem conexão com a internet" message

- [ ] **Step 5: Commit**

```bash
git add src/mobile/lib/presentation/screens/home/home_screen.dart src/mobile/lib/presentation/screens/home/home_view_model.dart
git commit -m "feat: add offline banner, first-boot empty state, and pull-to-refresh to HomeScreen"
```

---

## Task 11: Run full test suite and final check

- [ ] **Step 1: Run all tests**

```bash
cd src/mobile && flutter test
```

Expected: All tests pass. Fix any failures before proceeding.

- [ ] **Step 2: Check for unused imports left from old Lesson model**

```bash
cd src/mobile && flutter analyze 2>&1 | grep -i "unused\|undefined"
```

Fix any reported issues.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete MinIO content sync integration"
```
