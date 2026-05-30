# Database setup rule (s3-ui)

**Whenever the Prisma schema changes (new model, new field, index, relation), run the setup scripts to keep local DBs in sync. Never apply schema changes manually via psql.**

## Rule

After any change to `src/s3-ui/prisma/schema.prisma`:

1. Run `npm run db:setup:dev` — applies schema + regenerates Prisma client + seeds `betelapp_dev`
2. Run `npm run db:setup:test` — applies schema + regenerates Prisma client + seeds `betelapp_test`
3. In production (CI/pipeline) — only `prisma db push` against `betelapp` (no seed)

## How it works

`scripts/setup-db.sh <dev|test>` sources `.env.dev` or `.env.test` (never committed — in `.gitignore`), then runs:
- `prisma db push` — applies schema to that DB
- `prisma generate` — regenerates the Prisma client
- `tsx prisma/seed.ts` — seeds 24 lessons + victor admin user

## Environment files

| File | DB | Bucket | Committed |
|------|----|--------|-----------|
| `.env.dev` | `betelapp_dev` | `betelsas-content-dev` | No |
| `.env.test` | `betelapp_test` | `betelsas-content-test` | No |
| `.env.production` | `betelapp` | `betelsas-content` | No |

## Why

Forgetting to regenerate the Prisma client after a schema change causes runtime errors (`Unknown field`) that only appear at test/runtime, not at compile time. The setup script ensures generate always follows push.
