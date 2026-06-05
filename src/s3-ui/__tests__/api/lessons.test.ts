/**
 * @jest-environment node
 */
import { GET as getLessons } from '@/app/api/lessons/route'
import { PUT as updateTitle } from '@/app/api/lessons/[id]/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'
import { getObjectText, uploadObject } from '@/lib/minio'

jest.mock('@/lib/minio', () => ({
  getObjectText: jest.fn().mockResolvedValue(
    JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [] }),
  ),
  uploadObject: jest.fn().mockResolvedValue(undefined),
}))

const mockGetObjectText = jest.mocked(getObjectText)
const mockUploadObject = jest.mocked(uploadObject)

async function makeAuthRequest(method: string, url: string, body?: object): Promise<NextRequest> {
  // Any logged-in user (not necessarily admin) can mutate lessons
  const token = await signToken({ id: 1, username: 'victor', isAdmin: false, mustChangePassword: false })
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
    where: { id: 1 },
    update: {},
    create: { id: 1, title: 'Test Lesson' },
  })
})

afterAll(async () => {
  await prisma.$disconnect()
})

describe('GET /api/lessons', () => {
  it('returns lessons array', async () => {
    const res = await getLessons()
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(Array.isArray(data)).toBe(true)
  })
})

describe('PUT /api/lessons/[id]', () => {
  it('updates title successfully', async () => {
    const req = await makeAuthRequest('PUT', 'http://localhost/api/lessons/1', { title: 'Updated Title' })
    const res = await updateTitle(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.title).toBe('Updated Title')
  })

  it('returns 400 on empty title', async () => {
    const req = await makeAuthRequest('PUT', 'http://localhost/api/lessons/1', { title: '' })
    const res = await updateTitle(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(400)
  })

  it('returns 401 without token', async () => {
    const req = new NextRequest('http://localhost/api/lessons/1', {
      method: 'PUT',
      body: JSON.stringify({ title: 'No auth' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await updateTitle(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(401)
  })

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
    const uploaded = JSON.parse((manifestCallArgs![1] as Buffer).toString())
    const updatedLesson = uploaded.lessons.find((lesson: { id: number }) => lesson.id === 1)
    expect(updatedLesson?.title).toBe('New Title')
    expect(uploaded.version).toBe(2) // version increments so mobile clients re-sync the new title
  })

  it('returns 200 even when manifest fetch fails (manifest is best-effort)', async () => {
    mockGetObjectText.mockRejectedValueOnce(new Error('MinIO unreachable'))
    mockUploadObject.mockClear()

    const req = await makeAuthRequest('PUT', 'http://localhost/api/lessons/1', { title: 'Safe Title' })
    const res = await updateTitle(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.title).toBe('Safe Title')
  })

  it('does NOT write manifest when lesson is not in the manifest (unpublished)', async () => {
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
})
