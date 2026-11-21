'use strict';

const { applyCors, getAdmin, requireAuth, enforceRateLimit, cappedHttps } = require('./common.js');


function _getSpotifyCreds() {
  const id = (process.env.SPOTIFY_CLIENT_ID || '').trim();
  const secret = (process.env.SPOTIFY_CLIENT_SECRET || '').trim();
  return { id, secret };
}
let _spotifyTokenCache = null;
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

const proxySpotifySearch = cappedHttps(20, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'Only GET' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'proxySpotifySearch', limit: 120, windowMs: 60000, uid: decoded.uid })) return;
  const q = String(req.query.query || '').trim();
  const artist = String(req.query.artist || '').trim();
  const track = String(req.query.track || '').trim();
  const type = String(req.query.type || 'track').trim().toLowerCase();
  const query = q || (artist && track ? artist + ' ' + track : '') || artist || track;
  if (!query) { res.status(400).json({ error: 'Missing query or artist/track' }); return; }
  try {
    const token = await _getSpotifyAppToken();
    if (!token) { res.status(503).json({ error: 'Spotify not configured' }); return; }
    if (type === 'artist') {
      const name = artist || query;
      const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: name, type: 'artist', limit: '5', market: 'US' }).toString();
      const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(10000) });
      if (!r.ok) { res.status(r.status).json({ error: 'Spotify search failed ' + r.status }); return; }
      const data = await r.json();
      const items = data.artists && data.artists.items;
      if (!Array.isArray(items) || items.length === 0) { res.json({ artistId: null, query: name }); return; }
      const norm = (s) => String(s || '').toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
      const targetNorm = norm(name);
      let best = items[0];
      for (const it of items) {
        if (it && norm(it.name) === targetNorm) { best = it; break; }
      }
      const img = best.images && best.images[0] ? best.images[0].url : null;
      res.json({
        artistId: best.id || null,
        artistName: best.name || name,
        imageUrl: img,
        followers: (best.followers && best.followers.total) || 0,
        spotifyUrl: (best.external_urls && best.external_urls.spotify) || ('https://open.spotify.com/artist/' + best.id),
        query: name,
      });
      return;
    }
    const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: query, type: 'track', limit: '5', market: 'US' }).toString();
    const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(10000) });
    if (!r.ok) { res.status(r.status).json({ error: 'Spotify search failed ' + r.status }); return; }
    const data = await r.json();
    const items = data.tracks && data.tracks.items;
    if (!Array.isArray(items) || items.length === 0) { res.json({ trackId: null, query }); return; }
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

const spotifyExchange = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'spotifyExchange', limit: 30, windowMs: 60000, uid: decoded.uid })) return;
  const { code, redirectUri, codeVerifier } = req.body || {};
  if (!code || !redirectUri) { res.status(400).json({ error: 'code and redirectUri required' }); return; }
  const { id, secret } = _getSpotifyCreds();
  if (!id) { res.status(503).json({ error: 'Spotify not configured' }); return; }
  try {
    const params = new URLSearchParams({ grant_type: 'authorization_code', code: String(code), redirect_uri: String(redirectUri) });
    if (codeVerifier) params.set('code_verifier', String(codeVerifier));
    else if (secret) params.set('client_secret', secret);
    params.set('client_id', id);
    const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
    if (secret && !codeVerifier) headers['Authorization'] = 'Basic ' + Buffer.from(id + ':' + secret).toString('base64');
    const r = await fetch('https://accounts.spotify.com/api/token', { method: 'POST', headers, body: params.toString(), signal: AbortSignal.timeout(10000) });
    const text = await r.text();
    if (!r.ok) { console.warn('[spotifyExchange]', r.status, text); res.status(r.status).json({ error: text }); return; }
    const data = JSON.parse(text);
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

const spotifyRefresh = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'spotifyRefresh', limit: 30, windowMs: 60000, uid: decoded.uid })) return;
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

