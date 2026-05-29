/**
 * @jest-environment node
 */
import { POST as loginHandler } from '@/app/api/auth/login/route'
import { GET as meHandler } from '@/app/api/auth/me/route'
import { prisma } from '@/lib/prisma'
import bcrypt from 'bcryptjs'
import { NextRequest } from 'next/server'

function makeLoginRequest(body: object): NextRequest {
  return new NextRequest('http://localhost/api/auth/login', {
    method: 'POST',
    body: JSON.stringify(body),
    headers: { 'Content-Type': 'application/json' },
  })
}

const AUTH_TEST_USER = 'authtest_login_user'

beforeAll(async () => {
  await prisma.user.upsert({
    where: { username: AUTH_TEST_USER },
    update: {},
    create: {
      username: AUTH_TEST_USER,
      passwordHash: await bcrypt.hash('correct-pass', 12),
      isAdmin: false,
    },
  })
})

afterAll(async () => {
  await prisma.user.deleteMany({ where: { username: AUTH_TEST_USER } })
  await prisma.$disconnect()
})

describe('POST /api/auth/login', () => {
  it('returns 200 and sets cookie on valid credentials', async () => {
    const req = makeLoginRequest({ username: AUTH_TEST_USER, password: 'correct-pass' })
    const res = await loginHandler(req)
    expect(res.status).toBe(200)
    expect(res.cookies.get('token')?.value).toBeTruthy()
  })

  it('returns 401 on wrong password', async () => {
    const req = makeLoginRequest({ username: AUTH_TEST_USER, password: 'wrong' })
    const res = await loginHandler(req)
    expect(res.status).toBe(401)
  })

  it('returns 401 on unknown user', async () => {
    const req = makeLoginRequest({ username: 'nobody', password: 'pass' })
    const res = await loginHandler(req)
    expect(res.status).toBe(401)
  })
})

describe('GET /api/auth/me', () => {
  it('returns 401 with no token', async () => {
    const req = new NextRequest('http://localhost/api/auth/me')
    const res = await meHandler(req)
    expect(res.status).toBe(401)
  })

  it('returns user info with valid token', async () => {
    const loginReq = makeLoginRequest({ username: AUTH_TEST_USER, password: 'correct-pass' })
    const loginRes = await loginHandler(loginReq)
    const token = loginRes.cookies.get('token')!.value

    const req = new NextRequest('http://localhost/api/auth/me')
    req.cookies.set('token', token)
    const res = await meHandler(req)
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.username).toBe(AUTH_TEST_USER)
  })
})
