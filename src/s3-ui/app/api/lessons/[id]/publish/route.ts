export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { togglePublishSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const id = parseInt(idStr, 10)
  if (isNaN(id)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const body = await req.json()
  const parsed = togglePublishSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  try {
    const lesson = await prisma.lesson.update({
      where: { id },
      data: { published: parsed.data.published },
    })
    return NextResponse.json({ id: lesson.id, published: lesson.published })
  } catch {
    return NextResponse.json({ error: 'Lesson not found' }, { status: 404 })
  }
}
