/**
 * @jest-environment node
 */
import { POST as uploadFile } from '@/app/api/lessons/[id]/upload/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

const mockGetObjectText = jest.fn()
const mockUploadObject = jest.fn()

jest.mock('@/lib/minio', () => ({
  getObjectText: (...args: unknown[]) => mockGetObjectText(...args),
  uploadObject: (...args: unknown[]) => mockUploadObject(...args),
}))

const MANIFEST_WITHOUT_LESSON_24 = JSON.stringify({
  version: 1,
  updated_at: '2024-01-01T00:00:00Z',
  lessons: [],
})

async function makeUploadRequest(lessonId: number, type: 'audio' | 'pdf'): Promise<NextRequest> {
  const token = await signToken({ id: 1, username: 'victor', isAdmin: false, mustChangePassword: false })
  const form = new FormData()
  form.append('file', new File(['content'], `file.${type === 'pdf' ? 'pdf' : 'mp3'}`, { type: type === 'pdf' ? 'application/pdf' : 'audio/mpeg' }))
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

beforeAll(async () => {
  await prisma.lesson.upsert({
    where: { id: 24 },
    update: { title: 'Lição 24', pdfActive: null, pdfChecksum: null, audioActive: null },
    create: { id: 24, title: 'Lição 24' },
  })
})

afterAll(async () => {
  await prisma.$disconnect()
})

describe('POST /api/lessons/[id]/upload — lição ausente do manifest', () => {
  it('uploads pdf successfully even when lesson is not in manifest', async () => {
    const req = await makeUploadRequest(24, 'pdf')
    const res = await uploadFile(req, { params: Promise.resolve({ id: '24' }) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.path).toContain('lessons/24')
  })

  it('persists pdfActive in the database after upload even when lesson was not in manifest', async () => {
    await prisma.lesson.update({ where: { id: 24 }, data: { pdfActive: null, pdfChecksum: null } })
    const req = await makeUploadRequest(24, 'pdf')
    await uploadFile(req, { params: Promise.resolve({ id: '24' }) })
    const lesson = await prisma.lesson.findUnique({ where: { id: 24 } })
    expect(lesson?.pdfActive).not.toBeNull()
  })

  it('does NOT add an unpublished lesson to the manifest on upload', async () => {
    await prisma.lesson.update({ where: { id: 24 }, data: { published: false, pdfActive: null, pdfChecksum: null } })
    mockUploadObject.mockClear()
    const req = await makeUploadRequest(24, 'pdf')
    const res = await uploadFile(req, { params: Promise.resolve({ id: '24' }) })
    expect(res.status).toBe(200)

    const manifestUpload = mockUploadObject.mock.calls.find((call) => call[0] === 'manifest.json')
    expect(manifestUpload).toBeUndefined()
  })

  it('DOES update the manifest when uploading to a published lesson not currently in manifest', async () => {
    await prisma.lesson.update({ where: { id: 24 }, data: { published: true, pdfActive: null, pdfChecksum: null } })
    mockUploadObject.mockClear()
    const req = await makeUploadRequest(24, 'pdf')
    const res = await uploadFile(req, { params: Promise.resolve({ id: '24' }) })
    expect(res.status).toBe(200)

    const manifestUpload = mockUploadObject.mock.calls.find((call) => call[0] === 'manifest.json')
    expect(manifestUpload).toBeDefined()
    // Restore published=false for other tests
    await prisma.lesson.update({ where: { id: 24 }, data: { published: false } })
  })
})

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
    const oversizePdf = 51 * 1024 * 1024
    const req = await makeOversizeRequest(24, 'pdf', oversizePdf)
    const res = await uploadFile(req, { params: Promise.resolve({ id: '24' }) })
    expect(res.status).toBe(413)
    const body = await res.json()
    expect(body.error).toMatch(/50.*MB|tamanho/i)
  })

  it('returns 413 when audio exceeds 20 MB', async () => {
    const oversizeAudio = 21 * 1024 * 1024
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
