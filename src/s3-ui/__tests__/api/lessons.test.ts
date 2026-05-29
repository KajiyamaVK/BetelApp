/**
 * @jest-environment node
 */
import { GET as getLessons } from '@/app/api/lessons/route'
import { PUT as updateTitle } from '@/app/api/lessons/[id]/route'
import { prisma } from '@/lib/prisma'
import { NextRequest } from 'next/server'

beforeAll(async () => {
  await prisma.lesson.upsert({
    where: { id: 1 },
    update: {},
    create: { id: 1, title: 'Test Lesson' },
  })
})

afterAll(async () => {
  await prisma.$disconnect()
})

describe('GET /api/lessons', () => {
  it('returns lessons array', async () => {
    const res = await getLessons()
    expect(res.status).toBe(200)
    const data = await res.json()
    expect(Array.isArray(data)).toBe(true)
  })
})

describe('PUT /api/lessons/[id]', () => {
  it('updates title successfully', async () => {
    const req = new NextRequest('http://localhost/api/lessons/1', {
      method: 'PUT',
      body: JSON.stringify({ title: 'Updated Title' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await updateTitle(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(200)
    const body = await res.json()
    expect(body.title).toBe('Updated Title')
  })

  it('returns 400 on empty title', async () => {
    const req = new NextRequest('http://localhost/api/lessons/1', {
      method: 'PUT',
      body: JSON.stringify({ title: '' }),
      headers: { 'Content-Type': 'application/json' },
    })
    const res = await updateTitle(req, { params: Promise.resolve({ id: '1' }) })
    expect(res.status).toBe(400)
  })
})
