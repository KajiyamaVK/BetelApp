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

export const updateLessonSchema = z.object({
  title: z.string().min(1, 'Title required').optional(),
  order: z.number().int().nonnegative('Order must be a non-negative integer').optional(),
}).refine(
  (data) => data.title !== undefined || data.order !== undefined,
  { message: 'At least one field (title or order) is required' },
)

export const togglePublishSchema = z.object({
  published: z.boolean(),
})

export const createLessonSchema = z.object({
  id: z.number().int().min(0, 'Lesson number must be a non-negative integer'),
  title: z.string().min(1, 'Title required'),
})

export const createQuestionSchema = z.object({
  question: z.string().min(1, 'Pergunta obrigatória'),
  answer: z.string().min(1, 'Resposta obrigatória'),
  order: z.number().int().nonnegative().optional(),
})

export const updateQuestionSchema = z.object({
  question: z.string().min(1).optional(),
  answer: z.string().min(1).optional(),
  order: z.number().int().nonnegative().optional(),
}).refine(
  (data) => Object.keys(data).length > 0,
  { message: 'At least one field required' },
)

/** Generates a URL-safe slug from a title: strips accents, lowercases, replaces spaces with dashes */
export function slugify(title: string): string {
  return title
    .normalize('NFD')                       // decompose accents (é → e + combining accent)
    .replace(/[̀-ͯ]/g, '')        // strip combining diacritical marks
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')           // remove non-alphanumeric except spaces and dashes
    .replace(/\s+/g, '-')                   // spaces → dashes
    .replace(/-+/g, '-')                    // collapse consecutive dashes
    .replace(/^-|-$/g, '')                  // trim leading/trailing dashes
}

const CONTENT_LOCATIONS = ['HOME', 'HELP_DEVOCIONAIS', 'HELP_MUSICAS', 'HELP_REVISOES', 'HELP_FAVORITOS'] as const

export const createContentSchema = z.discriminatedUnion('type', [
  z.object({
    title: z.string().min(1, 'Título obrigatório'),
    type: z.literal('VIDEO'),
    youtubeUrl: z.string().url('URL inválida').min(1, 'URL do YouTube obrigatória'),
    order: z.number().int().nonnegative().optional(),
    displayLocation: z.enum(CONTENT_LOCATIONS).optional(),
  }),
  z.object({
    title: z.string().min(1, 'Título obrigatório'),
    type: z.literal('TEXT'),
    order: z.number().int().nonnegative().optional(),
    displayLocation: z.enum(CONTENT_LOCATIONS).optional(),
  }),
])

export const updateContentSchema = z.object({
  title: z.string().min(1).optional(),
  youtubeUrl: z.string().url().optional(),
  order: z.number().int().nonnegative().optional(),
  displayLocation: z.enum(CONTENT_LOCATIONS).optional(),
}).refine(
  (data) => Object.keys(data).length > 0,
  { message: 'At least one field required' },
)
