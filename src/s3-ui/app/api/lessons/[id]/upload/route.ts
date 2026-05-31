export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import crypto from 'crypto'
import { uploadObject, getObjectText } from '@/lib/minio'
import { parseManifest, applyUpload, upsertLesson } from '@/lib/manifest'
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

  const MAX_BYTES = type === 'pdf' ? 50 * 1024 * 1024 : 20 * 1024 * 1024
  const MAX_LABEL = type === 'pdf' ? '50 MB' : '20 MB'
  if (file.size > MAX_BYTES) {
    return NextResponse.json(
      { error: `O arquivo excede o limite de ${MAX_LABEL} para ${type === 'pdf' ? 'PDF' : 'áudio'}` },
      { status: 413 },
    )
  }

  const buffer = Buffer.from(await file.arrayBuffer())
  const checksum = crypto.createHash('md5').update(buffer).digest('hex')

  const [dbLesson, manifestText] = await Promise.all([
    prisma.lesson.findUnique({ where: { id } }),
    getObjectText('manifest.json'),
  ])
  if (!dbLesson) return NextResponse.json({ error: 'Lesson not found' }, { status: 404 })

  let manifest = parseManifest(manifestText)

  // If the lesson was removed from the manifest (e.g. unpublished), re-add it before uploading
  if (!manifest.lessons.find((lesson) => lesson.id === id)) {
    manifest = upsertLesson(manifest, {
      id,
      title: dbLesson.title,
      audio: dbLesson.audioActive ? { active: dbLesson.audioActive, ext: dbLesson.audioExt ?? 'mp3', checksum: dbLesson.audioChecksum ?? '', history: (dbLesson.audioHistory as string[]) ?? [] } : null,
      pdf: { active: dbLesson.pdfActive, checksum: dbLesson.pdfChecksum ?? '', history: (dbLesson.pdfHistory as string[]) ?? [] },
    })
  }

  const updated = applyUpload(manifest, id, type, checksum)
  const manifestLesson = updated.lessons.find((lesson) => lesson.id === id)
  if (!manifestLesson) return NextResponse.json({ error: 'Lesson not found in manifest' }, { status: 404 })

  const activePath = type === 'audio' ? manifestLesson.audio!.active! : manifestLesson.pdf.active!
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
    const audio = manifestLesson.audio!
    await prisma.lesson.update({
      where: { id },
      data: {
        audioActive: audio.active,
        audioExt: audio.ext,
        audioChecksum: audio.checksum,
        audioHistory: audio.history,
      },
    })
  }

  return NextResponse.json({ path: activePath, checksum })
}
