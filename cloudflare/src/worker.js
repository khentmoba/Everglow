import {
  failHtml,
  hlsPlayerHtml,
  isMegaPlayHost,
  megavidHeaders,
  megaplayHeaders,
  cinemaHeaders,
  CINEMA_PROVIDERS,
  resolveCinema,
  resolveEverglow,
  resolveMegaPlay,
  resolveMegavid,
  resolveYumeZone,
  rewriteCinemaPlaylist,
  rewritePlaylistWithHosts,
  scopedTarget,
  srtToVtt,
  stripAdCues,
  filterTsPmtAudio,
  validateAnimeParams,
} from './anime.js';
import { yumeHeaders } from './yumezone.js';

const ALLOWED_ORIGINS = new Set([
  'https://everglow-1c6db.web.app',
  'https://everglow-1c6db.firebaseapp.com',
]);

const WORKER_RATE_BUCKETS = new Map();

function isAllowedOriginUrl(raw, selfOrigin) {
  if (!raw) return false;
  try {
    const origin = new URL(raw).origin;
    if (ALLOWED_ORIGINS.has(origin) || (selfOrigin && origin === selfOrigin)) return true;
    return /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);
  } catch {
    return false;
  }
}

function checkWorkerRateLimit(request, bucket, limit, windowMs = 60_000) {
  const ip =
    request?.headers?.get('cf-connecting-ip') ||
    request?.headers?.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    'unknown';
  const now = Date.now();
  const key = `${bucket}:${ip}`;
  let entry = WORKER_RATE_BUCKETS.get(key);
  if (!entry || now >= entry.resetAt) {
    if (WORKER_RATE_BUCKETS.size >= 2000) {
      for (const [k, v] of WORKER_RATE_BUCKETS) {
        if (now >= v.resetAt) WORKER_RATE_BUCKETS.delete(k);
      }
      while (WORKER_RATE_BUCKETS.size >= 2000) {
        const oldest = WORKER_RATE_BUCKETS.keys().next().value;
        if (oldest === undefined) break;
        WORKER_RATE_BUCKETS.delete(oldest);
      }
    }
    entry = { count: 1, resetAt: now + windowMs };
    WORKER_RATE_BUCKETS.set(key, entry);
    return false;
  }
  entry.count += 1;
  return entry.count > limit;
}

function corsHeaders(request) {
  const origin = request?.headers?.get('origin') || '';
  let selfOrigin = '';
  try {
    selfOrigin = request?.url ? new URL(request.url).origin : '';
  } catch (_) {}
  const allowOrigin =
    origin && isAllowedOriginUrl(origin, selfOrigin)
      ? origin
      : 'https://everglow-1c6db.web.app';
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Vary': 'Origin',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, Range',
    'Access-Control-Expose-Headers': 'Content-Range, Content-Length, Accept-Ranges',
    'Access-Control-Max-Age': '86400',
  };
}

function htmlResponse(body, status, request) {
  return new Response(body, {
    status,
    headers: { ...corsHeaders(request), 'Content-Type': 'text/html; charset=utf-8' },
  });
}

function jsonResponse(body, status, request) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(request), 'Content-Type': 'application/json' },
  });
}

function proxyBase(request) {
  return `${new URL(request.url).origin}/proxyMegavidHls`;
}

function getEdgeCache() {
  return typeof caches !== 'undefined' && caches && caches.default ? caches.default : null;
}

function cachePut(ctx, cache, key, response) {
  if (!cache || !key || !response) return;
  const p = Promise.resolve(cache.put(key, response)).catch(() => {});
  if (ctx && typeof ctx.waitUntil === 'function') ctx.waitUntil(p);
}

function withFreshCors(headers, cors) {
  const out = new Headers(headers);
  for (const [k, v] of Object.entries(cors)) out.set(k, v);
  return out;
}

