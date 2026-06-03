# Revisões — Parte 1: Backend (s3-ui) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar tabelas `Question` e `QuestionAuditLog` ao Prisma, expor CRUD REST para Q&As de uma lição, e incluir Q&As no manifest ao publicar.

**Architecture:** DB PostgreSQL é fonte da verdade das Q&As. Q&As ativas são embutidas no manifest quando a lição é publicada (mesmo padrão de PDF/áudio). Delete é soft-delete + registro em `QuestionAuditLog`. Rotas seguem o padrão Next.js App Router com Zod + `requireAuth` já estabelecido.

**Tech Stack:** Next.js 14 App Router, Prisma v7, PostgreSQL, Zod, Jest (DB real em `betelapp_test`)

---

## Estrutura de arquivos

| Ação | Arquivo |
|------|---------|
| Modify | `src/s3-ui/prisma/schema.prisma` |
| Create | `src/s3-ui/app/api/lessons/[id]/questions/route.ts` |
| Create | `src/s3-ui/app/api/lessons/[id]/questions/[qid]/route.ts` |
| Modify | `src/s3-ui/lib/schemas.ts` |
| Modify | `src/s3-ui/lib/manifest.ts` |
| Modify | `src/s3-ui/app/api/lessons/[id]/publish/route.ts` |
| Create | `src/s3-ui/__tests__/api/questions.test.ts` |
| Create | `src/s3-ui/__tests__/api/questions.manifest.test.ts` |

---

### Task 1: Schema Prisma — modelos Question e QuestionAuditLog

**Files:**
- Modify: `src/s3-ui/prisma/schema.prisma`

- [ ] **Step 1: Adicionar models ao schema**

Adicionar ao final de `prisma/schema.prisma`:

```prisma
model Question {
  id        Int       @id @default(autoincrement())
  lessonId  Int
  question  String
  answer    String
  order     Int       @default(0)
  createdAt DateTime  @default(now())
  deletedAt DateTime?
}

model QuestionAuditLog {
  id         Int      @id @default(autoincrement())
  questionId Int
  lessonId   Int
  question   String
  answer     String
  deletedBy  String
  deletedAt  DateTime @default(now())
}
```

Nota: `Question` não tem relação FK com `Lesson` — mesmo padrão de `LessonAuditLog` onde `lessonId` é plain `Int` sem FK, para sobreviver a deletes. Sem `@relation` em `Lesson` também — mantém modelos independentes conforme o padrão do projeto.

- [ ] **Step 2: Aplicar schema nos DBs de dev e test**

```bash
cd src/s3-ui
npm run db:setup:dev
npm run db:setup:test
```

Esperado: sem erros. `prisma db push` aplica os novos models em `betelapp_dev` e `betelapp_test`.

- [ ] **Step 3: Verificar que o Prisma client foi regenerado**

```bash
cd src/s3-ui
npx tsx -e "import { prisma } from './lib/prisma'; prisma.question.findMany().then(r => { console.log('OK', r.length); prisma.\$disconnect(); })"
```

Esperado: `OK 0`

---

### Task 2: Schemas Zod para Q&As

**Files:**
- Modify: `src/s3-ui/lib/schemas.ts`

- [ ] **Step 1: Adicionar schemas**

Adicionar ao final de `src/s3-ui/lib/schemas.ts`:

```ts
export const createQuestionSchema = z.object({
  question: z.string().min(1, 'Pergunta obrigatória'),
  answer: z.string().min(1, 'Resposta obrigatória'),
  order: z.number().int().nonnegative().optional(),
})

export const updateQuestionSchema = z.object({
  question: z.string().min(1).optional(),
  answer: z.string().min(1).optional(),
  order: z.number().int().nonnegative().optional(),
})
```

---

### Task 3: API GET + POST /api/lessons/[id]/questions

**Files:**
- Create: `src/s3-ui/app/api/lessons/[id]/questions/route.ts`
- Create: `src/s3-ui/__tests__/api/questions.test.ts`

- [ ] **Step 1: Escrever testes falhando**

Criar `src/s3-ui/__tests__/api/questions.test.ts`:

