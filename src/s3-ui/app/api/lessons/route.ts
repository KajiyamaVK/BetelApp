import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'
import { prisma } from '@/lib/prisma'
import { getObjectText } from '@/lib/minio'
import { parseManifest } from '@/lib/manifest'

export async function GET() {
  const [lessons, manifestText] = await Promise.all([
    prisma.lesson.findMany({ orderBy: { id: 'asc' } }),
    getObjectText('manifest.json'),
  ])

  const manifest = parseManifest(manifestText)

  const result = lessons.map((lesson) => {
    const mLesson = manifest.lessons.find((m) => m.id === lesson.id)
    return {
      id: lesson.id,
      title: lesson.title,
      published: lesson.published,
      audio: mLesson?.audio ?? { active: null, ext: 'mp3', checksum: '', history: [] },
      pdf: mLesson?.pdf ?? { active: null, checksum: '', history: [] },
    }
  })

  return NextResponse.json(result)
}