function resolveCacheKey(params, selfOrigin) {
  const path =
    params.source === 'cinema'
      ? `cinema/${params.mediaType}/${params.tmdbId}/${params.season}/${params.ep}/${params.server || 'auto'}/${params.lang || ''}`
      : `${params.source}/${params.anilistId}/${params.malId}/${params.ep}/${params.audio}/${params.server || 'auto'}`;
  return new Request(
    `https://cache.everglow.internal/resolve/v1/${path}?origin=${encodeURIComponent(selfOrigin)}`,
  );
}

function hlsCacheKey(provider, selfOrigin, target, audioLang = '') {
  const a = audioLang ? `&a=${encodeURIComponent(audioLang)}` : '';
  return new Request(
    `https://cache.everglow.internal/hls/v1/${encodeURIComponent(provider)}?origin=${encodeURIComponent(selfOrigin)}&target=${encodeURIComponent(target)}${a}`,
  );
}

async function prewarmPlaylists(prefetched, base, selfOrigin, sealKey, edgeCache, ctx) {
  if (!edgeCache || !sealKey || !Array.isArray(prefetched) || !prefetched.length) return;
  const work = Promise.all(
    prefetched.map(async (item) => {
      if (!item || !item.url || !item.text || !item.text.includes('#EXTM3U')) return;
      try {
        const provider = item.provider || 'megavid';
        const audioLang = item.audioLang || '';
        const megaplay =
          provider === 'megaplay' ||
          (!CINEMA_PROVIDERS.has(provider) && isMegaPlayHost(new URL(item.url).hostname));
        const rewritten = megaplay
          ? await rewritePlaylistWithHosts(item.text, item.url, base, 'megaplay', sealKey, audioLang)
          : await rewriteCinemaPlaylist(item.text, item.url, base, provider, sealKey, audioLang);
        const key = hlsCacheKey(provider, selfOrigin, item.url, audioLang);
        const res = new Response(rewritten, {
          status: 200,
          headers: {
            'Content-Type': 'application/vnd.apple.mpegurl',
            'X-Content-Type-Options': 'nosniff',
            'Content-Security-Policy': "default-src 'none'; sandbox",
            'Cache-Control': 'public, max-age=45',
          },
        });
        await edgeCache.put(key, res);
      } catch {}
    }),
  ).catch(() => {});
  if (ctx && typeof ctx.waitUntil === 'function') ctx.waitUntil(work);
}

