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
  - **Por quê:** O projeto é desenvolvido por uma pessoa. Feature branches passam pelos testes mas só fazem deploy quando mergeados em main.

- **Sync via `rsync -a --delete` para o host path** — Jenkins copia o workspace para `/home/kajiyamavk/src/BetelApp` no servidor, excluindo `.env*`, `.ci`, `node_modules`, `.next`, `.prisma`.
  - **Por quê:** O host path contém segredos e artefatos gerados que não devem ser sobrescritos pelo CI. O rsync com excludes permite atualizar o código sem tocar nos segredos.

- **Jenkinsfile no root** — pipeline declarativo, um Jenkinsfile para todo o monorepo.

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

### NPM scripts no root

- **`package.json` na raiz** — orquestra testes de todos os subprojetos:
  | Script | O que faz |
  |--------|-----------|
  | `test` | `cd src/mobile && flutter test` |
  | `test:integration` | `cd src/mobile && ./scripts/run_integration_tests.sh` |
  | `test:all` | unit + integration do mobile |
  | `test:s3-ui` | Jest tests do s3-ui |
  | `test:s3-ui:e2e` | Playwright E2E do s3-ui |

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
