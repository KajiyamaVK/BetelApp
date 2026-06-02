/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent } from '@testing-library/react'
import { MiniPlayer } from '@/components/lessons/MiniPlayer'

const src = 'https://s3.kajiyama.com.br/betelapp-content/lessons/1/audio_v1.mp3'

beforeAll(() => {
  window.HTMLMediaElement.prototype.play = jest.fn().mockResolvedValue(undefined)
  window.HTMLMediaElement.prototype.pause = jest.fn()
})

describe('MiniPlayer', () => {
  it('renders a play button', () => {
    render(<MiniPlayer src={src} />)
    expect(screen.getByRole('button', { name: /play/i })).toBeInTheDocument()
  })

  it('shows 0:00 / 0:00 initially', () => {
    render(<MiniPlayer src={src} />)
    expect(screen.getByText('0:00 / 0:00')).toBeInTheDocument()
  })

  it('toggles aria-label on click', () => {
    render(<MiniPlayer src={src} />)
    const btn = screen.getByRole('button', { name: /play/i })
    fireEvent.click(btn)
    expect(screen.getByRole('button', { name: /pause/i })).toBeInTheDocument()
  })
})