async function handleProxyAnime(request, env, ctx) {
  const cors = corsHeaders(request);
  if (request.method === 'OPTIONS') {
    return new Response('', { status: 204, headers: cors });
  }
  if (request.method !== 'GET') {
    return htmlResponse(failHtml('Method not allowed', 'GET only.'), 405, request);
  }
  const selfOrigin = new URL(request.url).origin;
  const reqOrigin = request.headers.get('origin');
  const reqReferer = request.headers.get('referer');
  if (
    (reqOrigin && !isAllowedOriginUrl(reqOrigin, selfOrigin)) ||
    (reqReferer && !isAllowedOriginUrl(reqReferer, selfOrigin))
  ) {
    return jsonResponse({ error: 'Forbidden origin' }, 403, request);
  }
  if (checkWorkerRateLimit(request, 'proxyAnime', 60)) {
    return jsonResponse({ error: 'Too many requests' }, 429, request);
  }

  const query = Object.fromEntries(new URL(request.url).searchParams);
  const wantsJson = String(query.format || '').toLowerCase() === 'json';
  const params = validateAnimeParams(query);
  const notify = String(query.source || '').toLowerCase() === 'cinema';
  if (params.error) {
    return wantsJson
      ? jsonResponse({ error: params.error }, 400, request)
      : htmlResponse(failHtml('Bad request', params.error, { notify }), 400, request);
  }

  const base = proxyBase(request);
  const key = env.CDN_STAMP_KEY || null;
  const sendFail = (msg) => {
    console.warn(`[proxyAnime] ${params.source}: ${msg}`);
    return wantsJson
      ? jsonResponse({ error: msg }, 502, request)
      : htmlResponse(failHtml('Episode unavailable', msg, { notify }), 502, request);
  };

  const edgeCache = getEdgeCache();
  const bypassCache = query.fresh === '1';
  const resCacheKey = edgeCache && key && !bypassCache ? resolveCacheKey(params, selfOrigin) : null;

  try {
    let out = null;
    if (resCacheKey) {
      try {
        const hit = await edgeCache.match(resCacheKey);
        if (hit && hit.ok) {
          const parsed = await hit.json();
          if (parsed && parsed.src) out = parsed;
        }
      } catch {}
    }

    if (!out) {
      if (params.source === 'yumezone') {
        out = await resolveYumeZone(
          params.anilistId,
          params.ep,
          params.audio,
          params.server,
          base,
          key,
        );
      } else if (params.source === 'megavid') {
        out = await resolveMegavid(
          params.anilistId,
          params.malId,
          params.ep,
          params.audio,
          base,
          key,
        );
      } else if (params.source === 'megaplay') {
        out = await resolveMegaPlay(
          params.anilistId,
          params.malId,
          params.ep,
          params.audio,
          base,
          key,
        );
      } else if (params.source === 'everglow') {
        out = await resolveEverglow(
          params.anilistId,
          params.malId,
          params.ep,
          params.audio,
          params.server,
          base,
          key,
        );
      } else {
        out = await resolveCinema(
          params.mediaType,
          params.tmdbId,
          params.season,
          params.ep,
          base,
          key,
          { server: params.server, lang: params.lang },
        );
      }
      if (!out || !out.src) throw new Error('resolver returned no src');
      if (edgeCache && key) {
        prewarmPlaylists(out.prefetched, base, selfOrigin, key, edgeCache, ctx);
        if (resCacheKey) {
          const ttl = out.server === 'megaplay' ? 30 : 90;
          const cachedPayload = {
            src: out.src,
            tracks: Array.isArray(out.tracks) ? out.tracks : [],
            title: out.title,
            ep: out.ep,
            server: out.server || '',
            servers: Array.isArray(out.servers) ? out.servers : [],
          };
          cachePut(
            ctx,
            edgeCache,
            resCacheKey,
            new Response(JSON.stringify(cachedPayload), {
              status: 200,
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Cache-Control': `public, max-age=${ttl}`,
              },
            }),
          );
        }
      }
    }
    const isCinema = params.source === 'cinema';
    const named = String(query.title || '').replace(/\s+/g, ' ').trim().slice(0, 120);
    const title = isCinema && named
      ? params.mediaType === 'tv' ? `${named} · ${out.title}` : named
      : out.title;
    if (wantsJson) {
      return new Response(
        JSON.stringify({
          src: out.src,
          tracks: Array.isArray(out.tracks) ? out.tracks : [],
          title,
          ep: out.ep,
          hasEpisodes: isCinema && params.mediaType === 'tv',
          servers: Array.isArray(out.servers) ? out.servers : [],
          current: out.server || '',
        }),
        {
          status: 200,
          headers: {
            ...cors,
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'no-store',
          },
        },
      );
    }
    const page = hlsPlayerHtml({
      src: out.src,
      tracks: out.tracks,
      title,
      kind: isCinema ? 'cinema' : 'anime',
      hasEpisodes: isCinema && params.mediaType === 'tv',
      token: '',
      ep: out.ep,
      audio: params.audio,
      servers: Array.isArray(out.servers) ? out.servers : [],
      current: out.server || '',
    });
    return new Response(page, {
      status: 200,
      headers: {
        ...cors,
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'private, no-store',
        'Content-Security-Policy':
          "frame-ancestors 'self' https://everglow-1c6db.web.app https://everglow-1c6db.firebaseapp.com http://localhost:* http://127.0.0.1:*",
      },
    });
  } catch (e) {
    console.warn('[proxyAnime] resolve failed:', e && e.message);
    return sendFail('No stream found — try another server.');
  }
}

