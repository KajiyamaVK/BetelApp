export interface Content {
  id: number
  slug: string
  title: string
  type: 'VIDEO' | 'TEXT'
  youtubeUrl: string | null
  htmlPath: string | null
  published: boolean
  order: number
  pageCount?: number
}

export interface Lesson {
  id: number
  order: number
  title: string
  published: boolean
  audio: { active: string | null; ext: string; checksum: string; history: string[] }
  pdf: { active: string | null; checksum: string; history: string[] }
}

export interface User {
  id: number
  username: string
  isAdmin: boolean
  mustChangePassword: boolean
  createdAt: string
}
