---
name: data-dump-to-dev
description: Use when the user wants to copy all production data (lessons, Q&As, users, audit logs, MinIO files) into the dev environment for BetelApp.
---

# Data Dump to Dev

Replaces everything in the dev environment with a full copy of production: all Postgres tables and all MinIO bucket contents.

## What gets replaced

| | Source (prod) | Destination (dev) |
|---|---|---|
| Postgres DB | `betelapp` | `betelapp_dev` |
| MinIO bucket | `betelapp-content` | `betelapp-content-dev` |

All five tables are replaced: `User`, `Lesson`, `Question`, `LessonAuditLog`, `QuestionAuditLog`.

## Credentials

**Never hardcode credentials.** All DB and MinIO credentials are read from `src/s3-ui/.env.development` at runtime. The prod DB URL is derived from the dev URL by swapping the database name (`betelapp_dev` → `betelapp`) — same host, same user, same password.

```bash
cd src/s3-ui
source .env.development
PROD_DB="${DATABASE_URL/betelapp_dev/betelapp}"
DEV_DB="$DATABASE_URL"
```

## Steps

### 1 — Sync MinIO bucket (prod → dev)

```bash
mc mirror --overwrite betelsas-dev/betelapp-content betelsas-dev/betelapp-content-dev
```

This copies every object (manifest.json + all lesson files) from the prod bucket into the dev bucket, overwriting anything that already exists. The `mc` alias `betelsas-dev` is already configured.

### 2 — Truncate all tables in dev DB

Truncate in dependency order with CASCADE to avoid FK conflicts:

```bash
psql "$DEV_DB" -c '
TRUNCATE TABLE "QuestionAuditLog", "LessonAuditLog", "Question", "Lesson", "User" CASCADE;
'
```

### 3 — Dump prod data and restore into dev

```bash
pg_dump "$PROD_DB" \
  --data-only \
  --disable-triggers \
  --no-password \
  | psql "$DEV_DB"
```

- `--data-only` — skips DDL; Prisma already manages the schema
- `--disable-triggers` — suppresses FK trigger checks during import so row insertion order doesn't cause constraint errors
- No `--password` flag needed; credentials come from the connection string in `$PROD_DB`

### 4 — Verify

```bash
psql "$DEV_DB" -c '
SELECT
  (SELECT COUNT(*) FROM "User")                                  AS users,
  (SELECT COUNT(*) FROM "Lesson")                               AS lessons,
  (SELECT COUNT(*) FROM "Question" WHERE "deletedAt" IS NULL)   AS active_questions,
  (SELECT COUNT(*) FROM "LessonAuditLog")                       AS lesson_audit,
  (SELECT COUNT(*) FROM "QuestionAuditLog")                     AS question_audit;
'
```

Row counts should match production exactly.

## What is NOT touched

- The test database (`betelapp_test`) — run `npm run db:setup:test` separately if needed
- The `betelapp-content-test` MinIO bucket
- Any Jenkins credentials, Bitwarden entries, or local `.env` files
