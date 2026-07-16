/**
 * One-time backfill: reads manifest.json from MinIO and populates
 * pdfActive/pdfChecksum/pdfHistory/audioActive/audioExt/audioChecksum/audioHistory
 * for existing Lesson rows that still have those fields as null.
 *
 * Safe to run multiple times — only updates rows where pdfActive IS NULL.
 */
import { config } from 'dotenv'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { getObjectText } from '../lib/minio'

config({ path: '.env.local' })
config()

if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL env var is required')
if (!process.env.MINIO_ENDPOINT) throw new Error('MINIO_ENDPOINT env var is required')
if (!process.env.MINIO_BUCKET) throw new Error('MINIO_BUCKET env var is required')

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL })
const prisma = new PrismaClient({ adapter })

async function fetchManifest() {
  return JSON.parse(await getObjectText('manifest.json'))
}

async function main() {
  const manifest = await fetchManifest()
  const lessons = manifest.lessons as Array<{
    id: number
    pdf?: { active: string | null; checksum: string; history: string[] }
    audio?: { active: string | null; ext: string; checksum: string; history: string[] } | null
  }>

  let updated = 0
  for (const manifestLesson of lessons) {
    const dbLesson = await prisma.lesson.findUnique({ where: { id: manifestLesson.id } })
    if (!dbLesson || dbLesson.pdfActive !== null) continue

    await prisma.lesson.update({
      where: { id: manifestLesson.id },
      data: {
        pdfActive: manifestLesson.pdf?.active ?? null,
        pdfChecksum: manifestLesson.pdf?.checksum ?? null,
        pdfHistory: manifestLesson.pdf?.history ?? [],
        audioActive: manifestLesson.audio?.active ?? null,
        audioExt: manifestLesson.audio?.ext ?? null,
        audioChecksum: manifestLesson.audio?.checksum ?? null,
        audioHistory: manifestLesson.audio?.history ?? [],
      },
    })
    updated++
  }

  console.log(`Backfill complete — ${updated} lesson(s) updated`)
}

main().finally(() => prisma.$disconnect())
