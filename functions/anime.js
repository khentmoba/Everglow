'use strict';

/**
 * Everglow anime resolver — ad-free Megavid (+ legacy AnimePahe) playback.
 *
 * The app never talks to third-party anime APIs directly. It loads one of
 * these URLs in the sandboxed player frame:
 *
 *   GET /proxyAnime?source=megavid|animepahe&anilistId=<id>&malId=<id>
 *       &ep=<n>&audio=sub|dub&token=<firebase id token>
 *
 * The function resolves the episode server-side (through our own
 * self-hosted AnimePahe API instance, whose base
 * URL stays in a server env var) and serves a clean player page from OUR
 * domain — so no third-party ad script ever reaches Clair's phone.
 *
 * Self-host one instance (personal use only):
 *   - AnimePahe API: https://github.com/ElijahCodes12345/animepahe-api
 *                   (Docker or Railway; needs `npx playwright install`)
 * Then set ANIMEPAHE_API_BASE on
 * the functions (firebase functions .env) and redeploy.
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

/** Ad-free HLS player with recovery. The video URL must already be playable
 *  from a browser (proxied through us when the upstream needs headers).
 *
 *  The first version attached hls.js and hoped for the best: any fatal
 *  stream error stalled on an endless spinner, and phones that block
 *  unmuted autoplay never started at all. This version starts playback once
 *  the manifest is ready, retries transient failures, and — after repeated
 *  fatal errors — shows a "try another server" card with a retry button
 *  instead of spinning forever. The card deliberately avoids the failover
 *  marker text, so the app's server probe never mistakes a healthy player
 *  page for a dead one. */
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
    '<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}' +
    'video{width:100%;height:100%;background:#000}' +
    '.ov{position:fixed;inset:0;display:flex;align-items:center;' +
    'justify-content:center;background:rgba(0,0,0,.72);z-index:5}' +
    '.spin{width:44px;height:44px;border:4px solid rgba(255,255,255,.2);' +
    'border-top-color:#fff;border-radius:50%;animation:sp 1s linear infinite}' +
    '@keyframes sp{to{transform:rotate(360deg)}}' +
    '#tap{cursor:pointer;border:0;border-radius:999px;padding:14px 26px;' +
    'font-size:16px;font-weight:700;color:#fff;background:#ff2e63}' +
    '#dead{flex-direction:column;text-align:center;color:#e2e2ea;' +
    'font-family:sans-serif;padding:0 28px}' +
    '#dead button{margin-top:14px;cursor:pointer;border:1px solid #ff2e63;' +
    'border-radius:999px;padding:10px 24px;font-size:14px;color:#fff;' +
    'background:transparent}' +
    '</style></head><body>' +
    '<video id="v" controls playsinline autoplay preload="auto" ' +
    'crossorigin="anonymous">' +
    (trackTags ? '\n    ' + trackTags : '') +
    '</video>\n' +
    '<div class="ov" id="boot"><div class="spin"></div></div>\n' +
    '<div class="ov" id="tapw" hidden>' +
    '<button id="tap">&#9654; Tap to play</button></div>\n' +
    '<div class="ov" id="dead" hidden>' +
    '<p style="font-size:15px;margin:0 0 6px">This stream stalled.</p>' +
    '<p style="font-size:12px;color:#8b8b9e;margin:0">' +
    'Try another server below — or retry here.</p>' +
    '<button onclick="location.reload()">Retry</button></div>\n' +
    '<script src="https://cdn.jsdelivr.net/npm/hls.js@1"></script>\n' +
    '<script>(function(){var src=' + JSON.stringify(src) + ';var v=' +
    'document.getElementById("v");' +
    'var boot=document.getElementById("boot");' +
    'var tapw=document.getElementById("tapw");' +
    'var tap=document.getElementById("tap");' +
    'var dead=document.getElementById("dead");' +
    'function hideBoot(){boot.style.display="none";}' +
    'function showTap(){tapw.hidden=false;}' +
    'function tryPlay(){var p;try{p=v.play();}catch(e){showTap();return;}' +
    'if(p&&p.catch){p.catch(function(){showTap();});}}' +
    'function giveUp(){hideBoot();tapw.hidden=true;dead.hidden=false;' +
    'try{window.parent.postMessage("animex-content-error","*");}' +
    'catch(e){}}' +
    'tap.addEventListener("click",function(){tapw.hidden=true;tryPlay();});' +
    'v.addEventListener("playing",function(){hideBoot();tapw.hidden=true;});' +
    'v.addEventListener("waiting",function(){' +
    'if(dead.hidden){boot.style.display="flex";}});' +
    'if(window.Hls&&Hls.isSupported()){' +
    'var h=new Hls({maxBufferLength:30});var fatal=0;' +
    'h.on(Hls.Events.ERROR,function(ev,data){' +
    'if(!data||!data.fatal){return;}fatal++;' +
    'if(fatal>3){try{h.destroy();}catch(e){}giveUp();return;}' +
    'var ET=Hls.ErrorTypes||{};' +
    'try{' +
    'if(data.type===ET.NETWORK_ERROR){h.startLoad();}' +
    'else if(data.type===ET.MEDIA_ERROR){h.recoverMediaError();}' +
    'else if(fatal<3){h.startLoad();}' +
    'else{h.destroy();giveUp();}' +
    '}catch(e){giveUp();}});' +
    'h.on(Hls.Events.MANIFEST_PARSED,function(){tryPlay();});' +
    'h.loadSource(src);h.attachMedia(v);' +
    '}else{' +
    'v.src=src;' +
    'v.addEventListener("loadedmetadata",function(){tryPlay();});' +
    'v.addEventListener("error",function(){giveUp();});' +
    '}});</' + 'script></body></html>'
  );
}

