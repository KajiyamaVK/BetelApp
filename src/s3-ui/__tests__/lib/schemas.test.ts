import { loginSchema, createUserSchema, uploadQuerySchema, updateTitleSchema, updateLessonSchema, createContentSchema, updateContentSchema, slugify } from '@/lib/schemas'

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

describe('createContentSchema', () => {
  it('accepts valid VIDEO content', () => {
    const result = createContentSchema.safeParse({
      slug: 'welcome-video', title: 'Bem-vindo', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=abc',
    })
    expect(result.success).toBe(true)
  })

  it('accepts valid TEXT content', () => {
    const result = createContentSchema.safeParse({
      slug: 'about-catechism', title: 'Sobre', type: 'TEXT',
    })
    expect(result.success).toBe(true)
  })

  it('rejects VIDEO without youtubeUrl', () => {
    const result = createContentSchema.safeParse({
      title: 'Test', type: 'VIDEO',
    })
    expect(result.success).toBe(false)
  })

  it('rejects empty title', () => {
    const result = createContentSchema.safeParse({
      title: '', type: 'TEXT',
    })
    expect(result.success).toBe(false)
  })

  it('rejects invalid type', () => {
    const result = createContentSchema.safeParse({
      title: 'Test', type: 'IMAGE',
    })
    expect(result.success).toBe(false)
  })

  it('accepts optional order field', () => {
    const result = createContentSchema.safeParse({
      title: 'Test', type: 'TEXT', order: 5,
    })
    expect(result.success).toBe(true)
  })
})

describe('updateContentSchema', () => {
  it('accepts title only', () => {
    expect(updateContentSchema.safeParse({ title: 'Updated' }).success).toBe(true)
  })

  it('accepts youtubeUrl only', () => {
    expect(updateContentSchema.safeParse({ youtubeUrl: 'https://youtube.com/watch?v=xyz' }).success).toBe(true)
  })

  it('accepts order only', () => {
    expect(updateContentSchema.safeParse({ order: 3 }).success).toBe(true)
  })

  it('rejects empty object', () => {
    expect(updateContentSchema.safeParse({}).success).toBe(false)
  })
})

describe('slugify', () => {
  it('converts title to lowercase with dashes', () => {
    expect(slugify('Bem Vindo ao Curso')).toBe('bem-vindo-ao-curso')
  })

  it('strips accents', () => {
    expect(slugify('Lição de Português')).toBe('licao-de-portugues')
  })

  it('removes special characters', () => {
    expect(slugify('Hello, World! (2024)')).toBe('hello-world-2024')
  })

  it('collapses consecutive dashes', () => {
    expect(slugify('foo - - bar')).toBe('foo-bar')
  })

  it('trims leading and trailing dashes', () => {
    expect(slugify('  -hello- ')).toBe('hello')
  })

  it('returns empty string for non-alphanumeric input', () => {
    expect(slugify('!@#$%')).toBe('')
  })
})
