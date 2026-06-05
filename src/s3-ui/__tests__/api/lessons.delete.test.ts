/**
 * @jest-environment node
 */
import { DELETE as deleteLesson } from '@/app/api/lessons/[id]/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

const mockGetObjectText = jest.fn()
const mockUploadObject = jest.fn()
const mockDeleteFolder = jest.fn()

jest.mock('@/lib/minio', () => ({
  getObjectText: (...args: unknown[]) => mockGetObjectText(...args),
  uploadObject: (...args: unknown[]) => mockUploadObject(...args),
  deleteFolder: (...args: unknown[]) => mockDeleteFolder(...args),
}))

const MANIFEST_WITH_LESSON_900 = JSON.stringify({
  version: 1,
  updated_at: '2024-01-01T00:00:00Z',
  lessons: [
    {
      id: 900,
      title: 'Lição para deletar',
      pdf: { active: 'lessons/900/lesson_v1.pdf', checksum: 'abc', history: [] },
      audio: null,
    },
  ],
})

let nonAdminUserId: number

async function makeAdminRequest(): Promise<NextRequest> {
  const token = await signToken({ id: 1, username: 'victor', isAdmin: true, mustChangePassword: false })
  const req = new NextRequest('http://localhost/api/lessons/900', { method: 'DELETE' })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

async function makeNonAdminRequest(): Promise<NextRequest> {
  const token = await signToken({ id: nonAdminUserId, username: 'nonadmin-delete-test', isAdmin: false, mustChangePassword: false })
  const req = new NextRequest('http://localhost/api/lessons/900', { method: 'DELETE' })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeAll(async () => {
  await prisma.user.upsert({
    where: { id: 1 },
    update: { isAdmin: true },
    create: { id: 1, username: 'victor-delete-test', passwordHash: 'x', isAdmin: true },
  })
  const nonAdmin = await prisma.user.upsert({
    where: { username: 'nonadmin-delete-test' },
    update: { isAdmin: false },
    create: { username: 'nonadmin-delete-test', passwordHash: 'x', isAdmin: false },
  })
  nonAdminUserId = nonAdmin.id
})

beforeEach(async () => {
  await prisma.lesson.upsert({
    where: { id: 900 },
    update: { title: 'Lição para deletar', published: false, pdfActive: 'lessons/900/lesson_v1.pdf', pdfChecksum: 'abc', pdfHistory: [] },
    create: { id: 900, title: 'Lição para deletar', published: false, pdfActive: 'lessons/900/lesson_v1.pdf', pdfChecksum: 'abc', pdfHistory: [] },
  })
  mockGetObjectText.mockResolvedValue(MANIFEST_WITH_LESSON_900)
  mockUploadObject.mockResolvedValue(undefined)
  mockDeleteFolder.mockResolvedValue(undefined)
})

afterAll(async () => {
  await prisma.lesson.deleteMany({ where: { id: 900 } })
  await prisma.$disconnect()
})

describe('DELETE /api/lessons/[id] — admin guard', () => {
  it('returns 403 when caller is not admin', async () => {
    const req = await makeNonAdminRequest()
    const res = await deleteLesson(req, { params: Promise.resolve({ id: '900' }) })
    expect(res.status).toBe(403)
  })

  it('returns 401 when no token is present', async () => {
    const req = new NextRequest('http://localhost/api/lessons/900', { method: 'DELETE' })
    const res = await deleteLesson(req, { params: Promise.resolve({ id: '900' }) })
    expect(res.status).toBe(401)
  })
})

describe('DELETE /api/lessons/[id] — happy path', () => {
  it('returns 204 on success', async () => {
    const req = await makeAdminRequest()
    const res = await deleteLesson(req, { params: Promise.resolve({ id: '900' }) })
    expect(res.status).toBe(204)
  })

  it('removes the lesson from the database', async () => {
    const req = await makeAdminRequest()
    await deleteLesson(req, { params: Promise.resolve({ id: '900' }) })
    const lesson = await prisma.lesson.findUnique({ where: { id: 900 } })
    expect(lesson).toBeNull()
  })

  it('removes the lesson from the manifest', async () => {
    mockUploadObject.mockClear()
    const req = await makeAdminRequest()
    await deleteLesson(req, { params: Promise.resolve({ id: '900' }) })

    const manifestUpload = mockUploadObject.mock.calls.find((call) => call[0] === 'manifest.json')
    expect(manifestUpload).toBeDefined()
    const written = JSON.parse((manifestUpload![1] as Buffer).toString())
    const stillInManifest = written.lessons.find((lesson: { id: number }) => lesson.id === 900)
    expect(stillInManifest).toBeUndefined()
  })

  it('deletes MinIO files under lessons/{id}/', async () => {
    mockDeleteFolder.mockClear()
    const req = await makeAdminRequest()
    await deleteLesson(req, { params: Promise.resolve({ id: '900' }) })
    expect(mockDeleteFolder).toHaveBeenCalledWith('lessons/900/')
  })

  it('writes an audit log entry with action "delete" that survives lesson deletion', async () => {
    await prisma.lessonAuditLog.deleteMany({ where: { lessonId: 900 } })
    const req = await makeAdminRequest()
    await deleteLesson(req, { params: Promise.resolve({ id: '900' }) })

    const logEntry = await prisma.lessonAuditLog.findFirst({ where: { lessonId: 900, action: 'delete' } })
    expect(logEntry).not.toBeNull()
    expect(logEntry?.userId).toBe(1)
  })
})

describe('DELETE /api/lessons/[id] — questions cleanup', () => {
  it('hard-deletes all questions belonging to the lesson', async () => {
    await prisma.question.createMany({
      data: [
        { lessonId: 900, question: 'Q1?', answer: 'A1.', order: 0 },
        { lessonId: 900, question: 'Q2?', answer: 'A2.', order: 1, deletedAt: new Date() },
      ],
    })
    const req = await makeAdminRequest()
    await deleteLesson(req, { params: Promise.resolve({ id: '900' }) })
    const remaining = await prisma.question.findMany({ where: { lessonId: 900 } })
    expect(remaining).toHaveLength(0)
  })
})

describe('DELETE /api/lessons/[id] — edge cases', () => {
  it('returns 404 when lesson does not exist', async () => {
    const req = await makeAdminRequest()
    const res = await deleteLesson(req, { params: Promise.resolve({ id: '99999' }) })
    expect(res.status).toBe(404)
  })

  it('still removes lesson from DB even if lesson is not in manifest', async () => {
    mockGetObjectText.mockResolvedValue(JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [] }))
    const req = await makeAdminRequest()
    const res = await deleteLesson(req, { params: Promise.resolve({ id: '900' }) })
    expect(res.status).toBe(204)
    const lesson = await prisma.lesson.findUnique({ where: { id: 900 } })
    expect(lesson).toBeNull()
  })
})