```ts
/**
 * @jest-environment node
 */
import { GET, POST } from '@/app/api/lessons/[id]/questions/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

async function makeAuthRequest(method: string, url: string, body?: object): Promise<NextRequest> {
  const token = await signToken({ id: 1, username: 'victor', isAdmin: true, mustChangePassword: false })
  const req = new NextRequest(url, {
    method,
    body: body ? JSON.stringify(body) : undefined,
    headers: { 'Content-Type': 'application/json' },
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

const LESSON_ID = 1

beforeAll(async () => {
  await prisma.lesson.upsert({
    where: { id: LESSON_ID },
    update: { title: 'Test Lesson' },
    create: { id: LESSON_ID, title: 'Test Lesson' },
  })
  await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
})

afterAll(async () => {
  await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
  await prisma.$disconnect()
})

describe('GET /api/lessons/[id]/questions', () => {
  it('returns empty array when no questions exist', async () => {
    const req = await makeAuthRequest('GET', `http://localhost/api/lessons/${LESSON_ID}/questions`)
    const res = await GET(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(data).toEqual([])
  })

  it('returns only active (non-deleted) questions ordered by order asc', async () => {
    await prisma.question.createMany({
      data: [
        { lessonId: LESSON_ID, question: 'Q1', answer: 'A1', order: 1 },
        { lessonId: LESSON_ID, question: 'Q2', answer: 'A2', order: 2 },
        { lessonId: LESSON_ID, question: 'Q_deleted', answer: 'A_deleted', order: 3, deletedAt: new Date() },
      ],
    })
    const req = await makeAuthRequest('GET', `http://localhost/api/lessons/${LESSON_ID}/questions`)
    const res = await GET(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(data).toHaveLength(2)
    expect(data[0].question).toBe('Q1')
    expect(data[1].question).toBe('Q2')
  })

  it('returns 401 without token', async () => {
    const req = new NextRequest(`http://localhost/api/lessons/${LESSON_ID}/questions`, { method: 'GET' })
    const res = await GET(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(401)
  })
})

describe('POST /api/lessons/[id]/questions', () => {
  it('creates a question and returns it', async () => {
    const req = await makeAuthRequest('POST', `http://localhost/api/lessons/${LESSON_ID}/questions`, {
      question: 'Nova pergunta?',
      answer: 'Nova resposta.',
    })
    const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(201)
    const data = await res.json()
    expect(data.question).toBe('Nova pergunta?')
    expect(data.answer).toBe('Nova resposta.')
    expect(data.lessonId).toBe(LESSON_ID)
    expect(data.deletedAt).toBeNull()
  })

  it('returns 400 on missing question field', async () => {
    const req = await makeAuthRequest('POST', `http://localhost/api/lessons/${LESSON_ID}/questions`, {
      answer: 'Resposta sem pergunta.',
    })
    const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(400)
  })

  it('returns 401 without token', async () => {
    const req = new NextRequest(`http://localhost/api/lessons/${LESSON_ID}/questions`, {
      method: 'POST',
      body: JSON.stringify({ question: 'Q', answer: 'A' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(401)
  })
})
```

- [ ] **Step 2: Rodar e confirmar falha**

```bash
cd src/s3-ui
npx jest __tests__/api/questions.test.ts --no-coverage 2>&1 | tail -20
```

Esperado: `Cannot find module '@/app/api/lessons/[id]/questions/route'`

- [ ] **Step 3: Implementar a rota**

Criar `src/s3-ui/app/api/lessons/[id]/questions/route.ts`:

```ts
export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { createQuestionSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const lessonId = parseInt(idStr, 10)
  if (isNaN(lessonId)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const questions = await prisma.question.findMany({
    where: { lessonId, deletedAt: null },
    orderBy: { order: 'asc' },
  })

  return NextResponse.json(questions)
}

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const lessonId = parseInt(idStr, 10)
  if (isNaN(lessonId)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const body = await req.json()
  const parsed = createQuestionSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  const question = await prisma.question.create({
    data: {
      lessonId,
      question: parsed.data.question,
      answer: parsed.data.answer,
      order: parsed.data.order ?? 0,
    },
  })

  return NextResponse.json(question, { status: 201 })
}
```

- [ ] **Step 4: Rodar e confirmar verde**

```bash
cd src/s3-ui
npx jest __tests__/api/questions.test.ts --no-coverage 2>&1 | tail -20
```

Esperado: todos os testes passando.

- [ ] **Step 5: Commit**

```bash
git add src/s3-ui/prisma/schema.prisma src/s3-ui/lib/schemas.ts \
        src/s3-ui/app/api/lessons/[id]/questions/route.ts \
        src/s3-ui/__tests__/api/questions.test.ts
git commit -m "feat(s3-ui): add Question model and GET/POST /api/lessons/[id]/questions"
```

---

### Task 4: API PATCH + DELETE /api/lessons/[id]/questions/[qid]

**Files:**
- Create: `src/s3-ui/app/api/lessons/[id]/questions/[qid]/route.ts`

- [ ] **Step 1: Adicionar testes ao arquivo existente**

Adicionar ao final de `src/s3-ui/__tests__/api/questions.test.ts`:

```ts
import { PATCH, DELETE } from '@/app/api/lessons/[id]/questions/[qid]/route'

describe('PATCH /api/lessons/[id]/questions/[qid]', () => {
  let questionId: number

  beforeEach(async () => {
    const question = await prisma.question.create({
      data: { lessonId: LESSON_ID, question: 'Original?', answer: 'Original.', order: 10 },
    })
    questionId = question.id
  })

  afterEach(async () => {
    await prisma.question.deleteMany({ where: { id: questionId } })
  })

  it('updates question text', async () => {
    const req = await makeAuthRequest(
      'PATCH',
      `http://localhost/api/lessons/${LESSON_ID}/questions/${questionId}`,
      { question: 'Atualizada?' },
    )
    const res = await PATCH(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: String(questionId) }) })
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(data.question).toBe('Atualizada?')
    expect(data.answer).toBe('Original.')
  })

  it('returns 404 for non-existent question', async () => {
    const req = await makeAuthRequest(
      'PATCH',
      `http://localhost/api/lessons/${LESSON_ID}/questions/99999`,
      { question: 'X' },
    )
    const res = await PATCH(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: '99999' }) })
    expect(res.status).toBe(404)
  })
})

