import { useState, useEffect } from 'react'
import { useStore, mutation } from '../store'

const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0

export function Touch(): JSX.Element | null {
  if (!isTouchDevice) return null

  const actions = useStore((s) => s.actions)
  const [boost, setBoost] = useState(mutation.boost)

  useEffect(() => {
    const interval = setInterval(() => setBoost(mutation.boost), 100)
    return () => clearInterval(interval)
  }, [])

  const press = (action: (v: boolean) => void) => ({
    onPointerDown: (e: React.PointerEvent) => { e.preventDefault(); action(true) },
    onPointerUp: (e: React.PointerEvent) => { e.preventDefault(); action(false) },
    onPointerLeave: (e: React.PointerEvent) => { e.preventDefault(); action(false) },
    onPointerCancel: (e: React.PointerEvent) => { e.preventDefault(); action(false) },
  })

  const tap = (fn: () => void) => ({
    onPointerDown: (e: React.PointerEvent) => { e.preventDefault(); fn() },
  })

  return (
    <div className="touch-overlay">
      <div className="touch-left">
        <button className="touch-btn steer-l" {...press(actions.left)} aria-label="Steer left">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="15 18 9 12 15 6" />
          </svg>
        </button>
        <button className="touch-btn steer-r" {...press(actions.right)} aria-label="Steer right">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="9 6 15 12 9 18" />
          </svg>
        </button>
      </div>

      <div className="touch-right">
        <button className="touch-btn touch-boost" {...press(actions.boost)} aria-label="Boost">
          <div className="touch-boost-icon">⚡</div>
          <div className="touch-boost-bar">
            <div className="touch-boost-fill" style={{ width: `${(boost / 100) * 100}%` }} />
          </div>
        </button>
        <button className="touch-btn touch-gas" {...press(actions.forward)} aria-label="Gas">
          <span>GAS</span>
        </button>
        <button className="touch-btn touch-brake" {...press(actions.brake)} aria-label="Brake">
          <span>BRAKE</span>
        </button>
      </div>

      <button className="touch-btn touch-honk" {...press(actions.honk)} aria-label="Honk">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M17 8a13.5 13.5 0 0 1 0 8" />
          <path d="M20 6a17.5 17.5 0 0 1 0 12" />
          <path d="M4 10h-1a2 2 0 0 0-2 2v0a2 2 0 0 0 2 2h1l5 4h1l4-9h-1l-4 9" />
          <path d="M9 10l5-4" />
        </svg>
      </button>

      <button className="touch-btn touch-camera" {...tap(actions.camera)} aria-label="Switch camera">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
          <circle cx="12" cy="13" r="4" />
        </svg>
      </button>
    </div>
  )
}
