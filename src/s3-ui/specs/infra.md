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
| `migrator` | `node:20-alpine` | Copia `node_modules`, `prisma/`, `prisma.config.ts`, `docker-migrator-entrypoint.sh` do stage `builder` via `COPY --from=builder`. Roda `prisma generate` + `prisma db push`. |

- **Output `standalone`** definido em `next.config.mjs` — produz `server.js` autocontido sem `node_modules` no runtime.
  - **Por quê:** Container mais leve e sem dependência de `npm install` no runtime.

- **`DATABASE_URL=postgresql://x:x@localhost/x`** como placeholder no build — satisfaz `prisma generate` sem DB real.
  - **Por quê:** O Prisma precisa de uma connection string válida para gerar o client, mesmo que nunca conecte durante o build.

- **`GIT_COMMIT` como build-arg** — gravado em `.build-hash` no build. Não lido em runtime atualmente.
  - **Por quê:** Rastreabilidade de qual commit gerou a imagem.

### Docker Compose

- **`docker-compose.yml` (dev/genérico):**
  - `migrator`: target `migrator`, env de `.env.production`, `restart: "no"`, `extra_hosts: host.docker.internal:host-gateway`
  - `app`: target `runner`, porta `3001:3000`, `restart: unless-stopped`, `extra_hosts: host.docker.internal:host-gateway`, `depends_on: migrator (condition: service_completed_successfully)` — o app só sobe após o migrator terminar com sucesso. Um migrator com falha bloqueia o app até que o stack seja reiniciado.
  - Sem image tags — sempre rebuild local

- **`docker-compose.prod.yml` (produção):**
  - `app`: imagem nomeada `s3-ui-app`, mesma config de portas/restart, sem `depends_on` (migrador é invocado separadamente)
  - `migrator`: **profile-gated** (`profiles: [migrate]`), imagem nomeada `s3-ui-migrator`, sem `restart` explícito (default Docker: `no`). **Não adicionar `restart: unless-stopped`** — o migrator é um job one-shot; restartá-lo automaticamente causaria loop em caso de falha de schema.
  - **Invocação do migrator em prod:**
    ```
    docker compose -f docker-compose.prod.yml --profile migrate run --rm migrator
    ```
    O `--rm` garante remoção do container após execução. **Não usar `docker compose up`** para o migrator em produção — não remove o container automaticamente e pode gerar confusão com o serviço `app`.
  - **Por quê:** Em produção, migrações são executadas manualmente ou via CI específico — não em todo restart.
  - **Diferença entre dev e prod:** No `docker-compose.yml`, o `app` depende do `migrator` via `depends_on`. No `docker-compose.prod.yml`, não há `depends_on` — a responsabilidade de sequenciar migração → deploy cabe ao Jenkinsfile.

- **`extra_hosts: host.docker.internal:host-gateway`** — presente em todos os serviços de ambos os Compose files. Permite que os containers resolvam `host.docker.internal` para o IP gateway do host Docker, necessário para alcançar o PostgreSQL que roda no host (não em container).
  - **Por quê:** O PostgreSQL roda diretamente no homelab, fora do Docker. O `DATABASE_URL` usa `host.docker.internal` como hostname.
  - **Consequência:** Remover `extra_hosts` sem reconfigurar o `DATABASE_URL` causa falha de conexão com o banco em todo startup.

- **Porta 3001:3000** — container escuta na 3000, host expõe na 3001. Reverse proxy (não no repo) roteia tráfego externo.

### Migrator entrypoint

- **`docker-migrator-entrypoint.sh`:** Regenera Prisma client com placeholder `DATABASE_URL=postgresql://x:x@localhost/x` → `prisma db push` contra o DB real (via env de runtime). O `generate` usa placeholder pelo mesmo motivo do builder: satisfaz o Prisma sem conexão real. O `db push` subsequente usa o `DATABASE_URL` injetado pelo `env_file`.
  - **Por quê do `db push`:** O projeto usa `db push` (não migrations formais) durante desenvolvimento rápido. Migrations formais são para quando o schema estabilizar.
  - **Por quê do re-generate no runtime:** Garante que o client no container corresponde ao schema atual, caso a imagem tenha sido construída a partir de uma layer mais antiga que o schema.

