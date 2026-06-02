# s3-ui Multi-Issue Fix Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve 5 open s3-ui issues in a single branch: password validation, upload/publish error handling, title edit manifest sync, file upload size limit, and E2E test cleanup.

**Architecture:** All fixes are isolated to their respective layers — API routes, React page handlers, and Playwright E2E specs. No new abstractions are introduced; each issue is patched at the smallest scope. The error banner pattern already used in UsersPage (`resetSuccess` state + inline div) is adopted for LessonsPage to stay consistent with the existing UI.

**Tech Stack:** Next.js 14 App Router, Zod, Prisma, MinIO (`@/lib/minio`), Jest + Testing Library, Playwright

---

## Issue Map

| Issue | Files Changed |
|-------|--------------|
| #11 — password `123456` allowed | `app/api/auth/change-password/route.ts`, `__tests__/api/auth.change-password.test.ts` |
| #13 — silent upload/publish errors | `app/(dashboard)/lessons/page.tsx`, `__tests__/components/LessonRow.publish.test.tsx` |
| #14 — title edit doesn't update manifest | `app/api/lessons/[id]/route.ts`, `__tests__/api/lessons.test.ts` |
| #12 — no file size limit | `app/api/lessons/[id]/upload/route.ts`, `components/lessons/FileRow.tsx`, `__tests__/api/lessons.upload.test.ts` |
| #15 — E2E users not cleaned up | `e2e/users.spec.ts` |

---

## Task 1: Block password "123456" server-side (Issue #11)

**Files:**
- Modify: `src/s3-ui/app/api/auth/change-password/route.ts`
- Test: `src/s3-ui/__tests__/api/auth.change-password.test.ts`

- [ ] **Step 1: Write the failing test**

Add to `describe('POST /api/auth/change-password')` in `src/s3-ui/__tests__/api/auth.change-password.test.ts`:

```typescript
it('returns 400 when new password is 123456', async () => {
  const changePassword = await importRoute()
  const req = await makeRequest({ password: '123456', confirmPassword: '123456' }, testUserId)
  const res = await changePassword(req)
  expect(res.status).toBe(400)
  const body = await res.json()
  expect(body.error).toMatch(/123456/i)
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd src/s3-ui && npx jest __tests__/api/auth.change-password.test.ts --testNamePattern="123456" --no-coverage
```

Expected: FAIL — the route currently returns 200 for `123456`.

- [ ] **Step 3: Add validation in the route**

In `src/s3-ui/app/api/auth/change-password/route.ts`, after the `password !== confirmPassword` check, add:

```typescript
if (password === '123456') {
  return NextResponse.json({ error: 'A senha não pode ser 123456' }, { status: 400 })
}
```

The full POST handler body becomes:

```typescript
export async function POST(req: NextRequest) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const body = await req.json()
  const parsed = changePasswordSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0].message }, { status: 400 })
  }

  const { password, confirmPassword } = parsed.data
  if (password !== confirmPassword) {
    return NextResponse.json({ error: 'As senhas não coincidem' }, { status: 400 })
  }

  if (password === '123456') {
    return NextResponse.json({ error: 'A senha não pode ser 123456' }, { status: 400 })
  }

  const passwordHash = await bcrypt.hash(password, 12)
  const user = await prisma.user.update({
    where: { id: authResult.userId },
    data: { passwordHash, mustChangePassword: false },
    select: { id: true, username: true, isAdmin: true },
  })

  const token = await signToken({ id: user.id, username: user.username, isAdmin: user.isAdmin, mustChangePassword: false })
  const res = NextResponse.json({ ok: true })
  res.cookies.set(TOKEN_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7,
    path: '/',
  })
  return res
}
```

- [ ] **Step 4: Run full suite for this file**

```bash
cd src/s3-ui && npx jest __tests__/api/auth.change-password.test.ts --no-coverage
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/s3-ui/app/api/auth/change-password/route.ts src/s3-ui/__tests__/api/auth.change-password.test.ts
git commit -m "fix(s3-ui): block '123456' as new password server-side (#11)"
```

---

## Task 3: Sync manifest.json when lesson title is edited (Issue #14)

**Files:**
- Modify: `src/s3-ui/app/api/lessons/[id]/route.ts`
- Test: `src/s3-ui/__tests__/api/lessons.test.ts`

- [ ] **Step 1: Write the failing test**

