'use strict';

// Everglow Cloud Functions — catalog group.
// TMDB (cinema) + Last.fm (jukebox) proxies. Both keep API keys
// server-side and require a Firebase ID token.

const functions = require('firebase-functions/v1');

const {
  requireAuth,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
} = require('./common.js');
const {
  buildLastfmUpstream,
  buildTmdbUpstream,
} = require('./media_proxy_core.js');

/**
 * Authenticated TMDB metadata proxy. The client supplies the normal TMDB path
 * after /proxyTmdb (for example: /trending/all/week); any client api_key is
 * ignored and replaced server-side so the browser bundle never contains it.
 */
// No minInstances (cost): cold start ~1-2s is fine for metadata lookups.
const proxyTmdb = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  // Authenticated per-user responses stay private, but the CDN may serve
  // the identical TMDB catalog payload across users for 5 minutes. The
  // browser still revalidates via the in-memory instance cache below;
  // this header only lets Google's edge absorb repeat opens.
  res.set('Cache-Control', 'private, max-age=0, s-maxage=300');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const apiKey = (process.env.TMDB_API_KEY || '').trim();
  if (!apiKey) { res.status(503).json({ error: 'TMDB is not configured' }); return; }

  let upstream;
  try {
    upstream = buildTmdbUpstream(req.path, req.query, apiKey);
  } catch (_) {
    res.status(400).json({ error: 'Invalid TMDB path' });
    return;
  }

  // TMDB metadata is public and slow-moving: cache it per instance so the
  // ~30 calls behind one Cinema open (and repeat opens) don't each pay a
  // TMDB round trip. Auth + path validation above still run on every call;
  // only HTTP 200 bodies are cached. TTL lives in common.js (10m for TMDB).
  const cacheProbe = new URL(upstream.toString());
  cacheProbe.searchParams.delete('api_key');
  cacheProbe.searchParams.sort();
  const cacheKey = `tmdb:proxy:${cacheProbe.pathname}?${cacheProbe.searchParams.toString()}`;
  const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
  if (cached) {
    res.status(cached.status)
      .set('Content-Type', cached.contentType)
      .set('X-Cache', 'HIT')
      .send(cached.body);
    return;
  }

  try {
    const response = await fetch(upstream, { signal: AbortSignal.timeout(12000) });
    const body = await response.text();
    const contentType = response.headers.get('content-type') || 'application/json';
    if (response.status === 200) {
      _setExternalCache(cacheKey, { status: 200, contentType, body });
    }
    res.status(response.status)
      .set('Content-Type', contentType)
      .set('X-Cache', 'MISS')
      .send(body);
  } catch (e) {
    console.warn('[proxyTmdb] failed:', e.message);
    res.status(502).json({ error: 'TMDB request failed' });
  }
});

/**
 * Authenticated read-only Last.fm proxy. Only public catalog/user lookup
 * methods are allowed; the API key stays in Cloud Functions.
 */
// No minInstances (cost): cold start ~1-2s is fine for catalog lookups.
const proxyLastfm = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Cache-Control', 'private, no-store');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const apiKey = (process.env.LASTFM_API_KEY || '').trim();
  if (!apiKey) { res.status(503).json({ error: 'Last.fm is not configured' }); return; }

  let upstream;
  try {
    upstream = buildLastfmUpstream(req.query, apiKey);
  } catch (e) {
    res.status(400).json({ error: e.message });
    return;
  }
  try {
    const response = await fetch(upstream, { signal: AbortSignal.timeout(12000) });
    const body = await response.text();
    res.status(response.status)
      .set('Content-Type', response.headers.get('content-type') || 'application/json')
      .send(body);
  } catch (e) {
    console.warn('[proxyLastfm] failed:', e.message);
    res.status(502).json({ error: 'Last.fm request failed' });
  }
});

module.exports = {
  proxyTmdb,
  proxyLastfm,
};
