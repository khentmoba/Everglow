import { useRef } from 'react'
import { useBox } from '@react-three/cannon'
import { useGLTF } from '@react-three/drei'
import { useFrame } from '@react-three/fiber'
import type { Group } from 'three'
import { opponentState } from '../store'

export function GhostCar(): JSX.Element | null {
  const { nodes, materials } = useGLTF(`${import.meta.env.BASE_URL}models/chassis-draco.glb`) as any
  const [ref, api] = useBox(() => ({
    mass: 0,
    type: 'Kinematic',
    position: [0, -100, 0],
    args: [1.7, 0.8, 3.5],
  }))
  const visibleRef = useRef(false)

  useFrame(() => {
    const [x, y, z] = opponentState.position
    if (x === 0 && y === 0 && z === 0) return
    if (!visibleRef.current) visibleRef.current = true
    api.position.set(x, y, z)
  })

  if (!visibleRef.current && opponentState.position[0] === 0) return null

  return (
    <group ref={ref as React.Ref<Group>}>
      <mesh
        castShadow
        receiveShadow
        geometry={nodes.chassis_1.geometry}
        material={materials.chassis_1}
        material-color="#D4B5D6"
        material-opacity={0.7}
        material-transparent
      />
      <mesh
        castShadow
        receiveShadow
        geometry={nodes.chassis_2.geometry}
        material={materials.chassis_2}
        material-color="#D4B5D6"
        material-opacity={0.7}
        material-transparent
      />
      <mesh
        castShadow
        receiveShadow
        geometry={nodes.chassis_3.geometry}
        material={materials.chassis_3}
        material-color="#D4B5D6"
        material-opacity={0.7}
        material-transparent
      />
    </group>
  )
}
