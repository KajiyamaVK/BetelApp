export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import crypto from 'crypto'
import { uploadObject, getObjectText } from '@/lib/minio'
import { parseManifest, applyUpload } from '@/lib/manifest'
import { prisma } from '@/lib/prisma'
import { uploadQuerySchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

export async function POST(
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
  const formData = await req.formData()
  const file = formData.get('file') as File | null
  if (!file) return NextResponse.json({ error: 'No file provided' }, { status: 400 })

  const buffer = Buffer.from(await file.arrayBuffer())
  const checksum = crypto.createHash('md5').update(buffer).digest('hex')

  const manifestText = await getObjectText('manifest.json')
  const manifest = parseManifest(manifestText)

  const updated = applyUpload(manifest, id, type, checksum)
  const manifestLesson = updated.lessons.find((l) => l.id === id)
  if (!manifestLesson) return NextResponse.json({ error: 'Lesson not found in manifest' }, { status: 404 })

  const activePath = type === 'audio' ? manifestLesson.audio.active! : manifestLesson.pdf.active!
  const contentType = type === 'audio' ? 'audio/mpeg' : 'application/pdf'

  await uploadObject(activePath, buffer, contentType)
  await uploadObject('manifest.json', Buffer.from(JSON.stringify(updated, null, 2)), 'application/json')

  // Keep DB in sync with manifest so publish/unpublish can reconstruct the manifest entry
  if (type === 'pdf') {
    await prisma.lesson.update({
      where: { id },
      data: {
        pdfActive: manifestLesson.pdf.active,
        pdfChecksum: manifestLesson.pdf.checksum,
        pdfHistory: manifestLesson.pdf.history,
      },
    })
  } else {
    await prisma.lesson.update({
      where: { id },
      data: {
        audioActive: manifestLesson.audio.active,
        audioExt: manifestLesson.audio.ext,
        audioChecksum: manifestLesson.audio.checksum,
        audioHistory: manifestLesson.audio.history,
      },
    })
  }

  return NextResponse.json({ path: activePath, checksum })
}
