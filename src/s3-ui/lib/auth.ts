import { SignJWT, jwtVerify } from 'jose'
import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

/** Cookie name used to store the auth token */
export const TOKEN_COOKIE = 'token'

interface TokenPayload {
  id: number
  username: string
  isAdmin: boolean
  mustChangePassword: boolean
}

/** Encodes the JWT_SECRET env variable into a byte array for jose */
function getSecret(): Uint8Array {
  const secret = process.env.JWT_SECRET
  if (!secret) throw new Error('JWT_SECRET not set')
  return new TextEncoder().encode(secret)
}

/** Signs a JWT with HS256 and 7-day expiry */
export async function signToken(payload: TokenPayload): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('7d')
    .sign(getSecret())
}

/** Verifies a JWT and returns the decoded payload; throws on invalid/expired tokens */
export async function verifyToken(token: string): Promise<TokenPayload> {
  const { payload } = await jwtVerify(token, getSecret())
  return payload as unknown as TokenPayload
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
