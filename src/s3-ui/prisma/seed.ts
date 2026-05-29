import { config } from 'dotenv'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import bcrypt from 'bcryptjs'

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

async function main() {
  const password = process.env.SEED_VICTOR_PASSWORD
  if (!password) throw new Error('SEED_VICTOR_PASSWORD env var required')

  const passwordHash = await bcrypt.hash(password, 12)

  await prisma.user.upsert({
    where: { username: 'victor' },
    // Only refresh the password hash — never touch isAdmin so a deliberate demotion isn't silently undone
    update: { passwordHash },
    create: { username: 'victor', passwordHash, isAdmin: true },
  })

  for (let i = 0; i < LESSON_TITLES.length; i++) {
    await prisma.lesson.upsert({
      where: { id: i + 1 },
      update: {},
      create: { id: i + 1, title: LESSON_TITLES[i] },
    })
  }

  console.log('Seed complete — user victor created as admin, 24 lessons seeded')
}

main().finally(() => prisma.$disconnect())
