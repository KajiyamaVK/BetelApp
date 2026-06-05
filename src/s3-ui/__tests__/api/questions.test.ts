/**
 * @jest-environment node
 */
import { GET, POST } from '@/app/api/lessons/[id]/questions/route'
import { PATCH, DELETE } from '@/app/api/lessons/[id]/questions/[qid]/route'
import { prisma } from '@/lib/prisma'
import { signToken, TOKEN_COOKIE } from '@/lib/auth'
import { NextRequest } from 'next/server'
import { uploadObject } from '@/lib/minio'

jest.mock('@/lib/minio', () => ({
  getObjectText: jest.fn().mockResolvedValue(
    JSON.stringify({ version: 1, updated_at: '2024-01-01T00:00:00Z', lessons: [] }),
  ),
  uploadObject: jest.fn().mockResolvedValue(undefined),
}))

const mockUploadObject = uploadObject as jest.Mock

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

const LESSON_ID = 1

beforeEach(() => {
  mockUploadObject.mockReset()
  mockUploadObject.mockResolvedValue(undefined)
})

beforeAll(async () => {
  await prisma.lesson.upsert({
    where: { id: LESSON_ID },
    update: { title: 'Test Lesson' },
    create: { id: LESSON_ID, title: 'Test Lesson' },
  })
  await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
})

afterAll(async () => {
  await prisma.questionAuditLog.deleteMany({ where: { lessonId: LESSON_ID } })
  await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
  await prisma.$disconnect()
})

describe('GET /api/lessons/[id]/questions', () => {
  it('returns empty array when no questions exist', async () => {
    const req = await makeAuthRequest('GET', `http://localhost/api/lessons/${LESSON_ID}/questions`)
    const res = await GET(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(data).toEqual([])
  })

  it('returns only active (non-deleted) questions ordered by order asc', async () => {
    await prisma.question.createMany({
      data: [
        { lessonId: LESSON_ID, question: 'Q1', answer: 'A1', order: 1 },
        { lessonId: LESSON_ID, question: 'Q2', answer: 'A2', order: 2 },
        { lessonId: LESSON_ID, question: 'Q_deleted', answer: 'A_deleted', order: 3, deletedAt: new Date() },
      ],
    })
    const req = await makeAuthRequest('GET', `http://localhost/api/lessons/${LESSON_ID}/questions`)
    const res = await GET(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(data).toHaveLength(2)
    expect(data[0].question).toBe('Q1')
    expect(data[1].question).toBe('Q2')
  })

  it('returns 401 without token', async () => {
    const req = new NextRequest(`http://localhost/api/lessons/${LESSON_ID}/questions`, { method: 'GET' })
    const res = await GET(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(401)
  })
})

describe('POST /api/lessons/[id]/questions', () => {
  it('creates a question and returns it', async () => {
    const req = await makeAuthRequest('POST', `http://localhost/api/lessons/${LESSON_ID}/questions`, {
      question: 'Nova pergunta?',
      answer: 'Nova resposta.',
    })
    const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(201)
    const data = await res.json()
    expect(data.question).toBe('Nova pergunta?')
    expect(data.answer).toBe('Nova resposta.')
    expect(data.lessonId).toBe(LESSON_ID)
    expect(data.deletedAt).toBeNull()
  })

  it('returns 400 on missing question field', async () => {
    const req = await makeAuthRequest('POST', `http://localhost/api/lessons/${LESSON_ID}/questions`, {
      answer: 'Resposta sem pergunta.',
    })
    const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(400)
  })

  it('returns 401 without token', async () => {
    const req = new NextRequest(`http://localhost/api/lessons/${LESSON_ID}/questions`, {
      method: 'POST',
      body: JSON.stringify({ question: 'Q', answer: 'A' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(401)
  })

  it('assigns order as MAX(order)+1 of active questions, ignoring gaps from deletions', async () => {
    await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
    await prisma.question.createMany({
      data: [
        { lessonId: LESSON_ID, question: 'Q1', answer: 'A1', order: 0 },
        { lessonId: LESSON_ID, question: 'Q2', answer: 'A2', order: 1, deletedAt: new Date() },
        { lessonId: LESSON_ID, question: 'Q3', answer: 'A3', order: 2 },
      ],
    })
    const req = await makeAuthRequest('POST', `http://localhost/api/lessons/${LESSON_ID}/questions`, {
      question: 'Nova depois de gap',
      answer: 'Resposta.',
    })
    const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(201)
    const data = await res.json()
    expect(data.order).toBe(3)
  })

  it('assigns order 0 when no active questions exist', async () => {
    await prisma.question.deleteMany({ where: { lessonId: LESSON_ID } })
    const req = await makeAuthRequest('POST', `http://localhost/api/lessons/${LESSON_ID}/questions`, {
      question: 'Primeira pergunta',
      answer: 'Resposta.',
    })
    const res = await POST(req, { params: Promise.resolve({ id: String(LESSON_ID) }) })
    expect(res.status).toBe(201)
    const data = await res.json()
    expect(data.order).toBe(0)
  })
})

describe('PATCH /api/lessons/[id]/questions/[qid]', () => {
  let questionId: number

  beforeEach(async () => {
    const question = await prisma.question.create({
      data: { lessonId: LESSON_ID, question: 'Original?', answer: 'Original.', order: 10 },
    })
    questionId = question.id
  })

  afterEach(async () => {
    await prisma.question.deleteMany({ where: { id: questionId } })
  })

  it('updates question text', async () => {
    const req = await makeAuthRequest(
      'PATCH',
      `http://localhost/api/lessons/${LESSON_ID}/questions/${questionId}`,
      { question: 'Atualizada?' },
    )
    const res = await PATCH(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: String(questionId) }) })
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(data.question).toBe('Atualizada?')
    expect(data.answer).toBe('Original.')
  })

  it('returns 404 for non-existent question', async () => {
    const req = await makeAuthRequest(
      'PATCH',
      `http://localhost/api/lessons/${LESSON_ID}/questions/99999`,
      { question: 'X' },
    )
    const res = await PATCH(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: '99999' }) })
    expect(res.status).toBe(404)
  })

  it('returns 404 for a soft-deleted question', async () => {
    const softDeleted = await prisma.question.create({
      data: { lessonId: LESSON_ID, question: 'Soft deleted?', answer: 'Gone.', order: 99, deletedAt: new Date() },
    })
    const req = await makeAuthRequest(
      'PATCH',
      `http://localhost/api/lessons/${LESSON_ID}/questions/${softDeleted.id}`,
      { question: 'Try to update?' },
    )
    const res = await PATCH(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: String(softDeleted.id) }) })
    expect(res.status).toBe(404)
    await prisma.question.delete({ where: { id: softDeleted.id } })
  })
})

