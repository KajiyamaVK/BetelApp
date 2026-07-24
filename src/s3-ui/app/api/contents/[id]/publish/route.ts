export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { togglePublishSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'
import { getObjectText, uploadObject } from '@/lib/minio'
import {
  parseManifest,
  upsertContent,
  removeContent,
  type ManifestContent,
} from '@/lib/manifest'

type RouteContext = { params: Promise<{ id: string }> }

export async function PATCH(
  req: NextRequest,
  { params }: RouteContext,
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const contentId = parseInt(idStr, 10)

  const content = await prisma.content.findUnique({
    where: { id: contentId },
    include: { children: { orderBy: { pageIndex: 'asc' } } },
  })
  if (!content) {
    return NextResponse.json({ error: 'Content not found' }, { status: 404 })
  }

  const body = await req.json()
  const parsed = togglePublishSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0].message },
      { status: 400 },
    )
  }

  const { published } = parsed.data

  if (published && content.type === 'TEXT') {
    const hasChildren = content.children.length > 0

    if (hasChildren) {
      // Multi-page: all child pages must have HTML uploaded
      const missingPages = content.children.filter((child) => !child.htmlPath)
      if (missingPages.length > 0) {
        return NextResponse.json(
          { error: `${missingPages.length} página(s) sem conteúdo. Adicione conteúdo a todas as páginas antes de publicar.` },
          { status: 400 },
        )
      }
    } else if (!content.htmlPath) {
      // Single-page (legacy): must have its own HTML
      return NextResponse.json(
        { error: 'Conteúdo TEXT precisa de HTML para ser publicado' },
        { status: 400 },
      )
    }
  }

  // Read and update manifest
  const manifestJson = await getObjectText('manifest.json')
  let manifest = parseManifest(manifestJson)

  if (published) {
    const entry = await buildManifestEntry(content)
    if (entry) {
      manifest = upsertContent(manifest, entry)
    }
  } else {
    manifest = removeContent(manifest, contentId)
  }

  await uploadObject(
    'manifest.json',
    Buffer.from(JSON.stringify(manifest, null, 2)),
    'application/json',
  )

  const updated = await prisma.content.update({
    where: { id: contentId },
    data: { published },
  })

  return NextResponse.json(updated)
}

/** Builds a ManifestContent entry from a DB Content record.
 *  For multi-page TEXT: reads each child's HTML from MinIO and returns a pages array.
 *  For single-page TEXT: reads the HTML from MinIO and returns inline.
 *  For VIDEO: returns the YouTube URL.
 */
async function buildManifestEntry(
  content: {
    id: number; slug: string; title: string; type: string;
    youtubeUrl: string | null; htmlPath: string | null;
    displayLocation: string;
    children: { htmlPath: string | null; pageIndex: number | null }[];
  },
): Promise<ManifestContent | null> {
  if (content.type === 'VIDEO' && content.youtubeUrl) {
    return {
      id: content.id,
      slug: content.slug,
      title: content.title,
      type: 'VIDEO',
      youtubeUrl: content.youtubeUrl,
      displayLocation: content.displayLocation,
    }
  }

  if (content.type === 'TEXT') {
    // Multi-page: read each child's HTML from MinIO
    if (content.children.length > 0) {
      const pages: string[] = []
      for (const child of content.children) {
        if (!child.htmlPath) return null
        pages.push(await getObjectText(child.htmlPath))
      }
      return {
        id: content.id,
        slug: content.slug,
        title: content.title,
        type: 'TEXT',
        pages,
        displayLocation: content.displayLocation,
      }
    }

    // Single-page (legacy)
    if (content.htmlPath) {
      const html = await getObjectText(content.htmlPath)
      return {
        id: content.id,
        slug: content.slug,
        title: content.title,
        type: 'TEXT',
        html,
        displayLocation: content.displayLocation,
      }
    }
  }

  return null
}