describe('DELETE /api/lessons/[id]/questions/[qid]', () => {
  let questionId: number

  beforeEach(async () => {
    const question = await prisma.question.create({
      data: { lessonId: LESSON_ID, question: 'Para deletar?', answer: 'Resposta deletada.', order: 20 },
    })
    questionId = question.id
  })

  it('soft-deletes the question and creates audit log', async () => {
    const req = await makeAuthRequest(
      'DELETE',
      `http://localhost/api/lessons/${LESSON_ID}/questions/${questionId}`,
    )
    const res = await DELETE(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: String(questionId) }) })
    expect(res.status).toBe(204)

    const deleted = await prisma.question.findUnique({ where: { id: questionId } })
    expect(deleted?.deletedAt).not.toBeNull()

    const auditLog = await prisma.questionAuditLog.findFirst({
      where: { questionId },
      orderBy: { deletedAt: 'desc' },
    })
    expect(auditLog).toBeDefined()
    expect(auditLog?.question).toBe('Para deletar?')
    expect(auditLog?.answer).toBe('Resposta deletada.')
    expect(auditLog?.deletedBy).toBe('victor')
  })

  it('returns 404 for non-existent question', async () => {
    const req = await makeAuthRequest(
      'DELETE',
      `http://localhost/api/lessons/${LESSON_ID}/questions/99999`,
    )
    const res = await DELETE(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: '99999' }) })
    expect(res.status).toBe(404)
  })
})
```

- [ ] **Step 2: Rodar e confirmar falha**

```bash
cd src/s3-ui
npx jest __tests__/api/questions.test.ts --no-coverage 2>&1 | tail -20
```

Esperado: `Cannot find module '@/app/api/lessons/[id]/questions/[qid]/route'`

- [ ] **Step 3: Implementar a rota**

Criar `src/s3-ui/app/api/lessons/[id]/questions/[qid]/route.ts`:

```ts
export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { updateQuestionSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string; qid: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { qid: qidStr } = await params
  const qid = parseInt(qidStr, 10)
  if (isNaN(qid)) return NextResponse.json({ error: 'Invalid qid' }, { status: 400 })

  const body = await req.json()
  const parsed = updateQuestionSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  try {
    const question = await prisma.question.update({
      where: { id: qid, deletedAt: null },
      data: parsed.data,
    })
    return NextResponse.json(question)
  } catch {
    return NextResponse.json({ error: 'Question not found' }, { status: 404 })
  }
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ id: string; qid: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { qid: qidStr } = await params
  const qid = parseInt(qidStr, 10)
  if (isNaN(qid)) return NextResponse.json({ error: 'Invalid qid' }, { status: 400 })

  const existing = await prisma.question.findUnique({ where: { id: qid, deletedAt: null } })
  if (!existing) return NextResponse.json({ error: 'Question not found' }, { status: 404 })

  await prisma.questionAuditLog.create({
    data: {
      questionId: existing.id,
      lessonId: existing.lessonId,
      question: existing.question,
      answer: existing.answer,
      deletedBy: authResult.username,
    },
  })

  await prisma.question.update({
    where: { id: qid },
    data: { deletedAt: new Date() },
  })

  return new NextResponse(null, { status: 204 })
}
```

- [ ] **Step 4: Verificar que `authResult.username` existe**

O `requireAuth` em `src/s3-ui/lib/auth.ts` retorna `{ userId, username }`. Confirmar:

```bash
grep -n "username" src/s3-ui/lib/auth.ts | head -10
```

Se `username` não estiver no retorno, adicionar ao objeto retornado por `requireAuth`. O token JWT já contém `username` (ver `signToken` nos testes existentes).

- [ ] **Step 5: Rodar e confirmar verde**

```bash
cd src/s3-ui
npx jest __tests__/api/questions.test.ts --no-coverage 2>&1 | tail -20
```

Esperado: todos os testes passando.

- [ ] **Step 6: Commit**

```bash
git add src/s3-ui/app/api/lessons/[id]/questions/[qid]/route.ts \
        src/s3-ui/__tests__/api/questions.test.ts
