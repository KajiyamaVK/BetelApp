#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-}"
if [[ "$ENV" != "dev" && "$ENV" != "test" ]]; then
  echo "Usage: $0 <dev|test>" >&2
  exit 1
fi

ENV_FILE=".env.${ENV}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found. Copy .env.example and fill in the values." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

echo "==> Setting up betelapp_${ENV} (${DATABASE_URL%%@*}@...)"

echo "--- prisma db push"
npx prisma db push

echo "--- prisma generate"
npx prisma generate

echo "--- seed"
npx tsx prisma/seed.ts

echo "==> Done."
