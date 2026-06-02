import { NextRequest, NextResponse } from 'next/server'
import { Prisma } from '@prisma/client'

export const dynamic = 'force-dynamic'
import { prisma } from '@/lib/prisma'
import { createLessonSchema } from '@/lib/schemas'
import { requireAuth } from '@/lib/auth'

export async function GET() {
  const lessons = await prisma.lesson.findMany({ orderBy: { id: 'asc' } })

  const result = lessons.map((lesson) => ({
    id: lesson.id,
    title: lesson.title,
    published: lesson.published,
    audio: lesson.audioActive
      ? { active: lesson.audioActive, ext: lesson.audioExt ?? 'mp3', checksum: lesson.audioChecksum ?? '', history: (lesson.audioHistory as string[]) ?? [] }
      : { active: null, ext: 'mp3', checksum: '', history: [] },
    pdf: { active: lesson.pdfActive, checksum: lesson.pdfChecksum ?? '', history: (lesson.pdfHistory as string[]) ?? [] },
  }))

  return NextResponse.json(result)
}

export async function POST(req: NextRequest) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const body = await req.json()
  const parsed = createLessonSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0].message }, { status: 400 })
  }

  const { id, title } = parsed.data

  try {
    const lesson = await prisma.lesson.create({ data: { id, title } })

    return NextResponse.json({ id: lesson.id, title: lesson.title, published: lesson.published }, { status: 201 })
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return NextResponse.json({ error: `Lição #${id} já existe` }, { status: 409 })
    }
    throw error
  }
}
