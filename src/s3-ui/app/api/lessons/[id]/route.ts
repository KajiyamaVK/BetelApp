import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { updateTitleSchema } from '@/lib/schemas'

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id: idStr } = await params
  const id = parseInt(idStr, 10)
  if (isNaN(id)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const body = await req.json()
  const parsed = updateTitleSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  const lesson = await prisma.lesson.update({
    where: { id },
    data: { title: parsed.data.title },
  })

  return NextResponse.json(lesson)
}
