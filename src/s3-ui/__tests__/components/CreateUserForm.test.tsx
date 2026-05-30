/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { CreateUserForm } from '@/components/users/CreateUserForm'

describe('CreateUserForm', () => {
  it('renders username field and admin checkbox (no password field)', () => {
    render(<CreateUserForm onCreated={jest.fn()} />)
    expect(screen.getByLabelText(/usuário/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/administrador/i)).toBeInTheDocument()
    expect(screen.queryByLabelText(/senha/i)).toBeNull()
  })

  it('shows informational text about default password 123456', () => {
    render(<CreateUserForm onCreated={jest.fn()} />)
    expect(screen.getByText(/123456/)).toBeInTheDocument()
  })

  it('calls fetch with username and isAdmin (no password) on submit', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ id: 2, username: 'ana', isAdmin: false, mustChangePassword: true, createdAt: '' }),
    })
    const onCreated = jest.fn()
    render(<CreateUserForm onCreated={onCreated} />)
    fireEvent.change(screen.getByLabelText(/usuário/i), { target: { value: 'ana' } })
    fireEvent.click(screen.getByRole('button', { name: /criar/i }))
    await waitFor(() => expect(onCreated).toHaveBeenCalled())
    const fetchCall = (global.fetch as jest.Mock).mock.calls[0]
    const body = JSON.parse(fetchCall[1].body)
    expect(body).toHaveProperty('username', 'ana')
    expect(body).not.toHaveProperty('password')
  })

  it('shows error when username already exists', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      json: () => Promise.resolve({ error: 'Username already exists' }),
    })
    render(<CreateUserForm onCreated={jest.fn()} />)
    fireEvent.change(screen.getByLabelText(/usuário/i), { target: { value: 'victor' } })
    fireEvent.click(screen.getByRole('button', { name: /criar/i }))
    await waitFor(() => expect(screen.getByText(/username already exists/i)).toBeInTheDocument())
  })
})
