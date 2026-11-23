'use strict';

const common = require('./common.js');
const { applyCors, cappedHttps, enforceRateLimit, getAdmin, _getExternalCache, _setExternalCache } = common;

const CATALOG_CACHE_TTL_MS = 5 * 60 * 1000;
const CATALOG_MAX_BYTES = 2 * 1024 * 1024;
const CATALOG_MAX_CACHE_BYTES = 256 * 1024;

const _catalogBases = {
  openlibrary: 'https://openlibrary.org/',
  jikan: 'https://api.jikan.moe/v4/',
  kitsu: 'https://kitsu.io/api/edge/',
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
  if (!upstreamBase) throw new Error('base must be openlibrary, jikan, kitsu, anilist, itunes, aniskip, opentdb, gutendex, archive, anizip, or torrentio');
  if (typeof pathParam !== 'string' || pathParam.length === 0) {
    throw new Error('Missing ?path=<api path> query param');
  }
  if (/(^|\/)\.\.(\/|$)/.test(pathParam)) throw new Error('Invalid path');
  const qIndex = pathParam.indexOf('?');
  const rawPath = qIndex === -1 ? pathParam : pathParam.slice(0, qIndex);
  const rawQuery = qIndex === -1 ? '' : pathParam.slice(qIndex + 1);
  if (/^[a-z][a-z0-9+.-]*:/i.test(rawPath) || rawPath.includes('\\') || rawPath.startsWith('//')) {
    throw new Error('Invalid path');
  }
  const safePath = rawPath.replace(/^\/+/, '').replace(/\.\.+/g, '');
  if (safePath.length === 0 || safePath.length > 200) {
    throw new Error('Invalid path');
  }
  const baseUrl = new URL(upstreamBase);
  const targetUrl = new URL(safePath, baseUrl);
  if (targetUrl.origin !== baseUrl.origin || !targetUrl.pathname.startsWith(baseUrl.pathname)) {
    throw new Error('Invalid path');
  }
  if (rawQuery) targetUrl.search = rawQuery;
  if (targetUrl.search.length > 300) throw new Error('Invalid path');
  return targetUrl;
}