function isBlockedRedirectHost(hostname) {
  const h = hostname.toLowerCase().replace(/^\[|\]$/g, '');
  if (!h || h === 'localhost' || h.endsWith('.localhost') || h.endsWith('.local') || h.endsWith('.internal')) return true;
  if (/^(\d{1,3}\.){3}\d{1,3}$/.test(h)) {
    const [a, b, c] = h.split('.').map(Number);
    if (a === 0 || a === 10 || a === 127 || a >= 224) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 0 && c === 0) return true;
    if (a === 192 && b === 168) return true;
    if (a === 198 && (b === 18 || b === 19)) return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
  }
  if (h.includes(':')) {
    if (h === '::1' || h === '::' || /^fe[89ab][0-9a-f]:/i.test(h) || h.startsWith('fc') || h.startsWith('fd') || h.startsWith('::ffff:') || h.startsWith('64:ff9b:')) {
      return true;
    }
  }
  return false;
}

async function fetchPublicHls(initialTarget, initialHeaders, signal, method = 'GET') {
  let current = new URL(initialTarget);
  const reqHeaders = { ...initialHeaders };
  for (let hop = 0; hop <= 5; hop++) {
    if (current.protocol !== 'https:' || current.username || current.password || isBlockedRedirectHost(current.hostname)) {
      throw new Error('Redirect host not allowed');
    }
    const resp = await fetch(current.toString(), {
      method,
      headers: reqHeaders,
      redirect: 'manual',
      signal,
    });
    if ([301, 302, 303, 307, 308].includes(resp.status)) {
      const loc = resp.headers.get('location');
      await resp.body?.cancel().catch(() => {});
      if (!loc || hop === 5) throw new Error('Invalid or excessive redirects');
      const next = new URL(loc, current);
      if (next.origin !== current.origin) {
        for (const key of Object.keys(reqHeaders)) {
          const lower = key.toLowerCase();
          if (lower === 'referer' || lower === 'cookie' || lower === 'authorization') {
            delete reqHeaders[key];
          }
        }
      }
      current = next;
      continue;
    }
    return resp;
  }
  throw new Error('Excessive redirects');
}

async function readLimitedText(response, maxBytes) {
  const makeTooLarge = () => {
    const err = new Error('Upstream response exceeded size limit');
    err.code = 'TOO_LARGE';
    return err;
  };
  if (!response.body || typeof response.body.getReader !== 'function') {
    const text = await response.text();
    if (new TextEncoder().encode(text).byteLength > maxBytes) {
      throw makeTooLarge();
    }
    return text;
  }
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let total = 0;
  let out = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel().catch(() => {});
      throw makeTooLarge();
    }
    out += decoder.decode(value, { stream: true });
  }
  out += decoder.decode();
  return out;
}

const DISALLOWED_MEDIA_CT_RE =
  /^(text\/html|application\/xhtml\+xml|image\/svg\+xml|text\/xml|application\/xml|text\/javascript|application\/javascript|text\/ecmascript|application\/ecmascript)$/;

