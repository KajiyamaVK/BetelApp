'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { LogOut } from 'lucide-react'
import { NAV_ITEMS, logout } from '@/lib/navItems'

interface SidebarProps {
  username: string
  isAdmin: boolean
}

export function Sidebar({ username, isAdmin }: SidebarProps) {
  const pathname = usePathname()
  const router = useRouter()

  function navItem(href: string, icon: React.ReactNode, label: string) {
    const active = pathname.startsWith(href)
    return (
      <Link
        key={href}
        href={href}
        className={`flex items-center gap-3 px-4 py-2.5 rounded-lg text-sm font-medium transition-colors ${
          active
            ? 'bg-primary text-text-main'
            : 'text-gray-300 hover:bg-white/10'
        }`}
      >
        {icon}
        {label}
      </Link>
    )
  }

  return (
    <aside className="hidden md:flex flex-col w-60 min-h-screen bg-[#1a1a1a] px-3 py-6">
      <div className="px-4 mb-8">
        <span className="text-primary text-xl font-bold">Portal Betel</span>
      </div>

      <nav className="flex flex-col gap-1 flex-1">
        {NAV_ITEMS.filter((item) => !item.adminOnly || isAdmin).map((item) =>
          navItem(item.href, item.icon, item.label),
        )}
      </nav>

      <div className="border-t border-white/10 pt-4 px-4">
        <p className="text-xs text-gray-400 mb-2">{username}</p>
        <button
          onClick={() => logout(router)}
          className="flex items-center gap-2 text-sm text-gray-400 hover:text-white transition-colors"
        >
          <LogOut size={16} />
          Sair
        </button>
      </div>
    </aside>
  )
}
