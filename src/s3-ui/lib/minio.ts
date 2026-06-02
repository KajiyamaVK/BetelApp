import { Client } from 'minio'

/** Creates a fresh MinIO client from environment variables */
function createClient(): Client {
  return new Client({
    endPoint: process.env.MINIO_ENDPOINT!,
    port: Number(process.env.MINIO_PORT ?? 443),
    useSSL: process.env.MINIO_USE_SSL === 'true',
    accessKey: process.env.MINIO_ACCESS_KEY!,
    secretKey: process.env.MINIO_SECRET_KEY!,
  })
}

/** Returns a configured MinIO client */
export function getMinioClient(): Client {
  return createClient()
}

/** Returns the configured bucket name; throws if MINIO_BUCKET is not set */
export function getBucket(): string {
  const bucket = process.env.MINIO_BUCKET
  if (!bucket) throw new Error('MINIO_BUCKET not set')
  return bucket
}

/**
 * Uploads a buffer to MinIO under the given object name.
 * Caller is responsible for generating a unique, path-safe object name.
 */
export async function uploadObject(
  objectName: string,
  buffer: Buffer,
  contentType: string,
): Promise<void> {
  const client = getMinioClient()
  await client.putObject(getBucket(), objectName, buffer, buffer.length, {
    'Content-Type': contentType,
  })
}

/**
 * Deletes all objects whose names start with `prefix`.
 * Used to remove all lesson files when a lesson is deleted.
 */
export async function deleteFolder(prefix: string): Promise<void> {
  const client = getMinioClient()
  const bucket = getBucket()

  const objectNames: string[] = await new Promise((resolve, reject) => {
    const names: string[] = []
    const stream = client.listObjectsV2(bucket, prefix, true)
    stream.on('data', (obj) => { if (obj.name) names.push(obj.name) })
    stream.on('end', () => resolve(names))
    stream.on('error', reject)
  })

  if (objectNames.length === 0) return
  await client.removeObjects(bucket, objectNames)
}

/**
 * Downloads a MinIO object and returns its content as a UTF-8 string.
 * Used primarily for JSON manifest files.
 */
export async function getObjectText(objectName: string): Promise<string> {
  const client = getMinioClient()
  const stream = await client.getObject(getBucket(), objectName)
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = []
    stream.on('data', (chunk: Buffer) => chunks.push(chunk))
    stream.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')))
    stream.on('error', reject)
  })
}
