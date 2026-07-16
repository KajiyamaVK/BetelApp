export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { prisma } from '@/lib/prisma'
import { createUserSchema } from '@/lib/schemas'
import { requireAdmin, DEFAULT_PASSWORD } from '@/lib/auth'

export async function GET(req: NextRequest) {
  const authResult = await requireAdmin(req)
  if ('error' in authResult) return authResult.error

  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'asc' },
    select: { id: true, username: true, isAdmin: true, mustChangePassword: true, createdAt: true },
  })
  return NextResponse.json(users)
}

export async function POST(req: NextRequest) {
  const authResult = await requireAdmin(req)
  if ('error' in authResult) return authResult.error

  const body = await req.json()
  const parsed = createUserSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  const { username, isAdmin } = parsed.data
  const passwordHash = await bcrypt.hash(DEFAULT_PASSWORD, 12)

  try {
    const user = await prisma.user.create({
      data: { username, passwordHash, isAdmin, mustChangePassword: true },
      select: { id: true, username: true, isAdmin: true, mustChangePassword: true, createdAt: true },
    })
    return NextResponse.json(user, { status: 201 })
  } catch {
    return NextResponse.json({ error: 'Username already exists' }, { status: 409 })
  }
}
