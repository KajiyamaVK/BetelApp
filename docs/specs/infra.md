---
layer: infra
project: shared
last_reviewed: 2026-05-31
---

## Propósito

Governa decisões de infraestrutura compartilhada do projeto — CI/CD pipeline, Docker Compose, hosting, topologia de serviços, e gerenciamento de variáveis de ambiente que cruzam subprojetos.

## Decisões

### CI/CD

- **Jenkins com trigger `githubPush()`** — CI/CD via webhook do GitHub, sem polling.
  - **Por quê:** Jenkins já está rodando no homelab e integra com Docker nativamente. Não justifica pagar por CI cloud para um projeto pessoal.

- **Gate de deploy em `origin/main`** — todas as stages de deploy verificam `env.GIT_BRANCH == 'origin/main'`. Nenhum branch deploy.

- **Notificações de build via webhook** — cada pipeline event (`started`, `success`, `failure`, `aborted`) envia um POST JSON para `http://host.docker.internal:3000/notifications/jenkins` (o `my-agents-homelab` rodando no host). O payload inclui `status`, `pipeline`, `branch`, `buildUrl` e `buildNumber`. `jq` é usado para serializar o payload, evitando injeção por nomes de branch com caracteres especiais.
  - **Por quê:** Permite que o agente pessoal receba alertas de build sem expor o Jenkins publicamente ou depender de plugins externos de notificação.

- **Mobile build stage — change-gated, Dockerised** — o stage `Mobile: Build & Deploy to Play Store` só executa em `origin/main` e quando ao menos um dos seguintes arquivos muda: `src/mobile/pubspec.yaml`, `src/mobile/fastlane/Fastfile`, ou qualquer changelog em `src/mobile/fastlane/metadata/android/pt-BR/changelogs/**`. Um parâmetro booleano `FORCE_MOBILE` permite forçar o build manualmente sem alterar arquivos.
  - O build roda dentro de `betelapp-mobile-ci` (imagem construída a partir de `src/mobile/Dockerfile.ci`). O Android SDK está pré-compilado na imagem; apenas o cache Gradle é persistido em `/var/cache/betelapp/gradle` via volume mount no host.
  - Segredos (Play Store JSON, `key.properties`, `betelsas.keystore`) são injetados via `withCredentials` do Jenkins e copiados para `$APP_DIR/src/mobile/.ci-secrets` com `chmod 700`. Um `trap EXIT` garante remoção imediata após o container encerrar — eles nunca ficam em disco.
  - O container invoca a lane `internal` do Fastlane para upload na internal testing track da Play Store.
  - **Por quê:** O change-gate evita builds desnecessários quando apenas o backend muda. O Docker garante reproducibilidade sem instalar Flutter no agente Jenkins. O cache Gradle reduz o tempo de build de ~15 min para ~3 min em builds incrementais.
  - **Por quê:** O projeto é desenvolvido por uma pessoa. Feature branches passam pelos testes mas só fazem deploy quando mergeados em main.

- **Sync via `rsync -a --delete` para o host path** — Jenkins copia o workspace para `/home/kajiyamavk/src/BetelApp` no servidor, excluindo:

  | Path excluído | Motivo |
  |---------------|--------|
  | `.env*` | Segredos de produção gerenciados manualmente no host |
  | `.ci` | Diretório de artefatos CI gerenciados no host (não versionado) |
  | `node_modules` | Rebuilt pelo Docker no host; sobrescrever causaria conflitos |
  | `.next` | Artefato de build do Next.js; gerado pelo Docker |
  | `.prisma` | Prisma client gerado; rebuilt após migrations |

  - **Por quê:** O host path contém segredos e artefatos gerados que não devem ser sobrescritos pelo CI. O rsync com excludes permite atualizar o código sem tocar nos segredos.

- **Jenkinsfile no root** — pipeline declarativo, um Jenkinsfile para todo o monorepo.

- **Deploy via `docker compose` com compose file dedicado** — o stage `Build & Deploy` executa:
  ```
  docker compose --env-file src/s3-ui/.env.production -f src/s3-ui/docker-compose.prod.yml \
      build --build-arg GIT_COMMIT=<sha>
  docker compose ... up -d --wait --wait-timeout 180
  ```
  - `docker-compose.prod.yml` é o compose file de produção (separado do `docker-compose.yml` usado em dev).
  - `.env.production` fica apenas no host — nunca no repositório.
  - `GIT_COMMIT` é passado como build arg para que o SHA do commit fique disponível dentro da imagem (ex: endpoint `/health`).
  - `--wait --wait-timeout 180` bloqueia o stage até todos os containers reportarem healthy (timeout de 3 minutos).

