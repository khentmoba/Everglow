'use strict';

const common = require('./common.js');
const { applyCors, cappedHttps, enforceRateLimit, getAdmin, _getExternalCache, _setExternalCache } = common;

const CATALOG_CACHE_TTL_MS = 5 * 60 * 1000;
const CATALOG_MAX_BYTES = 2 * 1024 * 1024;
const CATALOG_MAX_CACHE_BYTES = 256 * 1024;

const _catalogBases = {
  openlibrary: 'https://openlibrary.org/',
  jikan: 'https://api.jikan.moe/v4/',
  itunes: 'https://itunes.apple.com/',
  aniskip: 'https://api.aniskip.com/',
  opentdb: 'https://opentdb.com/',
  gutendex: 'https://gutendex.com/',
  archive: 'https://archive.org/',
  anizip: 'https://api.ani.zip/',
  torrentio: 'https://torrentio.strem.fun/',
};

const _catalogNoStoreBases = new Set(['opentdb']);

function resolveCatalogUpstream(baseKey, pathParam) {
  const upstreamBase = _catalogBases[String(baseKey || '').toLowerCase()];
  if (!upstreamBase) throw new Error('base must be openlibrary, jikan, itunes, aniskip, opentdb, gutendex, archive, anizip, or torrentio');
  if (typeof pathParam !== 'string' || pathParam.length === 0) {
    throw new Error('Missing ?path=<api path> query param');
  }
  if (/(^|\/)\.\.(\/|$)/.test(pathParam)) throw new Error('Invalid path');
  const qIndex = pathParam.indexOf('?');
  const rawPath = qIndex === -1 ? pathParam : pathParam.slice(0, qIndex);
  const rawQuery = qIndex === -1 ? '' : pathParam.slice(qIndex + 1);
  if (/^[a-z][a-z0-9+.-]*:/i.test(rawPath) || /[\\#]/.test(rawPath) || rawPath.startsWith('//')) {
    throw new Error('Invalid path');
  }
  const safePath = rawPath.replace(/^\/+/, '');
  if (safePath.length === 0 || safePath.length > 200 || safePath.includes('//')) {
    throw new Error('Invalid path');
  }
  for (const segment of safePath.replace(/\/+$/, '').split('/')) {
    let decoded;
    try {
      decoded = decodeURIComponent(segment);
    } catch {
      throw new Error('Invalid path');
    }
    if (!decoded || decoded === '.' || decoded === '..' || /[/?#\\]/.test(decoded)) {
      throw new Error('Invalid path');
    }
  }
  const baseUrl = new URL(upstreamBase);
  const targetUrl = new URL(safePath, baseUrl);
  if (targetUrl.origin !== baseUrl.origin || !targetUrl.pathname.startsWith(baseUrl.pathname)) {
    throw new Error('Invalid path');
  }
  if (rawQuery) {
    const forwarded = new URLSearchParams(rawQuery);
    const credentialParams = new Set(['api_key', 'access_token', '__auth']);
    for (const key of new Set(forwarded.keys())) {
      if (credentialParams.has(key.toLowerCase())) forwarded.delete(key);
    }
    targetUrl.search = forwarded.toString();
  }
  if (targetUrl.search.length > 300) throw new Error('Invalid path');
  return targetUrl;
}

const proxyCatalog = cappedHttps(20, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'proxyCatalog', limit: 120, windowMs: 60000 })) return;
  const header = req.get('Authorization') || req.headers.authorization || '';
  const idToken = header ? String(header).replace(/^Bearer\s+/i, '') : '';
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken, true);
    } catch (e) {
      res.status(401).json({ error: 'Invalid or expired auth token' });
      return;
    }
  }

  let targetUrl;
  try {
    targetUrl = resolveCatalogUpstream(req.query.base, req.query.path);
  } catch (err) {
    res.status(400).json({ error: err.message || 'Invalid path' });
    return;
  }

  const noStore = _catalogNoStoreBases.has(String(req.query.base || '').toLowerCase());
  const cacheKey = `catalog:proxy:${targetUrl.toString()}`;
  if (!noStore) {
    const cached = _getExternalCache(cacheKey, CATALOG_CACHE_TTL_MS);
    if (cached) {
      res.status(cached.status);
      res.set('Content-Type', cached.contentType);
      res.set('X-Content-Type-Options', 'nosniff');
      res.set('Content-Security-Policy', "default-src 'none'; sandbox");
      res.set('Cache-Control', 'public, max-age=300');
      res.set('X-Cache', 'HIT');
      res.send(cached.body);
      return;
    }
  }

  try {
    const upstream = await common.fetchPublicUrl(targetUrl.toString(), {
      headers: {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(20000),
      httpsOnly: true,
      isAllowedUrl: (u) =>
        u.protocol === 'https:' &&
        (u.hostname === targetUrl.hostname || u.hostname.endsWith(`.${targetUrl.hostname}`)),
    });
    const body = await common.readLimitedText(upstream.body, CATALOG_MAX_BYTES);
    const rawCt = (upstream.headers.get('content-type') || 'application/json').split(';')[0].trim().toLowerCase();
    const contentType =
      rawCt === 'application/json' || rawCt === 'text/plain'
        ? `${rawCt}; charset=utf-8`
        : 'text/plain; charset=utf-8';
    if (!noStore && upstream.status === 200 && Buffer.byteLength(body, 'utf8') <= CATALOG_MAX_CACHE_BYTES) {
      _setExternalCache(cacheKey, { status: 200, contentType, body });
    }
    res.status(upstream.status);
    res.set('Content-Type', contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', "default-src 'none'; sandbox");
    res.set('Cache-Control', (noStore || upstream.status !== 200) ? 'private, no-store' : 'public, max-age=300');
    res.set('X-Cache', 'MISS');
    res.send(body);
  } catch (e) {
    console.warn(`proxyCatalog failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: 'Upstream fetch failed' });
  }
});

module.exports = { proxyCatalog, resolveCatalogUpstream };
