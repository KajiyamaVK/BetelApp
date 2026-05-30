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
  pdf: { active: 'lessons/1/lesson_v1.pdf', checksum: 'abc', history: [] as string[] },
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

beforeEach(() => {
  jest.clearAllMocks()
})

describe('LessonRow — publish toggle', () => {
  it('shows "Publicar" button when lesson is unpublished', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    expect(screen.getByRole('button', { name: /publicar/i })).toBeInTheDocument()
  })

  it('shows "Despublicar" button when lesson is published', () => {
    const publishedLesson = { ...baseLesson, published: true }
    render(<LessonRow uploadingKey={null} lesson={publishedLesson} {...handlers} />)
    expect(screen.getByRole('button', { name: /despublicar/i })).toBeInTheDocument()
  })

  it('opens confirmation dialog on publish click without calling onPublishToggle', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    fireEvent.click(screen.getByRole('button', { name: /publicar/i }))
    expect(screen.getByRole('alertdialog')).toBeInTheDocument()
    expect(handlers.onPublishToggle).not.toHaveBeenCalled()
  })

  it('opens confirmation dialog on despublicar click without calling onPublishToggle', () => {
    const publishedLesson = { ...baseLesson, published: true }
    render(<LessonRow uploadingKey={null} lesson={publishedLesson} {...handlers} />)
    fireEvent.click(screen.getByRole('button', { name: /despublicar/i }))
    expect(screen.getByRole('alertdialog')).toBeInTheDocument()
    expect(handlers.onPublishToggle).not.toHaveBeenCalled()
  })

  it('calls onPublishToggle with correct args after confirming publish', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    fireEvent.click(screen.getByRole('button', { name: /publicar/i }))
    fireEvent.click(screen.getByRole('button', { name: /confirmar/i }))
    expect(handlers.onPublishToggle).toHaveBeenCalledWith(1, true)
  })

  it('calls onPublishToggle with correct args after confirming despublicar', () => {
    const publishedLesson = { ...baseLesson, published: true }
    render(<LessonRow uploadingKey={null} lesson={publishedLesson} {...handlers} />)
    fireEvent.click(screen.getByRole('button', { name: /despublicar/i }))
    fireEvent.click(screen.getByRole('button', { name: /confirmar/i }))
    expect(handlers.onPublishToggle).toHaveBeenCalledWith(1, false)
  })

  it('does not call onPublishToggle when dialog is cancelled', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    fireEvent.click(screen.getByRole('button', { name: /publicar/i }))
    fireEvent.click(screen.getByRole('button', { name: /cancelar/i }))
    expect(handlers.onPublishToggle).not.toHaveBeenCalled()
  })
})
