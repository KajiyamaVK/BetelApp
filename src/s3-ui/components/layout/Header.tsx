'use client'

import { Menu } from 'lucide-react'
import { Button } from '@/components/ui/button'

interface HeaderProps {
  onMenuClick: () => void
}

export function Header({ onMenuClick }: HeaderProps) {
  return (
    <header className="md:hidden flex items-center justify-between bg-primary px-4 py-3">
      <span className="font-bold text-text-main">Portal Betel</span>
      <Button
        variant="ghost"
        size="icon"
        onClick={onMenuClick}
        className="text-text-main"
        aria-label="Abrir menu"
      >
        <Menu size={22} />
      </Button>
    </header>
  )
}
