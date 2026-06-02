import { execFileSync } from 'child_process'
import path from 'path'
import { config as loadEnv } from 'dotenv'

const E2E_LESSON_IDS = [200, 201, 202, 203]

export default async function globalSetup() {
  loadEnv({ path: path.resolve(__dirname, '../.env.test') })
  const dbUrl = process.env.DATABASE_URL
  if (!dbUrl) throw new Error('DATABASE_URL not set in .env.test')

  const minioEndpoint = process.env.MINIO_ENDPOINT
  const minioBucket = process.env.MINIO_BUCKET
  const minioAccessKey = process.env.MINIO_ACCESS_KEY
  const minioSecretKey = process.env.MINIO_SECRET_KEY
  const minioPort = process.env.MINIO_PORT ?? '443'
  const minioUseSsl = process.env.MINIO_USE_SSL === 'true'

  if (!minioEndpoint || !minioBucket || !minioAccessKey || !minioSecretKey) {
    throw new Error('MinIO env vars not set in .env.test')
  }

  // Clean test lessons from DB
  const ids = E2E_LESSON_IDS.join(', ')
  execFileSync('psql', [dbUrl, '-c', `DELETE FROM "Lesson" WHERE id IN (${ids});`], { stdio: 'pipe' })

  // Clean test lessons from manifest in MinIO
  const alias = 'e2e-setup-tmp'
  const protocol = minioUseSsl ? 'https' : 'http'
  execFileSync('mc', ['alias', 'set', alias, `${protocol}://${minioEndpoint}:${minioPort}`, minioAccessKey, minioSecretKey], { stdio: 'pipe' })

  try {
    const manifestJson = execFileSync('mc', ['cat', `${alias}/${minioBucket}/manifest.json`], { encoding: 'utf-8' })
    const manifest = JSON.parse(manifestJson)
    const cleanedLessons = manifest.lessons.filter((l: { id: number }) => !E2E_LESSON_IDS.includes(l.id))
    if (cleanedLessons.length !== manifest.lessons.length) {
      const cleaned = { ...manifest, version: manifest.version + 1, updated_at: new Date().toISOString(), lessons: cleanedLessons }
      const tmpFile = '/tmp/manifest-e2e-cleanup.json'
      require('fs').writeFileSync(tmpFile, JSON.stringify(cleaned, null, 2))
      execFileSync('mc', ['cp', tmpFile, `${alias}/${minioBucket}/manifest.json`], { stdio: 'pipe' })
    }
  } catch {
    // manifest may not exist yet in a fresh test environment — that is fine
  }
}
