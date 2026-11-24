'use strict';

const { applyCors, getAdmin, getVerifiedUsername, requireAuth, enforceRateLimit, cappedHttps } = require('./common.js');

const COUPLE_USERS = new Set(['khentsgdz', 'clairjassen']);
async function requireCoupleUser(decoded, res) {
  const username = await getVerifiedUsername(decoded);
  if (!COUPLE_USERS.has(username)) {
    res.status(403).json({ error: 'Spotify is only available to couple accounts' });
    return false;
  }
  return true;
}


function _normExpiresIn(data) {
  const n = Number(data && data.expires_in);
  return Number.isFinite(n) && n > 0 ? n : 3600;
}

function _getSpotifyCreds() {
  const id = (process.env.SPOTIFY_CLIENT_ID || '').trim();
  const secret = (process.env.SPOTIFY_CLIENT_SECRET || '').trim();
  return { id, secret };
}
let _spotifyTokenCache = null;
let _spotifyTokenInFlight = null;
async function _getSpotifyAppToken() {
  const { id, secret } = _getSpotifyCreds();
  if (!id || !secret) return null;
  if (_spotifyTokenCache && Date.now() < _spotifyTokenCache.expiresAt - 60000) return _spotifyTokenCache.token;
  if (_spotifyTokenInFlight) return _spotifyTokenInFlight;
  const basic = Buffer.from(id + ':' + secret).toString('base64');
  const task = (async () => {
    const res = await fetch('https://accounts.spotify.com/api/token', {
      method: 'POST',
      headers: { 'Authorization': 'Basic ' + basic, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'grant_type=client_credentials',
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) { console.warn('[spotify] token error', res.status, await res.text().catch(() => '')); return null; }
    const data = await res.json();
    if (!data || typeof data.access_token !== 'string' || !data.access_token) return null;
    const expiresInSec = _normExpiresIn(data);
    _spotifyTokenCache = { token: data.access_token, expiresAt: Date.now() + (expiresInSec * 1000) };
    return data.access_token;
  })();
  _spotifyTokenInFlight = task;
  try {
    return await task;
  } finally {
    if (_spotifyTokenInFlight === task) _spotifyTokenInFlight = null;
  }
}

const ALLOWED_SPOTIFY_REDIRECT_ORIGINS = new Set([
  'https://everglow-1c6db.web.app',
  'https://everglow-1c6db.firebaseapp.com',
]);

function isAllowedSpotifyRedirectUri(raw) {
  if (typeof raw !== 'string' || !raw.trim()) return false;
  try {
    const u = new URL(raw);
    if (u.pathname !== '/spotify/callback' || u.search || u.hash) return false;
    if (ALLOWED_SPOTIFY_REDIRECT_ORIGINS.has(u.origin)) return true;
    return /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(u.origin);
  } catch {
    return false;
  }
}

const proxySpotifySearch = cappedHttps(20, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');
  res.set('Cache-Control', 'private, no-store');
  res.set('Vary', 'Origin, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'Only GET' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (!(await requireCoupleUser(decoded, res))) return;
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
      if (!r.ok) {
        await r.body?.cancel?.().catch(() => {});
        res.status(r.status).json({ error: 'Spotify search failed ' + r.status });
        return;
      }
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
    if (!r.ok) {
      await r.body?.cancel?.().catch(() => {});
      res.status(r.status).json({ error: 'Spotify search failed ' + r.status });
      return;
    }
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
    res.status(502).json({ error: 'Spotify search failed' });
  }
});

const spotifyExchange = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS');
  res.set('Cache-Control', 'private, no-store');
  res.set('Vary', 'Origin, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (!(await requireCoupleUser(decoded, res))) return;
  if (enforceRateLimit(req, res, { endpoint: 'spotifyExchange', limit: 30, windowMs: 60000, uid: decoded.uid })) return;
  const { code, redirectUri, codeVerifier } = req.body || {};
  if (!code || !redirectUri) { res.status(400).json({ error: 'code and redirectUri required' }); return; }
  if (!isAllowedSpotifyRedirectUri(redirectUri)) { res.status(400).json({ error: 'Invalid redirectUri' }); return; }
  if (!codeVerifier || typeof codeVerifier !== 'string') { res.status(400).json({ error: 'codeVerifier required' }); return; }
  const { id } = _getSpotifyCreds();
  if (!id) { res.status(503).json({ error: 'Spotify not configured' }); return; }
  try {
    const params = new URLSearchParams({
      grant_type: 'authorization_code',
      code: String(code),
      redirect_uri: String(redirectUri),
      code_verifier: String(codeVerifier),
      client_id: id,
    });
    const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
    const r = await fetch('https://accounts.spotify.com/api/token', { method: 'POST', headers, body: params.toString(), signal: AbortSignal.timeout(10000) });
    const text = await r.text();
    if (!r.ok) {
      console.warn('[spotifyExchange]', r.status, text);
      const status = r.status >= 400 && r.status <= 599 ? r.status : 502;
      res.status(status).json({ error: 'Spotify token exchange failed' });
      return;
    }
    const data = JSON.parse(text);
    if (!data || typeof data.access_token !== 'string' || !data.access_token) {
      res.status(502).json({ error: 'Invalid Spotify token response' });
      return;
    }
    const expiresInSec = _normExpiresIn(data);
    const refreshToken = typeof data.refresh_token === 'string' && data.refresh_token ? data.refresh_token : null;
    const scope = typeof data.scope === 'string' ? data.scope : '';
    let profile = null;
    try {
      const pr = await fetch('https://api.spotify.com/v1/me', { headers: { 'Authorization': 'Bearer ' + data.access_token }, signal: AbortSignal.timeout(8000) });
      if (pr.ok) profile = await pr.json();
      else await pr.body?.cancel?.().catch(() => {});
    } catch (_) {}
    const doc = {
      access_token: data.access_token,
      refresh_token: refreshToken,
      expires_at: Date.now() + (expiresInSec * 1000),
      scope,
      spotify_user_id: profile ? profile.id : null,
      spotify_display_name: profile ? profile.display_name : null,
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    };
    const ref = getAdmin().firestore().collection('spotify_tokens').doc(decoded.uid);
    const existing = await ref.get();
    if (existing.exists && !refreshToken && existing.data().refresh_token) {
      doc.refresh_token = existing.data().refresh_token;
    }
    await ref.set(doc, { merge: true });
    res.json({ ok: true, expires_in: expiresInSec, spotify_user_id: doc.spotify_user_id });
  } catch (e) {
    console.warn('[spotifyExchange]', e.message);
    res.status(502).json({ error: 'Spotify token exchange failed' });
  }
});

