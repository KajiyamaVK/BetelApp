export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth'

export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAdmin(req)
  if ('error' in authResult) return authResult.error

  const { id } = await params
  const targetId = parseInt(id, 10)

  if (authResult.userId === targetId) {
    return NextResponse.json({ error: 'Não é possível deletar seu próprio usuário' }, { status: 403 })
  }

  const deleted = await prisma.user.deleteMany({ where: { id: targetId } })
  if (deleted.count === 0) {
    return NextResponse.json({ error: 'Usuário não encontrado' }, { status: 404 })
  }

  return NextResponse.json({ ok: true })
}
