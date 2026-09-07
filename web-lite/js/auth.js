import { auth, db, session } from './lib.js';

async function verifyPasscode(passcode) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 10000);
  try {
    const r = await fetch('https://us-central1-everglow-1c6db.cloudfunctions.net/verifyPasscode', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ passcode }),
      signal: ctrl.signal,
    });
    if (r.status === 401 || r.status === 400) return null;
    if (!r.ok) return undefined;
    const data = await r.json();
    if (!data || !data.token || !data.username) return undefined;
    return data;
  } catch {
    return undefined;
  } finally {
    clearTimeout(timer);
  }
}

export async function loginCouple(code) {
  const hit = await verifyPasscode(code);
  if (hit === undefined) throw new Error('unreachable');
  if (hit === null) return null;
  const a = await auth();
  await a.signInWithCustomToken(a.auth, hit.token);
  session.username = hit.username;
  await ensureUserDoc(hit.username);
  return hit.username;
}

export async function ensureUserDoc(username) {
  const u = (await auth()).auth.currentUser;
  if (!u || !username || username === 'breyan' || username === 'octagram') return;
  const { db: d, f } = await db();
  await f.setDoc(f.doc(d, 'users', u.uid), {
    username,
    partnerUsername: username === 'khentsgdz' ? 'clairjassen' : 'khentsgdz',
    updatedAt: f.serverTimestamp(),
  }, { merge: true });
}

export function displayName(username) {
  if (username === 'khentsgdz') return 'Khent';
  if (username === 'clairjassen') return 'Clair';
  return 'Love';
}

export function isCouple(username) {
  return username === 'khentsgdz' || username === 'clairjassen';
}

let ready = null;
export async function currentUser() {
  const a = await auth();
  if (a.auth.currentUser && !a.auth.currentUser.isAnonymous) return a.auth.currentUser;
  if (!ready) {
    ready = new Promise((resolve) => {
      const unsub = a.onAuthStateChanged(a.auth, (u) => {
        unsub();
        resolve(u && !u.isAnonymous ? u : null);
      });
      setTimeout(() => { try { unsub(); } catch {} resolve(a.auth.currentUser && !a.auth.currentUser.isAnonymous ? a.auth.currentUser : null); }, 3500);
    });
  }
  return ready;
}

export async function requireCouple(nav) {
  const u = await currentUser();
  if (!u || !isCouple(session.username)) {
    nav('#/');
    return null;
  }
  return u;
}

export async function logout() {
  ready = null;
  const a = await auth();
  try { await a.signOut(a.auth); } catch {}
  session.username = null;
}
