/**
 * @jest-environment jsdom
 */
import { render, screen } from '@testing-library/react'
import { LessonRow } from '@/components/lessons/LessonRow'

const handlers = {
  isAdmin: false,
  onUpload: jest.fn(),
  onDelete: jest.fn(),
  onDeleteLesson: jest.fn(),
  onPreview: jest.fn(),
  onLessonSave: jest.fn().mockResolvedValue(null),
  onPublishToggle: jest.fn(),
}

beforeAll(() => {
  window.HTMLMediaElement.prototype.play = jest.fn().mockResolvedValue(undefined)
  window.HTMLMediaElement.prototype.pause = jest.fn()
  // QASection fetches questions on mount when the row is expanded.
  global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => [] } as Response)
})

describe('LessonRow — Publicar guard', () => {
  it('disables Publicar button when pdf is absent', () => {
    const lesson = {
      id: 1,
      order: 1,
      title: 'Lição sem PDF',
      published: false,
      audio: { active: null as string | null, ext: 'mp3', checksum: '', history: [] as string[] },
      pdf: { active: null as string | null, checksum: '', history: [] as string[] },
    }
    render(<LessonRow uploadingKey={null} lesson={lesson} {...handlers} />)
    const publishButton = screen.getByRole('button', { name: /Publicar/i })
    expect(publishButton).toBeDisabled()
  })

  it('enables Publicar button when pdf is present', () => {
    const lesson = {
      id: 2,
      order: 2,
      title: 'Lição com PDF',
      published: false,
      audio: { active: null as string | null, ext: 'mp3', checksum: '', history: [] as string[] },
      pdf: { active: 'lessons/2/lesson_v1.pdf', checksum: 'abc', history: [] as string[] },
    }
    render(<LessonRow uploadingKey={null} lesson={lesson} {...handlers} />)
    const publishButton = screen.getByRole('button', { name: /Publicar/i })
    expect(publishButton).not.toBeDisabled()
  })

  it('shows a tooltip hint when Publicar is disabled due to missing PDF', () => {
    const lesson = {
      id: 3,
      order: 3,
      title: 'Lição sem PDF',
      published: false,
      audio: { active: null as string | null, ext: 'mp3', checksum: '', history: [] as string[] },
      pdf: { active: null as string | null, checksum: '', history: [] as string[] },
    }
    render(<LessonRow uploadingKey={null} lesson={lesson} {...handlers} />)
    const publishButton = screen.getByRole('button', { name: /Publicar/i })
    expect(publishButton).toHaveAttribute('title')
  })
})
