/**
 * @jest-environment node
 */
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'
import bcrypt from 'bcryptjs'

let adminId: number
let targetUserId: number

async function importRoute() {
  const mod = await import('@/app/api/users/[id]/reset-password/route')
  return mod.POST
}

async function makeRequest(targetId: number, callerId: number, callerIsAdmin: boolean): Promise<NextRequest> {
  const token = await signToken({ id: callerId, username: '__test_admin_reset__', isAdmin: callerIsAdmin, mustChangePassword: false })
  const req = new NextRequest(`http://localhost/api/users/${targetId}/reset-password`, { method: 'POST' })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeAll(async () => {
  const admin = await prisma.user.upsert({
    where: { username: '__test_admin_reset__' },
    update: {},
    create: { username: '__test_admin_reset__', passwordHash: 'x', isAdmin: true, mustChangePassword: false },
  })
  adminId = admin.id

  const target = await prisma.user.upsert({
    where: { username: '__test_target_reset__' },
    update: { mustChangePassword: false },
    create: { username: '__test_target_reset__', passwordHash: 'x', isAdmin: false, mustChangePassword: false },
  })
  targetUserId = target.id
})

afterAll(async () => {
  await prisma.user.deleteMany({ where: { username: { in: ['__test_admin_reset__', '__test_target_reset__'] } } })
})

describe('POST /api/users/[id]/reset-password', () => {
  it('resets password to 123456 and sets mustChangePassword=true', async () => {
    const resetPassword = await importRoute()
    const req = await makeRequest(targetUserId, adminId, true)
    const res = await resetPassword(req, { params: Promise.resolve({ id: String(targetUserId) }) })
    expect(res.status).toBe(200)

    const dbUser = await prisma.user.findUnique({ where: { id: targetUserId } })
    expect(dbUser!.mustChangePassword).toBe(true)
    const passwordIsDefault = await bcrypt.compare('123456', dbUser!.passwordHash)
    expect(passwordIsDefault).toBe(true)
  })

  it('after reset, next login issues JWT with mustChangePassword=true forcing /change-password redirect', async () => {
    // Reset the target user
    const resetPassword = await importRoute()
    const resetReq = await makeRequest(targetUserId, adminId, true)
    await resetPassword(resetReq, { params: Promise.resolve({ id: String(targetUserId) }) })

    // Simulate login — needs a real password hash in the DB
    const { POST: loginHandler } = await import('@/app/api/auth/login/route')
    const { verifyToken } = await import('@/lib/auth')

    // target was reset to 123456 — update username for lookup
    const targetUser = await prisma.user.findUnique({ where: { id: targetUserId } })
    const loginReq = new (await import('next/server')).NextRequest('http://localhost/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username: targetUser!.username, password: '123456' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const loginRes = await loginHandler(loginReq)
    expect(loginRes.status).toBe(200)

    const token = loginRes.cookies.get('token')!.value
    const payload = await verifyToken(token)
    expect(payload.mustChangePassword).toBe(true)
  })

  it('returns 403 for non-admin users', async () => {
    const nonAdmin = await prisma.user.upsert({
      where: { username: '__test_nonadmin_reset__' },
      update: {},
      create: { username: '__test_nonadmin_reset__', passwordHash: 'x', isAdmin: false, mustChangePassword: false },
    })
    const resetPassword = await importRoute()
    const req = await makeRequest(targetUserId, nonAdmin.id, false)
    const res = await resetPassword(req, { params: Promise.resolve({ id: String(targetUserId) }) })
    expect(res.status).toBe(403)
    await prisma.user.delete({ where: { id: nonAdmin.id } })
  })

  it('returns 404 when user does not exist', async () => {
    const resetPassword = await importRoute()
    const req = await makeRequest(99999, adminId, true)
    const res = await resetPassword(req, { params: Promise.resolve({ id: '99999' }) })
    expect(res.status).toBe(404)
  })
})
