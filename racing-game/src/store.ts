import { createRef } from 'react'
import create from 'zustand'
import shallow from 'zustand/shallow'
import type { RefObject } from 'react'
import type { PublicApi, WheelInfoOptions } from '@react-three/cannon'
import type { Group } from 'three'
import type { GetState, SetState, StateSelector } from 'zustand'

import { keys } from './keys'

export const angularVelocity = [0, 0, 0] as const
export const cameras = ['DEFAULT', 'FIRST_PERSON', 'BIRD_EYE'] as const

export const dpr = 1.5 as const
export const levelLayer = 1 as const
export const maxBoost = 100 as const
export const position = [-110, 0.75, 220] as const
export const rotation = [0, Math.PI / 2 + 0.35, 0] as const

export type Waypoint = { position: [number, number, number]; rotation: [number, number, number] }

export const waypoints: Waypoint[] = [
  { position: [-27, 1, 180], rotation: [0, 0.55, 0] },
  { position: [-22, 1, 130], rotation: [0, 0.45, 0] },
  { position: [-18, 1, 80], rotation: [0, 0.2, 0] },
  { position: [-30, 1, 30], rotation: [0, -0.2, 0] },
  { position: [-50, 1, -5], rotation: [0, -0.5, 0] },
  { position: [-78, 1, -35], rotation: [0, -0.85, 0] },
  { position: [-104, 1, -85], rotation: [0, -1.15, 0] },
  { position: [-104, 1, -140], rotation: [0, -1.25, 0] },
  { position: [-104, 1, -189], rotation: [0, -1.2, 0] },
  { position: [-90, 1, -215], rotation: [0, 1.55, 0] },
  { position: [-50, 1, -225], rotation: [0, 1.8, 0] },
  { position: [0, 1, -215], rotation: [0, 2.0, 0] },
  { position: [50, 1, -190], rotation: [0, -2.35, 0] },
  { position: [90, 1, -145], rotation: [0, -2.55, 0] },
  { position: [112, 1, -80], rotation: [0, -2.75, 0] },
  { position: [112, 1, 0], rotation: [0, -2.9, 0] },
  { position: [102, 1, 80], rotation: [0, 2.5, 0] },
  { position: [70, 1, 150], rotation: [0, 1.7, 0] },
  { position: [20, 1, 180], rotation: [0, 1.05, 0] },
]

export const vehicleConfig = {
  width: 1.7,
  height: -0.3,
  front: 1.35,
  back: -1.3,
  steer: 0.3,
  force: 1800,
  maxBrake: 65,
  maxSpeed: 88,
} as const

type VehicleConfig = typeof vehicleConfig

export type WheelInfo = Required<
  Pick<
    WheelInfoOptions,
    | 'axleLocal'
    | 'customSlidingRotationalSpeed'
    | 'directionLocal'
    | 'frictionSlip'
    | 'radius'
    | 'rollInfluence'
    | 'sideAcceleration'
    | 'suspensionRestLength'
    | 'suspensionStiffness'
    | 'useCustomSlidingRotationalSpeed'
  >
>

export const wheelInfo: WheelInfo = {
  axleLocal: [-1, 0, 0],
  customSlidingRotationalSpeed: -0.01,
  directionLocal: [0, -1, 0],
  frictionSlip: 1.5,
  radius: 0.38,
  rollInfluence: 0,
  sideAcceleration: 3,
  suspensionRestLength: 0.35,
  suspensionStiffness: 30,
  useCustomSlidingRotationalSpeed: true,
}

export const booleans = {
  binding: false,
  debug: false,
  editor: false,
  help: false,
  leaderboard: false,
  map: true,
  pickcolor: false,
  ready: false,
  shadows: true,
  stats: false,
  sound: true,
}

type Booleans = keyof typeof booleans

const exclusiveBooleans = ['help', 'leaderboard', 'pickcolor'] as const
type ExclusiveBoolean = typeof exclusiveBooleans[number]
const isExclusiveBoolean = (v: unknown): v is ExclusiveBoolean => exclusiveBooleans.includes(v as ExclusiveBoolean)

export type Camera = typeof cameras[number]

const controls = {
  backward: false,
  boost: false,
  brake: false,
  forward: false,
  honk: false,
  left: false,
  right: false,
}
export type Controls = typeof controls
type Control = keyof Controls
export const isControl = (v: PropertyKey): v is Control => Object.hasOwnProperty.call(controls, v)

export type BindableActionName = Control | ExclusiveBoolean | Extract<Booleans, 'editor' | 'map' | 'sound'> | 'camera' | 'reset'

export type ActionInputMap = Record<BindableActionName, string[]>

const actionInputMap: ActionInputMap = {
  backward: ['arrowdown', 's'],
  boost: ['shift'],
  brake: [' '],
  camera: ['c'],
  editor: ['.'],
  forward: ['arrowup', 'w', 'z'],
  help: ['i'],
  honk: ['h'],
  leaderboard: ['l'],
  left: ['arrowleft', 'a', 'q'],
  map: ['m'],
  pickcolor: ['p'],
  reset: ['r'],
  right: ['arrowright', 'd', 'e'],
  sound: ['u'],
}

type Getter = GetState<IState>
export type Setter = SetState<IState>

type BaseState = Record<Booleans, boolean>

type BooleanActions = Record<Booleans, () => void>
type ControlActions = Record<Control, (v: boolean) => void>
type TimerActions = Record<'onCheckpoint' | 'onFinish' | 'onStart', () => void>

