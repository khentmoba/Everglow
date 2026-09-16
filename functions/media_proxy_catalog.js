'use strict';

const { cappedHttps, enforceRateLimit, getAdmin } = require('./common.js');

/**
 * Generic allow-listed JSON catalog proxy for keyless public APIs
 * (Open Library, Jikan, iTunes, AniSkip). The client passes ?base=<openlibrary|jikan|itunes|aniskip> and
 * ?path=<api path with query>. Only those hosts are reachable;
 * auth is optional (validated when present) like proxyMangaDex.
 *
 *   GET /proxyCatalog?base=openlibrary&path=search.json%3Fq%3D...%26limit%3D20
 *   GET /proxyCatalog?base=jikan&path=anime%3Fq%3D...%26limit%3D20
 *   GET /proxyCatalog?base=itunes&path=search%3Fterm%3D...%26entity%3Dsong%26media%3Dmusic
 *   GET /proxyCatalog?base=aniskip&path=v1%2Fskip-times%2F5114%2F1%3Ftypes%5B%5D%3Dop
 *   GET /proxyCatalog?base=opentdb&path=api.php%3Famount%3D50%26category%3D9
 *   GET /proxyCatalog?base=gutendex&path=books%3Fsearch%3Ddune
 *   GET /proxyCatalog?base=archive&path=advancedsearch.php%3Fq%3D...%26output%3Djson
 *   GET /proxyCatalog?base=anizip&path=mappings%3Fmal_id%3D16498
 *
 * The pure parts (base allow-list, path sanitize, URL build) live in
 * [resolveCatalogUpstream] below so unit tests cover them without
 * stubbing firebase-functions' onRequest wrapper.
 */
const _catalogBases = {
  openlibrary: 'https://openlibrary.org/',
  jikan: 'https://api.jikan.moe/v4/',
  itunes: 'https://itunes.apple.com/',
  aniskip: 'https://api.aniskip.com/',
  opentdb: 'https://opentdb.com/',
  gutendex: 'https://gutendex.com/',
  archive: 'https://archive.org/',
  anizip: 'https://api.ani.zip/',
};

// Sessionful upstreams must never edge-cache: OpenTDB hands out a
// per-user session token and advances it on every question call, so a
// cached response would share tokens across players and repeat questions.
const _catalogNoStoreBases = new Set(['opentdb']);

function resolveCatalogUpstream(baseKey, pathParam) {
  const upstreamBase = _catalogBases[String(baseKey || '').toLowerCase()];
  if (!upstreamBase) throw new Error('base must be openlibrary, jikan, itunes, aniskip, opentdb, gutendex, archive, or anizip');
  if (typeof pathParam !== 'string' || pathParam.length === 0) {
    throw new Error('Missing ?path=<api path> query param');
  }
  if (/(^|\/)\.\.(\/|$)/.test(pathParam)) throw new Error('Invalid path');
  const qIndex = pathParam.indexOf('?');
  const rawPath = qIndex === -1 ? pathParam : pathParam.slice(0, qIndex);
  const rawQuery = qIndex === -1 ? '' : pathParam.slice(qIndex + 1);
  const safePath = rawPath.replace(/^\/+/, '').replace(/\.\.+/g, '');
  if (safePath.length === 0 || safePath.length > 200) {
    throw new Error('Invalid path');
  }
  const targetUrl = new URL(safePath, upstreamBase);
  if (rawQuery) targetUrl.search = rawQuery;
  if (targetUrl.search.length > 300) throw new Error('Invalid path');
  return targetUrl;
}

const proxyCatalog = cappedHttps(20, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  // Anonymous-tolerant by design (native clients without a token still
  // need covers). Upstreams like Jikan are strict (3/sec), so keep the
  // per-IP cap modest.
  if (enforceRateLimit(req, res, { endpoint: 'proxyCatalog', limit: 120, windowMs: 60000 })) return;
  const header = req.get('Authorization') || req.headers.authorization || '';
  const idToken = header ? String(header).replace(/^Bearer\s+/i, '') : '';
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
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

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(20000),
    });
    const body = await upstream.text();
    res.status(upstream.status);
    res.set(
      'Content-Type',
      upstream.headers.get('content-type') || 'application/json',
    );
    const _noStore = _catalogNoStoreBases.has(String(req.query.base || '').toLowerCase());
    res.set('Cache-Control', _noStore ? 'private, no-store' : 'public, max-age=300');
    res.send(body);
  } catch (e) {
    console.warn(`proxyCatalog failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = { proxyCatalog, resolveCatalogUpstream };
