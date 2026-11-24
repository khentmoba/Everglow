'use strict';

const common = require('./common.js');
const {
  applyCors,
  cappedHttps,
  enforceRateLimit,
  getAdmin,
  requireAuth,
  _getExternalCache,
  _setExternalCache,
} = common;
const { resolveRasterImageStream, streamMediaBody } = require('./stream_media_body');

const SANDBOX_CSP = "default-src 'none'; sandbox";
const MANGA_API_CACHE_TTL_MS = 60 * 1000;
const MANGA_API_MAX_CACHE_BYTES = 256 * 1024;

function resolveMangaApiUrl(origin, pathParam) {
  if (typeof pathParam !== 'string' || pathParam.length === 0) {
    throw new Error('Missing ?path=<api path> query param');
  }
  if (/(^|\/)\.\.(\/|$)/.test(pathParam)) {
    throw new Error('Invalid path');
  }
  const qIndex = pathParam.indexOf('?');
  const rawPath = qIndex === -1 ? pathParam : pathParam.slice(0, qIndex);
  const rawQuery = qIndex === -1 ? '' : pathParam.slice(qIndex + 1);
  if (/^[a-z][a-z0-9+.-]*:/i.test(rawPath) || rawPath.includes('\\') || rawPath.startsWith('//')) {
    throw new Error('Invalid path');
  }
  const safePath = rawPath.replace(/^\/+/, '').replace(/\.\.+/g, '');
  if (safePath.length === 0 || safePath.length > 400) {
    throw new Error('Invalid path');
  }
  const baseUrl = new URL(`${origin}/`);
  const targetUrl = new URL(safePath, baseUrl);
  if (targetUrl.origin !== baseUrl.origin) {
    throw new Error('Invalid path');
  }
  if (rawQuery) targetUrl.search = rawQuery;
  return targetUrl.toString();
}

function safeJsonContentType(raw) {
  const base = String(raw || 'application/json').split(';')[0].trim().toLowerCase();
  return base === 'application/json' || base === 'text/plain'
    ? `${base}; charset=utf-8`
    : 'text/plain; charset=utf-8';
}