describe('DELETE /api/lessons/[id]/questions/[qid]', () => {
  let questionId: number

  beforeEach(async () => {
    const question = await prisma.question.create({
      data: { lessonId: LESSON_ID, question: 'Para deletar?', answer: 'Resposta deletada.', order: 20 },
    })
    questionId = question.id
  })

  it('soft-deletes the question and creates audit log', async () => {
    const req = await makeAuthRequest(
      'DELETE',
      `http://localhost/api/lessons/${LESSON_ID}/questions/${questionId}`,
    )
    const res = await DELETE(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: String(questionId) }) })
    expect(res.status).toBe(204)

    const deleted = await prisma.question.findUnique({ where: { id: questionId } })
    expect(deleted?.deletedAt).not.toBeNull()

    const auditLog = await prisma.questionAuditLog.findFirst({
      where: { questionId },
      orderBy: { deletedAt: 'desc' },
    })
    expect(auditLog).toBeDefined()
    expect(auditLog?.question).toBe('Para deletar?')
    expect(auditLog?.answer).toBe('Resposta deletada.')
    expect(auditLog?.deletedBy).toBe('victor')
  })

  it('returns 404 for non-existent question', async () => {
    const req = await makeAuthRequest(
      'DELETE',
      `http://localhost/api/lessons/${LESSON_ID}/questions/99999`,
    )
    const res = await DELETE(req, { params: Promise.resolve({ id: String(LESSON_ID), qid: '99999' }) })
    expect(res.status).toBe(404)
  })
})
