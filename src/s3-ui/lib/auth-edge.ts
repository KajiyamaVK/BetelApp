import { jwtVerify } from 'jose'

export const TOKEN_COOKIE = 'token'

interface TokenPayload {
  id: number
  username: string
  isAdmin: boolean
  mustChangePassword: boolean
}

function getSecret(): Uint8Array {
  const secret = process.env.JWT_SECRET
  if (!secret) throw new Error('JWT_SECRET not set')
  return new TextEncoder().encode(secret)
}

/** Verifies a JWT using Web Crypto (Edge-compatible). Throws on invalid/expired tokens. */
export async function verifyToken(token: string): Promise<TokenPayload> {
  const { payload } = await jwtVerify(token, getSecret())
  return payload as unknown as TokenPayload
}
