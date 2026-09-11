'use strict';

/**
 * Everglow anime resolver — ad-free HiAnime + Megavid playback.
 *
 * The app never talks to third-party anime APIs directly. It loads one of
 * these URLs in the sandboxed player frame:
 *
 *   GET /proxyAnime?source=hianime|megavid|anivexa&anilistId=<id>&malId=<id>
 *       &ep=<n>&audio=sub|dub&token=<firebase id token>
 *
 * The function resolves the episode server-side (through our own
 * self-hosted HiAnime / AnimePahe / Anivexa API instances, whose base
 * URLs stay in server env vars) and serves a clean player page from OUR
 * domain — so no third-party ad script ever reaches Clair's phone.
 *
 * Self-host one instance of each (personal use only):
 *   - HiAnime API : https://github.com/MSMods-Pro/hianime-api
 *                   (Docker or Cloudflare Workers)
 *   - AnimePahe API: https://github.com/ElijahCodes12345/animepahe-api
 *                   (Docker or Railway; needs `npx playwright install`)
 *   - Anivexa API : https://github.com/walterwhite-69/Anivexa-API
 *                   (Node.js; Railway/Render/VPS — NOT Vercel, whose
 *                   datacenter IPs anime upstreams block)
 * Then set HIANIME_API_BASE / ANIMEPAHE_API_BASE / ANIVEXA_API_BASE on
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
  if (
    source !== 'hianime' &&
    source !== 'animepahe' &&
    source !== 'megavid' &&
    source !== 'anivexa'
  ) {
    return {
      error: 'source must be hianime, animepahe, megavid, or anivexa',
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

const DEFAULT_BASES = {
  HIANIME_API_BASE: 'https://hianime-api-two.vercel.app',
  // No public default: Anivexa must be self-hosted (personal use only).
  // Until ANIVEXA_API_BASE is set, the source fails over with the
  // "no playable stream sources" marker like any missing backend.
  ANIVEXA_API_BASE: '',
};

/** Anivexa providers to try, cleanest direct streams first.
 *
 * AniZone serves plain HLS with no token games (verified live); MP4
 * hosts follow; FlixCloud-backed providers sit last because their
 * playlists are encrypted and IP-bound, so they fail our playback
 * check and are skipped automatically. */
const ANIVEXA_PROVIDERS = [
  'anizone',
  'animegg',
  'anikoto',
  'anineko',
  '2dhive',
  'anibd',
  'kaa',
  'animedunya',
  'aniwaves',
  'reanime',
];

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

// ─── Megavid stream verification ────────────────────────────────

/** Origin our player pages serve from. Verification requests carry it so
 *  upstream CORS behavior matches what the real player sees in a browser —
 *  several CDNs only emit access-control headers when Origin is present. */
const PLAYER_ORIGIN = 'https://us-central1-everglow-1c6db.cloudfunctions.net';

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
 * Fetches an HLS playlist: it must answer 200, allow our player origin
 * (hls.js fetches with CORS — a playlist without the header can never
 * play in our player), and actually parse as a playlist.
 */
