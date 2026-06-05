export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { createQuestionSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'
import { resyncLessonInManifestIfPublished } from '@/lib/manifest-sync'

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const lessonId = parseInt(idStr, 10)
  if (isNaN(lessonId)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const questions = await prisma.question.findMany({
    where: { lessonId, deletedAt: null },
    orderBy: { order: 'asc' },
  })

  return NextResponse.json(questions)
}

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const lessonId = parseInt(idStr, 10)
  if (isNaN(lessonId)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const body = await req.json()
  const parsed = createQuestionSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  const maxOrderResult = await prisma.question.aggregate({
    where: { lessonId, deletedAt: null },
    _max: { order: true },
  })
  const nextOrder = (maxOrderResult._max.order ?? -1) + 1

  const question = await prisma.question.create({
    data: {
      lessonId,
      question: parsed.data.question,
      answer: parsed.data.answer,
      order: nextOrder,
    },
  })

  // Best-effort manifest resync — does not block the response if MinIO is unavailable
  try {
    await resyncLessonInManifestIfPublished(lessonId)
  } catch (err) {
    console.error('Failed to resync manifest after question create:', err)
  }

  return NextResponse.json(question, { status: 201 })
}