const spotifyRefresh = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS');
  res.set('Cache-Control', 'private, no-store');
  res.set('Vary', 'Origin, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (!(await requireCoupleUser(decoded, res))) return;
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
    if (!r.ok) {
      console.warn('[spotifyRefresh]', r.status, text);
      const status = r.status >= 400 && r.status <= 599 ? r.status : 502;
      res.status(status).json({ error: 'Spotify token refresh failed' });
      return;
    }
    const data = JSON.parse(text);
    if (!data || typeof data.access_token !== 'string' || !data.access_token) {
      res.status(502).json({ error: 'Invalid Spotify token response' });
      return;
    }
    const expiresInSec = _normExpiresIn(data);
    const refreshToken = typeof data.refresh_token === 'string' && data.refresh_token ? data.refresh_token : null;
    const scope = typeof data.scope === 'string' && data.scope ? data.scope : (snap.data().scope || '');
    await ref.set({
      access_token: data.access_token,
      expires_at: Date.now() + (expiresInSec * 1000),
      scope,
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
      ...(refreshToken ? { refresh_token: refreshToken } : {}),
    }, { merge: true });
    res.json({ ok: true, expires_in: expiresInSec, access_token: data.access_token });
  } catch (e) {
    console.warn('[spotifyRefresh]', e.message);
    res.status(502).json({ error: 'Spotify token refresh failed' });
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

function _normRecentTrackKey(artist, track) {
  const norm = (s) => String(s || '').toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
  return `${norm(artist)}|${norm(track)}`;
}

function _mapSpotifyRecentItems(items, maxUnique = 10) {
  if (!Array.isArray(items)) return [];
  const mappedAll = [];
  for (const entry of items) {
    if (!entry || !entry.track) continue;
    const playedMs = entry.played_at ? Date.parse(entry.played_at) : NaN;
    const mapped = _mapSpotifyTrack(entry.track, {
      isPlaying: false,
      timestamp: Number.isFinite(playedMs) ? playedMs : null,
    });
    if (mapped && mapped.trackName) mappedAll.push(mapped);
  }
  mappedAll.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
  const out = [];
  const seen = new Set();
  for (const track of mappedAll) {
    const key = _normRecentTrackKey(track.artistName, track.trackName);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(track);
    if (out.length >= maxUnique) break;
  }
  return out;
}

const spotifyCurrentlyPlaying = cappedHttps(20, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');
  res.set('Cache-Control', 'private, no-store');
  res.set('Vary', 'Origin, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (!(await requireCoupleUser(decoded, res))) return;
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
            if (dd && typeof dd.access_token === 'string' && dd.access_token) {
              const expiresInSec = _normExpiresIn(dd);
              const refreshToken = typeof dd.refresh_token === 'string' && dd.refresh_token ? dd.refresh_token : null;
              token = dd.access_token;
              expiresAt = Date.now() + (expiresInSec * 1000);
              await ref.set(
                {
                  access_token: token,
                  expires_at: expiresAt,
                  updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                  ...(refreshToken ? { refresh_token: refreshToken } : {}),
                },
                { merge: true },
              );
            } else {
              console.warn('[spotifyCurrentlyPlaying] invalid refresh payload');
            }
          } else {
            await rr.body?.cancel?.().catch(() => {});
          }
        } catch (_) {}
      }
    }
    const authHeaders = { 'Authorization': 'Bearer ' + token };
    const [r, recentResp] = await Promise.all([
      fetch('https://api.spotify.com/v1/me/player/currently-playing', { headers: authHeaders, signal: AbortSignal.timeout(8000) }),
      includeRecent
        ? fetch('https://api.spotify.com/v1/me/player/recently-played?limit=50', { headers: authHeaders, signal: AbortSignal.timeout(8000) }).catch(() => null)
        : Promise.resolve(null),
    ]);
    let recentTracks = [];
    if (recentResp && recentResp.ok) {
      const recentData = await recentResp.json().catch(() => null);
      recentTracks = _mapSpotifyRecentItems(recentData && recentData.items);
    } else if (recentResp) {
      await recentResp.body?.cancel?.().catch(() => {});
    }
    const needsRecentScope = includeRecent && Boolean(recentResp && recentResp.status === 403);
    const extra = includeRecent ? { recentTracks, ...(needsRecentScope ? { needsRecentScope: true } : {}) } : {};
    if (r.status === 204) {
      await r.body?.cancel?.().catch(() => {});
      res.json({ connected: true, isPlaying: false, ...extra });
      return;
    }
    if (r.status === 401) {
      await r.body?.cancel?.().catch(() => {});
      res.json({ connected: true, isPlaying: false, needsReauth: true, ...extra });
      return;
    }
    if (!r.ok) {
      await r.body?.cancel?.().catch(() => {});
      res.status(r.status).json({ error: 'Spotify API ' + r.status });
      return;
    }
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
    res.status(502).json({ error: 'Spotify playback lookup failed' });
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

