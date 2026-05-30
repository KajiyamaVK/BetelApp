/**
 * @jest-environment jsdom
 */
import { render, screen, fireEvent } from '@testing-library/react'
import { UserTable } from '@/components/users/UserTable'

const mockUsers = [
  { id: 1, username: 'admin', isAdmin: true, mustChangePassword: false, createdAt: '2024-01-01T00:00:00Z' },
  { id: 2, username: 'joao', isAdmin: false, mustChangePassword: false, createdAt: '2024-01-02T00:00:00Z' },
  { id: 3, username: 'maria', isAdmin: false, mustChangePassword: true, createdAt: '2024-01-03T00:00:00Z' },
]

describe('UserTable — actions', () => {
  it('shows Deletar and Resetar senha buttons for each user', () => {
    render(
      <UserTable
        users={mockUsers}
        currentUserId={99}
        onDelete={jest.fn()}
        onResetPassword={jest.fn()}
      />,
    )
    const deleteButtons = screen.getAllByRole('button', { name: /deletar/i })
    const resetButtons = screen.getAllByRole('button', { name: /resetar senha/i })
    expect(deleteButtons).toHaveLength(3)
    expect(resetButtons).toHaveLength(3)
  })

  it('hides Deletar button for the current logged-in user', () => {
    render(
      <UserTable
        users={mockUsers}
        currentUserId={1}
        onDelete={jest.fn()}
        onResetPassword={jest.fn()}
      />,
    )
    const deleteButtons = screen.getAllByRole('button', { name: /deletar/i })
    // Only 2 delete buttons — admin (id=1) should not have one
    expect(deleteButtons).toHaveLength(2)
  })

  it('shows mustChangePassword warning badge for users that must change password', () => {
    render(
      <UserTable
        users={mockUsers}
        currentUserId={99}
        onDelete={jest.fn()}
        onResetPassword={jest.fn()}
      />,
    )
    expect(screen.getByText(/não acessou/i)).toBeInTheDocument()
  })

  it('calls onResetPassword with user id when Resetar senha is clicked', () => {
    const onResetPassword = jest.fn()
    render(
      <UserTable
        users={mockUsers}
        currentUserId={99}
        onDelete={onResetPassword}
        onResetPassword={onResetPassword}
      />,
    )
    const resetButtons = screen.getAllByRole('button', { name: /resetar senha/i })
    fireEvent.click(resetButtons[0])
    expect(onResetPassword).toHaveBeenCalledWith(1)
  })
})
