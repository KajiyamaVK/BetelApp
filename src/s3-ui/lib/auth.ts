import { SignJWT, jwtVerify } from 'jose'

/** Cookie name used to store the auth token */
export const TOKEN_COOKIE = 'token'

interface TokenPayload {
  id: number
  username: string
  isAdmin: boolean
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
