import { config } from 'dotenv'
import { defineConfig, env } from 'prisma/config'

// Next.js uses .env.local for local overrides; load it explicitly for Prisma CLI
config({ path: '.env.local' })
config() // fallback to .env

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'tsx prisma/seed.ts',
  },
  datasource: {
    url: env('DATABASE_URL'),
  },
})