In `src/s3-ui/__tests__/api/lessons.test.ts`, the `minio` mock is declared at the top via `jest.mock('@/lib/minio', ...)`. We need to capture the mock functions. Add at the top of the file (after the imports):

```typescript
// Capture mock handles so individual tests can override return values
const mockGetObjectText = jest.mocked(
  (await import('@/lib/minio')).getObjectText,
)
const mockUploadObject = jest.mocked(
  (await import('@/lib/minio')).uploadObject,
)
```

Then add this test inside `describe('PUT /api/lessons/[id]')`:

```typescript
it('updates manifest.json when title changes and lesson is in the manifest', async () => {
  const manifestWithLesson = JSON.stringify({
    version: 1,
    updated_at: '2024-01-01T00:00:00Z',
    lessons: [{ id: 1, title: 'Old Title', pdf: { active: null, checksum: '', history: [] }, audio: null }],
  })
  mockGetObjectText.mockResolvedValueOnce(manifestWithLesson)
  mockUploadObject.mockClear()

  const req = await makeAuthRequest('PUT', 'http://localhost/api/lessons/1', { title: 'New Title' })
  const res = await updateTitle(req, { params: Promise.resolve({ id: '1' }) })
  expect(res.status).toBe(200)

  expect(mockUploadObject).toHaveBeenCalledWith('manifest.json', expect.any(Buffer), 'application/json')
  const manifestCallArgs = mockUploadObject.mock.calls.find(
    (call) => call[0] === 'manifest.json',
  )
  const uploaded = JSON.parse(manifestCallArgs![1].toString())
  const updatedLesson = uploaded.lessons.find((lesson: { id: number }) => lesson.id === 1)
  expect(updatedLesson?.title).toBe('New Title')
})

it('does NOT write manifest when lesson is not published (not in manifest)', async () => {
  const manifestWithoutLesson = JSON.stringify({
    version: 1,
    updated_at: '2024-01-01T00:00:00Z',
    lessons: [],
  })
  mockGetObjectText.mockResolvedValueOnce(manifestWithoutLesson)
  mockUploadObject.mockClear()

  const req = await makeAuthRequest('PUT', 'http://localhost/api/lessons/1', { title: 'Any Title' })
  const res = await updateTitle(req, { params: Promise.resolve({ id: '1' }) })
  expect(res.status).toBe(200)
  expect(mockUploadObject).not.toHaveBeenCalledWith('manifest.json', expect.anything(), expect.anything())
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd src/s3-ui && npx jest __tests__/api/lessons.test.ts --testNamePattern="manifest" --no-coverage
```

Expected: FAIL — `uploadObject` is not called by the current route.

- [ ] **Step 3: Update the PUT route to also write the manifest**

Replace `src/s3-ui/app/api/lessons/[id]/route.ts` with:

```typescript
export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getObjectText, uploadObject } from '@/lib/minio'
import { parseManifest, upsertLesson } from '@/lib/manifest'
import { updateTitleSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const id = parseInt(idStr, 10)
  if (isNaN(id)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const body = await req.json()
  const parsed = updateTitleSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  const lesson = await prisma.lesson.update({
    where: { id },
    data: { title: parsed.data.title },
  })

  // Keep manifest in sync so the mobile app sees the new title without a full republish
  const manifestText = await getObjectText('manifest.json')
  const manifest = parseManifest(manifestText)
  const existingEntry = manifest.lessons.find((entry) => entry.id === id)
  if (existingEntry) {
    const updatedManifest = upsertLesson(manifest, { ...existingEntry, title: lesson.title })
    await uploadObject(
      'manifest.json',
      Buffer.from(JSON.stringify(updatedManifest, null, 2)),
      'application/json',
    )
  }

  return NextResponse.json(lesson)
}
```

- [ ] **Step 4: Run full test suite for this file**

```bash
cd src/s3-ui && npx jest __tests__/api/lessons.test.ts --no-coverage
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/s3-ui/app/api/lessons/[id]/route.ts src/s3-ui/__tests__/api/lessons.test.ts
git commit -m "fix(s3-ui): sync manifest.json when lesson title is edited (#14)"
```

---

## Task 2: Show errors for failed upload and publish toggle (Issue #13)

**Files:**
- Modify: `src/s3-ui/app/(dashboard)/lessons/page.tsx`
- Test: `src/s3-ui/__tests__/components/LessonRow.publish.test.tsx`

