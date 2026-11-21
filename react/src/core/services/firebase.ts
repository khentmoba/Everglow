// Same Firebase project and web settings as lib/firebase_options.dart.
// The JS SDK shares its saved sign-in with the Flutter build on the same site.
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import {
  clearIndexedDbPersistence,
  getFirestore,
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
  terminate,
  type Firestore,
} from 'firebase/firestore';
import type { FirebaseStorage } from 'firebase/storage';

export const app = initializeApp({
  apiKey: 'AIzaSyBMk0z4e-k_SAYzaLypYKJn3euwfx0fW5c',
  appId: '1:220334592353:web:6b31555509529613647520',
  messagingSenderId: '220334592353',
  projectId: 'everglow-1c6db',
  authDomain: 'everglow-1c6db.firebaseapp.com',
  storageBucket: 'everglow-1c6db.firebasestorage.app',
});

export const auth = getAuth(app);

function initDb(): Firestore {
  try {
    return initializeFirestore(app, {
      localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }),
    });
  } catch {
    return getFirestore(app);
  }
}

export const db = initDb();

export async function clearFirestoreCache(): Promise<void> {
  try {
    await terminate(db);
  } catch {
    // Already terminated or unavailable.
  }
  try {
    await clearIndexedDbPersistence(db);
  } catch {
    // Another tab may still hold the lock or persistence may be disabled.
  }
}

let storagePromise: Promise<{ storage: FirebaseStorage; mod: typeof import('firebase/storage') }> | null = null;
export function loadStorage() {
  if (!storagePromise) {
    storagePromise = import('firebase/storage')
      .then((mod) => ({ storage: mod.getStorage(app), mod }))
      .catch((e: unknown) => {
        storagePromise = null;
        throw e;
      });
  }
  return storagePromise;
}
