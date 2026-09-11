'use strict';

/**
 * Everglow anime resolver — ad-free HiAnime + AnimePahe playback.
 *
 * The app never talks to third-party anime APIs directly. It loads one of
 * these URLs in the sandboxed player frame:
 *
 *   GET /proxyAnime?source=hianime|animepahe&anilistId=<id>&malId=<id>
 *       &ep=<n>&audio=sub|dub&token=<firebase id token>
 *
 * The function resolves the episode server-side (through our own
 * self-hosted HiAnime / AnimePahe API instances, whose base URLs stay in
 * server env vars) and serves a clean player page from OUR domain — so no
 * third-party ad script ever reaches Clair's phone.
 *
 * Self-host one instance of each (personal use only):
 *   - HiAnime API : https://github.com/MSMods-Pro/hianime-api
 *                   (Docker or Cloudflare Workers)
 *   - AnimePahe API: https://github.com/ElijahCodes12345/animepahe-api
 *                   (Docker or Railway; needs `npx playwright install`)
 * Then set HIANIME_API_BASE / ANIMEPAHE_API_BASE on the functions
 * (firebase functions .env) and redeploy.
 *
 * Auth: Firebase ID token via `Authorization: Bearer` header OR `?token=`
 * (player iframes cannot send headers). Failures always return an HTML
 * page containing the "no playable stream sources" marker, which the
 * app's dead-server probe already recognizes — so a missing backend or a
 * missing episode auto-advances to the next server instead of showing a
 * grey box.
 */

const functions = require('firebase-functions/v1');
const { getAdmin, isPublicDnsHost } = require('./common.js');

const DESKTOP_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/** Marker text the app probe recognizes as "try the next server". */
const NO_SOURCE_MARKER = 'no playable stream sources';

const SEGMENT_HOSTS = new Set(['kwik.cx', 'kwik.si', 'pahe.win']);

