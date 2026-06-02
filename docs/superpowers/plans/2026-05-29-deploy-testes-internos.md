# Deploy Testes Internos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configurar Fastlane com Google Play API e criar a skill `/deploy-testes-internos` que faz push do branch main e publica o AAB na faixa de teste interno do Play Store.

**Architecture:** Ruby/Fastlane instalado via rbenv (sem conflito com sistema), configurado no `src/mobile/`. A skill de projeto invoca um script shell que incrementa o versionCode, faz push, builda o AAB e chama `fastlane supply` para upload. A autenticação usa uma Service Account do Google Cloud com JSON de credenciais armazenado no Bitwarden.

**Tech Stack:** Fastlane (supply plugin), rbenv, Google Play Developer API v3, Flutter (pubspec.yaml versionCode), adb

---

## File Structure

| Arquivo | Ação | Responsabilidade |
|---------|------|-----------------|
| `src/mobile/fastlane/Appfile` | Criar | Package name e caminho da service account |
| `src/mobile/fastlane/Fastfile` | Criar | Lane `internal` que chama supply |
| `src/mobile/Gemfile` | Criar | Dependências Ruby (fastlane) |
| `scripts/deploy-internal.sh` | Criar | Incrementa versionCode, build, push, fastlane |
| `.claude/skills/deploy-testes-internos.md` | Criar | Skill do projeto para `/deploy-testes-internos` |
| `.gitignore` | Modificar | Ignorar JSON de credenciais da service account |

---

## Task 1: Instalar rbenv e Ruby

**Files:**
- Modifica: `~/.bashrc` (rbenv init — feito pelo instalador)

- [ ] **Step 1: Instalar rbenv via apt**

```bash
sudo apt-get install -y rbenv ruby-build
```

- [ ] **Step 2: Inicializar rbenv no shell atual**

```bash
eval "$(rbenv init -)"
```

- [ ] **Step 3: Instalar Ruby 3.2.2**

```bash
rbenv install 3.2.2
rbenv global 3.2.2
ruby --version
```

Esperado: `ruby 3.2.2 ...`

- [ ] **Step 4: Instalar Bundler**

```bash
gem install bundler
bundler --version
```

---

## Task 2: Configurar Fastlane no projeto

**Files:**
- Criar: `src/mobile/Gemfile`
- Criar: `src/mobile/fastlane/Appfile`
- Criar: `src/mobile/fastlane/Fastfile`

- [ ] **Step 1: Criar Gemfile**

```ruby
# src/mobile/Gemfile
source "https://rubygems.org"

gem "fastlane"
```

- [ ] **Step 2: Instalar dependências**

```bash
cd src/mobile
bundle install
```

Esperado: `Bundle complete!`

- [ ] **Step 3: Criar fastlane/Appfile**

```ruby
# src/mobile/fastlane/Appfile
package_name("com.kajiyama.betelapp")
json_key_file(ENV["PLAY_STORE_JSON_KEY"] || "fastlane/play-store-credentials.json")
```

- [ ] **Step 4: Criar fastlane/Fastfile**

```ruby
# src/mobile/fastlane/Fastfile
default_platform(:android)

platform :android do
  desc "Upload AAB to internal testing track"
  lane :internal do
    upload_to_play_store(
      track: "internal",
      aab: "build/app/outputs/bundle/release/app-release.aab",
      release_status: "draft",
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
end
```

- [ ] **Step 5: Verificar que fastlane reconhece a lane**

```bash
cd src/mobile
bundle exec fastlane lanes
```

Esperado: lista com `internal`

- [ ] **Step 6: Commit**

```bash
git add src/mobile/Gemfile src/mobile/Gemfile.lock src/mobile/fastlane/
git commit -m "chore(mobile): configure fastlane for internal track deploy"
```

---

## Task 3: Criar Service Account no Google Cloud e salvar no Bitwarden

**Files:** (sem arquivos de código — configuração externa)

- [ ] **Step 1: Acessar Google Cloud Console**

Acesse https://console.cloud.google.com → selecione o projeto vinculado ao Play Store.

- [ ] **Step 2: Criar Service Account**

Menu → IAM & Admin → Service Accounts → Create Service Account
- Nome: `fastlane-deploy`
- Role: nenhuma (o acesso é configurado no Play Console)
- Clique em Create and Continue → Done

- [ ] **Step 3: Gerar chave JSON**

Na lista de Service Accounts → clique na conta criada → Keys → Add Key → Create new key → JSON → Download

O arquivo baixado tem o formato `<project-id>-<hash>.json`.

- [ ] **Step 4: Dar acesso no Play Console**

Play Console → Setup → API access → Link ao projeto Google Cloud (se não estiver vinculado) → Grant access à service account criada → Permissão: **Release manager** → Save

- [ ] **Step 5: Salvar JSON no Bitwarden**

```bash
MASTER=$(secret-tool lookup service bitwarden account master)
bw serve --port 8088 &>/dev/null &
sleep 2
curl -s -X POST http://localhost:8088/unlock \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$MASTER\"}"

JSON_CONTENT=$(cat ~/Downloads/<nome-do-arquivo>.json | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))")
curl -s -X POST http://localhost:8088/object/item \
  -H "Content-Type: application/json" \
  -d "{\"type\":2,\"name\":\"BetelApp Play Store Service Account\",\"notes\":$JSON_CONTENT,\"organizationId\":null}"

kill $(pgrep -f "bw serve")
```

