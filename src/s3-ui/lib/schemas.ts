import { z } from 'zod'

export const loginSchema = z.object({
  username: z.string().min(1, 'Username required'),
  password: z.string().min(1, 'Password required'),
})

export const createUserSchema = z.object({
  username: z.string().min(1, 'Username required'),
  isAdmin: z.boolean(),
})

export const uploadQuerySchema = z.object({
  type: z.enum(['audio', 'pdf']),
})

export const updateTitleSchema = z.object({
  title: z.string().min(1, 'Title required'),
})

export const togglePublishSchema = z.object({
  published: z.boolean(),
})

export const createLessonSchema = z.object({
  id: z.number().int().positive('Lesson number must be a positive integer'),
  title: z.string().min(1, 'Title required'),
})