const proxyMangaImage = cappedHttps(30, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'proxyMangaImage', limit: 240, windowMs: 60000 })) return;
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







  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }
  const allowedHosts = new Set([
    'uploads.mangadex.org',
  ]);
  const allowedSuffixes = ['.mangadex.network', '.mangadex.org'];
  const isAllowedMangaDex = (u) => {
    const h = u.hostname.toLowerCase();
    return allowedHosts.has(h) || allowedSuffixes.some((s) => h.endsWith(s));
  };
  if (parsed.protocol !== 'https:' || !isAllowedMangaDex(parsed)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await common.fetchPublicUrl(targetUrl, {
      headers: { 'Accept': 'image/*,*/*;q=0.8' },
      signal: AbortSignal.timeout(20000),
      httpsOnly: true,
      isAllowedUrl: isAllowedMangaDex,
    });
    if (!upstream.ok) {
      await upstream.body?.cancel().catch(() => {});
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const resolved = await resolveRasterImageStream(upstream);
    if (!resolved) {
      res.status(415).json({ error: 'Upstream did not return a raster image' });
      return;
    }
    res.set('Content-Type', resolved.contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', SANDBOX_CSP);
    res.set('Cache-Control', 'public, max-age=600');
    await streamMediaBody(resolved.body, res);
  } catch (e) {
    console.warn(`proxyMangaImage failed (${targetUrl}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

const proxyMangaKakalotImage = cappedHttps(30, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'proxyMangaKakalotImage', limit: 240, windowMs: 60000 })) return;
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







  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  const allowedSuffixes = [
    '.mangakakalot.com',
    '.mkklcdnv6temp.com',
  ];
  const isAllowedKakalot = (u) => {
    const h = u.hostname.toLowerCase();
    return allowedSuffixes.some((s) => h.endsWith(s));
  };
  if (parsed.protocol !== 'https:' || !isAllowedKakalot(parsed)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await common.fetchPublicUrl(targetUrl, {
      headers: { 'Accept': 'image/*,*/*;q=0.8', 'Referer': 'https://mangakakalot.com/' },
      signal: AbortSignal.timeout(20000),
      httpsOnly: true,
      isAllowedUrl: isAllowedKakalot,
    });
    if (!upstream.ok) {
      await upstream.body?.cancel().catch(() => {});
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const resolved = await resolveRasterImageStream(upstream);
    if (!resolved) {
      res.status(415).json({ error: 'Upstream did not return a raster image' });
      return;
    }
    res.set('Content-Type', resolved.contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', SANDBOX_CSP);
    res.set('Cache-Control', 'public, max-age=600');
    await streamMediaBody(resolved.body, res);
  } catch (e) {
    console.warn(`proxyMangaKakalotImage failed (${targetUrl}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

const proxyMangaKatana = cappedHttps(30, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'proxyMangaKatana', limit: 240, windowMs: 60000 })) return;
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







  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  const allowedSuffixes = [
    '.mangakatana.com',
    '.mangakakalot.com',
    '.mkklcdnv6temp.com',
    '.catmanga.org',
  ];
  const isAllowedKatana = (u) => {
    const h = u.hostname.toLowerCase();
    return h === 'mangakatana.com' || allowedSuffixes.some((s) => h.endsWith(s));
  };
  if (parsed.protocol !== 'https:' || !isAllowedKatana(parsed)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await common.fetchPublicUrl(targetUrl, {
      headers: { 'Accept': 'image/*,*/*;q=0.8', 'Referer': 'https://mangakatana.com/' },
      signal: AbortSignal.timeout(20000),
      httpsOnly: true,
      isAllowedUrl: isAllowedKatana,
    });
    if (!upstream.ok) {
      await upstream.body?.cancel().catch(() => {});
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const resolved = await resolveRasterImageStream(upstream);
    if (!resolved) {
      res.status(415).json({ error: 'Upstream did not return a raster image' });
      return;
    }
    res.set('Content-Type', resolved.contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', SANDBOX_CSP);
    res.set('Cache-Control', 'public, max-age=600');
    await streamMediaBody(resolved.body, res);
  } catch (e) {
    console.warn(`proxyMangaKatana failed (${targetUrl}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

const proxyComick = cappedHttps(30, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');
  res.set('Cache-Control', 'private, no-store');
  res.set('Vary', 'Origin, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'proxyComick', limit: 240, windowMs: 60000, uid: decoded.uid })) return;







  let targetUrl;
  try {
    targetUrl = resolveMangaApiUrl('https://api.comick.dev', req.query.path);
  } catch (err) {
    res.status(400).json({ error: err.message || 'Invalid path' });
    return;
  }

  const cacheKey = `comick:proxy:${targetUrl}`;
  const cached = _getExternalCache(cacheKey, MANGA_API_CACHE_TTL_MS);
  if (cached) {
    res.status(cached.status);
    res.set('Content-Type', cached.contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', SANDBOX_CSP);
    res.set('Cache-Control', 'private, max-age=60');
    res.set('X-Cache', 'HIT');
    res.send(cached.body);
    return;
  }

  try {
    const upstream = await common.fetchPublicUrl(targetUrl, {
      headers: {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(20000),
      httpsOnly: true,
      isAllowedUrl: (u) => u.hostname.toLowerCase() === 'api.comick.dev',
    });
    const body = await common.readLimitedText(upstream.body, 2 * 1024 * 1024);
    const contentType = safeJsonContentType(upstream.headers.get('content-type'));
    if (upstream.status === 200 && Buffer.byteLength(body, 'utf8') <= MANGA_API_MAX_CACHE_BYTES) {
      _setExternalCache(cacheKey, { status: 200, contentType, body });
    }
    res.status(upstream.status);
    res.set('Content-Type', contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', SANDBOX_CSP);
    res.set('Cache-Control', 'private, max-age=60');
    res.set('X-Cache', 'MISS');
    res.send(body);
  } catch (e) {
    console.warn(`proxyComick failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

const proxyMangaDex = cappedHttps(30, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');
  res.set('Cache-Control', 'private, no-store');
  res.set('Vary', 'Origin, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'proxyMangaDex', limit: 240, windowMs: 60000, uid: decoded.uid })) return;







  let targetUrl;
  try {
    targetUrl = resolveMangaApiUrl('https://api.mangadex.org', req.query.path);
  } catch (err) {
    res.status(400).json({ error: err.message || 'Invalid path' });
    return;
  }

  const cacheKey = `mangadex:proxy:${targetUrl}`;
  const cached = _getExternalCache(cacheKey, MANGA_API_CACHE_TTL_MS);
  if (cached) {
    res.status(cached.status);
    res.set('Content-Type', cached.contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', SANDBOX_CSP);
    res.set('Cache-Control', 'private, max-age=60');
    res.set('X-Cache', 'HIT');
    res.send(cached.body);
    return;
  }

  try {
    const upstream = await common.fetchPublicUrl(targetUrl, {
      headers: {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(20000),
      httpsOnly: true,
      isAllowedUrl: (u) => u.hostname.toLowerCase() === 'api.mangadex.org',
    });
    const body = await common.readLimitedText(upstream.body, 2 * 1024 * 1024);
    const contentType = safeJsonContentType(upstream.headers.get('content-type'));
    if (upstream.status === 200 && Buffer.byteLength(body, 'utf8') <= MANGA_API_MAX_CACHE_BYTES) {
      _setExternalCache(cacheKey, { status: 200, contentType, body });
    }
    res.status(upstream.status);
    res.set('Content-Type', contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', SANDBOX_CSP);
    res.set('Cache-Control', 'private, max-age=60');
    res.set('X-Cache', 'MISS');
    res.send(body);
  } catch (e) {
    console.warn(`proxyMangaDex failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = {
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyMangaDex,
  resolveMangaApiUrl,
};
