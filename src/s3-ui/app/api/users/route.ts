import { NextRequest, NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { prisma } from '@/lib/prisma'
import { createUserSchema } from '@/lib/schemas'

export async function GET() {
  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'asc' },
    select: { id: true, username: true, isAdmin: true, createdAt: true },
  })
  return NextResponse.json(users)
}

export async function POST(req: NextRequest) {
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
