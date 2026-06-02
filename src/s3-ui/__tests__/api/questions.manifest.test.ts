/**
 * @jest-environment node
 */
import { PATCH as togglePublish } from '@/app/api/lessons/[id]/publish/route'
import { POST } from '@/app/api/lessons/[id]/questions/route'
import { PATCH, DELETE } from '@/app/api/lessons/[id]/questions/[qid]/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'
import { getObjectText, uploadObject } from '@/lib/minio'

jest.mock('@/lib/minio', () => ({
  getObjectText: jest.fn(),
  uploadObject: jest.fn().mockResolvedValue(undefined),
}))

const mockGetObjectText = getObjectText as jest.Mock
const mockUploadObject = uploadObject as jest.Mock

const LESSON_ID = 2

async function makeAuthRequest(method: string, url: string, body?: object): Promise<NextRequest> {
  const token = await signToken({ id: 1, username: 'victor', isAdmin: true, mustChangePassword: false })
  const req = new NextRequest(url, {
    method,
    body: body ? JSON.stringify(body) : undefined,
    headers: { 'Content-Type': 'application/json' },
  })
  req.cookies.set(TOKEN_COOKIE, token)
  return req
}

beforeAll(async () => {
  await prisma.lesson.upsert({
    where: { id: LESSON_ID },
    update: { title: 'Lição com Q&As', published: false, pdfActive: 'lessons/2/lesson_v1.pdf', pdfChecksum: 'abc', pdfHistory: [] },
    create: { id: LESSON_ID, title: 'Lição com Q&As', published: false, pdfActive: 'lessons/2/lesson_v1.pdf', pdfChecksum: 'abc', pdfHistory: [] },
  })
  await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
  await prisma.question.createMany({
    data: [
      { lessonId: LESSON_ID, question: 'Pergunta 1?', answer: 'Resposta 1.', order: 1 },
      { lessonId: LESSON_ID, question: 'Pergunta 2?', answer: 'Resposta 2.', order: 2 },
      { lessonId: LESSON_ID, question: 'Deletada?', answer: 'Deletada.', order: 3, deletedAt: new Date() },
    ],
  })
})

afterAll(async () => {
  await prisma.questionAuditLog.deleteMany({ where: { lessonId: LESSON_ID } })
  await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
  await prisma.lesson.update({ where: { id: LESSON_ID }, data: { published: false } })
  await prisma.$disconnect()
})

describe('PATCH /api/lessons/[id]/publish — Q&As no manifest', () => {
  beforeEach(() => {
    mockGetObjectText.mockReset()
    mockUploadObject.mockReset()
    mockUploadObject.mockResolvedValue(undefined)
    mockGetObjectText.mockResolvedValue(
      JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [] }),
    )
  })

  it('ao publicar, inclui apenas Q&As ativas no manifest', async () => {
    await prisma.lesson.update({ where: { id: LESSON_ID }, data: { published: false } })
    await prisma.question.updateMany({ where: { lessonId: LESSON_ID, question: 'Deletada?' }, data: { deletedAt: new Date() } })
    // Restore active questions
    await prisma.question.updateMany({
      where: { lessonId: LESSON_ID, question: { not: 'Deletada?' } },
      data: { deletedAt: null },
    })

    const req = await makeAuthRequest('PATCH', `http://localhost/api/lessons/${LESSON_ID}/publish`, { published: true })
    const res = await togglePublish(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(200)

    const writtenManifest = JSON.parse(
      (mockUploadObject.mock.calls[0][1] as Buffer).toString('utf-8'),
    )
    const lessonEntry = writtenManifest.lessons.find((lesson: { id: number }) => lesson.id === LESSON_ID)
    expect(lessonEntry).toBeDefined()
    expect(lessonEntry.questions).toHaveLength(2)
    expect(lessonEntry.questions[0]).toEqual({ id: expect.any(Number), q: 'Pergunta 1?', a: 'Resposta 1.' })
    expect(lessonEntry.questions[1]).toEqual({ id: expect.any(Number), q: 'Pergunta 2?', a: 'Resposta 2.' })
  })

  it('ao publicar lição sem Q&As, inclui questions: [] no manifest', async () => {
    await prisma.question.updateMany({ where: { lessonId: LESSON_ID }, data: { deletedAt: new Date() } })

    const req = await makeAuthRequest('PATCH', `http://localhost/api/lessons/${LESSON_ID}/publish`, { published: true })
    const res = await togglePublish(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(200)

    const writtenManifest = JSON.parse(
      (mockUploadObject.mock.calls[0][1] as Buffer).toString('utf-8'),
    )
    const lessonEntry = writtenManifest.lessons.find((lesson: { id: number }) => lesson.id === LESSON_ID)
    expect(lessonEntry.questions).toEqual([])
  })

  it('criar Q&A em lição publicada atualiza o manifest', async () => {
    await prisma.lesson.update({ where: { id: LESSON_ID }, data: { published: true } })
    mockGetObjectText.mockResolvedValue(
      JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [
        { id: LESSON_ID, title: 'Lição com Q&As', pdf: { active: 'lessons/2/lesson_v1.pdf', checksum: 'abc', history: [] }, audio: null, questions: [] },
      ]}),
    )

    const req = await makeAuthRequest('POST', `http://localhost/api/lessons/${LESSON_ID}/questions`, {
      question: 'Nova pergunta?', answer: 'Nova resposta.',
    })
    const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(201)
    expect(mockUploadObject).toHaveBeenCalled()
  })

  it('editar Q&A em lição publicada atualiza o manifest', async () => {
    await prisma.lesson.update({ where: { id: LESSON_ID }, data: { published: true } })
    const question = await prisma.question.findFirst({ where: { lessonId: LESSON_ID, deletedAt: null } })
    if (!question) throw new Error('No active question found')

    mockUploadObject.mockReset()
    mockUploadObject.mockResolvedValue(undefined)
    mockGetObjectText.mockResolvedValue(
      JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [
        { id: LESSON_ID, title: 'Lição com Q&As', pdf: { active: 'lessons/2/lesson_v1.pdf', checksum: 'abc', history: [] }, audio: null, questions: [] },
      ]}),
    )

    const req = await makeAuthRequest(
      'PATCH',
      `http://localhost/api/lessons/${LESSON_ID}/questions/${question.id}`,
      { answer: 'Resposta atualizada.' },
    )
    const res = await PATCH(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: String(question.id) }) })
    expect(res.status).toBe(200)
    expect(mockUploadObject).toHaveBeenCalled()
  })

  it('deletar Q&A em lição publicada atualiza o manifest', async () => {
    await prisma.lesson.update({ where: { id: LESSON_ID }, data: { published: true } })
    const question = await prisma.question.create({
      data: { lessonId: LESSON_ID, question: 'Para deletar?', answer: 'Resposta.', order: 99 },
    })

    mockUploadObject.mockReset()
    mockUploadObject.mockResolvedValue(undefined)
    mockGetObjectText.mockResolvedValue(
      JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [
        { id: LESSON_ID, title: 'Lição com Q&As', pdf: { active: 'lessons/2/lesson_v1.pdf', checksum: 'abc', history: [] }, audio: null, questions: [] },
      ]}),
    )

    const req = await makeAuthRequest(
      'DELETE',
      `http://localhost/api/lessons/${LESSON_ID}/questions/${question.id}`,
    )
    const res = await DELETE(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: String(question.id) }) })
    expect(res.status).toBe(204)
    expect(mockUploadObject).toHaveBeenCalled()
  })
})
