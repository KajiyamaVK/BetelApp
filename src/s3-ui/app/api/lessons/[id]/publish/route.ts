export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { removeLesson, upsertLesson } from '@/lib/manifest'
import { buildManifestLesson, updateManifest } from '@/lib/manifest-sync'
import { togglePublishSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'
import { Prisma } from '@prisma/client'

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

    let transform: Parameters<typeof updateManifest>[0]
    if (parsed.data.published) {
      // Fetch active (non-deleted) questions to include in the manifest entry
      const activeQuestions = await prisma.question.findMany({
        where: { lessonId: id, deletedAt: null },
        orderBy: { order: 'asc' },
      })
      const manifestLesson = buildManifestLesson(lesson, activeQuestions)
      transform = (manifest) => upsertLesson(manifest, manifestLesson)
    } else {
      transform = (manifest) => removeLesson(manifest, id)
    }

    await updateManifest(transform)

    return NextResponse.json({ id: lesson.id, published: lesson.published })
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      return NextResponse.json({ error: 'Lesson not found' }, { status: 404 })
    }
    throw err
  }
}
