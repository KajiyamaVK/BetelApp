/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent } from '@testing-library/react'
import { LessonRow } from '@/components/lessons/LessonRow'

const handlers = {
  isAdmin: false,
  onUpload: jest.fn(),
  onDelete: jest.fn(),
  onDeleteLesson: jest.fn(),
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

const publishedLessonWithPdf = {
  id: 1,
  title: 'Lição publicada com PDF',
  published: true,
  audio: { active: null as string | null, ext: 'mp3', checksum: '', history: [] as string[] },
  pdf: { active: 'lessons/1/lesson_v1.pdf', checksum: 'abc', history: [] as string[] },
}

describe('LessonRow — aviso ao deletar PDF de lição publicada', () => {
  it('shows unpublish warning dialog when deleting pdf of a published lesson', () => {
    render(<LessonRow uploadingKey={null} lesson={publishedLessonWithPdf} {...handlers} />)
    fireEvent.click(screen.getByText('Lição publicada com PDF'))
    fireEvent.click(screen.getByLabelText('Delete pdf'))
    expect(screen.getByRole('alertdialog')).toBeInTheDocument()
    expect(screen.getByText(/despublicada/i)).toBeInTheDocument()
  })

  it('calls onDelete and onPublishToggle(false) after confirming pdf delete on published lesson', () => {
    render(<LessonRow uploadingKey={null} lesson={publishedLessonWithPdf} {...handlers} />)
    fireEvent.click(screen.getByText('Lição publicada com PDF'))
    fireEvent.click(screen.getByLabelText('Delete pdf'))
    fireEvent.click(screen.getByRole('button', { name: /confirmar/i }))
    expect(handlers.onDelete).toHaveBeenCalledWith(1, 'pdf')
    expect(handlers.onPublishToggle).toHaveBeenCalledWith(1, false)
  })

  it('does not call onDelete when cancelling the unpublish warning', () => {
    render(<LessonRow uploadingKey={null} lesson={publishedLessonWithPdf} {...handlers} />)
    fireEvent.click(screen.getByText('Lição publicada com PDF'))
    fireEvent.click(screen.getByLabelText('Delete pdf'))
    fireEvent.click(screen.getByRole('button', { name: /cancelar/i }))
    expect(handlers.onDelete).not.toHaveBeenCalled()
    expect(handlers.onPublishToggle).not.toHaveBeenCalled()
  })

  it('does not show unpublish warning when deleting pdf of an unpublished lesson', () => {
    const unpublishedLesson = { ...publishedLessonWithPdf, published: false }
    render(<LessonRow uploadingKey={null} lesson={unpublishedLesson} {...handlers} />)
    fireEvent.click(screen.getByText('Lição publicada com PDF'))
    fireEvent.click(screen.getByLabelText('Delete pdf'))
    // The regular delete dialog (from the parent page) handles this — LessonRow just calls onDelete
    expect(handlers.onDelete).toHaveBeenCalledWith(1, 'pdf')
  })
})
