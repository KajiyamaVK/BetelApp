/**
 * @jest-environment node
 */
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'
import bcrypt from 'bcryptjs'

let testUserId: number

async function importRoute() {
  const mod = await import('@/app/api/auth/change-password/route')
  return mod.POST
}

async function makeRequest(body: object, userId: number, mustChangePassword = true): Promise<NextRequest> {
  const token = await signToken({ id: userId, username: '__test_chpwd__', isAdmin: false, mustChangePassword })
  const req = new NextRequest('http://localhost/api/auth/change-password', {
    method: 'POST',
    body: JSON.stringify(body),
    headers: { 'Content-Type': 'application/json' },
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeAll(async () => {
  const initialHash = await bcrypt.hash('123456', 12)
  const user = await prisma.user.upsert({
    where: { username: '__test_chpwd__' },
    update: { passwordHash: initialHash, mustChangePassword: true },
    create: { username: '__test_chpwd__', passwordHash: initialHash, isAdmin: false, mustChangePassword: true },
  })
  testUserId = user.id
})

afterAll(async () => {
  await prisma.user.deleteMany({ where: { username: '__test_chpwd__' } })
})

describe('POST /api/auth/change-password', () => {
  beforeEach(async () => {
    const initialHash = await bcrypt.hash('123456', 12)
    await prisma.user.update({ where: { id: testUserId }, data: { passwordHash: initialHash, mustChangePassword: true } })
  })

  it('changes password, sets mustChangePassword=false and issues a fresh JWT cookie', async () => {
    const changePassword = await importRoute()
    const req = await makeRequest({ password: 'novasenha123', confirmPassword: 'novasenha123' }, testUserId)
    const res = await changePassword(req)
    expect(res.status).toBe(200)

    const dbUser = await prisma.user.findUnique({ where: { id: testUserId } })
    expect(dbUser!.mustChangePassword).toBe(false)
    const newPasswordValid = await bcrypt.compare('novasenha123', dbUser!.passwordHash)
    expect(newPasswordValid).toBe(true)

    // Fresh JWT cookie must be set — and when decoded it must carry mustChangePassword=false
    // so the middleware stops redirecting back to /change-password on the very next request.
    const setCookie = res.headers.get('set-cookie')
    expect(setCookie).toContain('token=')

    const { verifyToken } = await import('@/lib/auth')
    const newToken = setCookie!.split('token=')[1].split(';')[0]
    const payload = await verifyToken(newToken)
    expect(payload.mustChangePassword).toBe(false)
  })

  it('returns 400 when passwords do not match', async () => {
    const changePassword = await importRoute()
    const req = await makeRequest({ password: 'novasenha123', confirmPassword: 'diferente456' }, testUserId)
    const res = await changePassword(req)
    expect(res.status).toBe(400)
    const body = await res.json()
    expect(body.error).toMatch(/coincidem|match/i)
  })

  it('returns 400 when password is shorter than 6 characters', async () => {
    const changePassword = await importRoute()
    const req = await makeRequest({ password: 'abc', confirmPassword: 'abc' }, testUserId)
    const res = await changePassword(req)
    expect(res.status).toBe(400)
  })

  it('returns 401 when no auth token', async () => {
    const changePassword = await importRoute()
    const req = new NextRequest('http://localhost/api/auth/change-password', {
      method: 'POST',
      body: JSON.stringify({ password: 'novasenha123', confirmPassword: 'novasenha123' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await changePassword(req)
    expect(res.status).toBe(401)
  })
})
