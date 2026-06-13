/**
 * @jest-environment node
 */
import { GET as listContents, POST as createContent } from '@/app/api/contents/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

jest.mock('@/lib/minio', () => ({
  getObjectText: jest.fn(),
  uploadObject: jest.fn(),
}))

async function makeAuthRequest(
  body: object,
  method = 'POST',
): Promise<NextRequest> {
  const token = await signToken({
    id: 1, username: 'victor', isAdmin: false, mustChangePassword: false,
  })
  const req = new NextRequest('http://localhost/api/contents', {
    method,
    body: method === 'POST' ? JSON.stringify(body) : undefined,
    headers: { 'Content-Type': 'application/json' },
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

async function makeGetRequest(): Promise<NextRequest> {
  const token = await signToken({
    id: 1, username: 'victor', isAdmin: false, mustChangePassword: false,
  })
  const req = new NextRequest('http://localhost/api/contents', { method: 'GET' })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

afterAll(async () => {
  await prisma.content.deleteMany({ where: { id: { gte: 900 } } })
  await prisma.$disconnect()
})

describe('GET /api/contents', () => {
  it('returns 200 with array', async () => {
    const res = await listContents()
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(Array.isArray(body)).toBe(true)
  })

  it('excludes child pages from the list (only root/standalone)', async () => {
    // Create a parent with 2 child pages
    const parent = await prisma.content.create({
      data: { slug: 'test-parent-list', title: 'Parent List', type: 'TEXT' },
    })
    await prisma.content.create({
      data: { slug: 'test-parent-list-p0', title: 'Parent List — Página 1', type: 'TEXT', parentId: parent.id, pageIndex: 0 },
    })
    await prisma.content.create({
      data: { slug: 'test-parent-list-p1', title: 'Parent List — Página 2', type: 'TEXT', parentId: parent.id, pageIndex: 1 },
    })

    const res = await listContents()
    const body = await res.json()
    const slugs = body.map((content: { slug: string }) => content.slug)

    expect(slugs).toContain('test-parent-list')
    expect(slugs).not.toContain('test-parent-list-p0')
    expect(slugs).not.toContain('test-parent-list-p1')
  })

  it('includes pageCount for multi-page content', async () => {
    const res = await listContents()
    const body = await res.json()
    const parent = body.find((content: { slug: string }) => content.slug === 'test-parent-list')

    expect(parent).toBeDefined()
    expect(parent.pageCount).toBe(2)
  })

  it('returns pageCount 0 for standalone content', async () => {
    await prisma.content.create({
      data: { slug: 'test-standalone-count', title: 'Standalone Count', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=x' },
    })

    const res = await listContents()
    const body = await res.json()
    const standalone = body.find((content: { slug: string }) => content.slug === 'test-standalone-count')

    expect(standalone).toBeDefined()
    expect(standalone.pageCount).toBe(0)
  })
})

describe('POST /api/contents', () => {
  beforeEach(async () => {
    await prisma.content.deleteMany({ where: { slug: { startsWith: 'test-' } } })
  })

  it('creates VIDEO content with auto-generated slug and returns 201', async () => {
    const req = await makeAuthRequest({
      title: 'Test Video Content', type: 'VIDEO',
      youtubeUrl: 'https://youtube.com/watch?v=abc',
    })
    const res = await createContent(req)
    expect(res.status).toBe(201)
    const body = await res.json()
    expect(body.slug).toBe('test-video-content')
    expect(body.type).toBe('VIDEO')
    expect(body.youtubeUrl).toBe('https://youtube.com/watch?v=abc')
    expect(body.published).toBe(false)
  })

  it('creates TEXT content with auto-generated slug and returns 201', async () => {
    const req = await makeAuthRequest({
      title: 'Test Text Content', type: 'TEXT',
    })
    const res = await createContent(req)
    expect(res.status).toBe(201)
    const body = await res.json()
    expect(body.slug).toBe('test-text-content')
    expect(body.type).toBe('TEXT')
    expect(body.youtubeUrl).toBeNull()
  })

  it('returns 409 when title already exists', async () => {
    await prisma.content.create({
      data: { slug: 'test-dup', title: 'Test Dup', type: 'TEXT' },
    })
    const req = await makeAuthRequest({
      title: 'Test Dup', type: 'TEXT',
    })
    const res = await createContent(req)
    expect(res.status).toBe(409)
  })

  it('returns 400 when VIDEO has no youtubeUrl', async () => {
    const req = await makeAuthRequest({
      title: 'Test No URL', type: 'VIDEO',
    })
    const res = await createContent(req)
    expect(res.status).toBe(400)
  })

  it('returns 400 when title is empty', async () => {
    const req = await makeAuthRequest({
      title: '', type: 'TEXT',
    })
    const res = await createContent(req)
    expect(res.status).toBe(400)
  })

  it('returns 401 without auth token', async () => {
    const req = new NextRequest('http://localhost/api/contents', {
      method: 'POST',
      body: JSON.stringify({ title: 'Test No Auth', type: 'TEXT' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await createContent(req)
    expect(res.status).toBe(401)
  })

  it('creates a child page linked to parent with auto-generated slug and title', async () => {
    const parent = await prisma.content.create({
      data: { slug: 'test-child-create', title: 'Child Create Parent', type: 'TEXT' },
    })
    const req = await makeAuthRequest({
      parentId: parent.id,
    })
    const res = await createContent(req)
    expect(res.status).toBe(201)
    const body = await res.json()
    expect(body.parentId).toBe(parent.id)
    expect(body.pageIndex).toBe(0)
    expect(body.type).toBe('TEXT')
    expect(body.slug).toBe('test-child-create-p0')
    expect(body.title).toBe('Child Create Parent — Página 1')
  })

  it('assigns sequential pageIndex to child pages', async () => {
    const parent = await prisma.content.create({
      data: { slug: 'test-seq-parent', title: 'Seq Parent', type: 'TEXT' },
    })
    // Create first child
    const req1 = await makeAuthRequest({ parentId: parent.id })
    await createContent(req1)
    // Create second child
    const req2 = await makeAuthRequest({ parentId: parent.id })
    const res2 = await createContent(req2)
    const body2 = await res2.json()
    expect(body2.pageIndex).toBe(1)
    expect(body2.slug).toBe('test-seq-parent-p1')
  })

  it('returns 400 when creating child page for VIDEO parent', async () => {
    const parent = await prisma.content.create({
      data: { slug: 'test-video-parent', title: 'Video Parent', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=x' },
    })
    const req = await makeAuthRequest({ parentId: parent.id })
    const res = await createContent(req)
    expect(res.status).toBe(400)
  })

  it('returns 404 when creating child page for non-existent parent', async () => {
    const req = await makeAuthRequest({ parentId: 999999 })
    const res = await createContent(req)
    expect(res.status).toBe(404)
  })

  it('does NOT write to manifest on create', async () => {
    const { uploadObject } = jest.requireMock('@/lib/minio') as { uploadObject: jest.Mock }
    uploadObject.mockClear()
    const req = await makeAuthRequest({
      title: 'Test No Manifest', type: 'TEXT',
    })
    await createContent(req)
    const manifestCalls = uploadObject.mock.calls.filter(
      (call: unknown[]) => call[0] === 'manifest.json',
    )
    expect(manifestCalls).toHaveLength(0)
  })
})
