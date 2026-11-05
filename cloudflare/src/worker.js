// Everglow streaming Worker — the Cloudflare replacement for the Firebase
// `proxyAnime` and `proxyMegavidHls` functions.
//
// Same paths, same query params, same player page, so the app only has to
// change its origin. Cloudflare Workers are not billed for bandwidth, which
// is the whole point of the move: a 1080p film is ~6.4 GB of egress.
//
// Secrets (wrangler secret put):
//   CDN_STAMP_KEY  HMAC key for the MegaPlay + Cinema URL stamps.

import {
  CINEMA_PROVIDERS,
  cinemaHeaders,
  cinemaProxyUrl,
  cinemaStampMessage,
  failHtml,
  hlsPlayerHtml,
  isAnimeCdnHost,
  isMegaPlayHost,
  isMegavidHost,
  megavidHeaders,
  megaplayHeaders,
  proxyUrl,
  resolveCinema,
  resolveMegaPlay,
  resolveMegavid,
  rewriteCinemaPlaylist,
  rewritePlaylistWithHosts,
  validCdnStamp,
  validateAnimeParams,
} from './anime.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, Range',
  'Access-Control-Expose-Headers': 'Content-Range, Content-Length, Accept-Ranges',
};

function htmlResponse(body, status) {
  return new Response(body, {
    status,
    headers: { ...CORS, 'Content-Type': 'text/html; charset=utf-8' },
  });
}

