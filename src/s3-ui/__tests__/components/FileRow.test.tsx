/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent } from '@testing-library/react'
import { FileRow } from '@/components/lessons/FileRow'

const baseProps = {
  lessonId: 1,
  type: 'audio' as const,
  active: null,
  onUpload: jest.fn(),
  onDelete: jest.fn(),
  onPreview: jest.fn(),
}

beforeAll(() => {
  window.HTMLMediaElement.prototype.play = jest.fn().mockResolvedValue(undefined)
  window.HTMLMediaElement.prototype.pause = jest.fn()
})

describe('FileRow — audio absent', () => {
  it('shows Upload button when no file', () => {
    render(<FileRow {...baseProps} />)
    expect(screen.getByRole('button', { name: /upload/i })).toBeInTheDocument()
  })

  it('does not show delete button when no file', () => {
    render(<FileRow {...baseProps} />)
    expect(screen.queryByRole('button', { name: /delete/i })).not.toBeInTheDocument()
  })
})

describe('FileRow — audio present', () => {
  const props = {
    ...baseProps,
    active: 'lessons/1/audio_v1.mp3',
  }

  it('shows MiniPlayer when audio active', () => {
    render(<FileRow {...props} />)
    expect(screen.getByRole('button', { name: /play/i })).toBeInTheDocument()
  })

  it('shows delete button', () => {
    render(<FileRow {...props} />)
    expect(screen.getByRole('button', { name: /delete/i })).toBeInTheDocument()
  })

  it('calls onDelete when delete clicked', () => {
    const onDelete = jest.fn()
    render(<FileRow {...props} onDelete={onDelete} />)
    fireEvent.click(screen.getByRole('button', { name: /delete/i }))
    expect(onDelete).toHaveBeenCalledWith(1, 'audio')
  })
})

describe('FileRow — pdf present', () => {
  const props = {
    ...baseProps,
    type: 'pdf' as const,
    active: 'lessons/1/lesson_v1.pdf',
  }

  it('shows pdf filename as clickable element', () => {
    render(<FileRow {...props} />)
    expect(screen.getByText('lesson_v1.pdf')).toBeInTheDocument()
  })

  it('calls onPreview when pdf filename clicked', () => {
    const onPreview = jest.fn()
    render(<FileRow {...props} onPreview={onPreview} />)
    fireEvent.click(screen.getByText('lesson_v1.pdf'))
    expect(onPreview).toHaveBeenCalledWith('lessons/1/lesson_v1.pdf')
  })
})
