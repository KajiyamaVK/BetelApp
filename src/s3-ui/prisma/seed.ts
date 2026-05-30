import { config } from 'dotenv'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import bcrypt from 'bcryptjs'
import { Client } from 'minio'

// Load .env.local first (Next.js convention), then fall back to .env
config({ path: '.env.local' })
config()

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL env var is required')
}

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL })
const prisma = new PrismaClient({ adapter })

const LESSON_TITLES = [
  'Qual o Fim principal?',
  'Que regra deu Deus?',
  'O que a escritura nos ensina?',
  'Quem é Deus?',
  'Será que existe mais de um Deus?',
  'Quantas pessoas há na divindade?',
  'Que são os Decretos de Deus?',
  'Como Deus executa seus decretos?',
  'Quais são as obras da criação?',
  'Como criou Deus o homem?',
  'Quais as obras da providência?',
  'Que ato especial da providência?',
  'Conservaram-se nossos primeiros pais?',
  'O que é pecado?',
  'Qual o primeiro pecado?',
  'Caiu todo gênero humano em Adão?',
  'Qual foi o Estado a que a queda reduziu o gênero humano?',
  'Em que consiste o estado de miséria?',
  'Qual miséria do estado que o homem caiu?',
  'Deixou Deus todo o gênero humano perecer no estado de pecado e miséria?',
  'Quem é o Redentor dos escolhidos de Deus?',
  'Como Cristo se fez homem?',
  'Que funções exerce Cristo como nosso Redentor?',
  'Como exerce Cristo as funções de profeta?',
]

interface ManifestLessonEntry {
  id: number
  pdf?: { active: string | null; checksum: string; history: string[] }
  audio?: { active: string | null; ext: string; checksum: string; history: string[] } | null
}

async function fetchManifestLessons(): Promise<ManifestLessonEntry[]> {
  const endpoint = process.env.MINIO_ENDPOINT
  const bucket = process.env.MINIO_BUCKET
  if (!endpoint || !bucket) {
    console.warn('MINIO_ENDPOINT or MINIO_BUCKET not set — skipping manifest sync in seed')
    return []
  }

  const minioClient = new Client({
    endPoint: endpoint,
    port: Number(process.env.MINIO_PORT ?? 443),
    useSSL: process.env.MINIO_USE_SSL === 'true',
    accessKey: process.env.MINIO_ACCESS_KEY!,
    secretKey: process.env.MINIO_SECRET_KEY!,
  })

  try {
    const stream = await minioClient.getObject(bucket, 'manifest.json')
    const chunks: Buffer[] = []
    await new Promise<void>((resolve, reject) => {
      stream.on('data', (chunk: Buffer) => chunks.push(chunk))
      stream.on('end', resolve)
      stream.on('error', reject)
    })
    const manifest = JSON.parse(Buffer.concat(chunks).toString('utf-8'))
    return manifest.lessons ?? []
  } catch {
    console.warn('Could not fetch manifest.json from MinIO — skipping manifest sync in seed')
    return []
  }
}

async function main() {
  const password = process.env.SEED_VICTOR_PASSWORD
  if (!password) throw new Error('SEED_VICTOR_PASSWORD env var required')

  const passwordHash = await bcrypt.hash(password, 12)

  await prisma.user.upsert({
    where: { username: 'victor' },
    // Only refresh the password hash — never touch isAdmin so a deliberate demotion isn't silently undone.
    // mustChangePassword is explicitly false for the seed user so dev/test logins work without a forced change.
    update: { passwordHash, mustChangePassword: false },
    create: { username: 'victor', passwordHash, isAdmin: true, mustChangePassword: false },
  })

  const manifestLessons = await fetchManifestLessons()
  const manifestMap = new Map(manifestLessons.map((l) => [l.id, l]))

  for (let i = 0; i < LESSON_TITLES.length; i++) {
    const lessonId = i + 1
    const manifestEntry = manifestMap.get(lessonId)

    await prisma.lesson.upsert({
      where: { id: lessonId },
      update: {},
      create: {
        id: lessonId,
        title: LESSON_TITLES[i],
        pdfActive: manifestEntry?.pdf?.active ?? null,
        pdfChecksum: manifestEntry?.pdf?.checksum ?? null,
        pdfHistory: manifestEntry?.pdf?.history ?? [],
        audioActive: manifestEntry?.audio?.active ?? null,
        audioExt: manifestEntry?.audio?.ext ?? null,
        audioChecksum: manifestEntry?.audio?.checksum ?? null,
        audioHistory: manifestEntry?.audio?.history ?? [],
      },
    })
  }

  console.log('Seed complete — user victor created as admin, 24 lessons seeded')
}

main().finally(() => prisma.$disconnect())