function validateAnimeParams(query) {
  const source = String(query.source || '').toLowerCase();
  if (source !== 'animepahe' && source !== 'megavid') {
    return {
      error: 'source must be animepahe or megavid',
    };
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

const DEFAULT_BASES = {};

/** Our self-hosted API hosts come from env or default bases,
 *  and must be public https hosts — same SSRF guard as the other proxies. */
async function envBase(name) {
  const raw = (process.env[name] || DEFAULT_BASES[name] || '')
    .trim()
    .replace(/\/+$/, '');
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

// ─── Megavid stream verification ────────────────────────────────

/** Megavid upstream hosts. Restricted allowlist so the HLS proxy below
 *  can never become an open proxy. */
const MEGAVID_HOSTS = new Set(['megavid.buzz']);

function isMegavidHost(hostname) {
  const h = String(hostname || '').toLowerCase();
  return [...MEGAVID_HOSTS].some((a) => h === a || h.endsWith(`.${a}`));
}

/** Resolves a possibly-relative playlist URI against its playlist URL. */
function resolvePlaylistUrl(ref, base) {
  try {
    const abs = new URL(String(ref || '').trim(), base).toString();
    if (abs.startsWith('https://') || abs.startsWith('http://')) return abs;
    return null;
  } catch (_) {
    return null;
  }
}

/**
 * Non-comment URIs from an HLS playlist, resolved to absolute http(s) URLs.
 * With [variantsOnly], only URIs following an `#EXT-X-STREAM-INF` line are
 * returned (master playlist quality variants).
 */
function playlistUris(text, base, { variantsOnly = false } = {}) {
  const lines = String(text || '').split(/\r?\n/);
  const out = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line || line.startsWith('#')) continue;
    if (variantsOnly) {
      const prev = (lines[i - 1] || '').trim();
      if (!prev.startsWith('#EXT-X-STREAM-INF')) continue;
    }
    const abs = resolvePlaylistUrl(line, base);
    if (abs && !out.includes(abs)) out.push(abs);
  }
  return out;
}

/**
 * Fetches an HLS playlist: it must answer 200 and actually parse as a
 * playlist. No CORS check here — server-side fetches ignore CORS, and
 * the browser never touches this URL directly (see proxyMegavidHls,
 * which re-serves everything from our own domain with `*`).
 */
async function fetchPlaylist(url, timeoutMs, label) {
  const res = await fetch(url, {
    headers: {
      'User-Agent': DESKTOP_UA,
      Accept: '*/*',
      Referer: 'https://megavid.buzz/',
    },
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) throw new Error(`megavid ${label} ${res.status}`);
  const text = await res.text();
  if (!text || !text.includes('#EXTM3U')) {
    throw new Error(`megavid ${label} is not a playlist`);
  }
  return text;
}

/**
 * Downloads just the first bytes of a segment, key, or init map: proves
 * the file exists without pulling megabytes when the CDN ignores our
 * Range request. No CORS check — the browser streams through
 * proxyMegavidHls (same-origin + `*`), so upstream headers don't matter.
 * Returns the first chunk for content checks.
 */
async function fetchSegmentHead(url, timeoutMs, label) {
  const res = await fetch(url, {
    headers: {
      'User-Agent': DESKTOP_UA,
      Accept: '*/*',
      Referer: 'https://megavid.buzz/',
      Range: 'bytes=0-1023',
    },
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) throw new Error(`megavid ${label} ${res.status}`);
  if (!res.body || typeof res.body.getReader !== 'function') {
    const buf = await res.arrayBuffer();
    if (!buf.byteLength) throw new Error(`megavid ${label} is empty`);
    return new Uint8Array(buf.slice(0, 1024));
  }
  const reader = res.body.getReader();
  try {
    const { done, value } = await reader.read();
    if (done || !value || !value.byteLength) {
      throw new Error(`megavid ${label} is empty`);
    }
    return value.slice ? value.slice(0, 1024) : value;
  } finally {
    try {
      await reader.cancel();
    } catch (_) {}
  }
}

/**
 * First segment bytes must look like MPEG-TS (sync byte 0x47) when the URL
 * points at a .ts file. CDNs often answer 200 with an HTML error page for
 * removed files — fetchable, but it can never play. Other containers
 * (fmp4 segments) only need to be non-empty.
 */
function assertPlayableHead(chunk, url, label) {
  const path = String(url).split('?')[0].toLowerCase();
  if (path.endsWith('.ts') && chunk[0] !== 0x47) {
    throw new Error(`megavid ${label} is not video data`);
  }
}

/** Total seconds of content in a media playlist. */
function playlistDuration(text) {
  let total = 0;
  for (const line of String(text || '').split(/\r?\n/)) {
    const m = line.trim().match(/^#EXTINF:\s*([0-9]+(?:\.[0-9]+)?)/);
    if (m) total += Number.parseFloat(m[1]);
  }
  return total;
}

/**
 * Minimum seconds for a playlist to plausibly be a full episode or movie.
 * Truncated uploads, trailers misfiled as episodes, and DMCA-gutted files
 * (seconds of valid video with a healthy structure) fail over instead of
 * playing a minute and dying. Rejecting here only demotes Megavid for the
 * title — the app still tries the next server.
 */
const MIN_MEGAVID_SECONDS = 120;

/**
 * Proves a Megavid stream is actually playable before we serve our player
 * page for it: master playlist, every variant (the player auto-switches
 * quality, so each rendition must work — or the master itself when it
 * already lists segments), encryption key / init map when present, and
 * each variant's first segment must all fetch with playable bytes. Every
 * rendition must also hold a plausible amount of content. Anything dead
 * throws, and the endpoint answers with the failover marker so the app
 * advances to the next server instead of stalling on a spinner.
 */
async function verifyMegavidStream(masterUrl) {
  const masterText = await fetchPlaylist(masterUrl, 8000, 'playlist');
  const variants = playlistUris(masterText, masterUrl, { variantsOnly: true });
  const medias =
    variants.length > 0
      ? await Promise.all(
          variants.slice(0, 4).map(async (v) => ({
            url: v,
            text: await fetchPlaylist(v, 8000, 'variant'),
          })),
        )
      : [{ url: masterUrl, text: masterText }];
  const first = medias[0];
  const keyMatch = first.text.match(/#EXT-X-KEY[^\r\n]*URI="([^"]+)"/);
  if (keyMatch) {
    const keyUrl = resolvePlaylistUrl(keyMatch[1], first.url);
    if (keyUrl) await fetchSegmentHead(keyUrl, 8000, 'key');
  }
  const mapMatch = first.text.match(/#EXT-X-MAP[^\r\n]*URI="([^"]+)"/);
  if (mapMatch) {
    const mapUrl = resolvePlaylistUrl(mapMatch[1], first.url);
    if (mapUrl) await fetchSegmentHead(mapUrl, 8000, 'init map');
  }
  await Promise.all(
    medias.map(async ({ url: mediaUrl, text: mediaText }) => {
      if (playlistDuration(mediaText) < MIN_MEGAVID_SECONDS) {
        throw new Error('megavid: playlist too short to be the episode');
      }
      const segments = playlistUris(mediaText, mediaUrl);
      if (!segments.length) {
        throw new Error('megavid: playlist has no segments');
      }
      const head = await fetchSegmentHead(segments[0], 10000, 'segment');
      assertPlayableHead(head, segments[0], 'segment');
    }),
  );
  const firstSegments = playlistUris(first.text, first.url);
  return { variantUrl: first.url, segmentUrl: firstSegments[0] };
}

// ─── Megavid (Proxied HLS Stream with NO ADS) ─────────────

/** Builds our same-origin proxy URL for one upstream Megavid file.
 *  Pure: `proxyBase` is `https://<host>/proxyMegavidHls`. */
function megavidProxyUrl(proxyBase, token, absUrl) {
  return (
    `${proxyBase}?u=${encodeURIComponent(absUrl)}` +
    `&token=${encodeURIComponent(String(token || ''))}`
  );
}

/** Rewrites every Megavid URI inside an HLS playlist to our proxy.
 *  Pure: bare URI lines plus `URI="..."` tag attributes (KEY/MAP/MEDIA).
 *  Non-Megavid URLs are left untouched so a future mixed playlist can't
 *  turn the proxy into an open relay. */
function rewritePlaylistWithHosts(text, playlistUrl, proxyBase, token, isAllowed) {
  const rewriteUri = (uri) => {
    const abs = resolvePlaylistUrl(uri, playlistUrl);
    if (!abs) return null;
    try {
      if (!isAllowed(new URL(abs).hostname)) return null;
    } catch (_) {
      return null;
    }
    return megavidProxyUrl(proxyBase, token, abs);
  };
  return String(text || '')
    .split(/\r?\n/)
    .map((line) => {
      const trimmed = line.trim();
      if (!trimmed) return line;
      if (trimmed.startsWith('#')) {
        if (!trimmed.includes('URI="')) return line;
        return line.replace(/URI="([^"]+)"/g, (m, uri) => {
          const out = rewriteUri(uri);
          return out ? `URI="${out}"` : m;
        });
      }
      const out = rewriteUri(trimmed);
      return out || line;
    })
    .join('\n');
}

function rewriteMegavidPlaylist(text, playlistUrl, proxyBase, token) {
  return rewritePlaylistWithHosts(
    text,
    playlistUrl,
    proxyBase,
    token,
    isMegavidHost,
  );
}

/** Own base URL for the Megavid HLS proxy, derived from the incoming
 *  request so staged and live hosts each rewrite to themselves. */
function megavidProxyBase(req) {
  const host = (req.get && req.get('host')) || req.headers.host || '';
  const proto = req.protocol || 'https';
  return `${proto}://${host}/proxyMegavidHls`;
}

async function resolveMegavid(anilistId, malId, ep, audio, req) {
  const isDub = audio === 'dub' ? 'dub' : 'sub';
  const url =
    anilistId > 0
      ? `https://megavid.buzz/ani/${anilistId}/${ep}/${isDub}/source`
      : `https://megavid.buzz/mal/${malId}/${ep}/${isDub}/source`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': DESKTOP_UA,
      Accept: 'application/json',
      Referer: 'https://megavid.buzz/',
    },
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) throw new Error(`megavid ${res.status}`);
  const data = await res.json();
  if (data.status !== 'ok' || !data.source) {
    throw new Error('megavid: no stream');
  }
  // Removed episodes and stale CDN records answer "ok" with a playlist
  // that never plays — verify first so the app fails over to the next
  // server instead of stalling (see verifyMegavidStream).
  await verifyMegavidStream(data.source);
  const tracks = (Array.isArray(data.tracks) ? data.tracks : []).filter(
    (t) => t && t.file,
  );
  // Megavid's CDN answers `access-control-allow-origin: https://megavid.buzz`
  // for every playlist and segment — never `*`, never our origin — so a
  // direct hls.js fetch from our player domain always dies on CORS and the
  // player shows "This stream stalled". Route every playlist, variant, key,
  // and segment through proxyMegavidHls (same-origin + `*`, Referer added
  // server-side) so the browser never talks to Megavid directly.
  const token = (req && req.query && req.query.token) || '';
  const src = megavidProxyUrl(
    megavidProxyBase(req),
    token,
    data.source,
  );
  return {
    playerHtml: hlsPlayerHtml({
      src,
      tracks,
      title: `Episode ${ep}`,
    }),
  };
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

  // Auth: token is validated if present; omitted/warming tokens are allowed
  // so public anime streaming isn't interrupted by async token refresh.
  const token = req.get('Authorization') || req.query.token;
  if (token) {
    await verifyToken(req);
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

  if (source === 'megavid') {
    try {
      const out = await resolveMegavid(anilistId, malId, ep, audio, req);
      res.set('Content-Type', 'text/html; charset=utf-8');
      res.set('Cache-Control', 'public, max-age=300');
      res.status(200).send(out.playerHtml);
      return;
    } catch (e) {
      // Megavid has no stream for this episode — its API answers
      // "missing" for unreleased or removed titles. The old code served
      // the Megavid website embed here, but that page just spins its
      // loader forever on missing episodes (and brings back the popunders
      // the direct-stream path was built to avoid). Fail with the marker
      // instead so the app auto-advances to the next server.
      sendFail('No stream found — try another server.');
      return;
    }
  }

  const base = await envBase('ANIMEPAHE_API_BASE');
  if (!base) {
    sendFail('Source is not set up yet — try another server.');
    return;
  }

  const clientTitle = String(req.query.title || '').trim();
  let titles = clientTitle ? [clientTitle] : [];
  let year = null;
  if (!titles.length) {
    try {
      const found = await anilistTitles(anilistId, malId);
      titles = found.titles;
      year = found.year;
    } catch (e) {
      sendFail('Title lookup failed — try another server.');
      return;
    }
  }
  if (!titles.length) {
    sendFail('Title lookup failed — try another server.');
    return;
  }

  try {
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

/** Megavid HLS proxy: re-serves playlists, keys, and segments from OUR
 *  domain so hls.js never hits Megavid's restrictive CORS (`allow-origin:
 *  https://megavid.buzz` only). Playlists are rewritten so every nested
 *  URI points back here; segments stream through with the Referer the
 *  CDN expects (browsers can't spoof it). Host allowlist keeps this from
 *  becoming an open proxy. Token is verified when present but optional —
 *  same public-anime rule as proxyAnime — so an expired token mid-episode
 *  never kills playback. */
const proxyMegavidHls = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range');
  res.set('Access-Control-Expose-Headers', 'Content-Range, Content-Length, Accept-Ranges');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.status(405).json({ error: 'GET only' });
    return;
  }
  const token = req.get('Authorization') || req.query.token;
  if (token) {
    // Best-effort: keep playback alive even when the token expired.
    try {
      await verifyToken(req);
    } catch (_) {}
  }

  const targetUrl = req.query.u;
  if (typeof targetUrl !== 'string' || !targetUrl) {
    res.status(400).json({ error: 'Missing ?u=<media url>' });
    return;
  }
  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }
  if (parsed.protocol !== 'https:' || !isMegavidHost(parsed.hostname)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }
  if (!(await isPublicDnsHost(parsed.hostname))) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }
  try {
    // Megavid's CDN only ever answers for its own origin.
    const headers = {
      'User-Agent': DESKTOP_UA,
      Accept: '*/*',
      Referer: 'https://megavid.buzz/',
    };
    const range = req.get('Range') || req.headers.range;
    if (range && typeof range === 'string') headers.Range = range;
    const upstream = await fetch(targetUrl, {
      headers,
      redirect: 'follow',
      signal: AbortSignal.timeout(25000),
    });
    if (!upstream.ok && upstream.status !== 206) {
      res.status(upstream.status).json({ error: `Upstream ${upstream.status}` });
      return;
    }
    const upstreamCt = (upstream.headers.get('content-type') || '').toLowerCase();
    const looksLikePlaylist =
      upstreamCt.includes('mpegurl') ||
      upstreamCt.includes('x-mpegurl') ||
      parsed.pathname.toLowerCase().includes('.m3u8');
    if (looksLikePlaylist) {
      const text = await upstream.text();
      if (text && text.includes('#EXTM3U')) {
        const proxyBase = megavidProxyBase(req);
        const tokenQ = String(req.query.token || '');
        const rewritten = rewriteMegavidPlaylist(
        text,
        targetUrl,
        proxyBase,
        tokenQ,
      );
        res.set('Content-Type', 'application/vnd.apple.mpegurl');
        res.set('Cache-Control', 'public, max-age=30');
        res.status(200).send(rewritten);
        return;
      }
      // Falls through as a plain file when the body isn't a playlist.
    }
    const ct =
      upstream.headers.get('content-type') || 'application/octet-stream';
    res.set('Content-Type', ct);
    res.set('Cache-Control', 'public, max-age=3600');
    const acceptRanges = upstream.headers.get('accept-ranges');
    if (acceptRanges) res.set('Accept-Ranges', acceptRanges);
    const contentRange = upstream.headers.get('content-range');
    if (contentRange) res.set('Content-Range', contentRange);
    const contentLength = upstream.headers.get('content-length');
    if (contentLength) res.set('Content-Length', contentLength);
    if (req.method === 'HEAD') {
      res.status(upstream.status === 206 ? 206 : 200).send('');
      return;
    }
    const status = upstream.status === 206 ? 206 : 200;
    if (upstream.body && typeof upstream.body.getReader === 'function') {
      const reader = upstream.body.getReader();
      res.status(status);
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(Buffer.from(value));
      }
      res.end();
      return;
    }
    res.status(status).send(Buffer.from(await upstream.arrayBuffer()));
  } catch (e) {
    console.warn(`[proxyMegavidHls] failed (${parsed.hostname}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
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
  proxyMegavidHls,
  // Pure helpers (unit-tested).
  normTitle,
  pickBestMatch,
  validateAnimeParams,
  failHtml,
  hlsPlayerHtml,
  firstM3u8,
  resolvePlaylistUrl,
  playlistUris,
  verifyMegavidStream,
  assertPlayableHead,
  playlistDuration,
  MIN_MEGAVID_SECONDS,
  NO_SOURCE_MARKER,
  isMegavidHost,
  megavidProxyUrl,
  rewriteMegavidPlaylist,
}
