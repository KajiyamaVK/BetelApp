'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { LogOut } from 'lucide-react'
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
} from '@/components/ui/drawer'
import { NAV_ITEMS, logout } from '@/lib/navItems'

interface MobileDrawerProps {
  open: boolean
  onClose: () => void
  username: string
  isAdmin: boolean
}

export function MobileDrawer({ open, onClose, username, isAdmin }: MobileDrawerProps) {
  const pathname = usePathname()
  const router = useRouter()

  async function handleLogout() {
    onClose()
    await logout(router)
  }

  function navItem(href: string, icon: React.ReactNode, label: string) {
    const active = pathname.startsWith(href)
    return (
      <Link
        key={href}
        href={href}
        onClick={onClose}
        className={`flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
          active ? 'bg-primary text-text-main' : 'text-gray-600 hover:bg-gray-100'
        }`}
      >
        {icon}
        {label}
      </Link>
    )
  }

  return (
    <Drawer open={open} onOpenChange={(isOpen) => !isOpen && onClose()} direction="left">
      <DrawerContent className="w-64 h-full flex flex-col">
        <DrawerHeader>
          <DrawerTitle className="text-primary text-lg">Portal Betel</DrawerTitle>
        </DrawerHeader>
        <nav className="flex flex-col gap-1 px-3 flex-1">
          {NAV_ITEMS.filter((item) => !item.adminOnly || isAdmin).map((item) =>
            navItem(item.href, item.icon, item.label),
          )}
        </nav>
        <div className="border-t p-4">
          <p className="text-xs text-gray-400 mb-2">{username}</p>
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-900"
          >
            <LogOut size={16} />
            Sair
          </button>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
