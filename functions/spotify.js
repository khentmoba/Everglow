// ===== Spotify: Client Credentials search + User OAuth (Duo) =====
'use strict';

const functions = require('firebase-functions/v1');

const { getAdmin, requireAuth } = require('./common.js');


// ===== Spotify: Client Credentials search + User OAuth (Duo) =====
function _getSpotifyCreds() {
  const id = (process.env.SPOTIFY_CLIENT_ID || '').trim() || (functions.config().spotify && functions.config().spotify.client_id) || '';
  const secret = (process.env.SPOTIFY_CLIENT_SECRET || '').trim() || (functions.config().spotify && functions.config().spotify.client_secret) || '';
  return { id, secret };
}
let _spotifyTokenCache = null; // { token, expiresAt }
async function _getSpotifyAppToken() {
  const { id, secret } = _getSpotifyCreds();
  if (!id || !secret) return null;
  if (_spotifyTokenCache && Date.now() < _spotifyTokenCache.expiresAt - 60000) return _spotifyTokenCache.token;
  const basic = Buffer.from(id + ':' + secret).toString('base64');
  const res = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: { 'Authorization': 'Basic ' + basic, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=client_credentials',
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) { console.warn('[spotify] token error', res.status, await res.text().catch(()=>'')); return null; }
  const data = await res.json();
  _spotifyTokenCache = { token: data.access_token, expiresAt: Date.now() + (data.expires_in * 1000) };
  return data.access_token;
}

/**
 * Resolves a track to a real Spotify ID via Client Credentials.
 * GET /proxySpotifySearch?query=Artist+Track  OR  ?artist=...&track=...
 * Auth required. Returns { trackId, trackName, artistName, albumName, imageUrl, previewUrl, spotifyUrl, embedUrl }.
 */
const proxySpotifySearch = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'Only GET' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const q = String(req.query.query || '').trim();
  const artist = String(req.query.artist || '').trim();
  const track = String(req.query.track || '').trim();
  const query = q || (artist && track ? artist + ' ' + track : '') || artist || track;
  if (!query) { res.status(400).json({ error: 'Missing query or artist/track' }); return; }
  const token = await _getSpotifyAppToken();
  if (!token) { res.status(503).json({ error: 'Spotify not configured' }); return; }
  try {
    const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: query, type: 'track', limit: '5', market: 'US' }).toString();
    const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(10000) });
    if (!r.ok) { res.status(r.status).json({ error: 'Spotify search failed ' + r.status }); return; }
    const data = await r.json();
    const items = data.tracks && data.tracks.items;
    if (!Array.isArray(items) || items.length === 0) { res.json({ trackId: null, query }); return; }
    // Prefer exact-ish match on track name
    const norm = (s) => s.toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
    const targetNorm = norm(track || query);
    let best = items[0];
    for (const it of items) {
      if (track && norm(it.name) === targetNorm) { best = it; break; }
    }
    const img = best.album && best.album.images && best.album.images[0] ? best.album.images[0].url : null;
    res.json({
      trackId: best.id,
      trackName: best.name,
      artistName: (best.artists && best.artists[0] && best.artists[0].name) || '',
      albumName: (best.album && best.album.name) || '',
      imageUrl: img,
      previewUrl: best.preview_url || null,
      durationMs: best.duration_ms || null,
      spotifyUrl: 'https://open.spotify.com/track/' + best.id,
      embedUrl: 'https://open.spotify.com/embed/track/' + best.id,
      query,
    });
  } catch (e) {
    console.warn('[proxySpotifySearch]', e.message);
    res.status(502).json({ error: e.message });
  }
});

/**
 * OAuth Authorization Code exchange (PKCE supported).
 * POST /spotifyExchange { code, redirectUri, codeVerifier? }
 * Auth required. Exchanges code for access/refresh tokens, stores in Firestore spotify_tokens/{uid}.
 */
const spotifyExchange = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const { code, redirectUri, codeVerifier } = req.body || {};
  if (!code || !redirectUri) { res.status(400).json({ error: 'code and redirectUri required' }); return; }
  const { id, secret } = _getSpotifyCreds();
  if (!id) { res.status(503).json({ error: 'Spotify not configured' }); return; }
  try {
    const params = new URLSearchParams({ grant_type: 'authorization_code', code: String(code), redirect_uri: String(redirectUri) });
    if (codeVerifier) params.set('code_verifier', String(codeVerifier));
    else if (secret) params.set('client_secret', secret);
    // Spotify requires client_id always
    params.set('client_id', id);
    const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
    if (secret && !codeVerifier) headers['Authorization'] = 'Basic ' + Buffer.from(id + ':' + secret).toString('base64');
    const r = await fetch('https://accounts.spotify.com/api/token', { method: 'POST', headers, body: params.toString(), signal: AbortSignal.timeout(10000) });
    const text = await r.text();
    if (!r.ok) { console.warn('[spotifyExchange]', r.status, text); res.status(r.status).json({ error: text }); return; }
    const data = JSON.parse(text);
    // Fetch profile to store display name
    let profile = null;
    try {
      const pr = await fetch('https://api.spotify.com/v1/me', { headers: { 'Authorization': 'Bearer ' + data.access_token }, signal: AbortSignal.timeout(8000) });
      if (pr.ok) profile = await pr.json();
    } catch (_) {}
    const doc = {
      access_token: data.access_token,
      refresh_token: data.refresh_token || null,
      expires_at: Date.now() + (data.expires_in * 1000),
      scope: data.scope || '',
      spotify_user_id: profile ? profile.id : null,
      spotify_display_name: profile ? profile.display_name : null,
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    };
    // Only overwrite refresh_token if we got a new one
    const ref = getAdmin().firestore().collection('spotify_tokens').doc(decoded.uid);
    const existing = await ref.get();
    if (existing.exists && !data.refresh_token && existing.data().refresh_token) doc.refresh_token = existing.data().refresh_token;
    await ref.set(doc, { merge: true });
    res.json({ ok: true, expires_in: data.expires_in, spotify_user_id: doc.spotify_user_id });
  } catch (e) {
    console.warn('[spotifyExchange]', e.message);
    res.status(502).json({ error: e.message });
  }
});

