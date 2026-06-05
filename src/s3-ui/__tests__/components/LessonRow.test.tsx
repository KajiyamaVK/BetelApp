/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent } from '@testing-library/react'
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

describe('LessonRow', () => {
  it('renders lesson order (display number) and title', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    expect(screen.getByText('3')).toBeInTheDocument()
    expect(screen.getByText('Qual o Fim principal?')).toBeInTheDocument()
  })

  it('shows warning badges when both files absent', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    const badges = screen.getAllByText('⚠')
    expect(badges.length).toBeGreaterThanOrEqual(2)
  })

  it('expands on click showing file rows', () => {
    render(<LessonRow uploadingKey={null} lesson={baseLesson} {...handlers} />)
    fireEvent.click(screen.getByText('Qual o Fim principal?'))
    expect(screen.getByText(/Nenhum áudio/)).toBeInTheDocument()
    expect(screen.getByText(/Nenhum PDF/)).toBeInTheDocument()
  })

  it('shows success badge when audio present', () => {
    const lesson = {
      ...baseLesson,
      audio: { active: 'lessons/1/audio_v1.mp3', ext: 'mp3', checksum: 'abc', history: [] as string[] },
    }
    render(<LessonRow uploadingKey={null} lesson={lesson} {...handlers} />)
    expect(screen.getAllByText('✓').length).toBeGreaterThanOrEqual(1)
  })
})