async function fetchPlaylist(url, timeoutMs, label) {
  const res = await fetch(url, {
    headers: {
      'User-Agent': DESKTOP_UA,
      Accept: '*/*',
      Referer: 'https://megavid.buzz/',
      Origin: PLAYER_ORIGIN,
    },
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) throw new Error(`megavid ${label} ${res.status}`);
  const allow =
    res.headers && typeof res.headers.get === 'function'
      ? res.headers.get('access-control-allow-origin')
      : null;
  if (!allow) {
    throw new Error(`megavid ${label} blocks cross-origin playback`);
  }
  const text = await res.text();
  if (!text || !text.includes('#EXTM3U')) {
    throw new Error(`megavid ${label} is not a playlist`);
  }
  return text;
}

/**
 * Downloads just the first bytes of a segment, key, or init map: proves
 * the file exists without pulling megabytes when the CDN ignores our
 * Range request. Like playlists, these go through hls.js, so the CORS
 * header is required too. Returns the first chunk for content checks.
 */
async function fetchSegmentHead(url, timeoutMs, label) {
  const res = await fetch(url, {
    headers: {
      'User-Agent': DESKTOP_UA,
      Accept: '*/*',
      Referer: 'https://megavid.buzz/',
      Origin: PLAYER_ORIGIN,
      Range: 'bytes=0-1023',
    },
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) throw new Error(`megavid ${label} ${res.status}`);
  const allow =
    res.headers && typeof res.headers.get === 'function'
      ? res.headers.get('access-control-allow-origin')
      : null;
  if (!allow) {
    throw new Error(`megavid ${label} blocks cross-origin playback`);
  }
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

/**
 * Proves a Megavid stream is actually playable before we serve our player
 * page for it: master playlist, every variant (the player auto-switches
 * quality, so each rendition must work — or the master itself when it
 * already lists segments), encryption key / init map when present, and
 * each variant's first segment must all fetch with playable bytes.
 * Anything dead throws, and the endpoint answers with the failover marker
 * so the app advances to the next server instead of stalling on a spinner.
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

// ─── Megavid (Direct HLS Stream with NO ADS) ─────────────

async function resolveMegavid(anilistId, malId, ep, audio) {
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
  return {
    playerHtml: hlsPlayerHtml({
      src: data.source,
      tracks,
      title: `Episode ${ep}`,
    }),
  };
}

// ─── Anivexa (AniList-keyed aggregator, direct streams, NO ADS) ───

/** Picks the episode id for [ep] from one Anivexa provider node.
 *  Pure: `data` is one `/episodes/...` response, `provider` one of
 *  [ANIVEXA_PROVIDERS]. Falls back to sub when the dub list is empty
 *  and to index position when numbering is off. */
function pickAnivexaEpisode(data, provider, ep, audio) {
  const node = data && data[provider];
  const bucket = node && node.episodes;
  const wanted =
    bucket && Array.isArray(bucket[audio]) && bucket[audio].length
      ? bucket[audio]
      : bucket && bucket.sub;
  if (!Array.isArray(wanted)) return null;
  const list = wanted;
  const hit =
    list.find((e) => Number(e && e.number) === ep) || list[ep - 1];
  return hit && hit.id ? String(hit.id) : null;
}

/** Picks the cleanest playable stream from an Anivexa `/watch/...`
 *  response. Pure: prefers plain HLS over MP4 and never returns
 *  `embed` fallbacks (those carry third-party ad scripts). Subtitle
 *  entries are normalized to the `{file, label}` shape [hlsPlayerHtml]
 *  expects. */
function pickAnivexaStream(watch) {
  const streams =
    watch && Array.isArray(watch.streams) ? watch.streams : [];
  const playable = streams.filter(
    (s) =>
      s &&
      typeof s.url === 'string' &&
      /^https?:\/\//i.test(s.url) &&
      (s.type === 'hls' || s.type === 'mp4'),
  );
  if (!playable.length) return null;
  const best =
    playable.find((s) => s.type === 'hls') || playable[0];
  const subs =
    watch && Array.isArray(watch.subtitles) ? watch.subtitles : [];
  const tracks = subs
    .filter((t) => t && (t.url || t.file))
    .map((t) => ({
      file: t.url || t.file,
      label: t.language || t.label || 'Subtitles',
    }))
    .slice(0, 8);
  return { src: best.url, tracks, type: best.type };
}

/** Fetches an Anivexa HLS playlist and proves it is a real playlist.
 *  (Unlike [fetchPlaylist], this stays host-neutral: third-party anime
 *  CDNs rarely send the CORS header Megavid's CDN does.) */
async function fetchAnivexaPlaylist(url, timeoutMs, label) {
  const res = await fetch(url, {
    headers: { 'User-Agent': DESKTOP_UA, Accept: '*/*' },
    redirect: 'follow',
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok && res.status !== 206) {
    throw new Error(`anivexa ${label} ${res.status}`);
  }
  const text = await res.text();
  if (!text || !text.includes('#EXTM3U')) {
    throw new Error(`anivexa ${label} is not a playlist`);
  }
  return text;
}

/** Confirms one MP4 file answers as video, reading a single chunk so
 *  a full-file 200 never downloads the whole episode server-side. */
async function verifyAnivexaMp4(url) {
  const res = await fetch(url, {
    headers: {
      'User-Agent': DESKTOP_UA,
      Accept: '*/*',
      Range: 'bytes=0-1023',
    },
    redirect: 'follow',
    signal: AbortSignal.timeout(8000),
  });
  if (!res.ok && res.status !== 206) {
    throw new Error(`anivexa file ${res.status}`);
  }
  const ct = (res.headers.get('content-type') || '').toLowerCase();
  if (!ct.includes('video/') && !ct.includes('octet-stream')) {
    throw new Error('anivexa file is not video');
  }
  try {
    if (res.body && typeof res.body.getReader === 'function') {
      const reader = res.body.getReader();
      try {
        await reader.read();
      } finally {
        try {
          await reader.cancel();
        } catch (_) {}
      }
    } else {
      await res.arrayBuffer();
    }
  } catch (_) {}
}

/** Proves a candidate stream actually plays before we hand it to
 *  Clair's phone: HLS playlists must parse down to a variant with
 *  segments (this also rejects the encrypted blobs some hosts
 *  serve with a playlist content-type); MP4s must answer as video.
 *  Anything dead throws so the caller moves to the next provider. */
async function verifyAnivexaStream(url, type) {
  if (type === 'mp4') {
    await verifyAnivexaMp4(url);
    return;
  }
  const master = await fetchAnivexaPlaylist(url, 8000, 'playlist');
  const variants = playlistUris(master, url, { variantsOnly: true });
  const mediaUrl = variants.length > 0 ? variants[0] : url;
  const media =
    variants.length > 0
      ? await fetchAnivexaPlaylist(mediaUrl, 8000, 'variant')
      : master;
  const segments = playlistUris(media, mediaUrl);
  if (!segments.length) throw new Error('anivexa: playlist has no segments');
}

async function resolveAnivexa(base, anilistId, ep, audio) {
  for (const provider of ANIVEXA_PROVIDERS) {
    let epId = null;
    try {
      const data = await fetchJson(
        `${base}/episodes/${provider}/${anilistId}`,
        10000,
      );
      epId = pickAnivexaEpisode(data, provider, ep, audio);
    } catch (_) {
      continue;
    }
    if (!epId) continue;
    try {
      const watch = await fetchJson(`${base}/${epId}`, 12000);
      const pick = pickAnivexaStream(watch);
      if (!pick) continue;
      // Removed episodes answer with dead links — verify first so the
      // app fails over to the next provider instead of stalling.
      await verifyAnivexaStream(pick.src, pick.type);
      return {
        playerHtml: hlsPlayerHtml({
          src: pick.src,
          tracks: pick.tracks,
          title: `Episode ${ep}`,
        }),
      };
    } catch (_) {
      continue;
    }
  }
  throw new Error('anivexa: no playable source found');
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
      const out = await resolveMegavid(anilistId, malId, ep, audio);
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

  // Anivexa is AniList-keyed and needs no title lookup: one id in,
  // direct streams out. It sits beside Megavid, ahead of the
  // title-search sources.
  if (source === 'anivexa') {
    if (anilistId <= 0) {
      sendFail('Anivexa needs an AniList id — try another server.');
      return;
    }
    const anivexaBase = await envBase('ANIVEXA_API_BASE');
    if (!anivexaBase) {
      sendFail('Source is not set up yet — try another server.');
      return;
    }
    try {
      const out = await resolveAnivexa(anivexaBase, anilistId, ep, audio);
      res.set('Content-Type', 'text/html; charset=utf-8');
      res.set('Cache-Control', 'public, max-age=300');
      res.status(200).send(out.playerHtml);
    } catch (e) {
      sendFail('No stream found — try another server.');
    }
    return;
  }

  const base = await envBase(
    source === 'hianime' ? 'HIANIME_API_BASE' : 'ANIMEPAHE_API_BASE',
  );
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
  ANIVEXA_PROVIDERS,
  pickAnivexaEpisode,
  pickAnivexaStream,
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
  NO_SOURCE_MARKER,
};
