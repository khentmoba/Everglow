import { useEffect } from 'react'
import debounce from 'lodash-es/debounce'

const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0

export function HideMouse({ delay = 3000 }) {
  useEffect(() => {
    if (isTouchDevice) return
    let isIdle = true

    const hideMouse = debounce(() => {
      isIdle = true
      document.documentElement.style.cursor = 'none'
    }, delay)

    const onMouseMovement = () => {
      if (isIdle) {
        isIdle = false
        document.documentElement.style.cursor = ''
      }
      hideMouse()
    }

    window.addEventListener('mousemove', onMouseMovement, { passive: true })
    return () => window.removeEventListener('mousemove', onMouseMovement)
  }, [delay])
  return null
}
