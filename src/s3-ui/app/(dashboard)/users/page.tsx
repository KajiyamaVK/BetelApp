'use client'

import { useEffect, useState } from 'react'
import { UserTable } from '@/components/users/UserTable'
import { CreateUserForm } from '@/components/users/CreateUserForm'

interface User {
  id: number
  username: string
  isAdmin: boolean
  createdAt: string
}

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([])

  useEffect(() => {
    fetch('/api/users').then((res) => res.json()).then(setUsers)
  }, [])

  function handleCreated(user: User) {
    setUsers((prev) => [...prev, user])
  }

  return (
    <div>
      <h1 className="text-xl font-bold text-text-main mb-6">Usuários</h1>
      <CreateUserForm onCreated={handleCreated} />
      <UserTable users={users} />
    </div>
  )
}