git commit -m "feat(s3-ui): add PATCH/DELETE /api/lessons/[id]/questions/[qid] with audit log"
```

---

### Task 5: Manifest — incluir Q&As ao publicar

**Files:**
- Modify: `src/s3-ui/lib/manifest.ts`
- Modify: `src/s3-ui/app/api/lessons/[id]/publish/route.ts`
- Create: `src/s3-ui/__tests__/api/questions.manifest.test.ts`

- [ ] **Step 1: Atualizar interface `ManifestLesson` em `manifest.ts`**

Em `src/s3-ui/lib/manifest.ts`, adicionar `questions` ao interface:

```ts
export interface ManifestQuestion {
  id: number
  q: string
  a: string
}

export interface ManifestLesson {
  id: number
  title: string
  audio: { active: string | null; ext: string; checksum: string; history: string[] } | null
  pdf: { active: string | null; checksum: string; history: string[] }
  questions: ManifestQuestion[]
}
```

- [ ] **Step 2: Escrever teste falhando para publicação com Q&As**

Criar `src/s3-ui/__tests__/api/questions.manifest.test.ts`:

```ts
/**
 * @jest-environment node
 */
import { PATCH as togglePublish } from '@/app/api/lessons/[id]/publish/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'
import { getObjectText, uploadObject } from '@/lib/minio'

jest.mock('@/lib/minio', () => ({
  getObjectText: jest.fn(),
  uploadObject: jest.fn().mockResolvedValue(undefined),
}))

const mockGetObjectText = getObjectText as jest.Mock
const mockUploadObject = uploadObject as jest.Mock

const LESSON_ID = 2