function escHtml(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function normTitle(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');
}

/**
 * Picks the upstream anime id whose title best matches one of ours.
 * Each candidate needs {key, title} (extra title keys are merged by the
 * caller). Exact normalized match wins, then prefix, then contains,
 * with a small bonus for a matching release year.
 */
function pickBestMatch(candidates, titles, year) {
  const wants = titles.map(normTitle).filter(Boolean);
  if (!wants.length || !Array.isArray(candidates)) return null;
  let best = null;
  let bestScore = 0;
  for (const c of candidates) {
    if (!c || !c.key) continue;
    const got = normTitle(c.title);
    if (!got) continue;
    let score = 0;
    for (const w of wants) {
      if (got === w) score = Math.max(score, 100);
      else if (got.startsWith(w) || w.startsWith(got)) score = Math.max(score, 60);
      else if (got.includes(w) || w.includes(got)) score = Math.max(score, 30);
    }
    if (score > 0 && year && c.year && Number(c.year) === Number(year)) score += 20;
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return bestScore > 0 ? best : null;
}

function failHtml(title, detail) {
  return (
    '<!DOCTYPE html><html><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>' + escHtml(title) + '</title></head>' +
    '<body style="margin:0;background:#000;color:#8b8b9e;' +
    'font-family:sans-serif;display:flex;align-items:center;' +
    'justify-content:center;height:100vh;text-align:center">' +
    '<div><p style="font-size:15px;color:#e2e2ea">' + escHtml(title) + '</p>' +
    '<p style="font-size:12px">' + escHtml(detail) + '</p>' +
    '<p style="font-size:12px">' + NO_SOURCE_MARKER + ' — try another server.</p></div>' +
    '</body></html>'
  );
}

/** Minimal ad-free HLS player. The video URL must already be playable
 *  from a browser (proxied through us when the upstream needs headers). */
function hlsPlayerHtml({ src, title, tracks }) {
  const trackTags = (Array.isArray(tracks) ? tracks : [])
    .filter((t) => t && t.file)
    .slice(0, 8)
    .map(
      (t) =>
        '<track kind="captions" src="' + escHtml(t.file) + '"' +
        (t.label ? ' label="' + escHtml(t.label) + '"' : '') +
        '>',
    )
    .join('\n    ');
  return (
    '<!DOCTYPE html><html><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<meta name="referrer" content="no-referrer">' +
    '<title>' + escHtml(title || 'Everglow') + '</title>' +
    '<style>html,body{margin:0;height:100%;background:#000}' +
    'video{width:100%;height:100%;background:#000}</style></head><body>' +
    '<video id="v" controls playsinline autoplay>' +
    (trackTags ? '\n    ' + trackTags : '') +
    '</video>\n' +
    '<script src="https://cdn.jsdelivr.net/npm/hls.js@1"></script>\n' +
    '<script>(function(){var src=' + JSON.stringify(src) + ';var v=' +
    "document.getElementById('v');" +
    'if(window.Hls&&Hls.isSupported()){var h=new Hls();h.loadSource(src);' +
    'h.attachMedia(v);}else{v.src=src;}})();</' + 'script></body></html>'
  );
}

function validateAnimeParams(query) {
  const source = String(query.source || '').toLowerCase();
  if (source !== 'hianime' && source !== 'animepahe') {
    return { error: 'source must be hianime or animepahe' };
  }
  const anilistId = Number.parseInt(String(query.anilistId || '0'), 10) || 0;
  const malId = Number.parseInt(String(query.malId || '0'), 10) || 0;
  if (anilistId <= 0 && malId <= 0) {
    return { error: 'anilistId or malId is required' };
  }
  const rawEp = query.ep == null || query.ep === '' ? '1' : String(query.ep);
  const ep = Number.parseInt(rawEp, 10);
  if (!Number.isFinite(ep) || ep < 1 || ep > 3000) {
    return { error: 'ep must be 1..3000' };
  }
  const audio = String(query.audio || 'sub').toLowerCase();
  if (audio !== 'sub' && audio !== 'dub') {
    return { error: 'audio must be sub or dub' };
  }
  return { source, anilistId, malId, ep, audio };
}

async function verifyToken(req) {
  const header = req.get('Authorization') || req.headers.authorization || '';
  const fromHeader = String(header).replace(/^Bearer\s+/i, '').trim();
  const token = fromHeader || String(req.query.token || '').trim();
  if (!token) return null;
  try {
    return await getAdmin().auth().verifyIdToken(token);
  } catch (e) {
    console.warn('[proxyAnime] token verify failed:', e.message);
    return null;
  }
}

async function fetchJson(url, timeoutMs) {
  const res = await fetch(url, {
    headers: { 'User-Agent': DESKTOP_UA, Accept: 'application/json' },
    signal: AbortSignal.timeout(timeoutMs || 12000),
  });
  if (!res.ok) throw new Error(`upstream ${res.status}`);
  return res.json();
}

/** Our self-hosted API hosts come from env only (never from the client),
 *  and must be public https hosts — same SSRF guard as the other proxies. */
async function envBase(name) {
  const raw = (process.env[name] || '').trim().replace(/\/+$/, '');
  if (!raw) return null;
  let parsed;
  try {
    parsed = new URL(raw);
  } catch (_) {
    return null;
  }
  if (parsed.protocol !== 'https:') return null;
  if (!(await isPublicDnsHost(parsed.hostname))) return null;
  return raw;
}

/** Titles for upstream search, via the free keyless AniList API. */
async function anilistTitles(anilistId, malId) {
  const query =
    'query($id:Int,$idMal:Int){Media(id:$id,idMal:$idMal,type:ANIME)' +
    '{title{romaji english native}synonyms startDate{year}}}';
  const vars = {};
  if (anilistId > 0) vars.id = anilistId;
  if (malId > 0) vars.idMal = malId;
  const res = await fetch('https://graphql.anilist.co', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ query, variables: vars }),
    signal: AbortSignal.timeout(12000),
  });
  if (!res.ok) throw new Error(`anilist ${res.status}`);
  const body = await res.json();
  const media = body && body.data && body.data.Media;
  if (!media) throw new Error('anilist: no match');
  const titles = [
    media.title && media.title.english,
    media.title && media.title.romaji,
    ...(Array.isArray(media.synonyms) ? media.synonyms : []),
  ].filter(Boolean);
  const year =
    media.startDate && media.startDate.year ? media.startDate.year : null;
  return { titles, year };
}

