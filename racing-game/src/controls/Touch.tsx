import { useState, useEffect } from 'react'
import { useStore, mutation } from '../store'

const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0

export function Touch(): JSX.Element | null {
  const actions = useStore((s) => s.actions)
  const respawnCount = useStore((s) => s.respawnCount)
  const [boost, setBoost] = useState(mutation.boost)

  useEffect(() => {
    const interval = setInterval(() => setBoost(mutation.boost), 100)
    return () => clearInterval(interval)
  }, [])

  useEffect(() => {
    if (respawnCount > 0) {
      const el = document.querySelector('.touch-overlay')
      el?.classList.add('flash')
      const t = setTimeout(() => el?.classList.remove('flash'), 600)
      return () => clearTimeout(t)
    }
  }, [respawnCount])

  if (!isTouchDevice) return null

  const press = (action: (v: boolean) => void) => ({
    onPointerDown: (e: React.PointerEvent) => { e.preventDefault(); action(true) },
    onPointerUp: (e: React.PointerEvent) => { e.preventDefault(); action(false) },
    onPointerLeave: (e: React.PointerEvent) => { e.preventDefault(); action(false) },
    onPointerCancel: (e: React.PointerEvent) => { e.preventDefault(); action(false) },
  })

  const tap = (fn: () => void) => ({
    onPointerDown: (e: React.PointerEvent) => { e.preventDefault(); fn() },
  })

  const boostPct = (boost / 100) * 100

  return (
    <div className="touch-overlay">
      <div className="touch-pedals">
        <button
          className="touch-btn pedal-boost"
          {...press(actions.boost)}
          aria-label="Boost"
        >
          <svg className="boost-ring" viewBox="0 0 56 56">
            <circle className="boost-ring-bg" cx="28" cy="28" r="24" />
            <circle
              className={`boost-ring-fg ${boost <= 30 ? 'boost-low' : boost <= 60 ? 'boost-mid' : 'boost-full'}`}
              cx="28"
              cy="28"
              r="24"
              style={{ strokeDasharray: `${(boostPct / 100) * 150.8} 150.8` }}
            />
          </svg>
          <svg className="boost-icon" viewBox="0 0 24 24" fill="currentColor">
            <path d="M13 2L3 14h7l-1 8 10-12h-7l1-8z" />
          </svg>
        </button>
        <div className="touch-pedal-row">
          <button className="touch-btn pedal-brake" {...press(actions.brake)} aria-label="Brake">
            <span className="pedal-label">BRAKE</span>
            <span className="pedal-icon">▼</span>
          </button>
          <button className="touch-btn pedal-gas" {...press(actions.forward)} aria-label="Gas">
            <span className="pedal-label">GAS</span>
            <span className="pedal-icon">▲</span>
          </button>
        </div>
      </div>

      <div className="touch-steering">
        <button
          className="touch-btn btn-honk"
          {...press(actions.honk)}
          aria-label="Honk"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M5 10h-1a2 2 0 0 0-2 2v0a2 2 0 0 0 2 2h1l4 4h1l3-9h-1l-3 9" />
            <path d="M13 10l3-4" />
            <path d="M16 9a5 5 0 0 1 0 6" />
            <path d="M19 7a8 8 0 0 1 0 10" />
          </svg>
        </button>
        <div className="steer-row">
          <button className="touch-btn btn-steer" {...press(actions.left)} aria-label="Steer left">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="15 18 9 12 15 6" />
            </svg>
          </button>
          <button className="touch-btn btn-steer" {...press(actions.right)} aria-label="Steer right">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="9 6 15 12 9 18" />
            </svg>
          </button>
        </div>
      </div>

      <button
        className="touch-btn btn-respawn"
        {...tap(() => actions.softReset())}
        aria-label="Respawn"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <polyline points="1 4 1 10 7 10" />
          <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10" />
        </svg>
      </button>

      <button
        className="touch-btn btn-camera"
        {...tap(actions.camera)}
        aria-label="Switch camera"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
          <circle cx="12" cy="13" r="4" />
        </svg>
      </button>
    </div>
  )
}
