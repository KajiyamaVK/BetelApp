export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { Prisma } from '@prisma/client'
import { prisma } from '@/lib/prisma'
import { updateContentSchema, slugify } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'
import { deleteFolder, uploadObject } from '@/lib/minio'
import { removeContent } from '@/lib/manifest'
import { updateManifest } from '@/lib/manifest-sync'

type RouteContext = { params: Promise<{ id: string }> }

export async function GET(
  _req: NextRequest,
  { params }: RouteContext,
) {
  const { id: idStr } = await params
  const contentId = parseInt(idStr, 10)

  const content = await prisma.content.findUnique({
    where: { id: contentId },
    include: { children: { orderBy: { pageIndex: 'asc' } } },
  })
  if (!content) {
    return NextResponse.json({ error: 'Content not found' }, { status: 404 })
  }

  return NextResponse.json(content)
}

export async function PUT(
  req: NextRequest,
  { params }: RouteContext,
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const contentId = parseInt(idStr, 10)

  const existing = await prisma.content.findUnique({ where: { id: contentId } })
  if (!existing) {
    return NextResponse.json({ error: 'Content not found' }, { status: 404 })
  }

  const body = await req.json()

  // Extract html field separately — it's a file upload in spirit, not a schema field
  const htmlContent: string | undefined =
    typeof body.html === 'string' && body.html.length > 0 ? body.html : undefined

  // Remove html from the body before schema validation
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { html: _html, ...schemaBody } = body

  // If no schema fields AND no html, it's a bad request
  const hasSchemaFields = Object.keys(schemaBody).length > 0
  if (!hasSchemaFields && !htmlContent) {
    return NextResponse.json(
      { error: 'At least one field required' },
      { status: 400 },
    )
  }

  // Validate schema fields if present
  let updateData: Record<string, unknown> = {}
  if (hasSchemaFields) {
    const parsed = updateContentSchema.safeParse(schemaBody)
    if (!parsed.success) {
      return NextResponse.json(
        { error: parsed.error.issues[0].message },
        { status: 400 },
      )
    }
    updateData = { ...parsed.data }
    // When title changes, regenerate the slug automatically
    if (parsed.data.title) {
      updateData.slug = slugify(parsed.data.title)
    }
  }

  // Check title uniqueness for root-level contents (children have auto-generated titles)
  if (updateData.title && !existing.parentId) {
    const duplicate = await prisma.content.findFirst({
      where: {
        title: updateData.title as string,
        id: { not: contentId },
        parentId: null,
      },
    })
    if (duplicate) {
      return NextResponse.json(
        { error: 'Já existe um conteúdo com este título' },
        { status: 409 },
      )
    }
  }

  // Upload HTML to MinIO if provided
  if (htmlContent) {
    const htmlPath = `contents/${contentId}/content.html`
    await uploadObject(htmlPath, Buffer.from(htmlContent, 'utf-8'), 'text/html')
    updateData.htmlPath = htmlPath
  }

  try {
    // If the content was published, auto-unpublish on edit so the user
    // must explicitly re-publish after reviewing the changes.
    const wasPublished = existing.published
    if (wasPublished) {
      updateData.published = false
    }

    const updated = await prisma.content.update({
      where: { id: contentId },
      data: updateData,
    })

    // Remove from manifest since we just unpublished
    if (wasPublished) {
      try {
        await updateManifest((manifest) => removeContent(manifest, contentId))
      } catch {
        // Best-effort manifest sync
      }
    }

    return NextResponse.json({
      ...updated,
      // Signal to the frontend that the content was auto-unpublished
      wasAutoUnpublished: wasPublished,
    })
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      return NextResponse.json(
        { error: 'Já existe um conteúdo com este título' },
        { status: 409 },
      )
    }
    throw error
  }
}

export async function DELETE(
  req: NextRequest,
  { params }: RouteContext,
) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const { id: idStr } = await params
  const contentId = parseInt(idStr, 10)

  const existing = await prisma.content.findUnique({ where: { id: contentId } })
  if (!existing) {
    return NextResponse.json({ error: 'Content not found' }, { status: 404 })
  }

  // Remove from manifest (best-effort)
  try {
    await updateManifest((manifest) => removeContent(manifest, contentId))
  } catch {
    // Best-effort — manifest sync failure doesn't block delete
  }

  // Delete MinIO folders for child pages before cascade deletes them from DB
  const children = await prisma.content.findMany({
    where: { parentId: contentId },
    select: { id: true },
  })
  for (const child of children) {
    try { await deleteFolder(`contents/${child.id}/`) } catch { /* best-effort */ }
  }

  // Delete MinIO folder for this content itself
  try {
    await deleteFolder(`contents/${contentId}/`)
  } catch {
    // Best-effort
  }

  // ON DELETE CASCADE removes child rows automatically
  await prisma.content.delete({ where: { id: contentId } })

  return new NextResponse(null, { status: 204 })
}

