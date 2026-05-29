import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'

// Reuse a single Prisma instance across hot reloads in development.
// globalForPrisma is typed explicitly to avoid TypeScript errors on globalThis.
const globalForPrisma = globalThis as unknown as { prisma: PrismaClient }

function createPrismaClient(): PrismaClient {
  // Prisma v7 requires a driver adapter — pg is the chosen adapter for this project.
  const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL! })
  return new PrismaClient({ adapter, log: ['error'] })
}

export const prisma = globalForPrisma.prisma ?? createPrismaClient()

// Prevent multiple instances in development when Next.js hot-reloads modules.
if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