function jsonResponse(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/** The proxy base for this request, so staged and live hosts each rewrite
 *  to themselves. */
function proxyBase(request) {
  return `${new URL(request.url).origin}/proxyMegavidHls`;
}

// ─── /proxyAnime ─────────────────────────────────────────

async function handleProxyAnime(request, env) {
  if (request.method === 'OPTIONS') {
    return new Response('', { status: 204, headers: CORS });
  }
  if (request.method !== 'GET') {
    return htmlResponse(failHtml('Method not allowed', 'GET only.'), 405);
  }

  const query = Object.fromEntries(new URL(request.url).searchParams);
  const params = validateAnimeParams(query);
  const notify = String(query.source || '').toLowerCase() === 'cinema';
  if (params.error) {
    return htmlResponse(failHtml('Bad request', params.error, { notify }), 400);
  }

  const base = proxyBase(request);
  const key = env.CDN_STAMP_KEY || null;
  const sendFail = (msg) => {
    console.warn(`[proxyAnime] ${params.source}: ${msg}`);
    return htmlResponse(failHtml('Episode unavailable', msg, { notify }), 502);
  };

  try {
    let out;
    if (params.source === 'megavid') {
      out = await resolveMegavid(params.anilistId, params.malId, params.ep, params.audio, base);
    } else if (params.source === 'megaplay' || params.source === 'everglow') {
      out = await resolveMegaPlay(
        params.anilistId,
        params.malId,
        params.ep,
        params.audio,
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
      );
    }
    const page = hlsPlayerHtml({
      src: out.src,
      tracks: out.tracks,
      title: out.title,
      token: query.token || '',
      ep: out.ep,
    });
    return new Response(page, {
      status: 200,
      headers: {
        ...CORS,
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'public, max-age=300',
      },
    });
  } catch (e) {
    return sendFail('No stream found — try another server.');
  }
}

// ─── /proxyMegavidHls ────────────────────────────────────

async function handleProxyHls(request, env) {
  if (request.method === 'OPTIONS') {
    return new Response('', { status: 204, headers: CORS });
  }
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return jsonResponse({ error: 'GET only' }, 405);
  }

  const url = new URL(request.url);
  const target = url.searchParams.get('u');
  if (!target) return jsonResponse({ error: 'Missing ?u=<media url>' }, 400);

  let parsed;
  try {
    parsed = new URL(target);
  } catch (_) {
    return jsonResponse({ error: 'Invalid url' }, 400);
  }

  // Unlisted hosts pass only with a stamp we minted ourselves: MegaPlay
  // stamps sign the bare URL; Cinema stamps (`p=fmov|vidbolt`) sign provider
  // + URL and are the ONLY way a Cinema URL gets through. Cinema has no host
  // allowlist on purpose — fmov.my runs its own open relay, so listing its
  // host would turn this Worker into an open proxy.
  const provider = CINEMA_PROVIDERS.has(url.searchParams.get('p'))
    ? url.searchParams.get('p')
    : null;
  const stamp = url.searchParams.get('s') || '';
  const key = stamp ? env.CDN_STAMP_KEY || null : null;
  const cinema =
    provider !== null &&
    (await validCdnStamp(key, cinemaStampMessage(provider, target), stamp));
  const stamped =
    provider === null && !isAnimeCdnHost(parsed.hostname) && (await validCdnStamp(key, target, stamp));
  const listed = provider === null && isAnimeCdnHost(parsed.hostname);
  if (parsed.protocol !== 'https:' || !(cinema || stamped || listed)) {
    return jsonResponse({ error: 'Host not allowed' }, 400);
  }

  const megaplay = stamped || isMegaPlayHost(parsed.hostname);
  const headers = cinema
    ? cinemaHeaders(provider)
    : megaplay
      ? megaplayHeaders()
      : megavidHeaders();
  const range = request.headers.get('Range');
  if (range) headers.Range = range;

  let upstream;
  try {
    upstream = await fetch(target, { headers, redirect: 'follow' });
  } catch (e) {
    console.warn(`[proxyMegavidHls] failed (${parsed.hostname}):`, e.message);
    return jsonResponse({ error: `Upstream fetch failed: ${e.message}` }, 502);
  }
  if (!upstream.ok && upstream.status !== 206) {
    return jsonResponse({ error: `Upstream ${upstream.status}` }, upstream.status);
  }

  const upstreamCt = (upstream.headers.get('content-type') || '').toLowerCase();
  const looksLikePlaylist =
    upstreamCt.includes('mpegurl') ||
    upstreamCt.includes('x-mpegurl') ||
    parsed.pathname.toLowerCase().includes('.m3u8') ||
    (parsed.search.toLowerCase().includes('.m3u8') && !upstreamCt.includes('video/'));

  if (looksLikePlaylist) {
    const text = await upstream.text();
    if (text && text.includes('#EXTM3U')) {
      const base = proxyBase(request);
      const isAllowed = megaplay ? isMegaPlayHost : isMegavidHost;
      const stampKey = megaplay ? env.CDN_STAMP_KEY || null : null;
      const rewritten = cinema
        ? await rewriteCinemaPlaylist(text, target, base, provider, key)
        : await rewritePlaylistWithHosts(text, target, base, isAllowed, stampKey);
      return new Response(rewritten, {
        status: 200,
        headers: {
          ...CORS,
          'Content-Type': 'application/vnd.apple.mpegurl',
          'Cache-Control': 'public, max-age=30',
        },
      });
    }
    // Falls through as a plain file when the body isn't a playlist.
  }

  const outHeaders = { ...CORS };
  outHeaders['Content-Type'] = upstream.headers.get('content-type') || 'application/octet-stream';
  outHeaders['Cache-Control'] = 'public, max-age=3600';
  for (const h of ['accept-ranges', 'content-range', 'content-length']) {
    const v = upstream.headers.get(h);
    if (v) outHeaders[h.replace(/(^|-)([a-z])/g, (m, a, b) => a + b.toUpperCase())] = v;
  }

  if (request.method === 'HEAD') {
    return new Response(null, { status: upstream.status === 206 ? 206 : 200, headers: outHeaders });
  }

  // Pass the upstream body straight through: Workers apply backpressure to
  // the client for us, so no manual reader loop is needed.
  return new Response(upstream.body, {
    status: upstream.status === 206 ? 206 : 200,
    headers: outHeaders,
  });
}

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (pathname === '/proxyAnime') return handleProxyAnime(request, env);
    if (pathname === '/proxyMegavidHls') return handleProxyHls(request, env);
    if (pathname === '/health') return new Response('ok', { headers: CORS });
    return new Response('Not found', { status: 404, headers: CORS });
  },
};

export { handleProxyAnime, handleProxyHls, proxyUrl, cinemaProxyUrl };
