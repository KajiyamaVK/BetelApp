import { SignJWT } from 'jose'
import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { TOKEN_COOKIE, TokenPayload, getSecret, verifyToken } from '@/lib/auth-token'

export { TOKEN_COOKIE, verifyToken }
export type { TokenPayload }

/** Cookie max-age in seconds — must match the JWT expiry of 7d */
export const TOKEN_MAX_AGE = 60 * 60 * 24 * 7

/** Default password assigned to new users and after a password reset; users must change it on first login */
export const DEFAULT_PASSWORD = '123456'

/** Signs a JWT with HS256 and 7-day expiry */
export async function signToken(payload: TokenPayload): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('7d')
    .sign(getSecret())
}

/** Sets the auth cookie on an existing NextResponse */
export function setAuthCookie(res: NextResponse, token: string): void {
  res.cookies.set(TOKEN_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: TOKEN_MAX_AGE,
    path: '/',
  })
}

/**
 * Verifies the auth cookie is present and valid. Returns { userId, username } on success,
 * or { error: NextResponse } on missing/invalid token.
 * Use this for routes that require any logged-in user (e.g. lesson mutations).
 */
export async function requireAuth(
  req: NextRequest,
): Promise<{ error: NextResponse } | { userId: number; username: string }> {
  const token = req.cookies.get(TOKEN_COOKIE)?.value
  if (!token) return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  try {
    const payload = await verifyToken(token)
    return { userId: payload.id, username: payload.username }
  } catch {
    return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  }
}

/**
 * Reads the auth cookie and verifies the user is an admin via a fresh DB lookup.
 * Returns { userId } on success, or { error: NextResponse } to return immediately.
 * Use this only for routes that require admin privileges (e.g. user management).
 */
export async function requireAdmin(
  req: NextRequest,
): Promise<{ error: NextResponse } | { userId: number }> {
  const token = req.cookies.get(TOKEN_COOKIE)?.value
  if (!token) return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  try {
    const payload = await verifyToken(token)
    // Re-fetch isAdmin from DB so revocation takes effect immediately (JWT claim is stale after 7 days)
    const user = await prisma.user.findUnique({ where: { id: payload.id }, select: { isAdmin: true } })
    if (!user?.isAdmin) return { error: NextResponse.json({ error: 'Forbidden' }, { status: 403 }) }
    return { userId: payload.id }
  } catch {
    return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  }
}