async function makeAuthRequest(method: string, url: string, body?: object): Promise<NextRequest> {
  const token = await signToken({ id: 1, username: 'victor', isAdmin: true, mustChangePassword: false })
  const req = new NextRequest(url, {
    method,
    body: body ? JSON.stringify(body) : undefined,
    headers: { 'Content-Type': 'application/json' },
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeAll(async () => {
  await prisma.lesson.upsert({
    where: { id: LESSON_ID },
    update: { title: 'Lição com Q&As', published: false, pdfActive: 'lessons/2/lesson_v1.pdf', pdfChecksum: 'abc', pdfHistory: [] },
    create: { id: LESSON_ID, title: 'Lição com Q&As', published: false, pdfActive: 'lessons/2/lesson_v1.pdf', pdfChecksum: 'abc', pdfHistory: [] },
  })
  await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
  await prisma.question.createMany({
    data: [
      { lessonId: LESSON_ID, question: 'Pergunta 1?', answer: 'Resposta 1.', order: 1 },
      { lessonId: LESSON_ID, question: 'Pergunta 2?', answer: 'Resposta 2.', order: 2 },
      { lessonId: LESSON_ID, question: 'Deletada?', answer: 'Deletada.', order: 3, deletedAt: new Date() },
    ],
  })
})

afterAll(async () => {
  await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
  await prisma.lesson.update({ where: { id: LESSON_ID }, data: { published: false } })
  await prisma.$disconnect()
})

describe('PATCH /api/lessons/[id]/publish — Q&As no manifest', () => {
  beforeEach(() => {
    mockGetObjectText.mockReset()
    mockUploadObject.mockReset()
    mockUploadObject.mockResolvedValue(undefined)
    mockGetObjectText.mockResolvedValue(
      JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [] }),
    )
  })

  it('ao publicar, inclui apenas Q&As ativas no manifest', async () => {
    const req = await makeAuthRequest('PATCH', `http://localhost/api/lessons/${LESSON_ID}/publish`, { published: true })
    const res = await togglePublish(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(200)

    const writtenManifest = JSON.parse(
      (mockUploadObject.mock.calls[0][1] as Buffer).toString('utf-8'),
    )
    const lessonEntry = writtenManifest.lessons.find((lesson: { id: number }) => lesson.id === LESSON_ID)
    expect(lessonEntry).toBeDefined()
    expect(lessonEntry.questions).toHaveLength(2)
    expect(lessonEntry.questions[0]).toEqual({ id: expect.any(Number), q: 'Pergunta 1?', a: 'Resposta 1.' })
    expect(lessonEntry.questions[1]).toEqual({ id: expect.any(Number), q: 'Pergunta 2?', a: 'Resposta 2.' })
  })

  it('ao publicar lição sem Q&As, inclui questions: [] no manifest', async () => {
    await prisma.question.updateMany({ where: { lessonId: LESSON_ID }, data: { deletedAt: new Date() } })

    const req = await makeAuthRequest('PATCH', `http://localhost/api/lessons/${LESSON_ID}/publish`, { published: true })
    const res = await togglePublish(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(200)

    const writtenManifest = JSON.parse(
      (mockUploadObject.mock.calls[0][1] as Buffer).toString('utf-8'),
    )
    const lessonEntry = writtenManifest.lessons.find((lesson: { id: number }) => lesson.id === LESSON_ID)
    expect(lessonEntry.questions).toEqual([])
  })
})
```

- [ ] **Step 3: Rodar e confirmar falha**

```bash
cd src/s3-ui
npx jest __tests__/api/questions.manifest.test.ts --no-coverage 2>&1 | tail -20
```

Esperado: falha (manifest não contém `questions` ainda).

- [ ] **Step 4: Atualizar `publish/route.ts` para incluir Q&As**

Em `src/s3-ui/app/api/lessons/[id]/publish/route.ts`, atualizar o bloco de publicação:

```ts
if (parsed.data.published) {
  const activeQuestions = await prisma.question.findMany({
    where: { lessonId: id, deletedAt: null },
    orderBy: { order: 'asc' },
  })

  const manifestLesson: ManifestLesson = {
    id: lesson.id,
    title: lesson.title,
    pdf: {
      active: lesson.pdfActive,
      checksum: lesson.pdfChecksum ?? '',
      history: (lesson.pdfHistory as string[]) ?? [],
    },
    audio: lesson.audioActive
      ? {
          active: lesson.audioActive,
          ext: lesson.audioExt ?? 'mp3',
          checksum: lesson.audioChecksum ?? '',
          history: (lesson.audioHistory as string[]) ?? [],
        }
      : null,
    questions: activeQuestions.map((question) => ({
      id: question.id,
      q: question.question,
      a: question.answer,
    })),
  }
  updatedManifest = upsertLesson(manifest, manifestLesson)
}
```

Também importar `ManifestLesson` (já importado) — verificar que o import inclui `ManifestLesson` de `@/lib/manifest`.

- [ ] **Step 5: Rodar e confirmar verde**

```bash
cd src/s3-ui
npx jest __tests__/api/questions.manifest.test.ts --no-coverage 2>&1 | tail -20
```

Esperado: todos os testes passando.

- [ ] **Step 6: Rodar suite completa para garantir regressão zero**

```bash
cd src/s3-ui
npx jest --no-coverage 2>&1 | tail -30
```

Esperado: todos os testes passando.

- [ ] **Step 7: Regenerar manifest ao criar/editar/deletar Q&A de lição publicada**

Nas rotas `POST /questions`, `PATCH /questions/[qid]`, e `DELETE /questions/[qid]`, após salvar no DB verificar se a lição está publicada. Se sim, regenerar o manifest (mesmo padrão da rota de publicação).

Helper reutilizável a extrair em `lib/manifest-sync.ts`:

```ts
import { prisma } from '@/lib/prisma'
import { getObjectText, uploadObject } from '@/lib/minio'
import { parseManifest, upsertLesson, ManifestLesson } from '@/lib/manifest'

export async function resyncLessonInManifestIfPublished(lessonId: number): Promise<void> {
  const lesson = await prisma.lesson.findUnique({ where: { id: lessonId } })
  if (!lesson?.published) return

  const activeQuestions = await prisma.question.findMany({
    where: { lessonId, deletedAt: null },
    orderBy: { order: 'asc' },
  })

  const manifestText = await getObjectText('manifest.json')
  const manifest = parseManifest(manifestText)

  const manifestLesson: ManifestLesson = {
    id: lesson.id,
    title: lesson.title,
    pdf: {
      active: lesson.pdfActive,
      checksum: lesson.pdfChecksum ?? '',
      history: (lesson.pdfHistory as string[]) ?? [],
    },
    audio: lesson.audioActive
      ? {
          active: lesson.audioActive,
          ext: lesson.audioExt ?? 'mp3',
          checksum: lesson.audioChecksum ?? '',
          history: (lesson.audioHistory as string[]) ?? [],
        }
      : null,
    questions: activeQuestions.map((question) => ({
      id: question.id,
      q: question.question,
      a: question.answer,
    })),
  }

  const updatedManifest = upsertLesson(manifest, manifestLesson)
  await uploadObject('manifest.json', Buffer.from(JSON.stringify(updatedManifest, null, 2)), 'application/json')
}
```

Chamar `resyncLessonInManifestIfPublished(lessonId)` no final de cada handler POST/PATCH/DELETE de questions, dentro de um try/catch (best-effort — falha do MinIO não deve bloquear a resposta da API).

Adicionar ao teste `questions.manifest.test.ts` um caso:
```ts
it('criar Q&A em lição publicada atualiza o manifest', async () => {
  await prisma.lesson.update({ where: { id: LESSON_ID }, data: { published: true } })
  mockGetObjectText.mockResolvedValue(
    JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [
      { id: LESSON_ID, title: 'Lição com Q&As', pdf: { active: 'lessons/2/lesson_v1.pdf', checksum: 'abc', history: [] }, audio: null, questions: [] }
    ]}),
  )

  const req = await makeAuthRequest('POST', `http://localhost/api/lessons/${LESSON_ID}/questions`, {
    question: 'Nova pergunta?', answer: 'Nova resposta.'
  })
  const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
  expect(res.status).toBe(201)
  expect(mockUploadObject).toHaveBeenCalled()
})
```

- [ ] **Step 8: Commit**

```bash
git add src/s3-ui/lib/manifest.ts \
        src/s3-ui/lib/manifest-sync.ts \
        src/s3-ui/app/api/lessons/[id]/publish/route.ts \
        src/s3-ui/app/api/lessons/[id]/questions/route.ts \
        src/s3-ui/app/api/lessons/[id]/questions/[qid]/route.ts \
        src/s3-ui/__tests__/api/questions.manifest.test.ts
git commit -m "feat(s3-ui): include active Q&As in manifest on lesson publish and Q&A mutations"
```