function firstM3u8(node, out) {
  const found = out || [];
  const walk = (v) => {
    if (typeof v === 'string') {
      const m = v.match(/https?:\/\/[^"'<>\s]+\.m3u8[^"'<>\s]*/i);
      if (m && !found.includes(m[0])) found.push(m[0]);
    } else if (Array.isArray(v)) {
      v.forEach(walk);
    } else if (v && typeof v === 'object') {
      Object.values(v).forEach(walk);
    }
  };
  walk(node);
  return found;
}

// ─── HiAnime ─────────────────────────────────────────────

async function resolveHianime(base, titles, year, ep, audio) {
  let matchKey = null;

  // 1. Try search API if available
  try {
    const search = await fetchJson(
      `${base}/api/v1/search?keyword=${encodeURIComponent(titles[0])}&page=1`,
      10000,
    );
    const results =
      search &&
      search.data &&
      (search.data.animes || search.data.response);
    const match = pickBestMatch(
      (Array.isArray(results) ? results : []).map((a) => ({
        key: a.id,
        title: [a.title, a.alternativeTitle, a.japanese]
          .filter(Boolean)
          .join(' ~ '),
      })),
      titles,
      year,
    );
    if (match && match.key) matchKey = match.key;
  } catch (_) {}

  // 2. If search fails or returns nothing, try slug candidates directly
  let eps = null;
  const candidates = matchKey ? [matchKey] : [];
  for (const t of titles) {
    const slug = t
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
    if (slug && !candidates.includes(slug)) candidates.push(slug);
  }

  for (const key of candidates) {
    try {
      const res = await fetchJson(
        `${base}/api/v1/episodes/${encodeURIComponent(key)}`,
        10000,
      );
      if (
        res &&
        res.data &&
        Array.isArray(res.data.episodes) &&
        res.data.episodes.length > 0
      ) {
        eps = res;
        matchKey = key;
        break;
      }
    } catch (_) {}
  }
  if (!eps) throw new Error('hianime: no match');

  const list = eps.data.episodes;
  const target =
    list.find((e) => Number(e.episodeNumber) === ep) || list[ep - 1];
  if (!target || !target.id) throw new Error('hianime: episode missing');

  // Normalize episode ID (handles both 'slug/ep-1' and 'slug::ep=1')
  const epId = target.id.replace(/\/ep-/, '::ep=');

  // Pick server
  let server = 'hd-1';
  let serverEmbedUrl = null;
  try {
    const servers = await fetchJson(
      `${base}/api/v1/servers?id=${encodeURIComponent(epId)}`,
      10000,
    );
    const serverList =
      servers && servers.data
        ? audio === 'dub' &&
          Array.isArray(servers.data.dub) &&
          servers.data.dub.length > 0
          ? servers.data.dub
          : Array.isArray(servers.data.sub)
          ? servers.data.sub
          : []
        : [];
    const pick = serverList[0];
    if (pick && pick.name) {
      server = String(pick.name).toLowerCase().replace(/\s+/g, '-');
      serverEmbedUrl = pick.embedUrl || null;
    }
  } catch (e) {
    console.warn('[proxyAnime] hianime servers fallback:', e.message);
  }

  // 1. Try clean embed endpoint
  try {
    const embedRes = await fetch(
      `${base}/api/v1/embed/${server}/${encodeURIComponent(epId)}/${audio}`,
      {
        headers: { 'User-Agent': DESKTOP_UA, Accept: 'text/html' },
        signal: AbortSignal.timeout(10000),
      },
    );
    if (embedRes.ok) {
      let html = await embedRes.text();
      if (html.includes('<video') || html.includes('hls')) {
        html = html.replace(
          /<head([^>]*)>/i,
          `<head$1><base href="${base}/">`,
        );
        return { playerHtml: html };
      }
    }
  } catch (_) {}

  // 2. Try stream endpoint
  try {
    const stream = await fetchJson(
      `${base}/api/v1/stream?id=${encodeURIComponent(epId)}&server=${encodeURIComponent(server)}&type=${audio}`,
      12000,
    );
    const data = stream && stream.data;
    const file =
      data &&
      (data.master_m3u8 ||
        (data.link && data.link.file) ||
        (data.variants && data.variants[0] && data.variants[0].url) ||
        data.streamingLink);
    if (file) {
      const proxied = `${base}/api/v1/proxy?url=${encodeURIComponent(file)}&referer=${encodeURIComponent(data.embedUrl || 'https://megacloud.tv')}`;
      const tracks =
        data.tracks && Array.isArray(data.tracks)
          ? data.tracks.filter((t) => t && t.file)
          : [];
      return {
        playerHtml: hlsPlayerHtml({
          src: proxied,
          tracks,
          title: matchKey,
        }),
      };
    }
    if (data && data.embedUrl) {
      serverEmbedUrl = data.embedUrl;
    }
  } catch (_) {}

  // 3. Fall back to sandboxed embed URL if available
  if (serverEmbedUrl) {
    const safeEmbedHtml =
      '<!DOCTYPE html><html><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<meta name="referrer" content="no-referrer">' +
      '<title>' +
      escHtml(titles[0]) +
      '</title>' +
      '<style>html,body,iframe{margin:0;padding:0;width:100%;height:100%;border:0;background:#000;overflow:hidden}</style>' +
      '</head><body><iframe src="' +
      escHtml(serverEmbedUrl) +
      '" allowfullscreen ' +
      'sandbox="allow-scripts allow-same-origin allow-forms allow-presentation allow-pointer-lock" ' +
      'allow="autoplay *; fullscreen *; encrypted-media *; picture-in-picture *"></iframe>' +
      '</body></html>';
    return { playerHtml: safeEmbedHtml };
  }

  throw new Error('hianime: no playable source found');
}

// ─── AnimePahe ───────────────────────────────────────────

async function resolvePahe(base, titles, year, ep, audio) {
  const search = await fetchJson(
    `${base}/api/search?q=${encodeURIComponent(titles[0])}`,
    12000,
  );
  const items = Array.isArray(search && search.data) ? search.data : [];
  const match = pickBestMatch(
    items.map((a) => ({ key: a.session, title: a.title, year: a.year })),
    titles,
    year,
  );
  if (!match) throw new Error('pahe: no match');

  const isDub = (r) =>
    /dub|\beng\b/i.test(
      [r.audio, r.edition, r.title].filter(Boolean).join(' '),
    );
  let chosen = null;
  const pages = [`${base}/api/${match.key}/releases?sort=episode_asc&page=1`];
  for (let p = 1; p <= 5; p++) {
    pages.push(`${base}/api/${match.key}/releases?sort=episode_desc&page=${p}`);
  }
  for (const url of pages) {
    let page;
    try {
      page = await fetchJson(url, 12000);
    } catch (e) {
      continue;
    }
    const rows = Array.isArray(page && page.data) ? page.data : [];
    const hits = rows.filter((r) => Number(r.episode) === ep);
    if (hits.length) {
      chosen =
        hits.find((r) => (audio === 'dub') === isDub(r)) || hits[0];
      break;
    }
    const last =
      page && page.paginationInfo && page.paginationInfo.lastPage;
    if (url.includes('episode_desc') && last && Number(last) <= 1) break;
  }
  if (!chosen || !chosen.session) throw new Error('pahe: episode missing');

  const play = await fetchJson(
    `${base}/api/play/${match.key}?episodeId=${encodeURIComponent(chosen.session)}` +
      '&downloads=false',
    15000,
  );
  const urls = firstM3u8(play);
  if (!urls.length) throw new Error('pahe: no stream');
  return { m3u8: urls[0] };
}

// ─── Endpoints ───────────────────────────────────────────

const proxyAnime = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).send(failHtml('Method not allowed', 'GET only.'));
    return;
  }

  const authed = await verifyToken(req);
  if (!authed) {
    res
      .status(401)
      .send(failHtml('Sign in expired', 'Reopen the app and try again.'));
    return;
  }

  const params = validateAnimeParams(req.query || {});
  if (params.error) {
    res.status(400).send(failHtml('Bad request', params.error));
    return;
  }
  const { source, anilistId, malId, ep, audio } = params;

  const sendFail = (msg) => {
    console.warn(`[proxyAnime] ${source} ep=${ep}: ${msg}`);
    res.status(502).send(failHtml('Episode unavailable', msg));
  };

  const base = await envBase(
    source === 'hianime' ? 'HIANIME_API_BASE' : 'ANIMEPAHE_API_BASE',
  );
  if (!base) {
    sendFail('Source is not set up yet — try another server.');
    return;
  }

  let titles;
  let year = null;
  try {
    const found = await anilistTitles(anilistId, malId);
    titles = found.titles;
    year = found.year;
  } catch (e) {
    sendFail('Title lookup failed — try another server.');
    return;
  }
  if (!titles.length) {
    sendFail('Title lookup failed — try another server.');
    return;
  }

  try {
    if (source === 'hianime') {
      const out = await resolveHianime(base, titles, year, ep, audio);
      res.set('Content-Type', 'text/html; charset=utf-8');
      res.set('Cache-Control', 'public, max-age=300');
      res.status(200).send(out.playerHtml);
      return;
    }
    const out = await resolvePahe(base, titles, year, ep, audio);
    const host = req.get('host') || req.headers.host || '';
    const seg =
      `${req.protocol || 'https'}://${host}/proxyAnimeSegment` +
      `?u=${encodeURIComponent(out.m3u8)}` +
      `&token=${encodeURIComponent(String(req.query.token || ''))}`;
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.set('Cache-Control', 'public, max-age=300');
    res
      .status(200)
      .send(hlsPlayerHtml({ src: seg, title: titles[0], tracks: [] }));
  } catch (e) {
    sendFail('No stream found — try another server.');
  }
});

