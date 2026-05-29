'use client'

import { useEffect, useState } from 'react'
import { Sidebar } from '@/components/layout/Sidebar'
import { Header } from '@/components/layout/Header'
import { MobileDrawer } from '@/components/layout/MobileDrawer'

interface CurrentUser {
  id: number
  username: string
  isAdmin: boolean
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<CurrentUser | null>(null)
  const [drawerOpen, setDrawerOpen] = useState(false)

  useEffect(() => {
    fetch('/api/auth/me')
      .then((res) => res.json())
      .then(setUser)
  }, [])

  if (!user) return null

  return (
    <div className="flex min-h-screen">
      <Sidebar username={user.username} isAdmin={user.isAdmin} />
      <MobileDrawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        username={user.username}
        isAdmin={user.isAdmin}
      />
      <div className="flex flex-col flex-1 min-w-0">
        <Header onMenuClick={() => setDrawerOpen(true)} />
        <main className="flex-1 p-6">{children}</main>
      </div>
    </div>
  )
}
