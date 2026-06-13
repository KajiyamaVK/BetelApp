export const dynamic = 'force-dynamic'

import crypto from 'crypto'
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth'
import { listImageObjects, uploadObject } from '@/lib/minio'

const ALLOWED_MIME_TYPES: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/gif': 'gif',
  'image/webp': 'webp',
}

export async function GET(req: NextRequest) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const images = await listImageObjects('contents/images/')
  return NextResponse.json(images)
}

export async function POST(req: NextRequest) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const formData = await req.formData()
  const file = formData.get('file') as File | null

  if (!file || !(file instanceof File)) {
    return NextResponse.json(
      { error: 'Arquivo de imagem obrigatório' },
      { status: 400 },
    )
  }

  const extension = ALLOWED_MIME_TYPES[file.type]
  if (!extension) {
    return NextResponse.json(
      { error: `Tipo de imagem não suportado: ${file.type}. Use JPEG, PNG, GIF ou WebP.` },
      { status: 400 },
    )
  }

  const buffer = Buffer.from(await file.arrayBuffer())
  const objectName = `contents/images/${crypto.randomUUID()}.${extension}`
  await uploadObject(objectName, buffer, file.type)

  const baseUrl = process.env.NEXT_PUBLIC_S3_BASE_URL ?? ''
  return NextResponse.json(
    { url: `${baseUrl}/${objectName}`, name: objectName },
    { status: 201 },
  )
}
