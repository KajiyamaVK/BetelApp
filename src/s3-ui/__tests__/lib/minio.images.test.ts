import { Readable } from 'stream'

// Mock the minio module's internal client so we can control listObjectsV2
jest.mock('minio', () => {
  const mockListObjectsV2 = jest.fn()
  return {
    Client: jest.fn().mockImplementation(() => ({
      listObjectsV2: mockListObjectsV2,
    })),
    __mockListObjectsV2: mockListObjectsV2,
  }
})

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { __mockListObjectsV2 } = require('minio') as { __mockListObjectsV2: jest.Mock }

// Set required env vars before importing the module under test
process.env.MINIO_ENDPOINT = 'localhost'
process.env.MINIO_PORT = '9000'
process.env.MINIO_USE_SSL = 'false'
process.env.MINIO_ACCESS_KEY = 'test'
process.env.MINIO_SECRET_KEY = 'test'
process.env.MINIO_BUCKET = 'test-bucket'
process.env.NEXT_PUBLIC_S3_BASE_URL = 'https://s3.example.com/test-bucket'

import { listImageObjects } from '@/lib/minio'

/** Creates a readable stream that emits the given objects then ends */
function createObjectStream(objects: Array<{ name?: string }>): Readable {
  const stream = new Readable({ objectMode: true, read() {} })
  for (const obj of objects) {
    stream.push(obj)
  }
  stream.push(null)
  return stream
}

describe('listImageObjects', () => {
  beforeEach(() => {
    __mockListObjectsV2.mockReset()
  })

  it('returns array of name+url for each object under the prefix', async () => {
    __mockListObjectsV2.mockReturnValue(
      createObjectStream([
        { name: 'contents/images/abc.jpg' },
        { name: 'contents/images/def.png' },
      ]),
    )

    const result = await listImageObjects('contents/images/')
    expect(result).toEqual([
      { name: 'contents/images/abc.jpg', url: 'https://s3.example.com/test-bucket/contents/images/abc.jpg' },
      { name: 'contents/images/def.png', url: 'https://s3.example.com/test-bucket/contents/images/def.png' },
    ])
  })

  it('returns empty array when no objects exist', async () => {
    __mockListObjectsV2.mockReturnValue(createObjectStream([]))

    const result = await listImageObjects('contents/images/')
    expect(result).toEqual([])
  })

  it('skips objects with no name property', async () => {
    __mockListObjectsV2.mockReturnValue(
      createObjectStream([{ name: 'contents/images/abc.jpg' }, {}]),
    )

    const result = await listImageObjects('contents/images/')
    expect(result).toHaveLength(1)
  })

  it('propagates stream errors', async () => {
    const stream = new Readable({ objectMode: true, read() {} })
    __mockListObjectsV2.mockReturnValue(stream)

    const promise = listImageObjects('contents/images/')
    stream.destroy(new Error('Connection lost'))

    await expect(promise).rejects.toThrow('Connection lost')
  })
})
