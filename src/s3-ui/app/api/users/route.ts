import { NextRequest, NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { prisma } from '@/lib/prisma'
import { createUserSchema } from '@/lib/schemas'
import { verifyToken, TOKEN_COOKIE } from '@/lib/auth'

async function requireAdmin(req: NextRequest): Promise<{ error: NextResponse } | { userId: number }> {
  const token = req.cookies.get(TOKEN_COOKIE)?.value
  if (!token) return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  try {
    const payload = await verifyToken(token)
    // Re-fetch isAdmin from DB so revocation takes effect immediately (middleware check is stale after 7 days)
    const user = await prisma.user.findUnique({ where: { id: payload.id }, select: { isAdmin: true } })
    if (!user?.isAdmin) return { error: NextResponse.json({ error: 'Forbidden' }, { status: 403 }) }
    return { userId: payload.id }
  } catch {
    return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  }
}

export async function GET(req: NextRequest) {
  const authResult = await requireAdmin(req)
  if ('error' in authResult) return authResult.error

  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'asc' },
    select: { id: true, username: true, isAdmin: true, createdAt: true },
  })
  return NextResponse.json(users)
}

export async function POST(req: NextRequest) {
  const authResult = await requireAdmin(req)
  if ('error' in authResult) return authResult.error

  const body = await req.json()
  const parsed = createUserSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  const { username, password, isAdmin } = parsed.data
  const passwordHash = await bcrypt.hash(password, 12)

  try {
    const user = await prisma.user.create({
      data: { username, passwordHash, isAdmin },
      select: { id: true, username: true, isAdmin: true, createdAt: true },
    })
    return NextResponse.json(user, { status: 201 })
  } catch {
    return NextResponse.json({ error: 'Username already exists' }, { status: 409 })
  }
}
