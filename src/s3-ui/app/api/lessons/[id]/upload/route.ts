import { NextRequest, NextResponse } from 'next/server'
import crypto from 'crypto'
import { uploadObject, getObjectText } from '@/lib/minio'
import { parseManifest, applyUpload } from '@/lib/manifest'
import { uploadQuerySchema } from '@/lib/schemas'

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
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
  const lesson = updated.lessons.find((l) => l.id === id)
  if (!lesson) return NextResponse.json({ error: 'Lesson not found in manifest' }, { status: 404 })

  const activePath = type === 'audio' ? lesson.audio.active! : lesson.pdf.active!
  const contentType = type === 'audio' ? 'audio/mpeg' : 'application/pdf'

  await uploadObject(activePath, buffer, contentType)
  await uploadObject('manifest.json', Buffer.from(JSON.stringify(updated, null, 2)), 'application/json')

  return NextResponse.json({ path: activePath, checksum })
}
