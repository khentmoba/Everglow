import { createRoot } from 'react-dom/client'
import { useGLTF, useTexture } from '@react-three/drei'
import './styles.css'
import { App } from './App'

const base = import.meta.env.BASE_URL

useTexture.preload(`${base}textures/heightmap_1024.png`)
useGLTF.preload(`${base}models/track-draco.glb`)
useGLTF.preload(`${base}models/chassis-draco.glb`)
useGLTF.preload(`${base}models/wheel-draco.glb`)

createRoot(document.getElementById('root')!).render(<App />)
