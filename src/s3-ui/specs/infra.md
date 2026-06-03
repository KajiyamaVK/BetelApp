---
layer: infra
project: s3-ui
last_reviewed: 2026-05-31
---

## Propósito

Governa decisões de infraestrutura do s3-ui — Dockerfile, build stages, Docker Compose, deploy, configuração de runtime, e gerenciamento de env vars.

## Decisões

### Dockerfile (3 stages)

| Stage | Base | Propósito |
|-------|------|-----------|
| `builder` | `node:20-alpine` | `npm ci`, `prisma generate` (com DB URL placeholder), `npm run build` |
| `runner` | `node:20-alpine` | Copia `.next/standalone`, `.next/static`, `public`. Porta 3000. CMD: `node server.js` |
| `migrator` | (do builder) | Copia `node_modules`, `prisma/`, `prisma.config.ts`, `docker-migrator-entrypoint.sh` |

- **Output `standalone`** definido em `next.config.mjs` — produz `server.js` autocontido sem `node_modules` no runtime.
  - **Por quê:** Container mais leve e sem dependência de `npm install` no runtime.

- **`DATABASE_URL=postgresql://x:x@localhost/x`** como placeholder no build — satisfaz `prisma generate` sem DB real.
  - **Por quê:** O Prisma precisa de uma connection string válida para gerar o client, mesmo que nunca conecte durante o build.

- **`GIT_COMMIT` como build-arg** — gravado em `.build-hash` no build. Não lido em runtime atualmente.
  - **Por quê:** Rastreabilidade de qual commit gerou a imagem.

### Docker Compose

- **`docker-compose.yml` (dev/genérico):**
  - `migrator`: target `migrator`, env de `.env.production`, `restart: "no"`
  - `app`: target `runner`, porta `3001:3000`, `restart: unless-stopped`, depende do migrator
  - Sem image tags — sempre rebuild local

- **`docker-compose.prod.yml` (produção):**
  - `app`: imagem nomeada `s3-ui-app`, mesma config de portas/restart
  - `migrator`: **profile-gated** (`profiles: [migrate]`) — não roda automaticamente. Invocado com `--profile migrate` quando necessário
  - **Por quê:** Em produção, migrações são executadas manualmente ou via CI específico — não em todo restart.

- **Porta 3001:3000** — container escuta na 3000, host expõe na 3001. Reverse proxy (não no repo) roteia tráfego externo.

### Migrator entrypoint

- **`docker-migrator-entrypoint.sh`:** Regenera Prisma client → `prisma db push` (schema push, não `migrate deploy`).
  - **Por quê:** O projeto usa `db push` (não migrations formais) durante desenvolvimento rápido. Migrations formais são para quando o schema estabilizar.

- **`docker-entrypoint.sh` (standalone, não wired):** `prisma migrate deploy` + `exec node server.js`. Existe mas não é usado pelo Dockerfile CMD.

### Variáveis de ambiente

| Variável | Obrigatória | Uso |
|----------|------------|-----|
| `DATABASE_URL` | Sim | Connection string PostgreSQL |
| `JWT_SECRET` | Sim | Mínimo 32 chars para HMAC-SHA256 |
| `MINIO_ENDPOINT` | Sim | `s3.kajiyama.com.br` |
| `MINIO_PORT` | Sim | `443` |
| `MINIO_USE_SSL` | Sim | `true` |
| `MINIO_ACCESS_KEY` | Sim | Credencial MinIO |
| `MINIO_SECRET_KEY` | Sim | Credencial MinIO |
| `MINIO_BUCKET` | Sim | `betelapp-content` (prod) |
| `NEXT_PUBLIC_S3_BASE_URL` | Sim | URL pública para assets (fallback hardcoded) |
| `SEED_VICTOR_PASSWORD` | Seed only | Senha do admin victor |
| `E2E_VICTOR_PASSWORD` | E2E only | Deve igualar a seed |
| `NODE_ENV` | Auto | `production` setado no Dockerfile runner |
| `CI` | CI only | Detectado pelo Playwright config |

- **Env files:**
  | Arquivo | DB | Bucket | Commitado |
  |---------|------|--------|-----------|
  | `.env.example` | template | template | Sim |
  | `.env.development` | `betelapp_dev` | `betelapp-content-dev` | Sim |
  | `.env.local` | = dev | = dev | Não |
  | `.env.test` | `betelapp_test` | `betelapp-content-dev` | Sim |
  | `.env.production` | `betelapp` | `betelapp-content` | Não (host-managed) |

### Testes (infra)

- **Jest:** `maxWorkers: 1` (sequencial, evita contention no DB). `transformIgnorePatterns` patcheado para transpilar `jose` (ESM-only).
- **Playwright:** Chromium only, `baseURL: http://localhost:3000`, `.env.test` carregado. `webServer` starta `next dev` com env de teste. `reuseExistingServer` em non-CI.
- **DB setup:** `npm run db:setup:dev` e `db:setup:test` — scripts em `scripts/setup-db.sh`.

## O que NÃO fazer

- **Não usar `migrate deploy`** em vez de `db push` sem antes estabilizar o schema e criar migrations formais.
- **Não remover o placeholder `DATABASE_URL` do Dockerfile** — `prisma generate` falha sem uma connection string sintacticamente válida.
- **Não commitar `.env.production`** — segredos de produção são gerenciados no host, nunca no repo.
- **Não expor o container diretamente** sem reverse proxy — a porta 3001 é interna ao homelab.
- **Não rodar `migrator` automaticamente em prod** sem validação — o profile gate existe por segurança.
- **Não alterar a porta do container (3000)** sem atualizar `docker-compose.yml`, `docker-compose.prod.yml`, e o reverse proxy.
