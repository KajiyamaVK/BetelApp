/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { CreateUserForm } from '@/components/users/CreateUserForm'

describe('CreateUserForm', () => {
  it('renders username, password, and admin checkbox', () => {
    render(<CreateUserForm onCreated={jest.fn()} />)
    expect(screen.getByLabelText(/usuário/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/senha/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/administrador/i)).toBeInTheDocument()
  })

  it('calls fetch with correct payload on submit', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ id: 2, username: 'ana', isAdmin: false, createdAt: '' }),
    })
    const onCreated = jest.fn()
    render(<CreateUserForm onCreated={onCreated} />)
    fireEvent.change(screen.getByLabelText(/usuário/i), { target: { value: 'ana' } })
    fireEvent.change(screen.getByLabelText(/senha/i), { target: { value: 'pass123' } })
    fireEvent.click(screen.getByRole('button', { name: /criar/i }))
    await waitFor(() => expect(onCreated).toHaveBeenCalled())
    expect(global.fetch).toHaveBeenCalledWith('/api/users', expect.objectContaining({ method: 'POST' }))
  })

  it('shows error when username already exists', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      json: () => Promise.resolve({ error: 'Username already exists' }),
    })
    render(<CreateUserForm onCreated={jest.fn()} />)
    fireEvent.change(screen.getByLabelText(/usuário/i), { target: { value: 'victor' } })
    fireEvent.change(screen.getByLabelText(/senha/i), { target: { value: 'pass123' } })
    fireEvent.click(screen.getByRole('button', { name: /criar/i }))
    await waitFor(() => expect(screen.getByText(/username already exists/i)).toBeInTheDocument())
  })
})