- [ ] **Step 6: Verificar que o item foi salvo**

```bash
MASTER=$(secret-tool lookup service bitwarden account master)
bw serve --port 8088 &>/dev/null &
sleep 2
curl -s -X POST http://localhost:8088/unlock \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$MASTER\"}" > /dev/null
curl -s "http://localhost:8088/list/object/items?search=BetelApp+Play+Store" | python3 -c "
import json,sys
items = json.load(sys.stdin)['data']['data']
for i in items: print(i['name'])
"
kill $(pgrep -f "bw serve")
```

Esperado: `BetelApp Play Store Service Account`

---

## Task 4: Criar script de deploy

**Files:**
- Criar: `scripts/deploy-internal.sh`

- [ ] **Step 1: Criar o script**

```bash
#!/usr/bin/env bash
# scripts/deploy-internal.sh
set -euo pipefail

PUBSPEC="src/mobile/pubspec.yaml"
MOBILE_DIR="src/mobile"
CREDENTIALS_TMP=$(mktemp /tmp/play-credentials-XXXXXX.json)

cleanup() { rm -f "$CREDENTIALS_TMP"; }
trap cleanup EXIT

# 1. Verificar branch main
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
  echo "Erro: deve estar no branch main (atual: $BRANCH)"
  exit 1
fi

# 2. Verificar working tree limpo
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Erro: há mudanças não commitadas. Faça commit antes de publicar."
  exit 1
fi

# 3. Incrementar versionCode
CURRENT=$(grep '^version:' "$PUBSPEC" | cut -d'+' -f2)
NEXT=$((CURRENT + 1))
VERSION_NAME=$(grep '^version:' "$PUBSPEC" | cut -d'+' -f1 | cut -d' ' -f2)
sed -i "s/^version: .*/version: ${VERSION_NAME}+${NEXT}/" "$PUBSPEC"
echo "versionCode: $CURRENT → $NEXT"

# 4. Commit e push
git add "$PUBSPEC"
git commit -m "chore: bump versionCode to $NEXT for internal release"
git push origin main

# 5. Buscar credenciais do Bitwarden
echo "Buscando credenciais no Bitwarden..."
MASTER=$(secret-tool lookup service bitwarden account master)
bw serve --port 8088 &>/dev/null &
BW_PID=$!
sleep 2
curl -s -X POST http://localhost:8088/unlock \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$MASTER\"}" > /dev/null

curl -s "http://localhost:8088/list/object/items?search=BetelApp+Play+Store" \
  | python3 -c "
import json,sys
items = json.load(sys.stdin)['data']['data']
print(items[0]['notes'])
" > "$CREDENTIALS_TMP"

kill $BW_PID 2>/dev/null || true

# 6. Build AAB
echo "Building AAB..."
cd "$MOBILE_DIR"
flutter build appbundle --release

# 7. Upload via Fastlane
echo "Publicando na faixa de teste interno..."
PLAY_STORE_JSON_KEY="$CREDENTIALS_TMP" bundle exec fastlane internal

echo "Publicado com sucesso! versionCode=$NEXT"
```

- [ ] **Step 2: Tornar executável**

```bash
chmod +x scripts/deploy-internal.sh
```

- [ ] **Step 3: Adicionar credenciais ao .gitignore**

No arquivo `.gitignore` raiz, adicionar:
```
fastlane/play-store-credentials.json
```

- [ ] **Step 4: Commit**

```bash
git add scripts/deploy-internal.sh .gitignore
git commit -m "chore: add deploy-internal script"
```

---

## Task 5: Criar skill do projeto `/deploy-testes-internos`

**Files:**
- Criar: `.claude/skills/deploy-testes-internos.md`

- [ ] **Step 1: Criar diretório de skills do projeto**

```bash
mkdir -p .claude/skills
```

- [ ] **Step 2: Criar o arquivo da skill**

```markdown
---
name: deploy-testes-internos
description: Deploy to Play Store internal testing track — bumps versionCode, pushes main, builds AAB, uploads via Fastlane
---

## deploy-testes-internos

Run the internal deploy pipeline:

1. Announce: "Running /deploy-testes-internos — publishing to Play Store internal track."
2. Confirm with the user that main is ready to publish (any last checks?)
3. Run from the repo root: `bash scripts/deploy-internal.sh`
4. Report the versionCode that was published and confirm success.

If the script fails, read the error output and fix the root cause before retrying.
Do NOT retry blindly — if versionCode was already bumped and committed, the next run will increment again.
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/deploy-testes-internos.md
git commit -m "chore: add /deploy-testes-internos project skill"
```

---

## Task 6: Teste de ponta a ponta

- [ ] **Step 1: Invocar a skill no Claude Code**

Digitar: `/deploy-testes-internos`

- [ ] **Step 2: Confirmar no Play Console**

Play Console → Teste interno → verificar que a nova versão aparece com o versionCode correto.
