import { Suspense, useEffect, useState } from 'react'
import { useProgress } from '@react-three/drei'

import type { ReactNode } from 'react'

import { useStore } from '../store'

export function Intro({ children }: { children: ReactNode }): JSX.Element {
  const [clicked, setClicked] = useState(false)
  const [loading, setLoading] = useState(true)
  const { progress } = useProgress()
  const set = useStore((state) => state.set)

  useEffect(() => {
    if (clicked && !loading) set({ ready: true })
  }, [clicked, loading])

  useEffect(() => {
    if (progress === 100) setLoading(false)
  }, [progress])

  return (
    <>
      <Suspense fallback={null}>{children}</Suspense>
      <div className={`fullscreen bg ${loading ? 'loading' : 'loaded'} ${clicked && 'clicked'}`}>
        <div className="midnight-logo">🏎️</div>
        <h1 className="midnight-title">Midnight Drive</h1>
        <p className="midnight-subtitle">Everglow</p>
        {loading ? (
          <p className="intro-loading-text">{`loading ${progress.toFixed()} %`}</p>
        ) : (
          <a className="start-link" href="#" onClick={() => setClicked(true)}>
            <span className="everglow-intro-btn">TAP TO START</span>
          </a>
        )}
        <div className="everglow-footer">Everglow \u2014 Play Zone</div>
      </div>
    </>
  )
}
