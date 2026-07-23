export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { Prisma } from '@prisma/client'
import { prisma } from '@/lib/prisma'
import { deleteFolder } from '@/lib/minio'
import { renameLesson, removeLesson } from '@/lib/manifest'
import { updateManifest } from '@/lib/manifest-sync'
import { updateLessonSchema } from '@/lib/schemas'
import { requireAuth, requireAdmin } from '@/lib/auth'

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const id = parseInt(idStr, 10)
  if (isNaN(id)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const body = await req.json()
  const parsed = updateLessonSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: parsed.error.issues[0].message }, { status: 400 })

  let lesson
  try {
    lesson = await prisma.lesson.update({
      where: { id },
      data: {
        ...(parsed.data.title !== undefined && { title: parsed.data.title }),
        ...(parsed.data.order !== undefined && { order: parsed.data.order }),
      },
    })
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return NextResponse.json({ error: 'Esse número de lição já está em uso' }, { status: 409 })
    }
    throw error
  }

  // Keep manifest in sync so the mobile app sees the new title without a full republish.
  // This is best-effort: a MinIO failure must never prevent the DB rename from returning 200.
  if (parsed.data.title !== undefined) {
    try {
      await updateManifest((manifest) =>
        manifest.lessons.some((entry) => entry.id === id)
          ? renameLesson(manifest, id, lesson.title)
          : manifest,
      )
    } catch (err) {
      console.error('Failed to update manifest after title rename:', err)
    }
  }

  return NextResponse.json(lesson)
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAdmin(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const id = parseInt(idStr, 10)
  if (isNaN(id)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const lesson = await prisma.lesson.findUnique({ where: { id } })
  if (!lesson) return NextResponse.json({ error: 'Lesson not found' }, { status: 404 })

  await prisma.lessonAuditLog.create({
    data: { lessonId: id, userId: authResult.userId, action: 'delete' },
  })

  await prisma.question.deleteMany({ where: { lessonId: id } })
  await prisma.lesson.delete({ where: { id } })

  // Remove from manifest (best-effort — manifest may not contain the lesson if unpublished)
  try {
    await updateManifest((manifest) => removeLesson(manifest, id))
  } catch (err) {
    console.error('Failed to update manifest after lesson delete:', err)
  }

  // Delete all MinIO files for this lesson
  await deleteFolder(`lessons/${id}/`)

  return new NextResponse(null, { status: 204 })
}
