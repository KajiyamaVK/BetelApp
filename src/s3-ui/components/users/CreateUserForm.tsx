'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Checkbox } from '@/components/ui/checkbox'

interface User {
  id: number
  username: string
  isAdmin: boolean
  mustChangePassword: boolean
  createdAt: string
}

interface CreateUserFormProps {
  onCreated: (user: User) => void
}

export function CreateUserForm({ onCreated }: CreateUserFormProps) {
  const [username, setUsername] = useState('')
  const [isAdmin, setIsAdmin] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const res = await fetch('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, isAdmin }),
      })
      const data = await res.json()
      if (!res.ok) { setError(data.error ?? 'Erro ao criar usuário'); return }
      onCreated(data)
      setUsername('')
      setIsAdmin(false)
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="bg-surface rounded-xl border border-gray-100 p-4 mb-6">
      <h2 className="text-sm font-semibold text-text-main mb-1">Novo usuário</h2>
      <p className="text-xs text-gray-400 mb-4">A senha inicial será <strong>123456</strong>. O usuário deverá trocá-la no primeiro acesso.</p>
      <div className="flex flex-wrap gap-3 items-end">
        <div className="space-y-1">
          <Label htmlFor="new-username">Usuário</Label>
          <Input id="new-username" value={username} onChange={(e) => setUsername(e.target.value)} required />
        </div>
        <div className="flex items-center gap-2 mb-1">
          <Checkbox
            aria-label="Administrador"
            checked={isAdmin}
            onCheckedChange={(checked) => setIsAdmin(!!checked)}
          />
          <span className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70">
            Administrador
          </span>
        </div>
        <Button
          type="submit"
          disabled={loading}
          className="bg-primary hover:bg-yellow-400 text-text-main font-semibold flex items-center gap-2"
          aria-label="Criar"
        >
          {loading && (
            <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
          )}
          {loading ? 'Criando...' : 'Criar'}
        </Button>
      </div>
      {error && <p className="text-sm text-warning mt-2">{error}</p>}
    </form>
  )
}
