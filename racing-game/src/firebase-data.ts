import { initializeApp } from 'firebase/app'
import { getFirestore, collection, query, orderBy, limit, getDocs, addDoc } from 'firebase/firestore'

const firebaseConfig = {
  apiKey: 'AIzaSyDn6NimhGDgY3w-B5eF1U0tH_wQ4jqG-7Q',
  authDomain: 'everglow-1c6db.firebaseapp.com',
  projectId: 'everglow-1c6db',
  storageBucket: 'everglow-1c6db.appspot.com',
  messagingSenderId: '220334592353',
  appId: '1:220334592353:web:6b31555509529613647520',
  measurementId: 'G-5VLGFK4VCM',
}

const app = initializeApp(firebaseConfig)
const db = getFirestore(app)

interface IScore {
  name: string
  time: number
}

export interface SavedScore extends IScore {
  id: string
}

export const getScores = async (limitCount = 50): Promise<SavedScore[]> => {
  const q = query(
    collection(db, 'racing_scores'),
    orderBy('time', 'asc'),
    limit(limitCount),
  )
  const snapshot = await getDocs(q)
  return snapshot.docs.map((doc) => ({
    id: doc.id,
    name: doc.data().name as string,
    time: doc.data().time as number,
  }))
}

export const insertScore = async ({ name, time }: IScore): Promise<SavedScore[]> => {
  const docRef = await addDoc(collection(db, 'racing_scores'), {
    name,
    time,
    createdAt: new Date(),
  })
  return [{ id: docRef.id, name, time }]
}
