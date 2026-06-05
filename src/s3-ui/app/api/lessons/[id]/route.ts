export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getObjectText, uploadObject, deleteFolder } from '@/lib/minio'
import { parseManifest, renameLesson, removeLesson } from '@/lib/manifest'
import { updateTitleSchema } from '@/lib/schemas'
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
  const parsed = updateTitleSchema.safeParse(body)
  if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })

  const lesson = await prisma.lesson.update({
    where: { id },
    data: { title: parsed.data.title },
  })

  // Keep manifest in sync so the mobile app sees the new title without a full republish.
  // This is best-effort: a MinIO failure must never prevent the DB rename from returning 200.
  try {
    const manifestText = await getObjectText('manifest.json')
    const manifest = parseManifest(manifestText)
    const existingEntry = manifest.lessons.find((entry) => entry.id === id)
    if (existingEntry) {
      const updatedManifest = renameLesson(manifest, id, lesson.title)
      await uploadObject(
        'manifest.json',
        Buffer.from(JSON.stringify(updatedManifest, null, 2)),
        'application/json',
      )
    }
  } catch (err) {
    console.error('Failed to update manifest after title rename:', err)
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
    const manifestText = await getObjectText('manifest.json')
    const manifest = parseManifest(manifestText)
    const updatedManifest = removeLesson(manifest, id)
    await uploadObject('manifest.json', Buffer.from(JSON.stringify(updatedManifest, null, 2)), 'application/json')
  } catch (err) {
    console.error('Failed to update manifest after lesson delete:', err)
  }

  // Delete all MinIO files for this lesson
  await deleteFolder(`lessons/${id}/`)

  return new NextResponse(null, { status: 204 })
}
