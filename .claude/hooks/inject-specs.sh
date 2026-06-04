#!/usr/bin/env bash
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then exit 0; fi

SPEC_PATHS=(
  "docs/specs-index.md"
  "docs/specs/infra.md"
  "src/mobile/specs/ui.md"
  "src/mobile/specs/business.md"
  "src/mobile/specs/data.md"
  "src/mobile/specs/infra.md"
  "src/s3-ui/specs/ui.md"
  "src/s3-ui/specs/business.md"
  "src/s3-ui/specs/data.md"
  "src/s3-ui/specs/infra.md"
  "src/backend/specs/ui.md"
  "src/backend/specs/business.md"
  "src/backend/specs/data.md"
  "src/backend/specs/infra.md"
)

context=""
loaded=()
for rel in "${SPEC_PATHS[@]}"; do
  abs="$REPO_ROOT/$rel"
  if [ -f "$abs" ]; then
    content=$(cat "$abs")
    context="${context}
--- $rel ---
$content
"
    loaded+=("$rel")
  fi
done

if [ -z "$context" ]; then exit 0; fi

summary=$(printf '%s\n' "${loaded[@]}" | sed 's/^/  - /')

python3 - <<PYEOF
import json
context = """=== SPECS CARREGADOS AUTOMATICAMENTE ===
Estes spec files são a fonte de verdade do projeto. Leia-os antes de propor qualquer implementação.

$summary

$context
=== FIM DOS SPECS ==="""
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": context}}))
PYEOF
