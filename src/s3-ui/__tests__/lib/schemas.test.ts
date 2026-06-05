import { loginSchema, createUserSchema, uploadQuerySchema, updateTitleSchema, updateLessonSchema } from '@/lib/schemas'

describe('loginSchema', () => {
  it('accepts valid credentials', () => {
    expect(loginSchema.safeParse({ username: 'victor', password: 'abc123' }).success).toBe(true)
  })
  it('rejects empty username', () => {
    expect(loginSchema.safeParse({ username: '', password: 'abc123' }).success).toBe(false)
  })
  it('rejects empty password', () => {
    expect(loginSchema.safeParse({ username: 'victor', password: '' }).success).toBe(false)
  })
})

describe('createUserSchema', () => {
  it('accepts valid user without password (password is always 123456 by default)', () => {
    expect(createUserSchema.safeParse({ username: 'ana', isAdmin: false }).success).toBe(true)
  })
  it('rejects empty username', () => {
    expect(createUserSchema.safeParse({ username: '', isAdmin: false }).success).toBe(false)
  })
  it('accepts extra password field and strips it (Zod strips unknown keys)', () => {
    const result = createUserSchema.safeParse({ username: 'ana', password: 'ignored', isAdmin: false })
    expect(result.success).toBe(true)
    if (result.success) expect((result.data as Record<string, unknown>).password).toBeUndefined()
  })
})

describe('uploadQuerySchema', () => {
  it('accepts audio', () => {
    expect(uploadQuerySchema.safeParse({ type: 'audio' }).success).toBe(true)
  })
  it('accepts pdf', () => {
    expect(uploadQuerySchema.safeParse({ type: 'pdf' }).success).toBe(true)
  })
  it('rejects unknown type', () => {
    expect(uploadQuerySchema.safeParse({ type: 'video' }).success).toBe(false)
  })
})

describe('updateTitleSchema', () => {
  it('accepts non-empty title', () => {
    expect(updateTitleSchema.safeParse({ title: 'Lesson 1' }).success).toBe(true)
  })
  it('rejects empty title', () => {
    expect(updateTitleSchema.safeParse({ title: '' }).success).toBe(false)
  })
})

describe('updateLessonSchema', () => {
  it('accepts title only', () => {
    expect(updateLessonSchema.safeParse({ title: 'Lesson 1' }).success).toBe(true)
  })
  it('accepts order only', () => {
    expect(updateLessonSchema.safeParse({ order: 3 }).success).toBe(true)
  })
  it('accepts both title and order', () => {
    expect(updateLessonSchema.safeParse({ title: 'Lesson 1', order: 3 }).success).toBe(true)
  })
  it('rejects empty title', () => {
    expect(updateLessonSchema.safeParse({ title: '' }).success).toBe(false)
  })
  it('rejects negative order', () => {
    expect(updateLessonSchema.safeParse({ order: -1 }).success).toBe(false)
  })
  it('rejects non-integer order', () => {
    expect(updateLessonSchema.safeParse({ order: 1.5 }).success).toBe(false)
  })
  it('rejects empty object (at least one field required)', () => {
    expect(updateLessonSchema.safeParse({}).success).toBe(false)
  })
})
