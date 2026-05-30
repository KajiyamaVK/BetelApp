/**
 * @jest-environment node
 */
import { POST as createUser } from '@/app/api/users/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'
import bcrypt from 'bcryptjs'

let adminId: number

beforeAll(async () => {
  const admin = await prisma.user.upsert({
    where: { username: '__test_admin__' },
    update: {},
    create: { username: '__test_admin__', passwordHash: 'x', isAdmin: true, mustChangePassword: false },
  })
  adminId = admin.id
})

afterAll(async () => {
  await prisma.user.deleteMany({ where: { username: { startsWith: '__test_' } } })
})

async function makeAdminRequest(body: object): Promise<NextRequest> {
  const token = await signToken({ id: adminId, username: '__test_admin__', isAdmin: true, mustChangePassword: false })
  const req = new NextRequest('http://localhost/api/users', {
    method: 'POST',
    body: JSON.stringify(body),
    headers: { 'Content-Type': 'application/json' },
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

describe('POST /api/users', () => {
  afterEach(async () => {
    await prisma.user.deleteMany({ where: { username: { startsWith: 'test_' } } })
  })

  it('creates user with default password 123456 and mustChangePassword=true', async () => {
    const req = await makeAdminRequest({ username: 'test_newuser', isAdmin: false })
    const res = await createUser(req)
    expect(res.status).toBe(201)

    const body = await res.json()
    expect(body.username).toBe('test_newuser')
    expect(body.mustChangePassword).toBe(true)
    expect(body).not.toHaveProperty('passwordHash')

    const dbUser = await prisma.user.findUnique({ where: { username: 'test_newuser' } })
    expect(dbUser).not.toBeNull()
    expect(dbUser!.mustChangePassword).toBe(true)
    const passwordIsDefault = await bcrypt.compare('123456', dbUser!.passwordHash)
    expect(passwordIsDefault).toBe(true)
  })

  it('ignores any password field in request — always uses 123456', async () => {
    const req = await makeAdminRequest({ username: 'test_withpwd', password: 'somepwd', isAdmin: false })
    const res = await createUser(req)
    // schema strips unknown fields; user is created with 123456 regardless
    expect(res.status).toBe(201)
    const dbUser = await prisma.user.findUnique({ where: { username: 'test_withpwd' } })
    const passwordIsDefault = await bcrypt.compare('123456', dbUser!.passwordHash)
    expect(passwordIsDefault).toBe(true)
  })

  it('returns 409 when username already exists', async () => {
    const req1 = await makeAdminRequest({ username: 'test_dup', isAdmin: false })
    await createUser(req1)
    const req2 = await makeAdminRequest({ username: 'test_dup', isAdmin: false })
    const res = await createUser(req2)
    expect(res.status).toBe(409)
  })

  it('returns 403 for non-admin users', async () => {
    const nonAdminUser = await prisma.user.upsert({
      where: { username: '__test_regular__' },
      update: {},
      create: { username: '__test_regular__', passwordHash: 'x', isAdmin: false, mustChangePassword: false },
    })
    const token = await signToken({ id: nonAdminUser.id, username: '__test_regular__', isAdmin: false, mustChangePassword: false })
    const req = new NextRequest('http://localhost/api/users', {
      method: 'POST',
      body: JSON.stringify({ username: 'test_unauthorized', isAdmin: false }),
      headers: { 'Content-Type': 'application/json' },
    })
    req.cookies.set(TOKEN_COOKIE, token)
    const res = await createUser(req)
    expect(res.status).toBe(403)
    await prisma.user.delete({ where: { username: '__test_regular__' } })
  })
})
