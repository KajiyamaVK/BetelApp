---
layer: data
project: s3-ui
last_reviewed: 2026-06-03
---

## Propósito

Governa decisões de dados do s3-ui — modelos Prisma, queries, schema, e integrações com S3/MinIO.

## Decisões

### Banco de dados

- **PostgreSQL** via **Prisma v7** com driver adapter `@prisma/adapter-pg`.
  - **Por quê:** Prisma v7 exige driver adapter explícito (não usa o engine binário). `@prisma/adapter-pg` com `pg` é o adapter para PostgreSQL.

- **Conexão:** `DATABASE_URL` env var lida via `prisma.config.ts` (padrão v7 — não via `datasource.url` no schema).

- **Singleton Prisma client** — cacheado em `globalThis` para evitar múltiplas instâncias durante hot reload do Next.js (`lib/prisma.ts`).

- **Logging:** Apenas `['error']` — sem query logging em produção.

### Models

**User:**
| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | `Int` | PK, autoincrement |
| `username` | `String` | `@unique` — único index secundário |
| `passwordHash` | `String` | bcrypt hash |
| `isAdmin` | `Boolean` | default `false` |
| `mustChangePassword` | `Boolean` | default `true` |
| `createdAt` | `DateTime` | default `now()` |

**Lesson:**
| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | `Int` | PK, **manual** (não autoincrement) |
| `title` | `String` | — |
| `published` | `Boolean` | default `false` |
| `pdfActive` | `String?` | Path ativo no MinIO |
| `pdfChecksum` | `String?` | MD5 hex |
| `pdfHistory` | `Json` | default `[]` — array de paths antigos |
| `audioActive` | `String?` | Path ativo no MinIO |
| `audioExt` | `String?` | Extensão (ex: `"mp3"`) |
| `audioChecksum` | `String?` | MD5 hex |
| `audioHistory` | `Json` | default `[]` — array de paths antigos |

**Question:**
| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | `Int` | PK, autoincrement |
| `lessonId` | `Int` | Plain Int sem FK — sobrevive a deletes de lição |
| `question` | `String` | Texto da pergunta |
| `answer` | `String` | Texto da resposta |
| `order` | `Int` | default `0` — ordena as Q&As dentro da lição |
| `createdAt` | `DateTime` | default `now()` |
| `deletedAt` | `DateTime?` | Soft-delete: null = ativo, data = deletado |

**QuestionAuditLog:**
| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | `Int` | PK, autoincrement |
| `questionId` | `Int` | Plain Int sem FK |
| `lessonId` | `Int` | Plain Int sem FK |
| `question` | `String` | Snapshot do texto no momento do delete |
| `answer` | `String` | Snapshot do texto no momento do delete |
| `deletedBy` | `String` | Username de quem deletou |
| `deletedAt` | `DateTime` | default `now()` |

- **Sem relações** entre User e Lesson — modelos independentes.
- **Lesson.id manual** — o ID é fornecido pelo admin na criação, não é autoincrement.
  - **Por quê:** Os IDs correspondem aos números das lições do catecismo (1-24), são semânticos e usados no path do MinIO (`lessons/{id}/`).

### Migrações

- **Uma migração inicial** em `prisma/migrations/20260530000000_init/`.
- **Campos adicionados após o init** (`published`, `pdfActive`, `pdfChecksum`, etc.) foram aplicados via `prisma db push` — sem migration files correspondentes.
  - **Por quê:** Projeto em desenvolvimento rápido; quando estabilizar, migrations formais serão o padrão.

### S3/MinIO

- **SDK:** `minio` v8 (SDK oficial MinIO JavaScript, não `aws-sdk`).
  - **Por quê:** O storage é MinIO rodando no homelab; o SDK nativo tem melhor compat.

- **Client:** Nova instância criada a cada chamada de `getMinioClient()` (sem singleton).
  - **Por quê:** Intencional para execução stateless em serverless/edge. Cada request tem seu client.

