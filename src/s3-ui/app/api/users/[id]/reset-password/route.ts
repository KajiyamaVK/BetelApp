export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth'

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAdmin(req)
  if ('error' in authResult) return authResult.error

  const { id } = await params
  const targetId = parseInt(id, 10)

  const passwordHash = await bcrypt.hash('123456', 12)
  const updated = await prisma.user.updateMany({
    where: { id: targetId },
    data: { passwordHash, mustChangePassword: true },
  })

  if (updated.count === 0) {
    return NextResponse.json({ error: 'Usuário não encontrado' }, { status: 404 })
  }

  return NextResponse.json({ ok: true })
}