type Actions = BooleanActions &
  ControlActions &
  TimerActions & {
    camera: () => void
    reset: () => void
    softReset: (currentPos?: [number, number, number]) => void
  }

export interface IState extends BaseState {
  actions: Actions
  api: PublicApi | null
  bestCheckpoint: number
  camera: Camera
  chassisBody: RefObject<Group>
  checkpoint: number
  color: string
  controls: Controls
  actionInputMap: ActionInputMap
  keyBindingsWithError: number[]
  dpr: number
  finished: number
  get: Getter
  lastCheckpointIndex: number
  level: RefObject<Group>
  userId: string | null
  displayName: string | null
  set: Setter
  start: number
  vehicleConfig: VehicleConfig
  wheelInfo: WheelInfo
  wheels: [RefObject<Group>, RefObject<Group>, RefObject<Group>, RefObject<Group>]
  keyInput: string | null
  respawnCount: number
  respawnFlash: number
}

const setExclusiveBoolean = (set: Setter, boolean: ExclusiveBoolean) => () =>
  set((state) => ({ ...exclusiveBooleans.reduce((o, key) => ({ ...o, [key]: key === boolean ? !state[boolean] : false }), state) }))

const useStoreImpl = create<IState>((set: SetState<IState>, get: GetState<IState>) => {
  const controlActions = keys(controls).reduce<Record<Control, (value: boolean) => void>>((o, control) => {
    o[control] = (value: boolean) => set((state) => ({ controls: { ...state.controls, [control]: value } }))
    return o
  }, {} as Record<Control, (value: boolean) => void>)

  const booleanActions = keys(booleans).reduce<Record<Booleans, () => void>>((o, boolean) => {
    o[boolean] = isExclusiveBoolean(boolean) ? setExclusiveBoolean(set, boolean) : () => set((state) => ({ ...state, [boolean]: !state[boolean] }))
    return o
  }, {} as Record<Booleans, () => void>)

  const actions: Actions = {
    ...booleanActions,
    ...controlActions,
    camera: () => set((state) => ({ camera: cameras[(cameras.indexOf(state.camera) + 1) % cameras.length] })),
    onCheckpoint: () => {
      const { start } = get()
      if (start) {
        const checkpoint = Date.now() - start
        set({ checkpoint, lastCheckpointIndex: 4 })
      }
    },
    onFinish: () => {
      const { finished, start } = get()
      if (start && !finished) {
        set({ finished: Math.max(Date.now() - start, 0) })
      }
    },
    onStart: () => {
      set({ finished: 0, start: Date.now() })
    },
    reset: () => {
      mutation.boost = maxBoost

      set((state) => {
        state.api?.angularVelocity.set(...angularVelocity)
        state.api?.position.set(...position)
        state.api?.rotation.set(...rotation)
        state.api?.velocity.set(0, 0, 0)

        return { ...state, finished: 0, start: 0 }
      })
    },
    softReset: (currentPos?: [number, number, number]) => {
      set((state) => {
        if (!state.api) return state

        const chassis = state.chassisBody.current
        const cx = currentPos?.[0] ?? chassis?.position.x ?? position[0]
        const cz = currentPos?.[2] ?? chassis?.position.z ?? position[2]

        const startIndex = Math.min(state.lastCheckpointIndex, waypoints.length - 1)
        let bestIndex = startIndex
        let bestDist = Infinity
        for (let i = startIndex; i < waypoints.length; i++) {
          const wp = waypoints[i]
          const dx = wp.position[0] - cx
          const dz = wp.position[2] - cz
          const d = dx * dx + dz * dz
          if (d < bestDist) {
            bestDist = d
            bestIndex = i
          }
        }

        const wp = waypoints[bestIndex]

        state.api.angularVelocity.set(0, 0, 0)
        state.api.position.set(wp.position[0], wp.position[1] + 0.5, wp.position[2])
        state.api.rotation.set(0, wp.rotation[1], 0)
        state.api.velocity.set(0, 0, 0)

        return { ...state, respawnCount: state.respawnCount + 1, respawnFlash: Date.now() }
      })
    },
  }

  return {
    ...booleans,
    actionInputMap,
    actions,
    api: null,
    bestCheckpoint: 0,
    camera: cameras[0],
    chassisBody: createRef<Group>(),
    checkpoint: 0,
    color: '#F4C2C2',
    controls,
    keyBindingsWithError: [],
    dpr,
    finished: 0,
    get,
    lastCheckpointIndex: 0,
    keyInput: null,
    level: createRef<Group>(),
    userId: null,
    displayName: null,
    set,
    start: 0,
    vehicleConfig,
    wheelInfo,
    wheels: [createRef<Group>(), createRef<Group>(), createRef<Group>(), createRef<Group>()],
    respawnCount: 0,
    respawnFlash: 0,
  }
})

interface Mutation {
  boost: number
  rpmTarget: number
  sliding: boolean
  speed: number
  velocity: [number, number, number]
}

export const mutation: Mutation = {
  boost: maxBoost,
  rpmTarget: 0,
  sliding: false,
  speed: 0,
  velocity: [0, 0, 0],
}

export const opponentState = {
  position: [0, 0, 0] as [number, number, number],
  speed: 0,
  boost: 0,
}

// Make the store shallow compare by default
const useStore = <T>(sel: StateSelector<IState, T>) => useStoreImpl(sel, shallow)
Object.assign(useStore, useStoreImpl)

const { getState, setState } = useStoreImpl

export { getState, setState, useStore }
