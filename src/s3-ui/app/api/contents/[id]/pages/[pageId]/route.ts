export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAuth } from '@/lib/auth'
import { deleteFolder, getObjectText, uploadObject } from '@/lib/minio'
import { parseManifest, removeContent } from '@/lib/manifest'

type RouteContext = { params: Promise<{ id: string; pageId: string }> }

/** Delete a specific page from a multi-page content group.
 *  After deletion, re-indexes remaining children so pageIndex stays sequential.
 *  If the parent was published, auto-unpublishes it.
 */
export async function DELETE(
  req: NextRequest,
  { params }: RouteContext,
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: parentIdStr, pageId: pageIdStr } = await params
  const parentId = parseInt(parentIdStr, 10)
  const pageId = parseInt(pageIdStr, 10)

  const parent = await prisma.content.findUnique({ where: { id: parentId } })
  if (!parent) {
    return NextResponse.json({ error: 'Parent not found' }, { status: 404 })
  }

  const page = await prisma.content.findUnique({ where: { id: pageId } })
  if (!page || page.parentId !== parentId) {
    return NextResponse.json({ error: 'Page not found' }, { status: 404 })
  }

  // Delete MinIO folder for the page (best-effort)
  try { await deleteFolder(`contents/${pageId}/`) } catch { /* best-effort */ }

  await prisma.content.delete({ where: { id: pageId } })

  // Re-index remaining children so pageIndex stays sequential (0, 1, 2...)
  const remainingChildren = await prisma.content.findMany({
    where: { parentId },
    orderBy: { pageIndex: 'asc' },
  })
  for (let index = 0; index < remainingChildren.length; index++) {
    const child = remainingChildren[index]
    if (child.pageIndex !== index) {
      await prisma.content.update({
        where: { id: child.id },
        data: {
          pageIndex: index,
          slug: `${parent.slug}-p${index}`,
          title: `${parent.title} — Página ${index + 1}`,
        },
      })
    }
  }

  // Auto-unpublish parent if it was published
  if (parent.published) {
    await prisma.content.update({
      where: { id: parentId },
      data: { published: false },
    })
    try {
      const manifestJson = await getObjectText('manifest.json')
      let manifest = parseManifest(manifestJson)
      manifest = removeContent(manifest, parentId)
      await uploadObject(
        'manifest.json',
        Buffer.from(JSON.stringify(manifest, null, 2)),
        'application/json',
      )
    } catch { /* best-effort */ }
  }

  return new NextResponse(null, { status: 204 })
}