function _mapSpotifyTrack(item, { isPlaying = false, timestamp = Date.now() } = {}) {
  if (!item) return null;
  const img = (item.album && item.album.images && item.album.images[0] && item.album.images[0].url) || null;
  return {
    trackId: item.id || null,
    trackName: item.name || '',
    artistName: (item.artists && item.artists[0] && item.artists[0].name) || '',
    albumName: (item.album && item.album.name) || '',
    imageUrl: img,
    previewUrl: item.preview_url || null,
    spotifyUrl: (item.external_urls && item.external_urls.spotify) || (item.id ? 'https://open.spotify.com/track/' + item.id : ''),
    embedUrl: item.id ? 'https://open.spotify.com/embed/track/' + item.id : null,
    durationMs: item.duration_ms || null,
    isPlaying: !!isPlaying,
    timestamp,
  };
}

function _mapSpotifyRecentItems(items) {
  if (!Array.isArray(items)) return [];
  const out = [];
  for (const entry of items) {
    if (!entry || !entry.track) continue;
    const playedMs = entry.played_at ? Date.parse(entry.played_at) : NaN;
    const mapped = _mapSpotifyTrack(entry.track, {
      isPlaying: false,
      timestamp: Number.isFinite(playedMs) ? playedMs : null,
    });
    if (mapped && mapped.trackName) out.push(mapped);
  }
  return out;
}

const spotifyCurrentlyPlaying = cappedHttps(20, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'spotifyCurrentlyPlaying', limit: 120, windowMs: 60000, uid: decoded.uid })) return;
  const includeRecent = req.query.includeRecent === '1' || req.query.includeRecent === 'true';
  try {
    const ref = getAdmin().firestore().collection('spotify_tokens').doc(decoded.uid);
    const snap = await ref.get();
    if (!snap.exists || !snap.data().access_token) { res.json({ connected: false }); return; }
    let token = snap.data().access_token;
    let expiresAt = snap.data().expires_at || 0;
    if (Date.now() > expiresAt - 60000) {
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
    const authHeaders = { 'Authorization': 'Bearer ' + token };
    const [r, recentResp] = await Promise.all([
      fetch('https://api.spotify.com/v1/me/player/currently-playing', { headers: authHeaders, signal: AbortSignal.timeout(8000) }),
      includeRecent
        ? fetch('https://api.spotify.com/v1/me/player/recently-played?limit=5', { headers: authHeaders, signal: AbortSignal.timeout(8000) }).catch(() => null)
        : Promise.resolve(null),
    ]);
    let recentTracks = [];
    if (recentResp && recentResp.ok) {
      const recentData = await recentResp.json().catch(() => null);
      recentTracks = _mapSpotifyRecentItems(recentData && recentData.items);
    }
    const needsRecentScope = includeRecent && Boolean(recentResp && recentResp.status === 403);
    const extra = includeRecent ? { recentTracks, ...(needsRecentScope ? { needsRecentScope: true } : {}) } : {};
    if (r.status === 204) { res.json({ connected: true, isPlaying: false, ...extra }); return; }
    if (r.status === 401) { res.json({ connected: true, isPlaying: false, needsReauth: true, ...extra }); return; }
    if (!r.ok) { res.status(r.status).json({ error: 'Spotify API ' + r.status }); return; }
    const data = await r.json();
    const mapped = _mapSpotifyTrack(data.item, { isPlaying: !!data.is_playing, timestamp: Date.now() });
    if (!mapped) { res.json({ connected: true, isPlaying: !!data.is_playing, ...extra }); return; }
    res.json({
      connected: true,
      progressMs: data.progress_ms,
      ...mapped,
      ...extra,
    });
  } catch (e) {
    console.warn('[spotifyCurrentlyPlaying]', e.message);
    res.status(502).json({ error: e.message });
  }
});

module.exports = {
  getSpotifyAppToken: _getSpotifyAppToken,
  proxySpotifySearch,
  spotifyExchange,
  spotifyRefresh,
  spotifyCurrentlyPlaying,
  _mapSpotifyRecentItems,
};