- **`docker-entrypoint.sh` (não usado):** Arquivo alternativo que executa `prisma migrate deploy` seguido de `exec node server.js` num único container. Existe como opção futura para quando o schema estabilizar e migrations formais forem adotadas. Atualmente não é referenciado pelo Dockerfile CMD nem por nenhum Compose file. Para usá-lo: substituir o CMD do stage `runner` no Dockerfile por `["./docker-entrypoint.sh"]` e remover o serviço `migrator` do Compose.

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
  | `.env.test` | `betelapp_test` | `betelapp-content-dev` | Sim |
  | `.env.production` | `betelapp` | `betelapp-content` | Não (host-managed) |

  - **`.env.local` não existe e não deve ser criado.** O ambiente dev usa exclusivamente `.env.development`. O Next.js prioriza `.env.local` sobre `.env.development`, o que causava divergências silenciosas entre seed e runtime (senhas diferentes no banco vs. no servidor).
  - **⚠️ `prisma/seed.ts` e `scripts/backfill-manifest-to-db.ts`** têm um `config({ path: '.env.local' })` legado no topo. É código morto — como `.env.local` não deve existir, não tem efeito. Ambos os scripts devem ser invocados via `npm run db:setup:dev` ou `db:setup:test`, que exportam as variáveis corretas via `setup-db.sh`. Rodar o seed diretamente sem as variáveis exportadas resultará em erro de `DATABASE_URL not set`.

### Módulos de auth por runtime

| Módulo | Runtime | Exporta | Restrição |
|--------|---------|---------|-----------|
| `lib/auth.ts` | Node.js | `signToken`, `verifyToken`, `requireAuth`, `requireAdmin`, `TOKEN_COOKIE` | Importa `prisma` — **não pode ser usado no Edge Runtime** |
| `lib/auth-edge.ts` | Edge (middleware) | `verifyToken`, `TOKEN_COOKIE` | Usa apenas Web Crypto — sem Prisma, sem Node APIs |

O middleware importa exclusivamente `lib/auth-edge.ts`. Qualquer rota de API usa `lib/auth.ts`. **Não combinar os dois módulos no mesmo arquivo** — o middleware falhará no build se importar `prisma` diretamente ou indiretamente.

### Testes (infra)

- **Jest:** `maxWorkers: 1` (sequencial, evita contention no DB). `transformIgnorePatterns` patcheado para transpilar `jose` (ESM-only).
- **Playwright:** Chromium only, `baseURL: http://localhost:3000`, `.env.test` carregado. `webServer` starta `next dev` com env de teste. `reuseExistingServer` em non-CI.
- **DB setup:** `npm run db:setup:dev` e `db:setup:test` — scripts em `scripts/setup-db.sh`.

## O que NÃO fazer

- **Não usar `migrate deploy`** em vez de `db push` sem antes estabilizar o schema e criar migrations formais.
- **Não remover o placeholder `DATABASE_URL` do Dockerfile** — `prisma generate` falha sem uma connection string sintacticamente válida.
- **Não commitar `.env.production`** — segredos de produção são gerenciados no host, nunca no repo.
- **Não criar `.env.local`** — o Next.js o prioriza sobre `.env.development`, quebrando a paridade seed/runtime. Toda configuração dev vai em `.env.development`.
- **Não expor o container diretamente** sem reverse proxy — a porta 3001 é interna ao homelab.
- **Não rodar `migrator` automaticamente em prod** sem validação — o profile gate existe por segurança.
- **Não alterar a porta do container (3000)** sem atualizar `docker-compose.yml`, `docker-compose.prod.yml`, e o reverse proxy.
