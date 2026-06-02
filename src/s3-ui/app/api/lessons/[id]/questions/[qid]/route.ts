export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { Prisma } from '@prisma/client'
import { prisma } from '@/lib/prisma'
import { updateQuestionSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string; qid: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr, qid: qidStr } = await params
  const lessonId = parseInt(idStr, 10)
  if (isNaN(lessonId)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })
  const qid = parseInt(qidStr, 10)
  if (isNaN(qid)) return NextResponse.json({ error: 'Invalid qid' }, { status: 400 })

  const body = await req.json()
  const parsed = updateQuestionSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  try {
    // Filter lessonId + deletedAt: null to enforce cross-lesson isolation and block soft-deleted questions
    const question = await prisma.question.update({
      where: { id: qid, lessonId, deletedAt: null },
      data: parsed.data,
    })
    return NextResponse.json(question)
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      return NextResponse.json({ error: 'Question not found' }, { status: 404 })
    }
    throw err
  }
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ id: string; qid: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr, qid: qidStr } = await params
  const lessonId = parseInt(idStr, 10)
  if (isNaN(lessonId)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })
  const qid = parseInt(qidStr, 10)
  if (isNaN(qid)) return NextResponse.json({ error: 'Invalid qid' }, { status: 400 })

  // Fetch the question before deleting so we can snapshot it in the audit log
  // Filter lessonId + deletedAt: null to enforce cross-lesson isolation
  const existing = await prisma.question.findUnique({ where: { id: qid, lessonId, deletedAt: null } })
  if (!existing) return NextResponse.json({ error: 'Question not found' }, { status: 404 })

  // Create audit log entry capturing the full content of the deleted question
  await prisma.questionAuditLog.create({
    data: {
      questionId: existing.id,
      lessonId: existing.lessonId,
      question: existing.question,
      answer: existing.answer,
      deletedBy: authResult.username,
    },
  })

  // Guard against concurrent deletes — only update if still not soft-deleted
  await prisma.question.update({
    where: { id: qid, deletedAt: null },
    data: { deletedAt: new Date() },
  })

  return new NextResponse(null, { status: 204 })
}
