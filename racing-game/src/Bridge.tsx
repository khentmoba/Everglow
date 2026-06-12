import { useEffect, useRef } from 'react'
import { useStore, mutation, opponentState } from './store'

function sendToParent(data: Record<string, unknown>) {
  if (window.parent !== window) {
    window.parent.postMessage(data, '*')
  }
}

export function Bridge() {
  const ready = useStore((s) => s.ready)
  const start = useStore((s) => s.start)
  const finished = useStore((s) => s.finished)
  const checkpoint = useStore((s) => s.checkpoint)
  const chassisBody = useStore((s) => s.chassisBody)
  const api = useStore((s) => s.api)
  const modeRef = useRef<string>('solo')
  const racingRef = useRef(false)

  useEffect(() => {
    sendToParent({ type: 'READY' })
  }, [])

  useEffect(() => {
    const handler = (event: MessageEvent) => {
      const data = event.data
      if (!data || typeof data !== 'object') return
      switch (data.type) {
        case 'INIT':
          modeRef.current = data.mode || 'solo'
          if (data.carColor) useStore.getState().set({ color: data.carColor })
          if (data.mute) useStore.getState().actions.sound()
          if (data.userId) useStore.getState().set({ userId: data.userId })
          if (data.displayName) useStore.getState().set({ displayName: data.displayName })
          break
        case 'OPPONENT_POSITION':
          opponentState.position = [data.x ?? 0, data.y ?? 0, data.z ?? 0]
          opponentState.speed = data.speed ?? 0
          opponentState.boost = data.boost ?? 0
          break
        case 'RACE_END':
          racingRef.current = false
          break
      }
    }
    window.addEventListener('message', handler)
    return () => window.removeEventListener('message', handler)
  }, [])

  useEffect(() => {
    if (start > 0) {
      racingRef.current = true
      sendToParent({ type: 'RACE_START', timestamp: start })
    }
  }, [start])

  useEffect(() => {
    if (checkpoint > 0) {
      sendToParent({ type: 'RACE_CHECKPOINT', time: checkpoint })
    }
  }, [checkpoint])

  useEffect(() => {
    if (finished > 0) {
      racingRef.current = false
      const totalTime = finished
      sendToParent({ type: 'RACE_COMPLETE', totalTime })
    }
  }, [finished])

  useEffect(() => {
    if (!api) return

    const interval = setInterval(() => {
      if (!racingRef.current) return
      const pos = chassisBody.current?.position
      if (!pos) return
      sendToParent({
        type: 'POSITION',
        x: pos.x,
        y: pos.y,
        z: pos.z,
        speed: mutation.speed,
        boost: mutation.boost,
      })
    }, 100)

    return () => clearInterval(interval)
  }, [api, chassisBody])

  return null
}
