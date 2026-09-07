// Everglow lite — Tier 1 shell.
// Same Firebase project + server contract as the Flutter app.
// Reads: firestore.rules, functions/passcode.js, functions/media_proxies.js.

export const ANNIVERSARY = new Date(2026, 1, 14);

export const firebaseConfig = {
  apiKey: 'AIzaSyBMk0z4e-k_SAYzaLypYKJn3euwfx0fW5c',
  appId: '1:220334592353:web:6b31555509529613647520',
  messagingSenderId: '220334592353',
  projectId: 'everglow-1c6db',
  authDomain: 'everglow-1c6db.firebaseapp.com',
  storageBucket: 'everglow-1c6db.firebasestorage.app',
};

export const CDN = 'https://www.gstatic.com/firebasejs/11.6.1';

export function monthDay(d = new Date()) {
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${m}-${day}`;
}

export function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

export function fmtTime(ts) {
  try {
    const d = ts && typeof ts.toDate === 'function' ? ts.toDate() : new Date(ts);
    return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
  } catch {
    return '';
  }
}

export function errMsg(e) {
  const code = String((e && e.code) || '');
  if (code.includes('permission-denied')) return 'Not allowed with this login. Please re-enter your passcode.';
  if (code.includes('unavailable') || code.includes('failed-precondition')) return 'No connection. Try again in a moment.';
  return 'Something went wrong. Please try again.';
}

export function ageParts(now = new Date()) {
  let ms = now - ANNIVERSARY;
  if (ms < 0) ms = 0;
  const days = Math.floor(ms / 86400000);
  const years = Math.floor(days / 365.2425);
  const months = Math.floor((days - Math.floor(years * 365.2425)) / 30.436875);
  const rest = days - Math.floor(years * 365.2425) - Math.floor(months * 30.436875);
  const hours = Math.floor(ms / 3600000) % 24;
  const minutes = Math.floor(ms / 60000) % 60;
  const seconds = Math.floor(ms / 1000) % 60;
  return { years, months, days: rest, totalDays: days, hours, minutes, seconds };
}

export const session = {
  get username() { try { return localStorage.getItem('eg_user'); } catch { return null; } },
  set username(v) { try { v ? localStorage.setItem('eg_user', v) : localStorage.removeItem('eg_user'); } catch {} },
};

const mods = {};
let app = null;

async function firebaseApp() {
  if (!app) {
    const { initializeApp, getApps, getApp } = await import(`${CDN}/firebase-app.js`);
    app = getApps().length ? getApp() : initializeApp(firebaseConfig);
  }
  return app;
}

export async function auth() {
  if (!mods.auth) {
    const a = await firebaseApp();
    const m = await import(`${CDN}/firebase-auth.js`);
    mods.auth = { app: a, ...m, auth: m.getAuth(a) };
  }
  return mods.auth;
}

export async function db() {
  if (!mods.db) {
    const a = await firebaseApp();
    const m = await import(`${CDN}/firebase-firestore.js`);
    mods.db = m.getFirestore(a);
    mods.f = m;
  }
  return { db: mods.db, f: mods.f };
}

export async function storage() {
  if (!mods.st) {
    const a = await firebaseApp();
    const m = await import(`${CDN}/firebase-storage.js`);
    mods.st = { st: m.getStorage(a), ...m };
  }
  return mods.st;
}

let tokenCache = null;
let tokenAt = 0;
export async function getIdToken() {
  const now = Date.now();
  if (tokenCache && now - tokenAt < 4 * 60 * 1000) return tokenCache;
  const a = await auth();
  tokenCache = await a.auth.currentUser.getIdToken();
  tokenAt = now;
  return tokenCache;
}

export function galleryDisplayUrl(imageUrl) {
  if (typeof imageUrl === 'string' && imageUrl.includes('firebasestorage.googleapis.com')) {
    return `https://us-central1-everglow-1c6db.cloudfunctions.net/proxyGalleryImage?url=${encodeURIComponent(imageUrl)}`;
  }
  return imageUrl;
}
