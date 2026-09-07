import { db, getIdToken } from './lib.js';

const DIRECT = 'https://us-central1-everglow-1c6db.cloudfunctions.net';
const SCOPES = [
  'user-read-playback-state',
  'user-read-currently-playing',
].join(' ');

const VERIFIER_KEY = 'eg_spotify_verifier';

let clientIdCache = null;

export async function spotifyClientId() {
  if (clientIdCache) return clientIdCache;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 10000);
  try {
    const token = await getIdToken();
    for (const base of ['', DIRECT]) {
      try {
        const r = await fetch(`${base}/api/spotifyClientId`, {
          headers: { Authorization: `Bearer ${token}` },
          signal: ctrl.signal,
        });
        if (!r.ok) continue;
        const data = await r.json();
        if (data && data.clientId) {
          clientIdCache = data.clientId;
          return clientIdCache;
        }
      } catch { /* try next base */ }
    }
    return null;
  } finally {
    clearTimeout(timer);
  }
}

function redirectUri() {
  return `${location.origin}/#/spotify/callback`;
}

function randVerifier() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  const bytes = new Uint8Array(64);
  crypto.getRandomValues(bytes);
  return [...bytes].map((b) => chars[b % chars.length]).join('');
}

async function challengeFor(verifier) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return btoa(String.fromCharCode(...new Uint8Array(digest)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export async function linkSpotify() {
  const clientId = await spotifyClientId();
  if (!clientId) throw new Error('unconfigured');
  const verifier = randVerifier();
  sessionStorage.setItem(VERIFIER_KEY, verifier);
  const url = new URL('https://accounts.spotify.com/authorize');
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('redirect_uri', redirectUri());
  url.searchParams.set('scope', SCOPES);
  url.searchParams.set('code_challenge_method', 'S256');
  url.searchParams.set('code_challenge', await challengeFor(verifier));
  location.assign(url.toString());
}

export async function handleSpotifyCallback() {
  const params = new URLSearchParams(location.hash.split('?')[1] || '');
  const code = params.get('code');
  const error = params.get('error');
  if (error) return { ok: false, error };
  if (!code) return { ok: false, error: 'No code returned' };
  const verifier = sessionStorage.getItem(VERIFIER_KEY);
  try {
    const token = await getIdToken();
    const body = { code, redirectUri: redirectUri() };
    if (verifier) body.codeVerifier = verifier;
    for (const base of ['', DIRECT]) {
      try {
        const ctrl = new AbortController();
        const timer = setTimeout(() => ctrl.abort(), 12000);
        const r = await fetch(`${base}/api/spotifyExchange`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
          body: JSON.stringify(body),
          signal: ctrl.signal,
        });
        clearTimeout(timer);
        if (r.status === 404) continue;
        if (!r.ok) return { ok: false, error: `Link failed (${r.status})` };
        sessionStorage.removeItem(VERIFIER_KEY);
        return { ok: true };
      } catch { /* try next base */ }
    }
    return { ok: false, error: 'Link failed — try again' };
  } catch {
    return { ok: false, error: 'Link failed — try again' };
  }
}

export async function linkStatus(uid) {
  try {
    const { db: d, f } = await db();
    const s = await f.getDoc(f.doc(d, 'spotify_tokens', uid));
    if (!s.exists()) return { linked: false };
    const c = s.data();
    return {
      linked: !!(c && c.access_token),
      name: (c && (c.spotify_display_name || c.spotify_user_id)) || null,
    };
  } catch {
    return { linked: false };
  }
}

export async function currentlyPlaying() {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 10000);
  try {
    const token = await getIdToken();
    for (const base of ['', DIRECT]) {
      try {
        const r = await fetch(`${base}/api/spotifyCurrentlyPlaying`, {
          headers: { Authorization: `Bearer ${token}` },
          signal: ctrl.signal,
        });
        if (r.status === 404) continue;
        if (!r.ok) return null;
        return r.json();
      } catch { /* try next base */ }
    }
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export async function unlinkSpotify(uid) {
  try {
    const { db: d, f } = await db();
    await f.deleteDoc(f.doc(d, 'spotify_tokens', uid));
  } catch { /* best-effort */ }
}
