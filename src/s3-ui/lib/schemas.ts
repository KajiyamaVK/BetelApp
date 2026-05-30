import { z } from 'zod'

export const loginSchema = z.object({
  username: z.string().min(1, 'Username required'),
  password: z.string().min(1, 'Password required'),
})

export const createUserSchema = z.object({
  username: z.string().min(1, 'Username required'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
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
