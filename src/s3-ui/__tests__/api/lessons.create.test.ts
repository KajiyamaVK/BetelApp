/**
 * @jest-environment node
 */
import { POST as createLesson } from '@/app/api/lessons/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

const mockGetObjectText = jest.fn()
const mockUploadObject = jest.fn()

jest.mock('@/lib/minio', () => ({
  getObjectText: (...args: unknown[]) => mockGetObjectText(...args),
  uploadObject: (...args: unknown[]) => mockUploadObject(...args),
}))

const EMPTY_MANIFEST = JSON.stringify({
  version: 1,
  updated_at: '2024-01-01T00:00:00Z',
  lessons: [],
})

async function makeAuthRequest(body: object): Promise<NextRequest> {
  const token = await signToken({ id: 1, username: 'victor', isAdmin: false, mustChangePassword: false })
  const req = new NextRequest('http://localhost/api/lessons', {
    method: 'POST',
    body: JSON.stringify(body),
    headers: { 'Content-Type': 'application/json' },
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeEach(() => {
  mockGetObjectText.mockResolvedValue(EMPTY_MANIFEST)
  mockUploadObject.mockResolvedValue(undefined)
})

afterAll(async () => {
  await prisma.lesson.deleteMany({ where: { id: { in: [901, 902] } } })
  await prisma.$disconnect()
})

describe('POST /api/lessons', () => {
  it('creates a lesson and returns 201 with id and title', async () => {
    const req = await makeAuthRequest({ id: 901, title: 'Nova Lição Teste' })
    const res = await createLesson(req)
    expect(res.status).toBe(201)
    const body = await res.json()
    expect(body.id).toBe(901)
    expect(body.title).toBe('Nova Lição Teste')
    expect(body.published).toBe(false)
  })

  it('persists the lesson in the database', async () => {
    await prisma.lesson.deleteMany({ where: { id: 902 } })
    const req = await makeAuthRequest({ id: 902, title: 'Lição Persistida' })
    await createLesson(req)
    const dbLesson = await prisma.lesson.findUnique({ where: { id: 902 } })
    expect(dbLesson).not.toBeNull()
    expect(dbLesson?.title).toBe('Lição Persistida')
  })

  it('adds the lesson entry to the manifest', async () => {
    await prisma.lesson.deleteMany({ where: { id: 902 } })
    mockUploadObject.mockClear()
    const req = await makeAuthRequest({ id: 902, title: 'Lição no Manifest' })
    await createLesson(req)
    const manifestUpload = mockUploadObject.mock.calls.find((call) => call[0] === 'manifest.json')
    expect(manifestUpload).toBeDefined()
    const writtenManifest = JSON.parse(manifestUpload[1].toString())
    const entry = writtenManifest.lessons.find((l: { id: number }) => l.id === 902)
    expect(entry).toBeDefined()
    expect(entry.title).toBe('Lição no Manifest')
  })

  it('returns 409 with message when id already exists', async () => {
    await prisma.lesson.upsert({
      where: { id: 901 },
      update: {},
      create: { id: 901, title: 'Já existe' },
    })
    const req = await makeAuthRequest({ id: 901, title: 'Duplicada' })
    const res = await createLesson(req)
    expect(res.status).toBe(409)
    const body = await res.json()
    expect(body.error).toMatch(/901/)
  })

  it('returns 400 when id is missing', async () => {
    const req = await makeAuthRequest({ title: 'Sem ID' })
    const res = await createLesson(req)
    expect(res.status).toBe(400)
  })

  it('returns 400 when id is not a positive integer', async () => {
    const req = await makeAuthRequest({ id: 0, title: 'ID zero' })
    const res = await createLesson(req)
    expect(res.status).toBe(400)
  })

  it('returns 400 when title is empty', async () => {
    const req = await makeAuthRequest({ id: 903, title: '' })
    const res = await createLesson(req)
    expect(res.status).toBe(400)
  })

  it('returns 401 without auth token', async () => {
    const req = new NextRequest('http://localhost/api/lessons', {
      method: 'POST',
      body: JSON.stringify({ id: 904, title: 'Sem auth' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await createLesson(req)
    expect(res.status).toBe(401)
  })
})