- **Migrações via profile `migrate`** — após o deploy, o stage `Migrate` sobe o serviço `migrator` (definido em `docker-compose.prod.yml` sob `--profile migrate`) que executa `prisma migrate deploy` contra o banco de produção e é removido com `--rm`.
  - **Por quê:** Manter as migrações num container efêmero separado evita que o container principal suba com schema desatualizado e garante que `migrate deploy` rode em ordem, após o build da nova imagem.

### Topologia de serviços

| Serviço | Host | Detalhes |
|---------|------|----------|
| PostgreSQL | homelab (interno) | Porta 5432; DBs: `betelapp`, `betelapp_dev`, `betelapp_test` |
| MinIO (S3) | `s3.kajiyama.com.br` | Porta 443, SSL; buckets: `betelapp-content`, `betelapp-content-dev` |
| App s3-ui | host:3001 | Container na 3000 → host 3001; reverse proxy na frente (não no repo) |
| Google Play Store | externo | Internal testing track via Fastlane |
| Jenkins | homelab | Trigger via GitHub webhooks |
| GitHub | `github.com/KajiyamaVK/BetelApp` | Source of truth do código |

### Scripts compartilhados

- **`scripts/migrate_manifest.sh`** — utilitário one-time para migrar o manifest de paths sem versão (`audio.mp3`) para paths versionados (`audio_v1.mp3`). Usa `mc` (MinIO client). Idempotente.
  - **Por quê:** Antes do sistema de versionamento de arquivos, os paths não tinham sufixo `_vN`. O script migrou os 24 lessons de uma vez.

- **`scripts/pre-push.hook`** — hook de pre-push que bloqueia pushes até que todos os gates passem. Deve ser linkado manualmente em `.git/hooks/pre-push` (não há script de auto-instalação). Gates executados em ordem:

  | Gate | Comando | Diretório |
  |------|---------|-----------|
  | Mobile unit tests | `flutter test` | `src/mobile` |
  | Mobile integration tests | `./scripts/run_integration_tests.sh` | `src/mobile` |
  | s3-ui Jest (sem coverage) | `npm test -- --no-coverage` | `src/s3-ui` |
  | s3-ui Playwright E2E | `npm run test:e2e` | `src/s3-ui` |
  | TypeScript check | `npx tsc --noEmit` | `src/s3-ui` |
  | Changelog gate (main only) | verifica `fastlane/metadata/.../changelogs/<versionCode>.txt` | repo root |

  O gate de Jest usa credenciais hardcoded para `betelapp_test` em `homelab:5432` — não depende de `.env.test` local. O changelog gate só executa quando o branch de push é `main`; bloqueia se o arquivo `src/mobile/fastlane/metadata/android/pt-BR/changelogs/<versionCode>.txt` estiver ausente ou vazio.
  - **Por quê:** Impede que código quebrado ou faltando changelog chegue ao CI/CD, onde uma falha custa mais tempo do que uma falha local.

### NPM scripts no root

- **`package.json` na raiz** — orquestra testes de todos os subprojetos:
  | Script | O que faz |
  |--------|-----------|
  | `test` | `cd src/mobile && flutter test` |
  | `test:integration` | `cd src/mobile && ./scripts/run_integration_tests.sh` |
  | `test:all` | unit + integration do mobile |
  | `test:s3-ui` | Jest tests do s3-ui (sem coverage) |
  | `test:s3-ui:e2e` | Playwright E2E do s3-ui |

  Nota: o TypeScript check (`npx tsc --noEmit`) do s3-ui **não tem script npm no root** — ele só é executado pelo `scripts/pre-push.hook`. Para rodar manualmente: `cd src/s3-ui && npx tsc --noEmit`.

### Hosting

- **Homelab self-hosted** — todo o backend (PostgreSQL, MinIO, Jenkins, app) roda no homelab pessoal.
  - **Por quê:** Custo zero de hosting. O app é de uso interno (catecismo de uma igreja) com poucos usuários.

- **Reverse proxy** na frente do container s3-ui (porta 3001) — configuração do proxy **não está no repositório**.

## O que NÃO fazer

- **Não sobrescrever `.env*` via rsync/CI** — segredos de produção são gerenciados manualmente no host, nunca versionados.
- **Não fazer deploy de branches que não sejam main** — o pipeline está desenhado para single-track deploy.
- **Não remover o `rsync --delete` sem entender os excludes** — o `--delete` remove arquivos que não estão no workspace, mas os excludes protegem segredos e artefatos.
- **Não migrar para CI cloud** sem necessidade — o Jenkins no homelab atende o escopo atual sem custo.
- **Não colocar configuração do reverse proxy no repo** — atualmente é gerenciada fora do projeto.
