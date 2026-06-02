#!/usr/bin/env bash
# migrate_manifest.sh
# Migrates BetelApp MinIO content to versioned filenames and generates new manifest.json
#
# What it does:
#   1. Copies audio.mp3 -> audio_v1.mp3 and lesson.pdf -> lesson_v1.pdf in S3
#   2. Removes the old unversioned files
#   3. Downloads each versioned file via HTTP to compute MD5 checksums
#   4. Generates and uploads a new manifest.json in the versioned schema

set -euo pipefail

MC="/tmp/mc"
ALIAS="homelab-minio"
BUCKET="betelapp-content"
BASE_URL="http://s3.kajiyama.com.br/betelapp-content"
UPDATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

declare -a TITLES=(
  "Qual o Fim principal?"
  "Que regra deu Deus?"
  "O que a escritura nos ensina?"
  "Quem é Deus?"
  "Será que existe mais de um Deus?"
  "Quantas pessoas há na divindade?"
  "Que são os Decretos de Deus?"
  "Como Deus executa seus decretos?"
  "Quais são as obras da criação?"
  "Como criou Deus o homem?"
  "Quais as obras da providência?"
  "Que ato especial da providência?"
  "Conservaram-se nossos primeiros pais?"
  "O que é pecado?"
  "Qual o primeiro pecado?"
  "Caiu todo gênero humano em Adão?"
  "Qual foi o Estado a que a queda reduziu o gênero humano?"
  "Em que consiste o estado de miséria?"
  "Qual miséria do estado que o homem caiu?"
  "Deixou Deus todo o gênero humano perecer no estado de pecado e miséria?"
  "Quem é o Redentor dos escolhidos de Deus?"
  "Como Cristo se fez homem?"
  "Que funções exerce Cristo como nosso Redentor?"
  "Como exerce Cristo as funções de profeta?"
)

echo "=== BetelApp MinIO Manifest Migration ==="
echo "Timestamp: $UPDATED_AT"
echo ""

# Step 1: Copy unversioned files to versioned names, then remove originals
echo "--- Step 1: Renaming files to versioned names ---"
for i in $(seq 1 24); do
  AUDIO_SRC="$ALIAS/$BUCKET/lessons/$i/audio.mp3"
  AUDIO_DST="$ALIAS/$BUCKET/lessons/$i/audio_v1.mp3"
  PDF_SRC="$ALIAS/$BUCKET/lessons/$i/lesson.pdf"
  PDF_DST="$ALIAS/$BUCKET/lessons/$i/lesson_v1.pdf"

  # Check if versioned file already exists (idempotent)
  if "$MC" stat "$AUDIO_DST" &>/dev/null; then
    echo "  Lesson $i: audio_v1.mp3 already exists, skipping copy"
  else
    echo "  Lesson $i: copying audio.mp3 -> audio_v1.mp3"
    "$MC" cp "$AUDIO_SRC" "$AUDIO_DST"
    echo "  Lesson $i: removing audio.mp3"
    "$MC" rm "$AUDIO_SRC"
  fi

  if "$MC" stat "$PDF_DST" &>/dev/null; then
    echo "  Lesson $i: lesson_v1.pdf already exists, skipping copy"
  else
    echo "  Lesson $i: copying lesson.pdf -> lesson_v1.pdf"
    "$MC" cp "$PDF_SRC" "$PDF_DST"
    echo "  Lesson $i: removing lesson.pdf"
    "$MC" rm "$PDF_SRC"
  fi
done

echo ""
echo "--- Step 2: Computing MD5 checksums from HTTP ---"

# Helper: compute MD5 of a remote file via curl
compute_md5() {
  local url="$1"
  curl -s --fail "$url" | md5sum | cut -d' ' -f1
}

# Step 2 + 3: Download each file, compute MD5, build manifest JSON
LESSONS_JSON=""
for i in $(seq 1 24); do
  TITLE="${TITLES[$((i-1))]}"
  AUDIO_URL="$BASE_URL/lessons/$i/audio_v1.mp3"
  PDF_URL="$BASE_URL/lessons/$i/lesson_v1.pdf"

  echo "  Lesson $i: computing audio checksum..."
  AUDIO_MD5="$(compute_md5 "$AUDIO_URL")"

  echo "  Lesson $i: computing PDF checksum..."
  PDF_MD5="$(compute_md5 "$PDF_URL")"

  echo "  Lesson $i: audio=$AUDIO_MD5  pdf=$PDF_MD5"

  # Escape title for JSON (handle apostrophes and special chars via python)
  TITLE_JSON="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$TITLE")"

  LESSON_ENTRY=$(cat <<LESSON_EOF
    {
      "id": $i,
      "title": $TITLE_JSON,
      "pdf": {
        "active": "lessons/$i/lesson_v1.pdf",
        "checksum": "$PDF_MD5",
        "history": []
      },
      "audio": {
        "active": "lessons/$i/audio_v1.mp3",
        "ext": "mp3",
        "checksum": "$AUDIO_MD5",
        "history": []
      }
    }
LESSON_EOF
)

  if [ -z "$LESSONS_JSON" ]; then
    LESSONS_JSON="$LESSON_ENTRY"
  else
    LESSONS_JSON="$LESSONS_JSON,
$LESSON_ENTRY"
  fi
done

# Step 3: Assemble full manifest
MANIFEST=$(cat <<MANIFEST_EOF
{
  "version": 1,
  "updated_at": "$UPDATED_AT",
  "lessons": [
$LESSONS_JSON
  ]
}
MANIFEST_EOF
)

echo ""
echo "--- Step 3: Uploading new manifest.json ---"

# Write to temp file and upload
TMP_MANIFEST="$(mktemp /tmp/manifest_XXXXXX.json)"
echo "$MANIFEST" > "$TMP_MANIFEST"

# Validate JSON before uploading
python3 -m json.tool "$TMP_MANIFEST" > /dev/null && echo "  JSON validation: OK"

"$MC" cp "$TMP_MANIFEST" "$ALIAS/$BUCKET/manifest.json"
echo "  manifest.json uploaded successfully"

rm -f "$TMP_MANIFEST"

echo ""
echo "=== Migration complete! ==="
echo "Run verification with:"
echo "  curl -s http://s3.kajiyama.com.br/betelapp-content/manifest.json | python3 -m json.tool | head -50"
echo "  curl -I http://s3.kajiyama.com.br/betelapp-content/lessons/1/lesson_v1.pdf"
