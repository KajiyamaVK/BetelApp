/**
 * @jest-environment node
 */
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

let adminId: number
let targetUserId: number

async function importRoute() {
  const mod = await import('@/app/api/users/[id]/route')
  return mod.DELETE
}

async function makeRequest(targetId: number, callerId: number, callerIsAdmin: boolean): Promise<NextRequest> {
  const token = await signToken({ id: callerId, username: '__test_admin_del__', isAdmin: callerIsAdmin, mustChangePassword: false })
  const req = new NextRequest(`http://localhost/api/users/${targetId}`, { method: 'DELETE' })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeAll(async () => {
  const admin = await prisma.user.upsert({
    where: { username: '__test_admin_del__' },
    update: {},
    create: { username: '__test_admin_del__', passwordHash: 'x', isAdmin: true, mustChangePassword: false },
  })
  adminId = admin.id

  const target = await prisma.user.upsert({
    where: { username: '__test_target_del__' },
    update: {},
    create: { username: '__test_target_del__', passwordHash: 'x', isAdmin: false, mustChangePassword: false },
  })
  targetUserId = target.id
})

afterAll(async () => {
  await prisma.user.deleteMany({ where: { username: { in: ['__test_admin_del__', '__test_target_del__'] } } })
})

describe('DELETE /api/users/[id]', () => {
  it('deletes a user when called by an admin', async () => {
    const toDelete = await prisma.user.upsert({
      where: { username: '__test_todelete__' },
      update: {},
      create: { username: '__test_todelete__', passwordHash: 'x', isAdmin: false },
    })
    const deleteUser = await importRoute()
    const req = await makeRequest(toDelete.id, adminId, true)
    ;(req as NextRequest & { params?: unknown }).params = { id: String(toDelete.id) }
    const res = await deleteUser(req, { params: Promise.resolve({ id: String(toDelete.id) }) })
    expect(res.status).toBe(200)

    const stillExists = await prisma.user.findUnique({ where: { id: toDelete.id } })
    expect(stillExists).toBeNull()
  })

  it('returns 403 when admin tries to delete themselves', async () => {
    const deleteUser = await importRoute()
    const req = await makeRequest(adminId, adminId, true)
    const res = await deleteUser(req, { params: Promise.resolve({ id: String(adminId) }) })
    expect(res.status).toBe(403)
  })

  it('returns 403 for non-admin users', async () => {
    const nonAdmin = await prisma.user.upsert({
      where: { username: '__test_nonadmin_del__' },
      update: {},
      create: { username: '__test_nonadmin_del__', passwordHash: 'x', isAdmin: false, mustChangePassword: false },
    })
    const deleteUser = await importRoute()
    const req = await makeRequest(targetUserId, nonAdmin.id, false)
    const res = await deleteUser(req, { params: Promise.resolve({ id: String(targetUserId) }) })
    expect(res.status).toBe(403)
    await prisma.user.delete({ where: { id: nonAdmin.id } })
  })

  it('returns 404 when user does not exist', async () => {
    const deleteUser = await importRoute()
    const req = await makeRequest(99999, adminId, true)
    const res = await deleteUser(req, { params: Promise.resolve({ id: '99999' }) })
    expect(res.status).toBe(404)
  })
})
