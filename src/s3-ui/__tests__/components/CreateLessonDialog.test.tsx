/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { CreateLessonDialog } from '@/components/lessons/CreateLessonDialog'

const handlers = {
  onCreated: jest.fn(),
  onClose: jest.fn(),
}

beforeEach(() => {
  jest.clearAllMocks()
  global.fetch = jest.fn()
})

afterEach(() => {
  jest.restoreAllMocks()
})

function renderDialog(suggestedId = 5) {
  render(<CreateLessonDialog open={true} suggestedId={suggestedId} onCreated={handlers.onCreated} onClose={handlers.onClose} />)
}

describe('CreateLessonDialog', () => {
  it('renders the form with id pre-filled with suggestedId', () => {
    renderDialog(5)
    const idInput = screen.getByLabelText(/número/i) as HTMLInputElement
    expect(idInput.value).toBe('5')
  })

  it('allows editing the lesson id', () => {
    renderDialog(5)
    const idInput = screen.getByLabelText(/número/i) as HTMLInputElement
    fireEvent.change(idInput, { target: { value: '10' } })
    expect(idInput.value).toBe('10')
  })

  it('calls onClose when cancel button is clicked', () => {
    renderDialog(5)
    fireEvent.click(screen.getByRole('button', { name: /cancelar/i }))
    expect(handlers.onClose).toHaveBeenCalled()
  })

  it('shows error when trying to save without a title', async () => {
    renderDialog(5)
    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))
    expect(await screen.findByText(/título é obrigatório/i)).toBeInTheDocument()
    expect(handlers.onCreated).not.toHaveBeenCalled()
  })

  it('does not throw when lesson creation fails with empty response body', async () => {
    ;(global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 401,
      json: async () => { throw new SyntaxError('Unexpected end of JSON input') },
    })
    renderDialog(5)
    fireEvent.change(screen.getByLabelText(/título/i), { target: { value: 'Minha Lição' } })
    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))
    expect(await screen.findByText(/erro ao criar lição/i)).toBeInTheDocument()
    expect(handlers.onCreated).not.toHaveBeenCalled()
  })

  it('shows inline error message when id already exists (409)', async () => {
    ;(global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 409,
      json: async () => ({ error: 'Lição #5 já existe' }),
    })
    renderDialog(5)
    fireEvent.change(screen.getByLabelText(/título/i), { target: { value: 'Minha Lição' } })
    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))
    expect(await screen.findByText(/lição #5 já existe/i)).toBeInTheDocument()
    expect(handlers.onCreated).not.toHaveBeenCalled()
  })

  it('calls onCreated after successful save with no files', async () => {
    ;(global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      status: 201,
      json: async () => ({ id: 5, title: 'Minha Lição', published: false }),
    })
    renderDialog(5)
    fireEvent.change(screen.getByLabelText(/título/i), { target: { value: 'Minha Lição' } })
    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))
    await waitFor(() => expect(handlers.onCreated).toHaveBeenCalled())
  })

  it('uploads pdf after lesson creation when pdf file is selected', async () => {
    ;(global.fetch as jest.Mock)
      .mockResolvedValueOnce({ ok: true, status: 201, json: async () => ({ id: 5, title: 'Lição', published: false }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({}) })

    renderDialog(5)
    fireEvent.change(screen.getByLabelText(/título/i), { target: { value: 'Lição' } })

    const pdfInput = screen.getByLabelText(/pdf/i) as HTMLInputElement
    const pdfFile = new File(['content'], 'lesson.pdf', { type: 'application/pdf' })
    fireEvent.change(pdfInput, { target: { files: [pdfFile] } })

    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))
    await waitFor(() => expect(handlers.onCreated).toHaveBeenCalled())

    const uploadCall = (global.fetch as jest.Mock).mock.calls[1]
    expect(uploadCall[0]).toContain('/api/lessons/5/upload')
    expect(uploadCall[0]).toContain('type=pdf')
  })

  it('uploads audio after lesson creation when audio file is selected', async () => {
    ;(global.fetch as jest.Mock)
      .mockResolvedValueOnce({ ok: true, status: 201, json: async () => ({ id: 5, title: 'Lição', published: false }) })
      .mockResolvedValueOnce({ ok: true, json: async () => ({}) })

    renderDialog(5)
    fireEvent.change(screen.getByLabelText(/título/i), { target: { value: 'Lição' } })

    const audioInput = screen.getByLabelText(/áudio/i) as HTMLInputElement
    const audioFile = new File(['content'], 'audio.mp3', { type: 'audio/mpeg' })
    fireEvent.change(audioInput, { target: { files: [audioFile] } })

    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))
    await waitFor(() => expect(handlers.onCreated).toHaveBeenCalled())

    const uploadCall = (global.fetch as jest.Mock).mock.calls[1]
    expect(uploadCall[0]).toContain('type=audio')
  })

  it('onCreated is called only after pdf upload completes, not before', async () => {
    let resolveUpload!: () => void
    const uploadDone = new Promise<void>((resolve) => { resolveUpload = resolve })

    ;(global.fetch as jest.Mock)
      .mockResolvedValueOnce({ ok: true, status: 201, json: async () => ({ id: 5, title: 'Lição', published: false }) })
      .mockImplementationOnce(() => uploadDone.then(() => ({ ok: true, json: async () => ({}) })))

    renderDialog(5)
    fireEvent.change(screen.getByLabelText(/título/i), { target: { value: 'Lição' } })

    const pdfInput = screen.getByLabelText(/pdf/i) as HTMLInputElement
    const pdfFile = new File(['content'], 'lesson.pdf', { type: 'application/pdf' })
    fireEvent.change(pdfInput, { target: { files: [pdfFile] } })

    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))

    // onCreated must NOT be called while upload is still in flight
    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(handlers.onCreated).not.toHaveBeenCalled()

    // only after upload resolves should onCreated fire
    resolveUpload()
    await waitFor(() => expect(handlers.onCreated).toHaveBeenCalled())
  })

  it('onCreated is called only after audio upload completes, not before', async () => {
    let resolveUpload!: () => void
    const uploadDone = new Promise<void>((resolve) => { resolveUpload = resolve })

    ;(global.fetch as jest.Mock)
      .mockResolvedValueOnce({ ok: true, status: 201, json: async () => ({ id: 5, title: 'Lição', published: false }) })
      .mockImplementationOnce(() => uploadDone.then(() => ({ ok: true, json: async () => ({}) })))

    renderDialog(5)
    fireEvent.change(screen.getByLabelText(/título/i), { target: { value: 'Lição' } })

    const audioInput = screen.getByLabelText(/áudio/i) as HTMLInputElement
    const audioFile = new File(['content'], 'audio.mp3', { type: 'audio/mpeg' })
    fireEvent.change(audioInput, { target: { files: [audioFile] } })

    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))

    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(handlers.onCreated).not.toHaveBeenCalled()

    resolveUpload()
    await waitFor(() => expect(handlers.onCreated).toHaveBeenCalled())
  })

  it('accepts lesson id = 0', async () => {
    ;(global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      status: 201,
      json: async () => ({ id: 0, title: 'Introdução', published: false }),
    })
    renderDialog(1)
    const idInput = screen.getByLabelText(/número/i) as HTMLInputElement
    fireEvent.change(idInput, { target: { value: '0' } })
    fireEvent.change(screen.getByLabelText(/título/i), { target: { value: 'Introdução' } })
    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))
    await waitFor(() => expect(handlers.onCreated).toHaveBeenCalled())
    const body = JSON.parse((global.fetch as jest.Mock).mock.calls[0][1].body)
    expect(body.id).toBe(0)
  })

  it('ignores non-digit characters (letters, hyphens) typed in the id field', () => {
    renderDialog(1)
    const idInput = screen.getByLabelText(/número/i) as HTMLInputElement
    fireEvent.change(idInput, { target: { value: 'abc' } })
    expect(idInput.value).toBe('1')
    fireEvent.change(idInput, { target: { value: '-5' } })
    expect(idInput.value).toBe('1')
  })

  it('shows error and does not call onCreated when pdf upload fails', async () => {
    ;(global.fetch as jest.Mock)
      .mockResolvedValueOnce({ ok: true, status: 201, json: async () => ({ id: 5, title: 'Lição', published: false }) })
      .mockResolvedValueOnce({ ok: false, status: 500, json: async () => ({ error: 'Erro no upload do PDF' }) })

    renderDialog(5)
    fireEvent.change(screen.getByLabelText(/título/i), { target: { value: 'Lição' } })

    const pdfInput = screen.getByLabelText(/pdf/i) as HTMLInputElement
    const pdfFile = new File(['content'], 'lesson.pdf', { type: 'application/pdf' })
    fireEvent.change(pdfInput, { target: { files: [pdfFile] } })

    fireEvent.click(screen.getByRole('button', { name: /salvar/i }))

    expect(await screen.findByText(/erro no upload do pdf/i)).toBeInTheDocument()
    expect(handlers.onCreated).not.toHaveBeenCalled()
  })
})
