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
  failHtml,
  hlsPlayerHtml,
  isAnimeCdnHost,
  isMegaPlayHost,
  isMegavidHost,
  megavidHeaders,
  megaplayHeaders,
  fmovHeaders,
  vidboltHeaders,
  proxyUrl,
  resolveCinema,
  resolveMegaPlay,
  resolveMegavid,
  rewriteCinemaPlaylist,
  rewritePlaylistWithHosts,
  scopeMessage,
  scopedTarget,
  STAMP_PROVIDERS,
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
  const wantsJson = String(query.format || '').toLowerCase() === 'json';
  const params = validateAnimeParams(query);
  const notify = String(query.source || '').toLowerCase() === 'cinema';
  if (params.error) {
    return wantsJson
      ? jsonResponse({ error: params.error }, 400)
      : htmlResponse(failHtml('Bad request', params.error, { notify }), 400);
  }

  const base = proxyBase(request);
  const key = env.CDN_STAMP_KEY || null;
  const sendFail = (msg) => {
    console.warn(`[proxyAnime] ${params.source}: ${msg}`);
    return wantsJson
      ? jsonResponse({ error: msg }, 502)
      : htmlResponse(failHtml('Episode unavailable', msg, { notify }), 502);
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
    // Cinema passes the real title (the Worker has no catalog to look it up);
    // it is display text only, escaped by the player and length-capped here.
    const isCinema = params.source === 'cinema';
    const named = String(query.title || '').replace(/\s+/g, ' ').trim().slice(0, 120);
    const title = isCinema && named
      ? params.mediaType === 'tv' ? `${named} · ${out.title}` : named
      : out.title;
    // The watch party plays the stream in its own <video> (so play/pause/seek
    // and captions are real), and asks for the resolved URLs instead of the
    // player page. Same resolver, same stamps — only the response shape differs.
    if (String(query.format || '').toLowerCase() === 'json') {
      return new Response(
        JSON.stringify({
          src: out.src,
          tracks: Array.isArray(out.tracks) ? out.tracks : [],
          title,
          ep: out.ep,
        }),
        {
          status: 200,
          headers: {
            ...CORS,
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'public, max-age=300',
          },
        },
      );
    }
    const page = hlsPlayerHtml({
      src: out.src,
      tracks: out.tracks,
      title,
      kind: isCinema ? 'cinema' : 'anime',
      token: query.token || '',
      ep: out.ep,
      audio: params.audio,
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

async function handleProxyHls(request, env, ctx) {
  if (request.method === 'OPTIONS') {
    return new Response('', { status: 204, headers: CORS });
  }
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return jsonResponse({ error: 'GET only' }, 405);
  }

  const url = new URL(request.url);
  const providerParam = url.searchParams.get('p');
  const provider = STAMP_PROVIDERS.has(providerParam) ? providerParam : null;
  // Stamped requests name their target through the signed scope (see
  // scopedTarget); unstamped ones may only name an allowlisted anime CDN.
  const scoped = provider !== null ? scopedTarget(url.searchParams) : null;
  const target = scoped ? scoped.target : url.searchParams.get('u') || '';
  if (!target) return jsonResponse({ error: 'Missing ?u=<media url>' }, 400);

  let parsed;
  try {
    parsed = new URL(target);
  } catch (_) {
    return jsonResponse({ error: 'Invalid url' }, 400);
  }

  // Unlisted hosts pass only with a stamp we minted ourselves, over
  // `provider | relay endpoint | folder of the URL actually fetched`. A relay
  // (fmov.my/api/proxy?url=…) is never covered by a folder stamp, so one stamp
  // lifted from a public player page cannot point the relay anywhere else.
  const stamp = url.searchParams.get('s') || '';
  const key = stamp ? env.CDN_STAMP_KEY || null : null;
  const stamped =
    scoped !== null &&
    (await validCdnStamp(key, scopeMessage(provider, scoped.relay, scoped.scope), stamp));
  const listed = !scoped && isAnimeCdnHost(parsed.hostname);
  if (parsed.protocol !== 'https:' || !(stamped || listed)) {
    return jsonResponse({ error: 'Host not allowed' }, 400);
  }

  const megaplay = provider === 'megaplay' || isMegaPlayHost(parsed.hostname);
  const headers =
    provider === 'vidbolt'
      ? vidboltHeaders()
      : megaplay
        ? megaplayHeaders()
        : provider === 'fmov'
          ? fmovHeaders()
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

  // Set when the body was already read as text and turned out not to be a
  // playlist; the stream is spent, so the text itself is sent instead.
  let consumed = null;
  if (looksLikePlaylist) {
    const text = await upstream.text();
    if (text && text.includes('#EXTM3U')) {
      const base = proxyBase(request);
      // MegaPlay is chosen by host OR stamp: its masters live on allowlisted
      // hosts and arrive unstamped. Routing them by `provider` alone sent them
      // to the Megavid rewriter, which has no key, so every variant came out
      // with an empty stamp and Everglow-server anime could not play.
      const rewritten = megaplay
        ? await rewritePlaylistWithHosts(text, target, base, isMegaPlayHost, env.CDN_STAMP_KEY || null)
        : provider !== null
          ? await rewriteCinemaPlaylist(text, target, base, provider, key)
          : await rewritePlaylistWithHosts(text, target, base, isMegavidHost, null);
      const response = new Response(rewritten, {
        status: 200,
        headers: {
          ...CORS,
          'Content-Type': 'application/vnd.apple.mpegurl',
          'Cache-Control': 'public, max-age=30',
        },
      });
      return response;
    }
    // Falls through as a plain file when the body isn't a playlist.
    consumed = text;
  }

  const outHeaders = { ...CORS };
  outHeaders['Content-Type'] = upstream.headers.get('content-type') || 'application/octet-stream';
  outHeaders['Cache-Control'] = 'public, max-age=3600';
  for (const h of ['accept-ranges', 'content-range', 'content-length']) {
    const v = upstream.headers.get(h);
    if (v) outHeaders[h.replace(/(^|-)([a-z])/g, (m, a, b) => a + b.toUpperCase())] = v;
  }
  if (consumed !== null) delete outHeaders['Content-Length'];

  if (request.method === 'HEAD') {
    return new Response(null, { status: upstream.status === 206 ? 206 : 200, headers: outHeaders });
  }

  // Pass the upstream body straight through: Workers apply backpressure to
  // the client for us, so no manual reader loop is needed.
  return new Response(consumed !== null ? consumed : upstream.body, {
    status: upstream.status === 206 ? 206 : 200,
    headers: outHeaders,
  });
}

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);
    if (pathname === '/proxyAnime') return handleProxyAnime(request, env);
    if (pathname === '/proxyMegavidHls') return handleProxyHls(request, env, ctx);
    if (pathname === '/health') return new Response('ok', { headers: CORS });
    return new Response('Not found', { status: 404, headers: CORS });
  },
};

export { handleProxyAnime, handleProxyHls, proxyUrl };
