/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent } from '@testing-library/react'
import { LessonRow } from '@/components/lessons/LessonRow'

const baseLesson = {
  id: 1,
  title: 'Qual o Fim principal?',
  published: false,
  audio: { active: null as string | null, ext: 'mp3', checksum: '', history: [] as string[] },
  pdf: { active: null as string | null, checksum: '', history: [] as string[] },
}

const handlers = {
  onUpload: jest.fn(),
  onDelete: jest.fn(),
  onPreview: jest.fn(),
  onTitleSave: jest.fn(),
  onPublishToggle: jest.fn(),
}

beforeAll(() => {
  window.HTMLMediaElement.prototype.play = jest.fn().mockResolvedValue(undefined)
  window.HTMLMediaElement.prototype.pause = jest.fn()
})

describe('LessonRow — publish toggle', () => {
  it('shows "Publicar" button when lesson is unpublished', () => {
    render(<LessonRow lesson={baseLesson} {...handlers} />)
    expect(screen.getByRole('button', { name: /publicar/i })).toBeInTheDocument()
  })

  it('shows "Despublicar" button when lesson is published', () => {
    const publishedLesson = { ...baseLesson, published: true }
    render(<LessonRow lesson={publishedLesson} {...handlers} />)
    expect(screen.getByRole('button', { name: /despublicar/i })).toBeInTheDocument()
  })

  it('calls onPublishToggle with correct args when clicking publish', () => {
    render(<LessonRow lesson={baseLesson} {...handlers} />)
    fireEvent.click(screen.getByRole('button', { name: /publicar/i }))
    expect(handlers.onPublishToggle).toHaveBeenCalledWith(1, true)
  })

  it('calls onPublishToggle with correct args when clicking despublicar', () => {
    const publishedLesson = { ...baseLesson, published: true }
    render(<LessonRow lesson={publishedLesson} {...handlers} />)
    fireEvent.click(screen.getByRole('button', { name: /despublicar/i }))
    expect(handlers.onPublishToggle).toHaveBeenCalledWith(1, false)
  })
})
