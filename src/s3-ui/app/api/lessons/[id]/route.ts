export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getObjectText, uploadObject } from '@/lib/minio'
import { parseManifest, renameLesson } from '@/lib/manifest'
import { updateTitleSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

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

  // Keep manifest in sync so the mobile app sees the new title without a full republish
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

  return NextResponse.json(lesson)
}
