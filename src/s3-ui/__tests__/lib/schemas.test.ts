import { loginSchema, createUserSchema, uploadQuerySchema, updateTitleSchema } from '@/lib/schemas'

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
  it('accepts valid user', () => {
    const input = { username: 'ana', password: 'pass123', isAdmin: false }
    expect(createUserSchema.safeParse(input).success).toBe(true)
  })
  it('rejects password shorter than 6 chars', () => {
    expect(createUserSchema.safeParse({ username: 'ana', password: '123', isAdmin: false }).success).toBe(false)
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
