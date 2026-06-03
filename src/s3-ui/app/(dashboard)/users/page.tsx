'use client'

import { useEffect, useState } from 'react'
import { UserTable } from '@/components/users/UserTable'
import { CreateUserForm } from '@/components/users/CreateUserForm'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'

interface User {
  id: number
  username: string
  isAdmin: boolean
  mustChangePassword: boolean
  createdAt: string
}

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([])
  const [currentUserId, setCurrentUserId] = useState<number>(0)
  const [deleteTargetId, setDeleteTargetId] = useState<number | null>(null)
  const [deleting, setDeleting] = useState(false)
  const [resetTargetId, setResetTargetId] = useState<number | null>(null)
  const [resetting, setResetting] = useState(false)
  const [resetSuccess, setResetSuccess] = useState<string | null>(null)

  useEffect(() => {
    fetch('/api/auth/me').then((res) => res.json()).then((data) => setCurrentUserId(data.id))
    fetch('/api/users').then((res) => res.json()).then(setUsers)
  }, [])

  function handleCreated(user: User) {
    setUsers((prev) => [...prev, user])
  }

  async function handleDeleteConfirm() {
    if (!deleteTargetId) return
    setDeleting(true)
    await fetch(`/api/users/${deleteTargetId}`, { method: 'DELETE' })
    setUsers((prev) => prev.filter((user) => user.id !== deleteTargetId))
    setDeleting(false)
    setDeleteTargetId(null)
  }

  async function handleResetConfirm() {
    if (!resetTargetId) return
    setResetting(true)
    const res = await fetch(`/api/users/${resetTargetId}/reset-password`, { method: 'POST' })
    if (res.ok) {
      setUsers((prev) =>
        prev.map((user) => user.id === resetTargetId ? { ...user, mustChangePassword: true } : user),
      )
      const target = users.find((user) => user.id === resetTargetId)
      setResetSuccess(`Senha de "${target?.username}" resetada para 123456. O usuário deverá trocá-la no próximo acesso.`)
    }
    setResetting(false)
    setResetTargetId(null)
  }

  return (
    <div>
      <h1 className="text-xl font-bold text-text-main mb-6">Usuários</h1>
      <CreateUserForm onCreated={handleCreated} />

      {resetSuccess && (
        <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-sm text-green-700">
          {resetSuccess}
          <button className="ml-2 underline text-xs" onClick={() => setResetSuccess(null)}>Fechar</button>
        </div>
      )}

      <UserTable
        users={users}
        currentUserId={currentUserId}
        onDelete={(userId) => setDeleteTargetId(userId)}
        onResetPassword={(userId) => setResetTargetId(userId)}
      />

      <AlertDialog open={!!deleteTargetId} onOpenChange={(open) => !open && setDeleteTargetId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Deletar usuário?</AlertDialogTitle>
            <AlertDialogDescription>
              Esta ação é irreversível. O usuário será removido permanentemente.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-delete-bg text-delete-text hover:bg-red-200 flex items-center gap-2"
              disabled={deleting}
              onClick={handleDeleteConfirm}
            >
              {deleting && (
                <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
              )}
              {deleting ? 'Deletando...' : 'Deletar'}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={!!resetTargetId} onOpenChange={(open) => !open && setResetTargetId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Resetar senha?</AlertDialogTitle>
            <AlertDialogDescription>
              A senha do usuário será redefinida para <strong>123456</strong>. Ele deverá trocá-la no próximo acesso.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={handleResetConfirm} disabled={resetting} className="flex items-center gap-2">
              {resetting && (
                <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
              )}
              {resetting ? 'Aguarde...' : 'Confirmar'}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
