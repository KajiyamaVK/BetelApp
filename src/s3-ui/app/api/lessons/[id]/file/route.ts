export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { deleteObject } from '@/lib/minio'
import { softDeleteFile } from '@/lib/manifest'
import { updateManifest } from '@/lib/manifest-sync'
import { uploadQuerySchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const id = parseInt(idStr, 10)
  if (isNaN(id)) return NextResponse.json({ error: 'Invalid id' }, { status: 400 })

  const typeParam = req.nextUrl.searchParams.get('type')
  const parsed = uploadQuerySchema.safeParse({ type: typeParam })
  if (!parsed.success) return NextResponse.json({ error: 'type must be audio or pdf' }, { status: 400 })

  const type = parsed.data.type

  const lesson = await prisma.lesson.findUnique({ where: { id } })
  const activePath = type === 'audio' ? lesson?.audioActive : lesson?.pdfActive

  const dbUpdate = type === 'audio'
    ? { audioActive: null, audioChecksum: null, audioExt: null }
    : { pdfActive: null, pdfChecksum: null }

  await prisma.lesson.update({ where: { id }, data: dbUpdate })

  if (activePath) {
    await deleteObject(activePath)
  }

  await updateManifest((manifest) => softDeleteFile(manifest, id, type))

  return NextResponse.json({ ok: true })
}
