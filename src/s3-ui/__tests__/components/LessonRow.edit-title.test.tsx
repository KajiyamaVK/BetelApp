/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { LessonRow } from '@/components/lessons/LessonRow'

const baseLesson = {
  id: 1,
  order: 3,
  title: 'Qual o Fim principal?',
  published: false,
  audio: { active: null as string | null, ext: 'mp3', checksum: '', history: [] as string[] },
  pdf: { active: null as string | null, checksum: '', history: [] as string[] },
}

const handlers = {
  isAdmin: true,
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
  global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => [] } as Response)
})

describe('LessonRow — edit lesson button', () => {
  it('renders a pencil button alongside publish and delete buttons', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    expect(screen.getByTestId('edit-lesson-btn')).toBeInTheDocument()
  })

  it('clicking the pencil button opens the edit dialog', async () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    fireEvent.click(screen.getByTestId('edit-lesson-btn'))
    await waitFor(() => expect(screen.getByRole('dialog')).toBeInTheDocument())
  })

  it('dialog pre-fills title and order from the lesson', async () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    fireEvent.click(screen.getByTestId('edit-lesson-btn'))
    await waitFor(() => {
      expect(screen.getByDisplayValue('Qual o Fim principal?')).toBeInTheDocument()
      expect(screen.getByDisplayValue('3')).toBeInTheDocument()
    })
  })

  it('calls onLessonSave with updated title and order on save', async () => {
    const onLessonSave = jest.fn().mockResolvedValue(null)
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} onLessonSave={onLessonSave} />)
    fireEvent.click(screen.getByTestId('edit-lesson-btn'))
    await waitFor(() => screen.getByRole('dialog'))

    const titleInput = screen.getByDisplayValue('Qual o Fim principal?')
    fireEvent.change(titleInput, { target: { value: 'Novo Título' } })

    const orderInput = screen.getByDisplayValue('3')
    fireEvent.change(orderInput, { target: { value: '5' } })

    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))
    expect(onLessonSave).toHaveBeenCalledWith(1, 'Novo Título', 5)
  })

  it('does not call onLessonSave when nothing changes and save is clicked', async () => {
    const onLessonSave = jest.fn().mockResolvedValue(null)
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} onLessonSave={onLessonSave} />)
    fireEvent.click(screen.getByTestId('edit-lesson-btn'))
    await waitFor(() => screen.getByRole('dialog'))
    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))
    expect(onLessonSave).not.toHaveBeenCalled()
  })

  it('keeps dialog open and shows error message when onLessonSave returns an error', async () => {
    const onLessonSave = jest.fn().mockResolvedValue('Esse número de lição já está em uso')
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} onLessonSave={onLessonSave} />)
    fireEvent.click(screen.getByTestId('edit-lesson-btn'))
    await waitFor(() => screen.getByRole('dialog'))

    const orderInput = screen.getByDisplayValue('3')
    fireEvent.change(orderInput, { target: { value: '5' } })
    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))

    await waitFor(() => expect(screen.getByText('Esse número de lição já está em uso')).toBeInTheDocument())
    expect(screen.getByRole('dialog')).toBeInTheDocument()
  })

  it('closes dialog on cancel without calling onLessonSave', async () => {
    const onLessonSave = jest.fn().mockResolvedValue(null)
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} onLessonSave={onLessonSave} />)
    fireEvent.click(screen.getByTestId('edit-lesson-btn'))
    await waitFor(() => screen.getByRole('dialog'))
    fireEvent.click(screen.getByRole('button', { name: /cancelar/i }))
    expect(onLessonSave).not.toHaveBeenCalled()
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
  })
})
