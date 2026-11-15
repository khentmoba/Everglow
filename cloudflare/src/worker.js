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
  stripAdCues,
  validateAnimeParams,
} from './anime.js';
import { yumeHeaders } from './yumezone.js';

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

function proxyBase(request) {
  return `${new URL(request.url).origin}/proxyMegavidHls`;
}

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
        { server: params.server },
      );
    }
    if (!out || !out.src) throw new Error('resolver returned no src');
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
          servers: Array.isArray(out.servers) ? out.servers : [],
          current: out.server || '',
        }),
        {
          status: 200,
          headers: {
            ...CORS,
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
      token: query.token || '',
      ep: out.ep,
      audio: params.audio,
      servers: Array.isArray(out.servers) ? out.servers : [],
      current: out.server || '',
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
    console.warn('[proxyAnime] resolve failed:', e && e.message);
    return sendFail('No stream found — try another server.');
  }
}

async function handleProxyHls(request, env, _ctx) {
  if (request.method === 'OPTIONS') {
    return new Response('', { status: 204, headers: CORS });
  }
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return jsonResponse({ error: 'GET only' }, 405);
  }

  const url = new URL(request.url);
  const sealed = await scopedTarget(url.searchParams, env.CDN_STAMP_KEY || null);
  if (!sealed) return jsonResponse({ error: 'Host not allowed' }, 400);
  const target = sealed.target;
  const provider = sealed.provider;

  let parsed;
  try {
    parsed = new URL(target);
  } catch {
    return jsonResponse({ error: 'Invalid url' }, 400);
  }
  if (parsed.protocol !== 'https:') {
    return jsonResponse({ error: 'Host not allowed' }, 400);
  }

  const megaplay =
    provider === 'megaplay' ||
    (!CINEMA_PROVIDERS.has(provider) && isMegaPlayHost(parsed.hostname));
  let headers;
  if (CINEMA_PROVIDERS.has(provider)) headers = cinemaHeaders(provider);
  else if (provider === 'yumezone') headers = yumeHeaders();
  else if (megaplay) headers = megaplayHeaders();
  else headers = megavidHeaders();
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

  let consumed = null;
  if (looksLikePlaylist) {
    const text = await upstream.text();
    if (text && text.includes('#EXTM3U')) {
      const base = proxyBase(request);
      const sealKey = env.CDN_STAMP_KEY || null;
      const rewritten = megaplay
        ? await rewritePlaylistWithHosts(text, target, base, 'megaplay', sealKey)
        : await rewriteCinemaPlaylist(text, target, base, provider, sealKey);
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
    consumed = text;
  }

  const looksLikeVtt =
    upstreamCt.includes('text/vtt') ||
    upstreamCt.includes('application/x-subrip') ||
    parsed.pathname.toLowerCase().endsWith('.vtt');
  if (looksLikeVtt) {
    const text = consumed !== null ? consumed : await upstream.text();
    const cleaned = stripAdCues(text);
    const vttHeaders = {
      ...CORS,
      'Content-Type': 'text/vtt; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    };
    if (request.method === 'HEAD') {
      return new Response(null, { status: 200, headers: vttHeaders });
    }
    return new Response(cleaned, { status: 200, headers: vttHeaders });
  }

  const outHeaders = { ...CORS };
  outHeaders['Content-Type'] = upstream.headers.get('content-type') || 'application/octet-stream';
  outHeaders['Cache-Control'] = 'public, max-age=3600';
  for (const h of ['accept-ranges', 'content-range', 'content-length']) {
    const v = upstream.headers.get(h);
    if (v) outHeaders[h.replace(/(^|-)([a-z])/g, (_m, a, b) => a + b.toUpperCase())] = v;
  }
  if (consumed !== null) delete outHeaders['Content-Length'];

  if (request.method === 'HEAD') {
    return new Response(null, { status: upstream.status === 206 ? 206 : 200, headers: outHeaders });
  }

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

export { handleProxyAnime, handleProxyHls };
