/**
 * @jest-environment node
 */
import { GET, POST } from '@/app/api/contents/images/route'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

const mockListImageObjects = jest.fn()
const mockUploadObject = jest.fn()

jest.mock('@/lib/minio', () => ({
  listImageObjects: (...args: unknown[]) => mockListImageObjects(...args),
  uploadObject: (...args: unknown[]) => mockUploadObject(...args),
}))

async function makeGetRequest(): Promise<NextRequest> {
  const token = await signToken({
    id: 1, username: 'victor', isAdmin: false, mustChangePassword: false,
  })
  const req = new NextRequest('http://localhost/api/contents/images', { method: 'GET' })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

async function makePostRequest(file: File): Promise<NextRequest> {
  const token = await signToken({
    id: 1, username: 'victor', isAdmin: false, mustChangePassword: false,
  })
  const formData = new FormData()
  formData.append('file', file)
  const req = new NextRequest('http://localhost/api/contents/images', {
    method: 'POST',
    body: formData,
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeEach(() => {
  mockListImageObjects.mockReset()
  mockUploadObject.mockReset()
  mockUploadObject.mockResolvedValue(undefined)
})

describe('GET /api/contents/images', () => {
  it('returns list of images from MinIO', async () => {
    mockListImageObjects.mockResolvedValue([
      { name: 'contents/images/abc.jpg', url: 'https://s3.example.com/abc.jpg' },
    ])
    const req = await makeGetRequest()
    const res = await GET(req)
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body).toHaveLength(1)
    expect(body[0].url).toBe('https://s3.example.com/abc.jpg')
  })

  it('returns empty array when no images', async () => {
    mockListImageObjects.mockResolvedValue([])
    const req = await makeGetRequest()
    const res = await GET(req)
    const body = await res.json()
    expect(body).toEqual([])
  })

  it('returns 401 without auth', async () => {
    const req = new NextRequest('http://localhost/api/contents/images', { method: 'GET' })
    const res = await GET(req)
    expect(res.status).toBe(401)
  })
})

describe('POST /api/contents/images', () => {
  it('uploads image and returns url + name', async () => {
    const file = new File(['fake image data'], 'photo.jpg', { type: 'image/jpeg' })
    const req = await makePostRequest(file)
    const res = await POST(req)
    expect(res.status).toBe(201)
    const body = await res.json()
    expect(body.url).toBeDefined()
    expect(body.name).toMatch(/^contents\/images\/.*\.jpg$/)
    expect(mockUploadObject).toHaveBeenCalledTimes(1)
  })

  it('returns 400 for non-image MIME type', async () => {
    const file = new File(['not an image'], 'data.txt', { type: 'text/plain' })
    const req = await makePostRequest(file)
    const res = await POST(req)
    expect(res.status).toBe(400)
    const body = await res.json()
    expect(body.error).toMatch(/imagem|image/i)
  })

  it('returns 400 when no file is provided', async () => {
    const token = await signToken({
      id: 1, username: 'victor', isAdmin: false, mustChangePassword: false,
    })
    const formData = new FormData()
    const req = new NextRequest('http://localhost/api/contents/images', {
      method: 'POST',
      body: formData,
    })
    req.cookies.set(TOKEN_COOKIE, token)
    const res = await POST(req)
    expect(res.status).toBe(400)
  })

  it('returns 401 without auth', async () => {
    const file = new File(['data'], 'img.png', { type: 'image/png' })
    const formData = new FormData()
    formData.append('file', file)
    const req = new NextRequest('http://localhost/api/contents/images', {
      method: 'POST',
      body: formData,
    })
    const res = await POST(req)
    expect(res.status).toBe(401)
  })
})
