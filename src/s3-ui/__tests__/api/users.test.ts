/**
 * @jest-environment node
 */
import { GET as getUsers, POST as createUser } from '@/app/api/users/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

async function makeAdminRequest(method: string, body?: object): Promise<NextRequest> {
  const token = await signToken({ id: 1, username: 'victor', isAdmin: true, mustChangePassword: false })
  const req = new NextRequest('http://localhost/api/users', {
    method,
    body: body ? JSON.stringify(body) : undefined,
    headers: { 'Content-Type': 'application/json' },
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

afterEach(async () => {
  await prisma.user.deleteMany({ where: { username: { startsWith: 'integtest_' } } })
})

afterAll(() => prisma.$disconnect())

describe('POST /api/users', () => {
  it('creates user and returns 201', async () => {
    const req = await makeAdminRequest('POST', { username: 'integtest_ana', password: 'pass123', isAdmin: false })
    const res = await createUser(req)
    expect(res.status).toBe(201)
    const body = await res.json()
    expect(body.username).toBe('integtest_ana')
  })

  it('returns 409 on duplicate username', async () => {
    const req1 = await makeAdminRequest('POST', { username: 'integtest_dup', password: 'pass123', isAdmin: false })
    await createUser(req1)
    const req2 = await makeAdminRequest('POST', { username: 'integtest_dup', password: 'pass123', isAdmin: false })
    const res = await createUser(req2)
    expect(res.status).toBe(409)
  })

  it('returns 403 without admin token', async () => {
    const req = new NextRequest('http://localhost/api/users', {
      method: 'POST',
      body: JSON.stringify({ username: 'integtest_unauth', password: 'pass123', isAdmin: false }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await createUser(req)
    expect(res.status).toBe(401)
  })
})

describe('GET /api/users', () => {
  it('returns array for admin', async () => {
    const req = await makeAdminRequest('GET')
    const res = await getUsers(req)
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(Array.isArray(data)).toBe(true)
  })

  it('returns 401 without token', async () => {
    const req = new NextRequest('http://localhost/api/users')
    const res = await getUsers(req)
    expect(res.status).toBe(401)
  })
})
