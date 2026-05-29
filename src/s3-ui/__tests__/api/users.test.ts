/**
 * @jest-environment node
 */
import { GET as getUsers, POST as createUser } from '@/app/api/users/route'
import { prisma } from '@/lib/prisma'
import { NextRequest } from 'next/server'

afterEach(async () => {
  await prisma.user.deleteMany({ where: { username: { startsWith: 'integtest_' } } })
})

afterAll(() => prisma.$disconnect())

describe('POST /api/users', () => {
  it('creates user and returns 201', async () => {
    const req = new NextRequest('http://localhost/api/users', {
      method: 'POST',
      body: JSON.stringify({ username: 'integtest_ana', password: 'pass123', isAdmin: false }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await createUser(req)
    expect(res.status).toBe(201)
    const body = await res.json()
    expect(body.username).toBe('integtest_ana')
  })

  it('returns 409 on duplicate username', async () => {
    const makeReq = () => new NextRequest('http://localhost/api/users', {
      method: 'POST',
      body: JSON.stringify({ username: 'integtest_dup', password: 'pass123', isAdmin: false }),
      headers: { 'Content-Type': 'application/json' },
    })
    await createUser(makeReq())
    const res = await createUser(makeReq())
    expect(res.status).toBe(409)
  })
})

describe('GET /api/users', () => {
  it('returns array', async () => {
    const res = await getUsers()
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(Array.isArray(data)).toBe(true)
  })
})
