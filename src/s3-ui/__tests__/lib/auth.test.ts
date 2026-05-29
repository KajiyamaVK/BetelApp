/**
 * @jest-environment jest-environment-node
 */
import { signToken, verifyToken, TOKEN_COOKIE } from '@/lib/auth'

beforeAll(() => {
  process.env.JWT_SECRET = 'test-secret-for-unit-tests-minimum-32-chars'
})

describe('auth', () => {
  const payload = { id: 1, username: 'victor', isAdmin: true }

  it('signs and verifies a token', async () => {
    const token = await signToken(payload)
    const result = await verifyToken(token)
    expect(result.username).toBe('victor')
    expect(result.isAdmin).toBe(true)
  })

  it('throws on invalid token', async () => {
    await expect(verifyToken('not-a-token')).rejects.toThrow()
  })

  it('TOKEN_COOKIE is a non-empty string', () => {
    expect(typeof TOKEN_COOKIE).toBe('string')
    expect(TOKEN_COOKIE.length).toBeGreaterThan(0)
  })
})