- **Configuração via env vars:** `MINIO_ENDPOINT`, `MINIO_PORT`, `MINIO_USE_SSL`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_BUCKET`.

- **Bucket:** `betelapp-content` (configurável).

- **URLs públicas:** `NEXT_PUBLIC_S3_BASE_URL` concatenado com o path ativo no browser — o browser acessa MinIO diretamente, sem proxy pelo Next.js.

- **Operações S3 usadas:**
  | Operação | Método | Quando |
  |----------|--------|--------|
  | Upload | `client.putObject()` | Upload de arquivo e manifest |
  | Download como stream | `client.getObject()` | Leitura de manifest |

- **Sem operação de delete** — soft-delete apenas (null no active, path movido para history).

### Manifest como artefato de dados

- **Localização:** `manifest.json` na raiz do bucket MinIO.
- **Estrutura:**
  ```json
  {
    "version": 1,
    "updated_at": "2026-05-31T...",
    "lessons": [
      {
        "id": 1,
        "title": "...",
        "pdf": { "active": "lessons/1/lesson_v1.pdf", "checksum": "abc...", "history": [] },
        "audio": { "active": "lessons/1/audio_v1.mp3", "ext": "mp3", "checksum": "def...", "history": [] },
        "questions": [
          { "id": 10, "q": "Qual o fim principal...", "a": "Glorificar a Deus..." }
        ]
      }
    ]
  }
  ```

- **Q&As no manifest:** Campo `questions` (array) presente em cada lição. Contém apenas Q&As ativas (não soft-deletadas). Chaves `"q"` e `"a"` são abreviadas para reduzir tamanho. Array vazio `[]` quando a lição não tem Q&As.
- **Resync automático:** Mutações via CRUD de Q&As em lições publicadas disparam `resyncLessonInManifestIfPublished()` de forma best-effort (try/catch — falha no MinIO não bloqueia a resposta da API).

- **Funções core** (`lib/manifest.ts`):
  | Função | O que faz | Incrementa `version`? |
  |--------|-----------|----------------------|
  | `upsertLesson` | Adiciona ou substitui lição | Sim |
  | `removeLesson` | Remove lição do array | Sim |
  | `applyUpload` | Versiona path, move active para history | Não (só `updated_at`) |
  | `softDeleteFile` | Nula active, move para history | Não (só `updated_at`) |
  | `nextVersion` | Calcula próxima versão via regex no histórico | — |

- **DB como espelho do manifest** — campos `pdfActive`, `pdfChecksum`, etc. no DB são mantidos em sync com o manifest após cada write. Permite reconstruir o manifest entry a partir do DB sem re-ler MinIO.

### Seed

- **Admin user:** Upsert de `victor` com `SEED_VICTOR_PASSWORD` env var. `mustChangePassword: false`. Nunca sobrescreve `isAdmin` em update (evita demoção acidental).

- **24 lições:** IDs 1-24 com títulos do Breve Catecismo de Westminster em português. `update: {}` (no-op em conflito) — nunca sobrescreve lições existentes.

- **Pré-populate de manifest:** Se MinIO está disponível, o seed lê `manifest.json` e popula metadados de arquivo nas lições. Se MinIO está indisponível, pula silenciosamente.

- **Scripts:**
  - `npm run db:setup:dev` — push + generate + seed em `betelapp_dev`
  - `npm run db:setup:test` — push + generate + seed em `betelapp_test`

### Backfill

- **`scripts/backfill-manifest-to-db.ts`** — utilitário one-time que lê `manifest.json` do MinIO e popula campos de arquivo no DB onde `pdfActive IS NULL`. Idempotente (safe to re-run).

### API patterns

- **Next.js App Router REST route handlers** — sem tRPC, sem server actions.
- **`export const dynamic = 'force-dynamic'`** em todas as routes (desabilita caching estático do Next.js).
- **Zod validation** em todas as routes de input.
- Queries Prisma usam apenas API do client (`findMany`, `findUnique`, `create`, `update`, `deleteMany`, `upsert`) — sem raw SQL.

### Ambientes

| Arquivo | DB | Bucket | Commitado |
|---------|------|--------|-----------|
| `.env.dev` | `betelapp_dev` | `betelapp-content-dev` | Não |
| `.env.test` | `betelapp_test` | `betelapp-content-test` | Não |
| `.env.production` | `betelapp` | `betelapp-content` | Não |

### Testes de dados

- **Jest (unit/integration):** Testes de API usam DB real (`betelapp_test`), não mocks. `maxWorkers: 1` para evitar contention. Cada suite cria e limpa dados em `beforeAll`/`afterAll`.
- **Playwright (E2E):** Usa `E2E_VICTOR_PASSWORD` env var. Testes de usuário criam users com timestamp no nome mas não limpam — acumulam no DB. ⚠️ Gap conhecido.

### Docker

- **3-stage build:**
  1. `builder` — `next build` + `prisma generate`
  2. `runner` — standalone output, `node server.js`
  3. `migrator` — `prisma db push` (roda antes do app via compose `depends_on`)

## O que NÃO fazer

- **Não alterar o schema Prisma sem rodar `db:setup:dev` e `db:setup:test`** — a regra em `.claude/rules/database-setup.md` é non-negotiable.
- **Não usar `aws-sdk`** para MinIO — o projeto usa o SDK nativo `minio`.
- **Não fazer delete real no MinIO** — o padrão é soft-delete. Arquivos antigos ficam no bucket para rollback.
- **Não criar migrations Prisma formais** para mudanças incrementais durante desenvolvimento rápido — usar `db push`. Migrations formais são para quando o schema estabilizar.
- **Não servir arquivos via proxy Next.js** — o browser acessa MinIO diretamente via `NEXT_PUBLIC_S3_BASE_URL`.
- **Não usar raw SQL** — todas as queries via Prisma Client API.
- **Não tornar `Lesson.id` autoincrement** — os IDs são semânticos (números do catecismo) e usados nos paths do MinIO.
