export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import { Prisma } from '@prisma/client'
import { prisma } from '@/lib/prisma'
import { createContentSchema, slugify } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

export async function GET() {
  // Only return root-level contents (not child pages of multi-page groups)
  const contents = await prisma.content.findMany({
    where: { parentId: null },
    orderBy: { order: 'asc' },
    include: { _count: { select: { children: true } } },
  })

  // Flatten the _count into a top-level pageCount field for the frontend
  const result = contents.map(({ _count, ...content }) => ({
    ...content,
    pageCount: _count.children,
  }))

  return NextResponse.json(result)
}

export async function POST(req: NextRequest) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const body = await req.json()

  // Child page creation: when parentId is present, create a page linked to the parent.
  // The child inherits type from the parent and gets auto-generated slug/title.
  if (body.parentId != null) {
    return createChildPage(body.parentId)
  }

  const parsed = createContentSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0].message },
      { status: 400 },
    )
  }

  const slug = slugify(parsed.data.title)
  if (!slug) {
    return NextResponse.json(
      { error: 'Título não gera um slug válido' },
      { status: 400 },
    )
  }

  // Check title uniqueness among root-level contents (child pages have auto-generated titles)
  const duplicate = await prisma.content.findFirst({
    where: { title: parsed.data.title, parentId: null },
  })
  if (duplicate) {
    return NextResponse.json(
      { error: 'Já existe um conteúdo com este título' },
      { status: 409 },
    )
  }

  try {
    const content = await prisma.content.create({
      data: {
        slug,
        title: parsed.data.title,
        type: parsed.data.type,
        youtubeUrl: parsed.data.type === 'VIDEO' ? parsed.data.youtubeUrl : null,
        order: parsed.data.order ?? 0,
      },
    })
    return NextResponse.json(content, { status: 201 })
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      // Slug collision (slug is still @unique in the schema)
      return NextResponse.json(
        { error: 'Já existe um conteúdo com este título' },
        { status: 409 },
      )
    }
    throw error
  }
}

/** Creates a child page linked to an existing parent TEXT content.
 *  Assigns the next sequential pageIndex and auto-generates slug/title.
 */
async function createChildPage(parentId: number) {
  const parent = await prisma.content.findUnique({ where: { id: parentId } })
  if (!parent) {
    return NextResponse.json({ error: 'Parent not found' }, { status: 404 })
  }
  if (parent.type !== 'TEXT') {
    return NextResponse.json(
      { error: 'Multi-page is only supported for TEXT content' },
      { status: 400 },
    )
  }

  // Determine the next pageIndex by counting existing children
  const childCount = await prisma.content.count({ where: { parentId } })
  const pageIndex = childCount

  const child = await prisma.content.create({
    data: {
      slug: `${parent.slug}-p${pageIndex}`,
      title: `${parent.title} — Página ${pageIndex + 1}`,
      type: 'TEXT',
      parentId,
      pageIndex,
    },
  })

  return NextResponse.json(child, { status: 201 })
}
