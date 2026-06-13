/**
 * @jest-environment node
 */
import { GET, PUT, DELETE } from '@/app/api/contents/[id]/route'
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

const MANIFEST_WITH_CONTENT = JSON.stringify({
  version: 1,
  updated_at: '2024-01-01T00:00:00Z',
  lessons: [],
  contents: [
    { id: 950, slug: 'crud-published', title: 'Published', type: 'TEXT', html: '<p>hi</p>' },
  ],
})

function makeParams(id: number) {
  return Promise.resolve({ id: String(id) })
}

async function makeRequest(
  id: number,
  method: string,
  body?: object,
): Promise<NextRequest> {
  const token = await signToken({
    id: 1, username: 'victor', isAdmin: false, mustChangePassword: false,
  })
  const req = new NextRequest(`http://localhost/api/contents/${id}`, {
    method,
    body: body ? JSON.stringify(body) : undefined,
    headers: body ? { 'Content-Type': 'application/json' } : {},
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeAll(async () => {
  await prisma.content.deleteMany({ where: { id: { gte: 940 } } })
  await prisma.content.createMany({
    data: [
      { id: 950, slug: 'crud-published', title: 'Published', type: 'TEXT', htmlPath: 'contents/950/content.html', published: true },
      { id: 951, slug: 'crud-unpublished', title: 'Unpublished', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=x' },
    ],
  })
})

beforeEach(() => {
  mockGetObjectText.mockReset()
  mockUploadObject.mockReset()
  mockDeleteFolder.mockReset()
  mockGetObjectText.mockResolvedValue(MANIFEST_WITH_CONTENT)
  mockUploadObject.mockResolvedValue(undefined)
  mockDeleteFolder.mockResolvedValue(undefined)
})

afterAll(async () => {
  await prisma.content.deleteMany({ where: { id: { gte: 940 } } })
  await prisma.$disconnect()
})

describe('GET /api/contents/[id]', () => {
  it('returns 200 with content by id', async () => {
    const req = await makeRequest(950, 'GET')
    const res = await GET(req, { params: makeParams(950) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.slug).toBe('crud-published')
  })

  it('returns 404 for unknown id', async () => {
    const req = await makeRequest(999, 'GET')
    const res = await GET(req, { params: makeParams(999) })
    expect(res.status).toBe(404)
  })

  it('includes children sorted by pageIndex when parent has child pages', async () => {
    const parent = await prisma.content.create({
      data: { id: 945, slug: 'crud-multi', title: 'Multi Page', type: 'TEXT' },
    })
    await prisma.content.createMany({
      data: [
        { slug: 'crud-multi-p1', title: 'Multi Page — Página 2', type: 'TEXT', parentId: parent.id, pageIndex: 1 },
        { slug: 'crud-multi-p0', title: 'Multi Page — Página 1', type: 'TEXT', parentId: parent.id, pageIndex: 0 },
      ],
    })

    const req = await makeRequest(945, 'GET')
    const res = await GET(req, { params: makeParams(945) })
    const body = await res.json()

    expect(body.children).toHaveLength(2)
    expect(body.children[0].pageIndex).toBe(0)
    expect(body.children[1].pageIndex).toBe(1)
  })
})

describe('PUT /api/contents/[id]', () => {
  it('updates title and regenerates slug automatically', async () => {
    const req = await makeRequest(951, 'PUT', { title: 'Updated Title' })
    const res = await PUT(req, { params: makeParams(951) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.title).toBe('Updated Title')
    expect(body.slug).toBe('updated-title')
    // Restore original title/slug for other tests
    await prisma.content.update({ where: { id: 951 }, data: { title: 'Unpublished', slug: 'crud-unpublished' } })
  })

  it('returns 409 when updating to duplicate title', async () => {
    const req = await makeRequest(951, 'PUT', { title: 'Published' })
    const res = await PUT(req, { params: makeParams(951) })
    expect(res.status).toBe(409)
  })

  it('returns 400 for empty body', async () => {
    const req = await makeRequest(951, 'PUT', {})
    const res = await PUT(req, { params: makeParams(951) })
    expect(res.status).toBe(400)
  })

  it('returns 404 for unknown id', async () => {
    const req = await makeRequest(999, 'PUT', { title: 'Ghost' })
    const res = await PUT(req, { params: makeParams(999) })
    expect(res.status).toBe(404)
  })

  it('uploads HTML to MinIO when html field is provided', async () => {
    const req = await makeRequest(950, 'PUT', { html: '<p>New content</p>' })
    const res = await PUT(req, { params: makeParams(950) })
    expect(res.status).toBe(200)
    expect(mockUploadObject).toHaveBeenCalledWith(
      'contents/950/content.html',
      expect.any(Buffer),
      'text/html',
    )
  })

  it('auto-unpublishes published content on edit and removes from manifest', async () => {
    // Ensure content 950 is published before the test
    await prisma.content.update({ where: { id: 950 }, data: { published: true } })

    const req = await makeRequest(950, 'PUT', { title: 'Edited Published' })
    const res = await PUT(req, { params: makeParams(950) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.published).toBe(false)
    expect(body.wasAutoUnpublished).toBe(true)

    // Should have removed from manifest
    expect(mockGetObjectText).toHaveBeenCalledWith('manifest.json')
    const manifestWriteCalls = mockUploadObject.mock.calls.filter(
      (call: unknown[]) => call[0] === 'manifest.json',
    )
    expect(manifestWriteCalls.length).toBeGreaterThanOrEqual(1)

    // Restore published state for other tests
    await prisma.content.update({ where: { id: 950 }, data: { published: true, title: 'Published', slug: 'crud-published' } })
  })

  it('does not set wasAutoUnpublished when editing unpublished content', async () => {
    const req = await makeRequest(951, 'PUT', { youtubeUrl: 'https://youtube.com/watch?v=new' })
    const res = await PUT(req, { params: makeParams(951) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.wasAutoUnpublished).toBe(false)
    // Restore
    await prisma.content.update({ where: { id: 951 }, data: { youtubeUrl: 'https://youtube.com/watch?v=x' } })
  })

  it('returns 401 without auth', async () => {
    const req = new NextRequest('http://localhost/api/contents/950', {
      method: 'PUT',
      body: JSON.stringify({ title: 'No Auth' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await PUT(req, { params: makeParams(950) })
    expect(res.status).toBe(401)
  })
})

describe('DELETE /api/contents/[id]', () => {
  it('deletes content and returns 204', async () => {
    // Create a content to delete
    await prisma.content.create({
      data: { id: 960, slug: 'crud-to-delete', title: 'Delete Me', type: 'TEXT' },
    })
    const req = await makeRequest(960, 'DELETE')
    const res = await DELETE(req, { params: makeParams(960) })
    expect(res.status).toBe(204)
    const deleted = await prisma.content.findUnique({ where: { id: 960 } })
    expect(deleted).toBeNull()
  })

  it('removes content from manifest on delete', async () => {
    await prisma.content.create({
      data: { id: 961, slug: 'crud-manifest-del', title: 'Manifest Delete', type: 'TEXT', published: true },
    })
    const req = await makeRequest(961, 'DELETE')
    await DELETE(req, { params: makeParams(961) })
    // Should have read manifest and written updated version
    expect(mockGetObjectText).toHaveBeenCalledWith('manifest.json')
    expect(mockUploadObject).toHaveBeenCalledWith(
      'manifest.json', expect.any(Buffer), 'application/json',
    )
  })

  it('deletes MinIO folder for the content', async () => {
    await prisma.content.create({
      data: { id: 962, slug: 'crud-minio-del', title: 'MinIO Delete', type: 'TEXT' },
    })
    const req = await makeRequest(962, 'DELETE')
    await DELETE(req, { params: makeParams(962) })
    expect(mockDeleteFolder).toHaveBeenCalledWith('contents/962/')
  })

  it('returns 404 for unknown id', async () => {
    const req = await makeRequest(999, 'DELETE')
    const res = await DELETE(req, { params: makeParams(999) })
    expect(res.status).toBe(404)
  })
})
