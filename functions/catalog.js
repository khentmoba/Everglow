'use strict';

const {
  applyCors,
  cappedHttps,
  getVerifiedUsername,
  requireAuth,
  enforceRateLimit,
  readLimitedText,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
} = require('./common.js');

const COUPLE_USERS = new Set(['khentsgdz', 'clairjassen']);
const CATALOG_MAX_BYTES = 2 * 1024 * 1024;
const CATALOG_MAX_CACHE_BYTES = 256 * 1024;
const SANDBOX_CSP = "default-src 'none'; sandbox";
const _inFlight = new Map();

async function fetchCatalogSingleflight(cacheKey, upstream, shouldCache) {
  let task = _inFlight.get(cacheKey);
  if (!task) {
    task = (async () => {
      const response = await fetch(upstream, { signal: AbortSignal.timeout(12000) });
      const body = await readLimitedText(response.body, CATALOG_MAX_BYTES);
      const rawCt = (response.headers.get('content-type') || 'application/json').split(';')[0].trim().toLowerCase();
      const contentType =
        rawCt === 'application/json' || rawCt === 'text/plain'
          ? `${rawCt}; charset=utf-8`
          : 'application/json; charset=utf-8';
      const entry = { status: response.status, contentType, body };
      if (shouldCache(entry) && Buffer.byteLength(body, 'utf8') <= CATALOG_MAX_CACHE_BYTES) {
        _setExternalCache(cacheKey, entry);
      }
      return entry;
    })();
    _inFlight.set(cacheKey, task);
    try {
      return await task;
    } finally {
      if (_inFlight.get(cacheKey) === task) _inFlight.delete(cacheKey);
    }
  }
  return await task;
}
const {
  buildLastfmUpstream,
  buildTmdbUpstream,
} = require('./media_proxy_core.js');

function externalCacheKey(prefix, upstream) {
  const query = [...upstream.searchParams.entries()]
    .filter(([name]) => name !== 'api_key')
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([name, value]) => `${name}=${value}`)
    .join('&');
  return `${prefix}${upstream.pathname}?${query}`;
}

function lastfmCacheTtlMs(method, period) {
  const m = String(method || '').toLowerCase();
  const p = String(period || 'overall').toLowerCase();
  if (m === 'user.getrecenttracks') return 30 * 1000;
  if (m === 'artist.getinfo' || m === 'artist.gettoptracks') return 30 * 60 * 1000;
  if (
    m === 'user.gettoptracks' ||
    m === 'user.gettopartists' ||
    m === 'user.gettopalbums'
  ) {
    return p === 'overall' ? 30 * 60 * 1000 : _EXTERNAL_CACHE_TTLS.lastfm;
  }
  return _EXTERNAL_CACHE_TTLS.lastfm;
}

const proxyTmdb = cappedHttps(20, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');
  res.set('Vary', 'Origin, Authorization');
  res.set('Cache-Control', 'private, no-store');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'proxyTmdb', limit: 300, windowMs: 60000, uid: decoded.uid })) return;

  const apiKey = (process.env.TMDB_API_KEY || '').trim();
  if (!apiKey) { res.status(503).json({ error: 'TMDB is not configured' }); return; }

  let upstream;
  try {
    upstream = buildTmdbUpstream(req.path, req.query, apiKey);
  } catch (_) {
    res.status(400).json({ error: 'Invalid TMDB path' });
    return;
  }

  const cacheKey = externalCacheKey('tmdb:proxy:', upstream);
  const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
  if (cached) {
    res.status(cached.status)
      .set('Content-Type', cached.contentType)
      .set('X-Content-Type-Options', 'nosniff')
      .set('Content-Security-Policy', SANDBOX_CSP)
      .set('Cache-Control', cached.status === 200 ? 'private, max-age=300' : 'private, no-store')
      .set('X-Cache', 'HIT')
      .send(cached.body);
    return;
  }

  try {
    const result = await fetchCatalogSingleflight(
      cacheKey,
      upstream,
      (entry) => entry.status === 200,
    );
    res.status(result.status)
      .set('Content-Type', result.contentType)
      .set('X-Content-Type-Options', 'nosniff')
      .set('Content-Security-Policy', SANDBOX_CSP)
      .set('Cache-Control', result.status === 200 ? 'private, max-age=300' : 'private, no-store')
      .set('X-Cache', 'MISS')
      .send(result.body);
  } catch (e) {
    console.warn('[proxyTmdb] failed:', e.message);
    res.status(502).json({ error: 'TMDB request failed' });
  }
});

const proxyLastfm = cappedHttps(20, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');
  res.set('Vary', 'Origin, Authorization');
  res.set('Cache-Control', 'private, no-store');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const username = await getVerifiedUsername(decoded);
  if (!COUPLE_USERS.has(username)) {
    res.status(403).json({ error: 'Last.fm is only available to couple accounts' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'proxyLastfm', limit: 120, windowMs: 60000, uid: decoded.uid })) return;

  const apiKey = (process.env.LASTFM_API_KEY || '').trim();
  if (!apiKey) { res.status(503).json({ error: 'Last.fm is not configured' }); return; }

  let upstream;
  try {
    upstream = buildLastfmUpstream(req.query, apiKey);
  } catch (e) {
    res.status(400).json({ error: e.message });
    return;
  }

  const cacheKey = externalCacheKey('lastfm:proxy:', upstream);
  const cached = _getExternalCache(
    cacheKey,
    lastfmCacheTtlMs(req.query.method, req.query.period),
  );
  if (cached) {
    res.status(cached.status)
      .set('Content-Type', cached.contentType)
      .set('X-Content-Type-Options', 'nosniff')
      .set('Content-Security-Policy', SANDBOX_CSP)
      .set('X-Cache', 'HIT')
      .send(cached.body);
    return;
  }

  try {
    const result = await fetchCatalogSingleflight(
      cacheKey,
      upstream,
      (entry) => entry.status === 200 && !entry.body.includes('"error":'),
    );
    res.status(result.status)
      .set('Content-Type', result.contentType)
      .set('X-Content-Type-Options', 'nosniff')
      .set('Content-Security-Policy', SANDBOX_CSP)
      .set('X-Cache', 'MISS')
      .send(result.body);
  } catch (e) {
    console.warn('[proxyLastfm] failed:', e.message);
    res.status(502).json({ error: 'Last.fm request failed' });
  }
});

module.exports = {
  proxyTmdb,
  proxyLastfm,
  lastfmCacheTtlMs,
  externalCacheKey,
};
