/**
 * @jest-environment node
 */
import { GET as getLessons } from '@/app/api/lessons/route'
import { PATCH as togglePublish } from '@/app/api/lessons/[id]/publish/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

jest.mock('@/lib/minio', () => ({
  getObjectText: jest.fn().mockResolvedValue(
    JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [] }),
  ),
  uploadObject: jest.fn().mockResolvedValue(undefined),
}))

async function makeAuthRequest(method: string, url: string, body?: object): Promise<NextRequest> {
  const token = await signToken({ id: 1, username: 'victor', isAdmin: true })
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
    update: { title: 'Test Lesson', published: false },
    create: { id: 1, title: 'Test Lesson', published: false },
  })
})

afterAll(async () => {
  await prisma.$disconnect()
})

describe('GET /api/lessons — published field', () => {
  it('returns published field on each lesson', async () => {
    const res = await getLessons()
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(Array.isArray(data)).toBe(true)
    const lesson = data.find((l: { id: number }) => l.id === 1)
    expect(lesson).toBeDefined()
    expect(typeof lesson.published).toBe('boolean')
  })
})

describe('PATCH /api/lessons/[id]/publish', () => {
  it('publishes an unpublished lesson', async () => {
    const req = await makeAuthRequest('PATCH', 'http://localhost/api/lessons/1/publish', {
      published: true,
    })
    const res = await togglePublish(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.published).toBe(true)
  })

  it('unpublishes a published lesson', async () => {
    await prisma.lesson.update({ where: { id: 1 }, data: { published: true } })

    const req = await makeAuthRequest('PATCH', 'http://localhost/api/lessons/1/publish', {
      published: false,
    })
    const res = await togglePublish(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.published).toBe(false)
  })

  it('returns 400 on invalid body', async () => {
    const req = await makeAuthRequest('PATCH', 'http://localhost/api/lessons/1/publish', {
      published: 'yes',
    })
    const res = await togglePublish(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(400)
  })

  it('returns 401 without token', async () => {
    const req = new NextRequest('http://localhost/api/lessons/1/publish', {
      method: 'PATCH',
      body: JSON.stringify({ published: true }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await togglePublish(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(401)
  })

  it('returns 404 for non-existent lesson', async () => {
    const req = await makeAuthRequest('PATCH', 'http://localhost/api/lessons/9999/publish', {
      published: true,
    })
    const res = await togglePublish(req, { params: Promise.resolve({ id: '9999' }) })
    expect(res.status).toBe(404)
  })
})
