export const dynamic = 'force-dynamic'

import { NextRequest, NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { z } from 'zod'
import { prisma } from '@/lib/prisma'
import { requireAuth, signToken, TOKEN_COOKIE } from '@/lib/auth'

const changePasswordSchema = z.object({
  password: z.string().min(6, 'A senha deve ter ao menos 6 caracteres'),
  confirmPassword: z.string(),
})

export async function POST(req: NextRequest) {
  const authResult = await requireAuth(req)
  if ('error' in authResult) return authResult.error

  const body = await req.json()
  const parsed = changePasswordSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0].message }, { status: 400 })
  }

  const { password, confirmPassword } = parsed.data
  if (password !== confirmPassword) {
    return NextResponse.json({ error: 'As senhas não coincidem' }, { status: 400 })
  }

  if (password === '123456') {
    return NextResponse.json({ error: 'A senha não pode ser 123456' }, { status: 400 })
  }

  const passwordHash = await bcrypt.hash(password, 12)
  const user = await prisma.user.update({
    where: { id: authResult.userId },
    data: { passwordHash, mustChangePassword: false },
    select: { id: true, username: true, isAdmin: true },
  })

  // Issue a fresh JWT with mustChangePassword=false so the middleware
  // stops redirecting back to /change-password on the next request.
  const token = await signToken({ id: user.id, username: user.username, isAdmin: user.isAdmin, mustChangePassword: false })
  const res = NextResponse.json({ ok: true })
  res.cookies.set(TOKEN_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7,
    path: '/',
  })
  return res
}
