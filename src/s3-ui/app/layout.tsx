import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'BetelSAS Admin',
  description: 'Content management for BetelSAS lessons',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  )
}
