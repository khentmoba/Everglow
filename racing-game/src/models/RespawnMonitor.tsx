import { useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { Vector3 } from 'three'

import { getState, mutation } from '../store'

const FLIP_UP_THRESHOLD = -0.25
const FLIP_HOLD_SECONDS = 1.4
const FALL_Y_THRESHOLD = -8
const IDLE_RESPAWN_SPEED = 0.5
const IDLE_RESPAWN_SECONDS = 8
const COOLDOWN_MS = 1500

const up = new Vector3(0, 1, 0)
const worldUp = new Vector3()

export function RespawnMonitor() {
  const lastRespawn = useRef(0)
  const flipTimer = useRef(0)
  const lowSpeedTime = useRef(0)

  useFrame((_, delta) => {
    const state = getState()
    const chassis = state.chassisBody.current
    if (!chassis) return

    const now = performance.now()
    if (now - lastRespawn.current < COOLDOWN_MS) return

    const pos = chassis.position
    const quat = chassis.quaternion
    worldUp.copy(up).applyQuaternion(quat)
    const upDot = worldUp.y

    if (upDot < FLIP_UP_THRESHOLD) {
      flipTimer.current += delta
    } else {
      flipTimer.current = 0
    }

    if (pos.y < FALL_Y_THRESHOLD) {
      lastRespawn.current = now
      state.actions.softReset([pos.x, pos.y, pos.z])
      flipTimer.current = 0
      lowSpeedTime.current = 0
      return
    }

    if (flipTimer.current >= FLIP_HOLD_SECONDS) {
      lastRespawn.current = now
      state.actions.softReset([pos.x, pos.y, pos.z])
      flipTimer.current = 0
      lowSpeedTime.current = 0
      return
    }

    if (state.start > 0 && !state.finished) {
      if (mutation.speed < IDLE_RESPAWN_SPEED) {
        lowSpeedTime.current += delta
      } else {
        lowSpeedTime.current = 0
      }
      if (lowSpeedTime.current > IDLE_RESPAWN_SECONDS && pos.y < 6) {
        lastRespawn.current = now
        state.actions.softReset([pos.x, pos.y, pos.z])
        lowSpeedTime.current = 0
        flipTimer.current = 0
      }
    }
  })

  return null
}
