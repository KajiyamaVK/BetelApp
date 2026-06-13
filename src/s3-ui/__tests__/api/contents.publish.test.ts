/**
 * @jest-environment node
 */
import { PATCH } from '@/app/api/contents/[id]/publish/route'
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
  contents: [],
})

function makeParams(id: number) {
  return Promise.resolve({ id: String(id) })
}

async function makeRequest(id: number, published: boolean): Promise<NextRequest> {
  const token = await signToken({
    id: 1, username: 'victor', isAdmin: false, mustChangePassword: false,
  })
  const req = new NextRequest(`http://localhost/api/contents/${id}/publish`, {
    method: 'PATCH',
    body: JSON.stringify({ published }),
    headers: { 'Content-Type': 'application/json' },
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeAll(async () => {
  await prisma.content.deleteMany({ where: { id: { gte: 970 } } })
  await prisma.content.createMany({
    data: [
      { id: 970, slug: 'pub-video', title: 'Pub Video', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=v1' },
      { id: 971, slug: 'pub-text', title: 'Pub Text', type: 'TEXT', htmlPath: 'contents/971/content.html' },
      { id: 972, slug: 'pub-text-no-html', title: 'No HTML', type: 'TEXT' },
      { id: 973, slug: 'pub-unpublish', title: 'To Unpublish', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=v2', published: true },
    ],
  })
})

beforeEach(() => {
  mockGetObjectText.mockReset()
  mockUploadObject.mockReset()
  mockGetObjectText.mockImplementation((path: string) => {
    if (path === 'manifest.json') return Promise.resolve(EMPTY_MANIFEST)
    if (path === 'contents/971/content.html') return Promise.resolve('<p>Hello World</p>')
    return Promise.reject(new Error(`Unknown path: ${path}`))
  })
  mockUploadObject.mockResolvedValue(undefined)
})

afterAll(async () => {
  await prisma.content.deleteMany({ where: { id: { gte: 970 } } })
  await prisma.$disconnect()
})

describe('PATCH /api/contents/[id]/publish', () => {
  it('publishes VIDEO content — adds to manifest with youtubeUrl', async () => {
    const req = await makeRequest(970, true)
    const res = await PATCH(req, { params: makeParams(970) })
    expect(res.status).toBe(200)

    const manifestCall = mockUploadObject.mock.calls.find(
      (call: unknown[]) => call[0] === 'manifest.json',
    )
    expect(manifestCall).toBeDefined()
    const writtenManifest = JSON.parse(manifestCall![1].toString())
    const videoEntry = writtenManifest.contents.find(
      (content: { id: number }) => content.id === 970,
    )
    expect(videoEntry.type).toBe('VIDEO')
    expect(videoEntry.youtubeUrl).toBe('https://youtube.com/watch?v=v1')
    expect(videoEntry.slug).toBe('pub-video')
  })

  it('publishes TEXT content — reads HTML from MinIO and inlines in manifest', async () => {
    const req = await makeRequest(971, true)
    const res = await PATCH(req, { params: makeParams(971) })
    expect(res.status).toBe(200)

    // Should have read the HTML file from MinIO
    expect(mockGetObjectText).toHaveBeenCalledWith('contents/971/content.html')

    const manifestCall = mockUploadObject.mock.calls.find(
      (call: unknown[]) => call[0] === 'manifest.json',
    )
    const writtenManifest = JSON.parse(manifestCall![1].toString())
    const textEntry = writtenManifest.contents.find(
      (content: { id: number }) => content.id === 971,
    )
    expect(textEntry.type).toBe('TEXT')
    expect(textEntry.html).toBe('<p>Hello World</p>')
  })

  it('returns 400 when TEXT content has no htmlPath', async () => {
    const req = await makeRequest(972, true)
    const res = await PATCH(req, { params: makeParams(972) })
    expect(res.status).toBe(400)
    const body = await res.json()
    expect(body.error).toMatch(/conteúdo|HTML/i)
  })

  it('unpublishes content — removes from manifest', async () => {
    // First ensure content 973 is in the manifest
    const manifestWithContent = JSON.stringify({
      version: 2,
      updated_at: '2024-01-01',
      lessons: [],
      contents: [{ id: 973, slug: 'pub-unpublish', title: 'To Unpublish', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=v2' }],
    })
    mockGetObjectText.mockImplementation((path: string) => {
      if (path === 'manifest.json') return Promise.resolve(manifestWithContent)
      return Promise.reject(new Error(`Unknown path: ${path}`))
    })

    const req = await makeRequest(973, false)
    const res = await PATCH(req, { params: makeParams(973) })
    expect(res.status).toBe(200)

    const manifestCall = mockUploadObject.mock.calls.find(
      (call: unknown[]) => call[0] === 'manifest.json',
    )
    const writtenManifest = JSON.parse(manifestCall![1].toString())
    const removed = writtenManifest.contents.find(
      (content: { id: number }) => content.id === 973,
    )
    expect(removed).toBeUndefined()
  })

  it('returns 404 for unknown id', async () => {
    const req = await makeRequest(999, true)
    const res = await PATCH(req, { params: makeParams(999) })
    expect(res.status).toBe(404)
  })

  it('returns 401 without auth', async () => {
    const req = new NextRequest('http://localhost/api/contents/970/publish', {
      method: 'PATCH',
      body: JSON.stringify({ published: true }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await PATCH(req, { params: makeParams(970) })
    expect(res.status).toBe(401)
  })
})