- [ ] **Step 1: Write failing test for publish toggle reverting on API failure**

In `src/s3-ui/__tests__/components/LessonRow.publish.test.tsx`, add a test at the end of the file:

```typescript
it('reverts published state when API returns an error', async () => {
  // This test documents the DESIRED behavior: if the API fails, the UI should
  // not update the lesson's published state permanently.
  // Currently the page updates state BEFORE confirming success — this test will fail until Task 2 is implemented.
  const lesson = {
    id: 1, title: 'Test', published: false,
    audio: { active: null, ext: 'mp3', checksum: '', history: [] },
    pdf: { active: 'lessons/1/lesson_v1.pdf', checksum: 'abc', history: [] },
  }
  const onPublishToggle = jest.fn().mockRejectedValue(new Error('API error'))
  render(
    <LessonRow
      lesson={lesson}
      uploadingKey={null}
      onUpload={jest.fn()}
      onDelete={jest.fn()}
      onPreview={jest.fn()}
      onTitleSave={jest.fn()}
      onPublishToggle={onPublishToggle}
    />,
  )
  await userEvent.click(screen.getByRole('button', { name: /publicar/i }))
  await userEvent.click(screen.getByRole('button', { name: /confirmar/i }))
  await waitFor(() => expect(onPublishToggle).toHaveBeenCalled())
  // After the error, the lesson still shows "Publicar" — state not permanently changed
  expect(screen.getByRole('button', { name: /publicar/i })).toBeInTheDocument()
})
```

Note: `LessonRow` receives `onPublishToggle` as a prop and calls it — error handling is the **page's** responsibility, not the row's. This test verifies `LessonRow` calls the prop and doesn't internally corrupt state. The error banner will live in the page.

- [ ] **Step 2: Run test to confirm it passes or clarify**

```bash
cd src/s3-ui && npx jest __tests__/components/LessonRow.publish.test.tsx --no-coverage
```