async function handleProxyHls(request, env, ctx) {
  const cors = corsHeaders(request);
  if (request.method === 'OPTIONS') {
    return new Response('', { status: 204, headers: cors });
  }
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return jsonResponse({ error: 'GET only' }, 405, request);
  }
  if (checkWorkerRateLimit(request, 'proxyHls', 600)) {
    return jsonResponse({ error: 'Too many requests' }, 429, request);
  }

  const url = new URL(request.url);
  const sealed = await scopedTarget(url.searchParams, env.CDN_STAMP_KEY || null);
  if (!sealed) return jsonResponse({ error: 'Host not allowed' }, 400, request);
  const target = sealed.target;
  const provider = sealed.provider;
  const audioLang = sealed.audioLang || '';

  let parsed;
  try {
    parsed = new URL(target);
  } catch {
    return jsonResponse({ error: 'Invalid url' }, 400, request);
  }
  if (parsed.protocol !== 'https:') {
    return jsonResponse({ error: 'Host not allowed' }, 400, request);
  }

  const range = request.headers.get('Range');
  const edgeCache = getEdgeCache();
  const canCache = Boolean(edgeCache && request.method === 'GET' && !range);
  const cacheKey = canCache ? hlsCacheKey(provider, url.origin, target, audioLang) : null;
  if (cacheKey) {
    try {
      const hit = await edgeCache.match(cacheKey);
      if (hit && hit.status === 200) {
        return new Response(hit.body, {
          status: 200,
          headers: withFreshCors(hit.headers, cors),
        });
      }
    } catch {}
  }

  const megaplay =
    provider === 'megaplay' ||
    (!CINEMA_PROVIDERS.has(provider) && isMegaPlayHost(parsed.hostname));
  let headers;
  if (CINEMA_PROVIDERS.has(provider)) headers = cinemaHeaders(provider);
  else if (provider === 'yumezone') headers = yumeHeaders();
  else if (megaplay) headers = megaplayHeaders();
  else headers = megavidHeaders();
  if (range) headers.Range = range;

  let upstream;
  try {
    upstream = await fetchPublicHls(
      target,
      headers,
      AbortSignal.timeout(25_000),
      request.method === 'HEAD' ? 'HEAD' : 'GET',
    );
  } catch (e) {
    console.warn(`[proxyMegavidHls] failed (${parsed.hostname}):`, e.message);
    return jsonResponse({ error: 'Upstream fetch failed' }, 502, request);
  }
  if (!upstream.ok && upstream.status !== 206) {
    await upstream.body?.cancel().catch(() => {});
    const status = upstream.status >= 400 && upstream.status <= 599 ? upstream.status : 502;
    return jsonResponse({ error: `Upstream ${upstream.status}` }, status, request);
  }

  const upstreamCt = (upstream.headers.get('content-type') || '').toLowerCase();
  const looksLikePlaylist =
    upstreamCt.includes('mpegurl') ||
    upstreamCt.includes('x-mpegurl') ||
    parsed.pathname.toLowerCase().includes('.m3u8') ||
    (parsed.search.toLowerCase().includes('.m3u8') && !upstreamCt.includes('video/'));

  let consumed = null;
  if (looksLikePlaylist) {
    if (request.method === 'HEAD') {
      await upstream.body?.cancel().catch(() => {});
      return new Response(null, {
        status: 200,
        headers: {
          ...cors,
          'Content-Type': 'application/vnd.apple.mpegurl',
          'X-Content-Type-Options': 'nosniff',
          'Content-Security-Policy': "default-src 'none'; sandbox",
          'Cache-Control': 'public, max-age=30',
        },
      });
    }
    let text;
    try {
      text = await readLimitedText(upstream, 2 * 1024 * 1024);
    } catch (e) {
      console.warn(`[proxyMegavidHls] playlist read failed (${parsed.hostname}):`, e.message);
      return jsonResponse(
        { error: e && e.code === 'TOO_LARGE' ? 'Playlist too large' : 'Upstream read failed' },
        502,
        request,
      );
    }
    if (text && text.includes('#EXTM3U')) {
      const base = proxyBase(request);
      const sealKey = env.CDN_STAMP_KEY || null;
      const finalUrl = upstream.url || target;
      const rewritten = megaplay
        ? await rewritePlaylistWithHosts(text, finalUrl, base, 'megaplay', sealKey, audioLang)
        : await rewriteCinemaPlaylist(text, finalUrl, base, provider, sealKey, audioLang);
      const response = new Response(rewritten, {
        status: 200,
        headers: {
          ...cors,
          'Content-Type': 'application/vnd.apple.mpegurl',
          'X-Content-Type-Options': 'nosniff',
          'Content-Security-Policy': "default-src 'none'; sandbox",
          'Cache-Control': 'public, max-age=45',
        },
      });
      if (cacheKey) cachePut(ctx, edgeCache, cacheKey, response.clone());
      return response;
    }
    consumed = text;
  }

  const lowerPath = parsed.pathname.toLowerCase();
  const looksLikeVtt =
    upstreamCt.includes('text/vtt') ||
    upstreamCt.includes('application/x-subrip') ||
    lowerPath.endsWith('.vtt') ||
    lowerPath.endsWith('.srt') ||
    lowerPath.includes('/subtitles/') ||
    (upstreamCt.includes('text/plain') && /(?:format(?:=|%3d)srt|\.srt|\.vtt)/i.test(parsed.search));
  if (looksLikeVtt) {
    const vttHeaders = {
      ...cors,
      'Content-Type': 'text/vtt; charset=utf-8',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'; sandbox",
      'Cache-Control': 'public, max-age=3600',
    };
    if (request.method === 'HEAD') {
      await upstream.body?.cancel().catch(() => {});
      return new Response(null, { status: 200, headers: vttHeaders });
    }
    let text;
    try {
      text = consumed !== null ? consumed : await readLimitedText(upstream, 4 * 1024 * 1024);
    } catch (e) {
      console.warn(`[proxyMegavidHls] subtitle read failed (${parsed.hostname}):`, e.message);
      return jsonResponse(
        { error: e && e.code === 'TOO_LARGE' ? 'Subtitle too large' : 'Upstream read failed' },
        502,
        request,
      );
    }
    const cleaned = stripAdCues(srtToVtt(text));
    const vttResponse = new Response(cleaned, { status: 200, headers: vttHeaders });
    if (cacheKey) cachePut(ctx, edgeCache, cacheKey, vttResponse.clone());
    return vttResponse;
  }

  const baseCt = (upstream.headers.get('content-type') || 'application/octet-stream').split(';')[0].trim().toLowerCase();
  const safeCt = DISALLOWED_MEDIA_CT_RE.test(baseCt)
    ? 'application/octet-stream'
    : (upstream.headers.get('content-type') || 'application/octet-stream');

  const outHeaders = { ...cors };
  outHeaders['Content-Type'] = safeCt;
  outHeaders['X-Content-Type-Options'] = 'nosniff';
  outHeaders['Content-Security-Policy'] = "default-src 'none'; sandbox";
  // Range is forwarded upstream. Key the cache on it so a full response is
  // never replayed for a byte-range request. A cached 206 must not be reused
  // for a different range — that stalls or corrupts video playback.
  outHeaders['Vary'] = 'Origin, Range';
  outHeaders['Cache-Control'] = upstream.status === 206
    ? 'private, no-store'
    : 'public, max-age=3600';
  for (const h of ['accept-ranges', 'content-range', 'content-length']) {
    const v = upstream.headers.get(h);
    if (v) outHeaders[h.replace(/(^|-)([a-z])/g, (_m, a, b) => a + b.toUpperCase())] = v;
  }
  if (consumed !== null) delete outHeaders['Content-Length'];

  if (request.method === 'HEAD') {
    await upstream.body?.cancel().catch(() => {});
    return new Response(null, { status: upstream.status === 206 ? 206 : 200, headers: outHeaders });
  }

  const mediaStatus = upstream.status === 206 ? 206 : 200;
  let body = consumed !== null ? consumed : upstream.body;
  if (audioLang && consumed === null && mediaStatus === 200) {
    try {
      const bytes = new Uint8Array(await upstream.arrayBuffer());
      body = filterTsPmtAudio(bytes, audioLang);
    } catch (e) {
      console.warn(`[proxyMegavidHls] ts audio filter failed (${parsed.hostname}):`, e.message);
      return jsonResponse({ error: 'Upstream read failed' }, 502, request);
    }
  }
  const mediaResponse = new Response(body, {
    status: mediaStatus,
    headers: outHeaders,
  });
  if (cacheKey && mediaStatus === 200) {
    cachePut(ctx, edgeCache, cacheKey, mediaResponse.clone());
  }
  return mediaResponse;
}

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);
    if (pathname === '/proxyAnime') return handleProxyAnime(request, env, ctx);
    if (pathname === '/proxyMegavidHls') return handleProxyHls(request, env, ctx);
    if (pathname === '/health') return new Response('ok', { headers: corsHeaders(request) });
    return new Response('Not found', { status: 404, headers: corsHeaders(request) });
  },
};

export { handleProxyAnime, handleProxyHls };
