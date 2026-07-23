import { NextRequest, NextResponse } from 'next/server'
import { verifyToken, TOKEN_COOKIE } from '@/lib/auth-edge'

const PUBLIC_PATHS = new Set(['/login', '/change-password', '/api/auth/login', '/api/auth/change-password', '/privacy-policy'])

function isPublic(pathname: string): boolean {
  if (PUBLIC_PATHS.has(pathname)) return true
  for (const publicPath of PUBLIC_PATHS) {
    if (pathname.startsWith(publicPath + '/')) return true
  }
  return false
}

export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl

  if (isPublic(pathname)) {
    return NextResponse.next()
  }

  const token = req.cookies.get(TOKEN_COOKIE)?.value
  if (!token) {
    return NextResponse.redirect(new URL('/login', req.url))
  }

  try {
    const payload = await verifyToken(token)

    // Force password change before accessing any other route
    if (payload.mustChangePassword && !pathname.startsWith('/change-password') && !pathname.startsWith('/api/')) {
      return NextResponse.redirect(new URL('/change-password', req.url))
    }

    if (pathname.startsWith('/users') || pathname.startsWith('/api/users')) {
      // Use isAdmin from the JWT payload — avoids importing Prisma/pg which are not Edge-compatible.
      // If admin access is revoked, the user's token will expire within 7 days naturally.
      if (!payload.isAdmin) {
        return pathname.startsWith('/api/')
          ? NextResponse.json({ error: 'Forbidden' }, { status: 403 })
          : NextResponse.redirect(new URL('/lessons', req.url))
      }
    }

    return NextResponse.next()
  } catch {
    return NextResponse.redirect(new URL('/login', req.url))
  }
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
