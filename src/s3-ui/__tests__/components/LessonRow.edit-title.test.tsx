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
  isAdmin: true,
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
  global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => [] } as Response)
})

describe('LessonRow — edit title button', () => {
  it('renders a pencil button visible alongside publish and delete buttons', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    expect(screen.getByTestId('edit-title-btn')).toBeInTheDocument()
  })

  it('clicking the pencil button activates inline title editing', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    fireEvent.click(screen.getByTestId('edit-title-btn'))
    expect(screen.getByDisplayValue('Qual o Fim principal?')).toBeInTheDocument()
  })

  it('saves the new title when Enter is pressed', () => {
    const onTitleSave = jest.fn()
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} onTitleSave={onTitleSave} />)
    fireEvent.click(screen.getByTestId('edit-title-btn'))
    const input = screen.getByDisplayValue('Qual o Fim principal?')
    fireEvent.change(input, { target: { value: 'Novo Título' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    expect(onTitleSave).toHaveBeenCalledWith(1, 'Novo Título')
  })

  it('does not call onTitleSave when title is unchanged', () => {
    const onTitleSave = jest.fn()
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} onTitleSave={onTitleSave} />)
    fireEvent.click(screen.getByTestId('edit-title-btn'))
    const input = screen.getByDisplayValue('Qual o Fim principal?')
    fireEvent.keyDown(input, { key: 'Enter' })
    expect(onTitleSave).not.toHaveBeenCalled()
  })
})
