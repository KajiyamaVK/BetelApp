/**
 * @jest-environment node
 */
import { DELETE as deleteFile } from '@/app/api/lessons/[id]/file/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'

const mockDeleteObject = jest.fn().mockResolvedValue(undefined)

jest.mock('@/lib/minio', () => ({
  getObjectText: jest.fn().mockResolvedValue(
    JSON.stringify({
      version: 1,
      updated_at: '2024-01-01T00:00:00Z',
      lessons: [
        {
          id: 1,
          title: 'Test',
          pdf: { active: 'lessons/1/lesson_v1.pdf', checksum: 'abc', history: [] },
          audio: { active: 'lessons/1/audio_v1.mp3', ext: 'mp3', checksum: 'def', history: [] },
        },
      ],
    }),
  ),
  uploadObject: jest.fn().mockResolvedValue(undefined),
  deleteObject: (...args: unknown[]) => mockDeleteObject(...args),
}))

async function makeDeleteRequest(lessonId: number, type: 'audio' | 'pdf'): Promise<NextRequest> {
  const token = await signToken({ id: 1, username: 'victor', isAdmin: false, mustChangePassword: false })
  const req = new NextRequest(`http://localhost/api/lessons/${lessonId}/file?type=${type}`, {
    method: 'DELETE',
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeAll(async () => {
  await prisma.lesson.upsert({
    where: { id: 1 },
    update: {
      audioActive: 'lessons/1/audio_v1.mp3',
      audioExt: 'mp3',
      audioChecksum: 'def',
      audioHistory: [],
      pdfActive: 'lessons/1/lesson_v1.pdf',
      pdfChecksum: 'abc',
      pdfHistory: [],
    },
    create: {
      id: 1,
      title: 'Test Lesson',
      audioActive: 'lessons/1/audio_v1.mp3',
      audioExt: 'mp3',
      audioChecksum: 'def',
      audioHistory: [],
      pdfActive: 'lessons/1/lesson_v1.pdf',
      pdfChecksum: 'abc',
      pdfHistory: [],
    },
  })
})

afterAll(async () => {
  await prisma.$disconnect()
})

beforeEach(() => {
  mockDeleteObject.mockClear()
})

describe('DELETE /api/lessons/[id]/file', () => {
  it('hard-deletes the audio file from MinIO when deleting audio', async () => {
    await prisma.lesson.update({ where: { id: 1 }, data: { audioActive: 'lessons/1/audio_v1.mp3', audioChecksum: 'def' } })
    const req = await makeDeleteRequest(1, 'audio')
    await deleteFile(req, { params: Promise.resolve({ id: '1' }) })
    expect(mockDeleteObject).toHaveBeenCalledWith('lessons/1/audio_v1.mp3')
  })

  it('hard-deletes the pdf file from MinIO when deleting pdf', async () => {
    await prisma.lesson.update({ where: { id: 1 }, data: { pdfActive: 'lessons/1/lesson_v1.pdf', pdfChecksum: 'abc' } })
    const req = await makeDeleteRequest(1, 'pdf')
    await deleteFile(req, { params: Promise.resolve({ id: '1' }) })
    expect(mockDeleteObject).toHaveBeenCalledWith('lessons/1/lesson_v1.pdf')
  })

  it('does not call deleteObject when active path is already null', async () => {
    await prisma.lesson.update({ where: { id: 1 }, data: { audioActive: null, audioChecksum: null } })
    const req = await makeDeleteRequest(1, 'audio')
    await deleteFile(req, { params: Promise.resolve({ id: '1' }) })
    expect(mockDeleteObject).not.toHaveBeenCalled()
  })

  it('clears audioActive in the database when deleting audio', async () => {
    const req = await makeDeleteRequest(1, 'audio')
    const res = await deleteFile(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(200)

    const lesson = await prisma.lesson.findUnique({ where: { id: 1 } })
    expect(lesson?.audioActive).toBeNull()
    expect(lesson?.audioChecksum).toBeNull()
  })

  it('clears pdfActive in the database when deleting pdf', async () => {
    await prisma.lesson.update({ where: { id: 1 }, data: { pdfActive: 'lessons/1/lesson_v1.pdf', pdfChecksum: 'abc' } })
    const req = await makeDeleteRequest(1, 'pdf')
    const res = await deleteFile(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(200)

    const lesson = await prisma.lesson.findUnique({ where: { id: 1 } })
    expect(lesson?.pdfActive).toBeNull()
    expect(lesson?.pdfChecksum).toBeNull()
  })
})
