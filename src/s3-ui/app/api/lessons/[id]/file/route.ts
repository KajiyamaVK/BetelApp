export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { uploadObject, getObjectText } from '@/lib/minio'
import { parseManifest, softDeleteFile } from '@/lib/manifest'
import { uploadQuerySchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

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

  const manifestText = await getObjectText('manifest.json')
  const manifest = parseManifest(manifestText)
  const updated = softDeleteFile(manifest, id, parsed.data.type)

  await uploadObject('manifest.json', Buffer.from(JSON.stringify(updated, null, 2)), 'application/json')

  return NextResponse.json({ ok: true })
}
