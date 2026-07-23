import { BookOpen, FileText, Users } from 'lucide-react'

export const NAV_ITEMS = [
  { href: '/lessons', icon: <BookOpen size={18} />, label: 'Lições', adminOnly: false },
  { href: '/contents', icon: <FileText size={18} />, label: 'Conteúdos', adminOnly: false },
  { href: '/users', icon: <Users size={18} />, label: 'Usuários', adminOnly: true },
] as const

export async function logout(router: { push: (path: string) => void }) {
  await fetch('/api/auth/logout', { method: 'POST' })
  router.push('/login')
}