/** Streams one upstream segment file with the headers the source needs
 *  (Kwik checks Referer, which browsers cannot spoof). Same token check
 *  as proxyAnime; host allowlist keeps it from becoming an open proxy. */
const proxyAnimeSegment = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'GET only' });
    return;
  }
  const authed = await verifyToken(req);
  if (!authed) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }

  const targetUrl = req.query.u;
  if (typeof targetUrl !== 'string' || !targetUrl) {
    res.status(400).json({ error: 'Missing ?u=<segment url>' });
    return;
  }
  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }
  const host = parsed.hostname.toLowerCase();
  const allowed = [...SEGMENT_HOSTS].some(
    (h) => host === h || host.endsWith(`.${h}`),
  );
  if (parsed.protocol !== 'https:' || !allowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }
  if (!(await isPublicDnsHost(host))) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      headers: {
        'User-Agent': DESKTOP_UA,
        Accept: '*/*',
        Referer: 'https://kwik.cx/',
      },
      redirect: 'follow',
      signal: AbortSignal.timeout(30000),
    });
    if (!upstream.ok) {
      res.status(upstream.status).json({ error: `Upstream ${upstream.status}` });
      return;
    }
    res.set(
      'Content-Type',
      upstream.headers.get('content-type') || 'application/octet-stream',
    );
    res.set('Cache-Control', 'public, max-age=300');
    if (upstream.body && typeof upstream.body.getReader === 'function') {
      const reader = upstream.body.getReader();
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(Buffer.from(value));
      }
      res.end();
      return;
    }
    res.status(200).send(Buffer.from(await upstream.arrayBuffer()));
  } catch (e) {
    console.warn(`[proxyAnimeSegment] failed (${host}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = {
  proxyAnime,
  proxyAnimeSegment,
  // Pure helpers (unit-tested).
  normTitle,
  pickBestMatch,
  validateAnimeParams,
  failHtml,
  hlsPlayerHtml,
  firstM3u8,
  NO_SOURCE_MARKER,
};
