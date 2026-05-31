#!/bin/sh
set -e
# Regenerate Prisma client against the current schema before pushing —
# ensures the client matches the schema even if the image was built from an older layer.
DATABASE_URL=postgresql://x:x@localhost/x npx prisma generate
npx prisma db push