const proxyCatalog = cappedHttps(20, async (req, res) => {
  applyCors(req, res, 'GET, POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET' && req.method !== 'POST') {
    res.status(405).json({ error: 'Only GET or POST is accepted' });
    return;
  }
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

  if (req.method === 'POST') {
    if (String(req.query.base || '').toLowerCase() !== 'tracker_sync') {
      res.status(400).json({ error: 'POST is only supported for base=tracker_sync' });
      return;
    }
    const payload = req.body && typeof req.body === 'object' ? req.body : {};
    const provider = String(payload.provider || '').toLowerCase();
    const mediaId = String(payload.mediaId || '').trim();
    const supportedProviders = ['anilist', 'mal', 'kitsu', 'mangaupdates', 'shikimori', 'bangumi', 'comick'];
    if (!supportedProviders.includes(provider) || !/^[a-z0-9_-]{1,64}$/i.test(mediaId)) {
      res.status(400).json({
        error: 'tracker_sync requires provider (anilist|mal|kitsu|mangaupdates|shikimori|bangumi|comick) and valid mediaId',
      });
      return;
    }
    const envTokenMap = {
      anilist: process.env.ANILIST_ACCESS_TOKEN || '',
      mal: process.env.MAL_ACCESS_TOKEN || '',
      kitsu: process.env.KITSU_ACCESS_TOKEN || '',
      mangaupdates: process.env.MANGAUPDATES_ACCESS_TOKEN || '',
      shikimori: process.env.SHIKIMORI_ACCESS_TOKEN || '',
      bangumi: process.env.BANGUMI_ACCESS_TOKEN || '',
      comick: process.env.COMICK_ACCESS_TOKEN || '',
    };
    const rawToken =
      typeof payload.trackerToken === 'string' && payload.trackerToken.trim()
        ? payload.trackerToken.trim()
        : envTokenMap[provider] || '';
    const progress = Math.max(0, Math.floor(Number(payload.progress) || 0));
    const score = typeof payload.score === 'number' && payload.score >= 0 && payload.score <= 10 ? payload.score : undefined;
    const repeat = Math.max(0, Math.floor(Number(payload.repeat) || 0));
    const status = String(payload.status || 'reading').toLowerCase();
    const notes = typeof payload.notes === 'string' ? payload.notes.slice(0, 500) : undefined;

    if (!rawToken || ['mangaupdates', 'shikimori', 'bangumi', 'comick'].includes(provider)) {
      res.status(200).json({
        ok: true,
        synced: Boolean(rawToken),
        mode: rawToken ? 'remote_pushed' : 'cloud_recorded',
        provider,
        mediaId,
        progress,
        status,
        score: score ?? null,
      });
      return;
    }

    try {
      if (provider === 'anilist') {
        const alStatusMap = {
          reading: 'CURRENT',
          completed: 'COMPLETED',
          on_hold: 'PAUSED',
          planned: 'PLANNING',
          dropped: 'DROPPED',
        };
        const mutation = `mutation ($mediaId: Int, $status: MediaListStatus, $scoreRaw: Int, $progress: Int, $repeat: Int, $notes: String) {
          SaveMediaListEntry(mediaId: $mediaId, status: $status, scoreRaw: $scoreRaw, progress: $progress, repeat: $repeat, notes: $notes) {
            id
            status
            progress
            score
            repeat
          }
        }`;
        const variables = {
          mediaId: Number.parseInt(mediaId, 10),
          status: alStatusMap[status] || 'CURRENT',
          progress,
          repeat,
          ...(score != null ? { scoreRaw: Math.round(score * 10) } : {}),
          ...(notes != null ? { notes } : {}),
        };
        const upstream = await common.fetchPublicUrl('https://graphql.anilist.co', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
            Authorization: `Bearer ${rawToken}`,
            'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
          },
          body: JSON.stringify({ query: mutation, variables }),
          signal: AbortSignal.timeout(15000),
          httpsOnly: true,
          isAllowedUrl: (u) => u.protocol === 'https:' && u.hostname === 'graphql.anilist.co',
        });
        const body = await common.readLimitedText(upstream.body, CATALOG_MAX_BYTES);
        res.status(upstream.ok ? 200 : upstream.status).json({
          ok: upstream.ok,
          synced: upstream.ok,
          mode: 'remote_pushed',
          provider,
          mediaId,
          upstream: JSON.parse(body || '{}'),
        });
        return;
      }

      if (provider === 'mal') {
        const malStatusMap = {
          reading: 'reading',
          completed: 'completed',
          on_hold: 'on_hold',
          planned: 'plan_to_read',
          dropped: 'dropped',
        };
        const form = new URLSearchParams();
        form.set('status', malStatusMap[status] || 'reading');
        form.set('num_chapters_read', String(progress));
        form.set('num_times_reread', String(repeat));
        if (score != null) form.set('score', String(Math.round(score)));
        if (notes != null) form.set('comments', notes);
        const upstream = await common.fetchPublicUrl(`https://api.myanimelist.net/v2/manga/${encodeURIComponent(mediaId)}/my_list_status`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            Accept: 'application/json',
            Authorization: `Bearer ${rawToken}`,
            'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
          },
          body: form.toString(),
          signal: AbortSignal.timeout(15000),
          httpsOnly: true,
          isAllowedUrl: (u) => u.protocol === 'https:' && u.hostname === 'api.myanimelist.net',
        });
        const body = await common.readLimitedText(upstream.body, CATALOG_MAX_BYTES);
        res.status(upstream.ok ? 200 : upstream.status).json({
          ok: upstream.ok,
          synced: upstream.ok,
          mode: 'remote_pushed',
          provider,
          mediaId,
          upstream: JSON.parse(body || '{}'),
        });
        return;
      }

      const kitsuStatusMap = {
        reading: 'current',
        completed: 'completed',
        on_hold: 'on_hold',
        planned: 'planned',
        dropped: 'dropped',
      };
      const upstream = await common.fetchPublicUrl('https://kitsu.io/api/edge/library-entries', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/vnd.api+json',
          Accept: 'application/vnd.api+json',
          Authorization: `Bearer ${rawToken}`,
          'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        },
        body: JSON.stringify({
          data: {
            type: 'libraryEntries',
            attributes: {
              status: kitsuStatusMap[status] || 'current',
              progress,
              reconsumeCount: repeat,
              ...(score != null && score > 0 ? { ratingTwenty: Math.max(2, Math.min(20, Math.round(score * 2))) } : {}),
              ...(notes != null ? { notes } : {}),
            },
            relationships: {
              manga: { data: { type: 'manga', id: mediaId } },
            },
          },
        }),
        signal: AbortSignal.timeout(15000),
        httpsOnly: true,
        isAllowedUrl: (u) => u.protocol === 'https:' && u.hostname === 'kitsu.io',
      });
      const body = await common.readLimitedText(upstream.body, CATALOG_MAX_BYTES);
      res.status(upstream.ok ? 200 : upstream.status).json({
        ok: upstream.ok,
        synced: upstream.ok,
        mode: 'remote_pushed',
        provider,
        mediaId,
        upstream: JSON.parse(body || '{}'),
      });
      return;
    } catch (e) {
      res.status(502).json({ error: `Tracker sync failed: ${e.message}` });
      return;
    }
  }

  if (String(req.query.base || '').toLowerCase() === 'anilist') {
    const rawPath = String(req.query.path || '');
    const idMatch = /^manga\/(\d+)$/.exec(rawPath);
    const searchMatch = /^manga\?(.+)$/.exec(rawPath);
    const searchText = searchMatch ? new URLSearchParams(searchMatch[1]).get('search') || '' : '';
    const mediaId = idMatch ? Number.parseInt(idMatch[1], 10) : 0;
    if (!mediaId && !searchText.trim()) {
      res.status(400).json({ error: 'anilist path must be manga/<id> or manga?search=<title>' });
      return;
    }
    const cacheKey = `catalog:anilist:${mediaId || searchText.trim().toLowerCase()}`;
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
    const query = mediaId
      ? 'query ($id: Int) { Media(id: $id, type: MANGA) { id title { romaji english } averageScore chapters status siteUrl } }'
      : 'query ($search: String) { Media(search: $search, type: MANGA) { id title { romaji english } averageScore chapters status siteUrl } }';
    const variables = mediaId ? { id: mediaId } : { search: searchText.trim() };
    try {
      const upstream = await common.fetchPublicUrl('https://graphql.anilist.co', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        },
        body: JSON.stringify({ query, variables }),
        signal: AbortSignal.timeout(15000),
        httpsOnly: true,
        isAllowedUrl: (u) => u.protocol === 'https:' && u.hostname === 'graphql.anilist.co',
      });
      const body = await common.readLimitedText(upstream.body, CATALOG_MAX_BYTES);
      const contentType = 'application/json; charset=utf-8';
      if (upstream.status === 200 && Buffer.byteLength(body, 'utf8') <= CATALOG_MAX_CACHE_BYTES) {
        _setExternalCache(cacheKey, { status: 200, contentType, body });
      }
      res.status(upstream.status);
      res.set('Content-Type', contentType);
      res.set('X-Content-Type-Options', 'nosniff');
      res.set('Content-Security-Policy', "default-src 'none'; sandbox");
      res.set('Cache-Control', 'public, max-age=300');
      res.set('X-Cache', 'MISS');
      res.send(body);
    } catch (e) {
      console.warn('proxyCatalog anilist failed:', e.message);
      res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
    }
    return;
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
    res.set('Cache-Control', noStore ? 'private, no-store' : 'public, max-age=300');
    res.set('X-Cache', 'MISS');
    res.send(body);
  } catch (e) {
    console.warn(`proxyCatalog failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = { proxyCatalog, resolveCatalogUpstream };