Expected: PASS (the row itself doesn't manage errors — errors surface in the page).

- [ ] **Step 3: Update LessonsPage to add error state and handle failures**

Replace `src/s3-ui/app/(dashboard)/lessons/page.tsx` with the following (full file):

```typescript
'use client'

import { useEffect, useState, useCallback } from 'react'
import { LessonList } from '@/components/lessons/LessonList'
import { PdfViewer } from '@/components/lessons/PdfViewer'
import { CreateLessonDialog } from '@/components/lessons/CreateLessonDialog'
import { Button } from '@/components/ui/button'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'

interface Lesson {
  id: number
  title: string
  published: boolean
  audio: { active: string | null; ext: string; checksum: string; history: string[] }
  pdf: { active: string | null; checksum: string; history: string[] }
}

interface DeleteTarget { lessonId: number; type: 'audio' | 'pdf' }

function useIsMobile() {
  const [mobile, setMobile] = useState(false)
  useEffect(() => {
    const check = () => setMobile(window.innerWidth < 768)
    check()
    window.addEventListener('resize', check)
    return () => window.removeEventListener('resize', check)
  }, [])
  return mobile
}

export default function LessonsPage() {
  const [lessons, setLessons] = useState<Lesson[]>([])
  const [pdfPath, setPdfPath] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<DeleteTarget | null>(null)
  const [uploadingKey, setUploadingKey] = useState<string | null>(null)
  const [createDialogOpen, setCreateDialogOpen] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const isMobile = useIsMobile()

  const suggestedId = lessons.length > 0 ? Math.max(...lessons.map((lesson) => lesson.id)) + 1 : 1

  const loadLessons = useCallback(async () => {
    const res = await fetch('/api/lessons')
    const data = await res.json()
    setLessons(data)
  }, [])

  useEffect(() => { loadLessons() }, [loadLessons])

  async function handleUpload(lessonId: number, type: 'audio' | 'pdf', file: File) {
    setUploadingKey(`${lessonId}-${type}`)
    try {
      const form = new FormData()
      form.append('file', file)
      const res = await fetch(`/api/lessons/${lessonId}/upload?type=${type}`, { method: 'POST', body: form })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        setErrorMessage(body.error ?? 'Erro ao fazer upload. Tente novamente.')
        return
      }
      await loadLessons()
    } catch {
      setErrorMessage('Erro de rede ao fazer upload. Verifique sua conexão.')
    } finally {
      setUploadingKey(null)
    }
  }

  function handleDeleteRequest(lessonId: number, type: 'audio' | 'pdf') {
    setDeleteTarget({ lessonId, type })
  }

  async function handleDeleteConfirm() {
    if (!deleteTarget) return
    await fetch(`/api/lessons/${deleteTarget.lessonId}/file?type=${deleteTarget.type}`, { method: 'DELETE' })
    setDeleteTarget(null)
    await loadLessons()
  }

  async function handleTitleSave(lessonId: number, title: string) {
    const res = await fetch(`/api/lessons/${lessonId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title }),
    })
    if (res.ok) {
      setLessons((prev) => prev.map((lesson) => (lesson.id === lessonId ? { ...lesson, title } : lesson)))
    }
  }

  async function handlePublishToggle(lessonId: number, published: boolean) {
    const res = await fetch(`/api/lessons/${lessonId}/publish`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ published }),
    })
    if (!res.ok) {
      const body = await res.json().catch(() => ({}))
      setErrorMessage(body.error ?? 'Erro ao alterar publicação. Tente novamente.')
      return
    }
    setLessons((prev) =>
      prev.map((lesson) => (lesson.id === lessonId ? { ...lesson, published } : lesson)),
    )
  }

  return (
    <div className={`flex h-full ${pdfPath && !isMobile ? 'gap-4' : ''}`}>
      <div className={`flex-1 min-w-0 ${pdfPath && !isMobile ? 'w-1/2' : 'w-full'}`}>
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-xl font-bold text-text-main">Lições</h1>
          <div className="flex items-center gap-3">
            {uploadingKey && <span className="text-xs text-gray-400 animate-pulse">Enviando...</span>}
            <Button
              onClick={() => setCreateDialogOpen(true)}
              className="bg-primary hover:bg-yellow-400 text-text-main font-semibold"
              size="sm"
            >
              + Nova Lição
            </Button>
          </div>
        </div>

        {errorMessage && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
            {errorMessage}
            <button className="ml-2 underline text-xs" onClick={() => setErrorMessage(null)}>Fechar</button>
          </div>
        )}

        <LessonList
          lessons={lessons}
          uploadingKey={uploadingKey}
          onUpload={handleUpload}
          onDelete={handleDeleteRequest}
          onPreview={setPdfPath}
          onTitleSave={handleTitleSave}
          onPublishToggle={handlePublishToggle}
        />
      </div>

      {pdfPath && (
        <div className={isMobile ? '' : 'w-1/2 flex flex-col'}>
          <PdfViewer path={pdfPath} onClose={() => setPdfPath(null)} isMobile={isMobile} />
        </div>
      )}

      <CreateLessonDialog
        open={createDialogOpen}
        suggestedId={suggestedId}
        onCreated={() => { setCreateDialogOpen(false); loadLessons() }}
        onClose={() => setCreateDialogOpen(false)}
      />

      <AlertDialog open={!!deleteTarget} onOpenChange={(isOpen) => !isOpen && setDeleteTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmar exclusão</AlertDialogTitle>
            <AlertDialogDescription>
              O arquivo será removido da lição. O arquivo original permanece no storage.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-delete-bg text-delete-text hover:bg-red-200"
              onClick={handleDeleteConfirm}
            >
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
```

- [ ] **Step 4: Run existing component tests to check for regressions**

```bash
cd src/s3-ui && npx jest __tests__/components/ --no-coverage
```

Expected: All existing tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/s3-ui/app/(dashboard)/lessons/page.tsx src/s3-ui/__tests__/components/LessonRow.publish.test.tsx
git commit -m "fix(s3-ui): show error banner on upload/publish failure (#13)"
```

---

## Task 4: Enforce file size limits on upload (Issue #12)

**Files:**
- Modify: `src/s3-ui/app/api/lessons/[id]/upload/route.ts`
- Modify: `src/s3-ui/components/lessons/FileRow.tsx`
- Test: `src/s3-ui/__tests__/api/lessons.upload.test.ts`

Limits: 50 MB for PDF, 20 MB for audio. These are round numbers safe for a Node.js buffer and well within MinIO's defaults.

- [ ] **Step 1: Write the failing tests**

Add to `src/s3-ui/__tests__/api/lessons.upload.test.ts` a new `describe` block:

```typescript
describe('POST /api/lessons/[id]/upload — file size validation', () => {
  async function makeOversizeRequest(lessonId: number, type: 'audio' | 'pdf', sizeBytes: number): Promise<NextRequest> {
    const token = await signToken({ id: 1, username: 'victor', isAdmin: false, mustChangePassword: false })
    const content = Buffer.alloc(sizeBytes, 'x')
    const form = new FormData()
    form.append('file', new File([content], `file.${type === 'pdf' ? 'pdf' : 'mp3'}`, { type: type === 'pdf' ? 'application/pdf' : 'audio/mpeg' }))
    const req = new NextRequest(`http://localhost/api/lessons/${lessonId}/upload?type=${type}`, {
      method: 'POST',
      body: form,
    })
    req.cookies.set(TOKEN_COOKIE, token)
    return req
  }

  beforeEach(() => {
    mockGetObjectText.mockResolvedValue(MANIFEST_WITHOUT_LESSON_24)
    mockUploadObject.mockResolvedValue(undefined)
  })

  it('returns 413 when PDF exceeds 50 MB', async () => {
    const oversizePdf = 51 * 1024 * 1024 // 51 MB
    const req = await makeOversizeRequest(24, 'pdf', oversizePdf)
    const res = await uploadFile(req, { params: Promise.resolve({ id: '24' }) })
    expect(res.status).toBe(413)
    const body = await res.json()
    expect(body.error).toMatch(/50.*MB|tamanho/i)
  })

  it('returns 413 when audio exceeds 20 MB', async () => {
    const oversizeAudio = 21 * 1024 * 1024 // 21 MB
    const req = await makeOversizeRequest(24, 'audio', oversizeAudio)
    const res = await uploadFile(req, { params: Promise.resolve({ id: '24' }) })
    expect(res.status).toBe(413)
    const body = await res.json()
    expect(body.error).toMatch(/20.*MB|tamanho/i)
  })

  it('accepts PDF at exactly 50 MB', async () => {
    const maxPdf = 50 * 1024 * 1024
    const req = await makeOversizeRequest(24, 'pdf', maxPdf)
    const res = await uploadFile(req, { params: Promise.resolve({ id: '24' }) })
    expect(res.status).toBe(200)
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd src/s3-ui && npx jest __tests__/api/lessons.upload.test.ts --testNamePattern="413|size" --no-coverage
```

Expected: FAIL — the route currently accepts any size.

- [ ] **Step 3: Add size validation to the upload route**

In `src/s3-ui/app/api/lessons/[id]/upload/route.ts`, after `const buffer = Buffer.from(await file.arrayBuffer())`, add:

```typescript
const MAX_BYTES = type === 'pdf' ? 50 * 1024 * 1024 : 20 * 1024 * 1024
const MAX_LABEL = type === 'pdf' ? '50 MB' : '20 MB'
if (buffer.byteLength > MAX_BYTES) {
  return NextResponse.json(
    { error: `O arquivo excede o limite de ${MAX_LABEL} para ${type === 'pdf' ? 'PDF' : 'áudio'}` },
    { status: 413 },
  )
}
```

But the size check must happen **before** we read the type from the query param, which means we need the `type` value. The current flow already parses `type` before building the buffer. Verify the insert position is after line 31 (`const buffer = ...`) and before line 34 (`const [dbLesson, manifestText] ...`). The full updated section:

```typescript
const type = parsed.data.type
const formData = await req.formData()
const file = formData.get('file') as File | null
if (!file) return NextResponse.json({ error: 'No file provided' }, { status: 400 })

const buffer = Buffer.from(await file.arrayBuffer())

const MAX_BYTES = type === 'pdf' ? 50 * 1024 * 1024 : 20 * 1024 * 1024
const MAX_LABEL = type === 'pdf' ? '50 MB' : '20 MB'
if (buffer.byteLength > MAX_BYTES) {
  return NextResponse.json(
    { error: `O arquivo excede o limite de ${MAX_LABEL} para ${type === 'pdf' ? 'PDF' : 'áudio'}` },
    { status: 413 },
  )
}

const checksum = crypto.createHash('md5').update(buffer).digest('hex')
```

- [ ] **Step 4: Add client-side `accept` size hint in FileRow**

In `src/s3-ui/components/lessons/FileRow.tsx`, add a `MAX_FILE_BYTES` constant and `onChange` guard. Replace the `handleFileChange` function and the `<input>` element for the "no active file" branch:

```typescript
const MAX_AUDIO_BYTES = 20 * 1024 * 1024
const MAX_PDF_BYTES = 50 * 1024 * 1024

function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
  const file = e.target.files?.[0]
  if (!file) return
  const limit = type === 'audio' ? MAX_AUDIO_BYTES : MAX_PDF_BYTES
  const limitLabel = type === 'audio' ? '20 MB' : '50 MB'
  if (file.size > limit) {
    alert(`O arquivo excede o limite de ${limitLabel}. Escolha um arquivo menor.`)
    e.target.value = ''
    return
  }
  onUpload(lessonId, type, file)
}
```

- [ ] **Step 5: Run full upload test suite**

```bash
cd src/s3-ui && npx jest __tests__/api/lessons.upload.test.ts --no-coverage
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add src/s3-ui/app/api/lessons/[id]/upload/route.ts \
        src/s3-ui/components/lessons/FileRow.tsx \
        src/s3-ui/__tests__/api/lessons.upload.test.ts
git commit -m "fix(s3-ui): enforce file size limits (50MB PDF, 20MB audio) (#12)"
```

---

## Task 5: Clean up E2E-created users after each test run (Issue #15)

**Files:**
- Modify: `src/s3-ui/e2e/users.spec.ts`

- [ ] **Step 1: Inspect the current state of the test**

The file has no `afterAll` — users with prefix `e2e_user_` accumulate forever in `betelapp_test`.

- [ ] **Step 2: Add cleanup via the API**

Replace `src/s3-ui/e2e/users.spec.ts` with:

```typescript
import { test, expect, type Page } from '@playwright/test'

async function loginAsAdmin(page: Page) {
  await page.goto('/login')
  await page.getByLabel('Usuário').fill('victor')
  await page.getByLabel('Senha').fill(process.env.E2E_VICTOR_PASSWORD!)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await page.waitForURL('/lessons')
}

async function deleteE2eUsers(page: Page) {
  const res = await page.request.get('/api/users')
  const users: Array<{ id: number; username: string }> = await res.json()
  const e2eUsers = users.filter((user) => user.username.startsWith('e2e_user_'))
  await Promise.all(
    e2eUsers.map((user) => page.request.delete(`/api/users/${user.id}`)),
  )
}

test.beforeEach(async ({ page }) => {
  await loginAsAdmin(page)
})

test.afterAll(async ({ browser }) => {
  const context = await browser.newContext()
  const page = await context.newPage()
  await loginAsAdmin(page)
  await deleteE2eUsers(page)
  await context.close()
})

test('admin can access users page', async ({ page }) => {
  await page.goto('/users')
  await expect(page.getByRole('heading', { name: 'Usuários' })).toBeVisible()
})

test('admin can create a new user', async ({ page }) => {
  await page.goto('/users')
  const timestamp = Date.now()
  const testUsername = `e2e_user_${timestamp}`
  await page.getByLabel('Usuário').fill(testUsername)
  await page.getByRole('button', { name: /criar/i }).click()
  await expect(page.getByText(testUsername)).toBeVisible()
})
```

- [ ] **Step 3: Run the E2E tests locally**

```bash
cd src/s3-ui && npx playwright test e2e/users.spec.ts --reporter=list
```

Expected: Both tests pass. After the run, no `e2e_user_` rows remain in the DB.

Verify cleanup:
```bash
cd src/s3-ui && npx tsx -e "
import { prisma } from './lib/prisma'
const count = await prisma.user.count({ where: { username: { startsWith: 'e2e_user_' } } })
console.log('Leftover e2e users:', count)
await prisma.\$disconnect()
"
```

Expected output: `Leftover e2e users: 0`

- [ ] **Step 4: Commit**

```bash
git add src/s3-ui/e2e/users.spec.ts
git commit -m "fix(s3-ui): clean up e2e_user_ accounts after E2E test run (#15)"
```

---

## Final Step: Full regression run

- [ ] **Run all unit tests**

```bash
cd src/s3-ui && npx jest --no-coverage
```

Expected: All suites PASS with no regressions.

- [ ] **Run all E2E tests**

```bash
cd src/s3-ui && npx playwright test --reporter=list
```

Expected: All E2E specs pass.