/**
 * Refreshes a stored Spotify token.
 * POST /spotifyRefresh  (no body; uses stored refresh_token)
 * Auth required.
 */
const spotifyRefresh = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const { id, secret } = _getSpotifyCreds();
  if (!id) { res.status(503).json({ error: 'Spotify not configured' }); return; }
  try {
    const ref = getAdmin().firestore().collection('spotify_tokens').doc(decoded.uid);
    const snap = await ref.get();
    if (!snap.exists || !snap.data().refresh_token) { res.status(404).json({ error: 'No refresh token' }); return; }
    const rt = snap.data().refresh_token;
    const params = new URLSearchParams({ grant_type: 'refresh_token', refresh_token: rt, client_id: id });
    const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
    if (secret) headers['Authorization'] = 'Basic ' + Buffer.from(id + ':' + secret).toString('base64');
    const r = await fetch('https://accounts.spotify.com/api/token', { method: 'POST', headers, body: params.toString(), signal: AbortSignal.timeout(10000) });
    const text = await r.text();
    if (!r.ok) { console.warn('[spotifyRefresh]', r.status, text); res.status(r.status).json({ error: text }); return; }
    const data = JSON.parse(text);
    await ref.set({
      access_token: data.access_token,
      expires_at: Date.now() + (data.expires_in * 1000),
      scope: data.scope || snap.data().scope || '',
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
      ...(data.refresh_token ? { refresh_token: data.refresh_token } : {}),
    }, { merge: true });
    res.json({ ok: true, expires_in: data.expires_in, access_token: data.access_token });
  } catch (e) {
    console.warn('[spotifyRefresh]', e.message);
    res.status(502).json({ error: e.message });
  }
});

/**
 * Proxies Spotify currently-playing for authenticated user (server-side token).
 * GET /spotifyCurrentlyPlaying
 * Useful if client prefers server to fetch with stored token (avoids exposing token to JS).
 */
const spotifyCurrentlyPlaying = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  try {
    const ref = getAdmin().firestore().collection('spotify_tokens').doc(decoded.uid);
    const snap = await ref.get();
    if (!snap.exists || !snap.data().access_token) { res.json({ connected: false }); return; }
    let token = snap.data().access_token;
    let expiresAt = snap.data().expires_at || 0;
    if (Date.now() > expiresAt - 60000) {
      // try refresh inline
      const { id, secret } = _getSpotifyCreds();
      const rt = snap.data().refresh_token;
      if (rt && id) {
        try {
          const params = new URLSearchParams({ grant_type: 'refresh_token', refresh_token: rt, client_id: id });
          const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
          if (secret) headers['Authorization'] = 'Basic ' + Buffer.from(id + ':' + secret).toString('base64');
          const rr = await fetch('https://accounts.spotify.com/api/token', { method: 'POST', headers, body: params.toString(), signal: AbortSignal.timeout(10000) });
          if (rr.ok) {
            const dd = await rr.json();
            token = dd.access_token;
            expiresAt = Date.now() + (dd.expires_in * 1000);
            await ref.set({ access_token: token, expires_at: expiresAt, updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(), ...(dd.refresh_token ? { refresh_token: dd.refresh_token } : {}) }, { merge: true });
          }
        } catch (_) {}
      }
    }
    const r = await fetch('https://api.spotify.com/v1/me/player/currently-playing', { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(8000) });
    if (r.status === 204) { res.json({ connected: true, isPlaying: false }); return; }
    if (r.status === 401) { res.json({ connected: true, isPlaying: false, needsReauth: true }); return; }
    if (!r.ok) { res.status(r.status).json({ error: 'Spotify API ' + r.status }); return; }
    const data = await r.json();
    const item = data.item;
    if (!item) { res.json({ connected: true, isPlaying: !!data.is_playing }); return; }
    res.json({
      connected: true,
      isPlaying: !!data.is_playing,
      progressMs: data.progress_ms,
      trackId: item.id,
      trackName: item.name,
      artistName: (item.artists && item.artists[0] && item.artists[0].name) || '',
      albumName: (item.album && item.album.name) || '',
      imageUrl: (item.album && item.album.images && item.album.images[0] && item.album.images[0].url) || null,
      spotifyUrl: item.external_urls && item.external_urls.spotify,
      embedUrl: 'https://open.spotify.com/embed/track/' + item.id,
      durationMs: item.duration_ms,
      timestamp: Date.now(),
    });
  } catch (e) {
    console.warn('[spotifyCurrentlyPlaying]', e.message);
    res.status(502).json({ error: e.message });
  }
});

module.exports = {
  proxySpotifySearch,
  spotifyExchange,
  spotifyRefresh,
  spotifyCurrentlyPlaying,
};

