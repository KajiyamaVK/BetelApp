import { useEffect, useState } from 'react'
import { MOBILE_BREAKPOINT_PX } from '@/lib/constants'

export function useIsMobile() {
  const [mobile, setMobile] = useState(false)
  useEffect(() => {
    const check = () => setMobile(window.innerWidth < MOBILE_BREAKPOINT_PX)
    check()
    window.addEventListener('resize', check)
    return () => window.removeEventListener('resize', check)
  }, [])
  return mobile
}
