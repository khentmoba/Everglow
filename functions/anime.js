'use strict';

const crypto = require('crypto');
const { streamMediaBody } = require('./stream_media_body');
const { escHtml, hlsPlayerHtml } = require('./hls_player');

const common = require('./common.js');
const { applyCors, getAdmin, getDb, getVerifiedUsername, isPublicDnsHost, enforceRateLimit, cappedHttps } = common;

const DESKTOP_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const NO_SOURCE_MARKER = 'no playable stream sources';

const SEGMENT_HOSTS = new Set(['kwik.cx', 'kwik.si', 'pahe.win']);

function normTitle(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');
}

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

function validateAnimeParams(query) {
  const source = String(query.source || '').toLowerCase();
  if (
    source !== 'animepahe' &&
    source !== 'megavid' &&
    source !== 'megaplay' &&
    source !== 'everglow'
  ) {
    return {
      error: 'source must be animepahe, megavid, megaplay, or everglow',
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
    const decoded = await getAdmin().auth().verifyIdToken(token);
    return await getVerifiedUsername(decoded) ? decoded : null;
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

const MEGAVID_HOSTS = new Set([
  'megavid.buzz',
  'cdn.api-webs.com',
  'megavid.se',
]);
const MEGAVID_EXACT_HOSTS = new Set(['cdnx.aniwatchtv.site']);

const MEGAPLAY_HOSTS = new Set([
  'megaplay.buzz',
  'nexabloom.top',
  'qeltrix.top',
  'eclipseharbor.world',
  'eclipseharbor.space',
  'emeralddrift.world',
  'emeralddrift.space',
]);

const MEGAVID_ORIGIN = 'https://megavid.buzz';

const MEGAPLAY_ORIGIN = 'https://megaplay.buzz';

const MEGAPLAY_ENC_KEY = 'i?LMTAx0Q6,:}50U';
const MEGAPLAY_ENC_IV = "W0;27ToaUpl_P%'c";
const MEGAPLAY_HMAC_SECRET = 'MpCdnT0k3n!9f2K#xQ7vL5mR8wN1pY4s';

function megavidHeaders(extra) {
  return Object.assign(
    {
      'User-Agent': DESKTOP_UA,
      Accept: '*/*',
      Referer: `${MEGAVID_ORIGIN}/`,
      Origin: MEGAVID_ORIGIN,
    },
    extra || {},
  );
}

function megaplayHeaders(extra) {
  return Object.assign(
    {
      'User-Agent': DESKTOP_UA,
      Accept: '*/*',
      Referer: `${MEGAPLAY_ORIGIN}/`,
      Origin: MEGAPLAY_ORIGIN,
    },
    extra || {},
  );
}

function isMegavidHost(hostname) {
  const h = String(hostname || '').toLowerCase();
  return (
    MEGAVID_EXACT_HOSTS.has(h) ||
    [...MEGAVID_HOSTS].some((a) => h === a || h.endsWith(`.${a}`))
  );
}

function isMegaPlayHost(hostname) {
  const h = String(hostname || '').toLowerCase();
  return [...MEGAPLAY_HOSTS].some((a) => h === a || h.endsWith(`.${a}`));
}

function isAnimeCdnHost(hostname) {
  return isMegavidHost(hostname) || isMegaPlayHost(hostname);
}

let cdnKeyPromise = null;
function cdnKey() {
  if (!cdnKeyPromise) {
    const db = getDb();
    const ref = db.collection('server_keys').doc('anime_cdn');
    cdnKeyPromise = db
      .runTransaction(async (tx) => {
        const saved = await tx.get(ref);
        if (saved.exists && saved.data().secret) return saved.data().secret;
        const secret = crypto.randomBytes(32).toString('hex');
        tx.set(ref, { secret });
        return secret;
      })
      .catch((e) => {
        cdnKeyPromise = null;
        throw e;
      });
  }
  return cdnKeyPromise;
}

function cdnStamp(key, url) {
  return crypto.createHmac('sha256', key).update(String(url)).digest('hex');
}

function validCdnStamp(key, url, stamp) {
  if (!key || !/^[a-f0-9]{64}$/.test(String(stamp || ''))) return false;
  return crypto.timingSafeEqual(
    Buffer.from(cdnStamp(key, url), 'hex'),
    Buffer.from(stamp, 'hex'),
  );
}

function megaplayProxyUrl(proxyBase, absUrl, key) {
  const url = megavidProxyUrl(proxyBase, absUrl);
  let host = '';
  try {
    host = new URL(absUrl).hostname;
  } catch (_) {}
  if (!key || isAnimeCdnHost(host)) return url;
  return `${url}&s=${cdnStamp(key, absUrl)}`;
}

function padKeyBytes(str, len) {
  const enc = Buffer.from(str, 'utf8');
  const out = Buffer.alloc(len, 0);
  enc.copy(out, 0, 0, Math.min(enc.length, len));
  return out;
}

function base64url(buf) {
  return Buffer.from(buf)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function decryptMegaPlayPayload(encStr) {
  const key = padKeyBytes(MEGAPLAY_ENC_KEY, 32);
  const iv = padKeyBytes(MEGAPLAY_ENC_IV, 16);
  let b64 = String(encStr || '').replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4) b64 += '=';
  const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
  let decrypted = decipher.update(Buffer.from(b64, 'base64'));
  decrypted = Buffer.concat([decrypted, decipher.final()]);
  return JSON.parse(decrypted.toString('utf8'));
}

function makeMegaPlayToken(path) {
  const exp = Math.floor(Date.now() / 1000) + 90;
  const payload = `${exp}|${path}`;
  const hmac = crypto
    .createHmac('sha256', MEGAPLAY_HMAC_SECRET)
    .update(payload)
    .digest();
  return `${base64url(Buffer.from(payload))}.${base64url(hmac)}`;
}

function resolvePlaylistUrl(ref, base) {
  try {
    const abs = new URL(String(ref || '').trim(), base).toString();
    if (abs.startsWith('https://') || abs.startsWith('http://')) return abs;
    return null;
  } catch (_) {
    return null;
  }
}

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

async function fetchPlaylist(url, timeoutMs, label, headers = megavidHeaders()) {
  const res = await fetch(url, {
    headers,
    signal: AbortSignal.timeout(timeoutMs),
  });
  const prefix = isMegaPlayHost(new URL(url).hostname) ? 'megaplay' : 'megavid';
  if (!res.ok) throw new Error(`${prefix} ${label} ${res.status}`);
  const text = await res.text();
  if (!text || !text.includes('#EXTM3U')) {
    throw new Error(`${prefix} ${label} is not a playlist`);
  }
  return text;
}

async function fetchSegmentHead(url, timeoutMs, label, headers = megavidHeaders()) {
  const h = Object.assign({}, headers, { Range: 'bytes=0-1023' });
  const res = await fetch(url, {
    headers: h,
    signal: AbortSignal.timeout(timeoutMs),
  });
  const prefix = isMegaPlayHost(new URL(url).hostname) ? 'megaplay' : 'megavid';
  if (!res.ok) throw new Error(`${prefix} ${label} ${res.status}`);
  if (!res.body || typeof res.body.getReader !== 'function') {
    const buf = await res.arrayBuffer();
    if (!buf.byteLength) throw new Error(`${prefix} ${label} is empty`);
    return new Uint8Array(buf.slice(0, 1024));
  }
  const reader = res.body.getReader();
  try {
    const { done, value } = await reader.read();
    if (done || !value || !value.byteLength) {
      throw new Error(`${prefix} ${label} is empty`);
    }
    return value.slice ? value.slice(0, 1024) : value;
  } finally {
    try {
      await reader.cancel();
    } catch (_) {}
  }
}

function assertPlayableHead(chunk, url, label) {
  const path = String(url).split('?')[0].toLowerCase();
  const prefix = isMegaPlayHost(new URL(url).hostname) ? 'megaplay' : 'megavid';
  if (path.endsWith('.ts') && chunk[0] !== 0x47) {
    throw new Error(`${prefix} ${label} is not video data`);
  }
  if (path.endsWith('.jpg') && isMegaPlayHost(new URL(url).hostname) && chunk[0] !== 0x47) {
    throw new Error(`${prefix} ${label} is not video data`);
  }
}

function playlistDuration(text) {
  let total = 0;
  for (const line of String(text || '').split(/\r?\n/)) {
    const m = line.trim().match(/^#EXTINF:\s*([0-9]+(?:\.[0-9]+)?)/);
    if (m) total += Number.parseFloat(m[1]);
  }
  return total;
}

const MIN_MEGAVID_SECONDS = 120;

async function verifyStream(masterUrl, headers = megavidHeaders()) {
  const prefix = isMegaPlayHost(new URL(masterUrl).hostname) ? 'megaplay' : 'megavid';
  const masterText = await fetchPlaylist(masterUrl, 8000, 'playlist', headers);
  const variants = playlistUris(masterText, masterUrl, { variantsOnly: true });
  const medias =
    variants.length > 0
      ? await Promise.all(
          variants.slice(0, 4).map(async (v) => ({
            url: v,
            text: await fetchPlaylist(v, 8000, 'variant', headers),
          })),
        )
      : [{ url: masterUrl, text: masterText }];
  const first = medias[0];
  const keyMatch = first.text.match(/#EXT-X-KEY[^\r\n]*URI="([^"]+)"/);
  if (keyMatch) {
    const keyUrl = resolvePlaylistUrl(keyMatch[1], first.url);
    if (keyUrl) await fetchSegmentHead(keyUrl, 8000, 'key', headers);
  }
  const mapMatch = first.text.match(/#EXT-X-MAP[^\r\n]*URI="([^"]+)"/);
  if (mapMatch) {
    const mapUrl = resolvePlaylistUrl(mapMatch[1], first.url);
    if (mapUrl) await fetchSegmentHead(mapUrl, 8000, 'init map', headers);
  }
  await Promise.all(
    medias.map(async ({ url: mediaUrl, text: mediaText }) => {
      if (playlistDuration(mediaText) < MIN_MEGAVID_SECONDS) {
        throw new Error(`${prefix}: playlist too short to be the episode`);
      }
      const segments = playlistUris(mediaText, mediaUrl);
      if (!segments.length) {
        throw new Error(`${prefix}: playlist has no segments`);
      }
      const head = await fetchSegmentHead(segments[0], 10000, 'segment', headers);
      assertPlayableHead(head, segments[0], 'segment');
    }),
  );
  const firstSegments = playlistUris(first.text, first.url);
  return { variantUrl: first.url, segmentUrl: firstSegments[0] };
}

async function verifyMegavidStream(masterUrl) {
  return verifyStream(masterUrl, megavidHeaders());
}

async function verifyMegaPlayStream(masterUrl) {
  return verifyStream(masterUrl, megaplayHeaders());
}

function megavidProxyUrl(proxyBase, absUrl) {
  return `${proxyBase}?u=${encodeURIComponent(absUrl)}`;
}

function rewritePlaylistWithHosts(text, playlistUrl, proxyBase, isAllowed, stampKey) {
  const rewriteUri = (uri) => {
    const abs = resolvePlaylistUrl(uri, playlistUrl);
    if (!abs) return null;
    try {
      if (!isAllowed(new URL(abs).hostname)) {
        return stampKey ? megaplayProxyUrl(proxyBase, abs, stampKey) : null;
      }
    } catch (_) {
      return null;
    }
    return megavidProxyUrl(proxyBase, abs);
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

function rewriteMegavidPlaylist(text, playlistUrl, proxyBase) {
  return rewritePlaylistWithHosts(
    text,
    playlistUrl,
    proxyBase,
    isMegavidHost,
  );
}

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
    headers: megavidHeaders({ Accept: 'application/json' }),
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) throw new Error(`megavid ${res.status}`);
  const data = await res.json();
  if (data.status !== 'ok' || !data.source) {
    throw new Error('megavid: no stream');
  }
  await verifyMegavidStream(data.source);
  const tracks = (Array.isArray(data.tracks) ? data.tracks : [])
    .filter((t) => t && t.file)
    .map((t) => ({
      ...t,
      file: megavidProxyUrl(megavidProxyBase(req), t.file),
    }));
  const token = (req && req.query && req.query.token) || '';
  const src = megavidProxyUrl(megavidProxyBase(req), data.source);
  return {
    playerHtml: hlsPlayerHtml({
      src,
      tracks,
      title: `Episode ${ep}`,
      token,
      ep,
      audio: isDub,
    }),
  };
}

async function resolveMegaPlay(anilistId, malId, ep, audio, req) {
  const isDub = audio === 'dub' ? 'dub' : 'sub';
  const pageUrl =
    anilistId > 0
      ? `https://megaplay.buzz/stream/ani/${anilistId}/${ep}/${isDub}`
      : `https://megaplay.buzz/stream/mal/${malId}/${ep}/${isDub}`;
  const pageRes = await fetch(pageUrl, {
    headers: megaplayHeaders(),
    signal: AbortSignal.timeout(10000),
  });
  if (!pageRes.ok) throw new Error(`megaplay page ${pageRes.status}`);
  const html = await pageRes.text();
  const idMatch = html.match(
    /id=["']megaplay-player["'][^>]*data-id=["']([0-9a-zA-Z_-]+)["']/i,
  );
  if (!idMatch) throw new Error('megaplay: data-id not found');
  const dataId = idMatch[1];

  const sourcesUrl = `https://megaplay.buzz/stream/getSources?id=${dataId}&platform=OTHER`;
  const sourcesRes = await fetch(sourcesUrl, {
    headers: megaplayHeaders({ 'X-Requested-With': 'XMLHttpRequest' }),
    signal: AbortSignal.timeout(10000),
  });
  if (!sourcesRes.ok) throw new Error(`megaplay sources ${sourcesRes.status}`);
  const data = await sourcesRes.json();
  if (!data || !data.enc) throw new Error('megaplay: no enc payload');

  const decrypted = decryptMegaPlayPayload(data.enc);
  if (!decrypted || !decrypted.file) throw new Error('megaplay: decrypted no file');

  const m = decrypted.file.match(/\/anime\/([^/]+\/[^/]+)\/master\.m3u8/);
  const streamPath = m ? m[1] : '';
  const token = streamPath ? makeMegaPlayToken(streamPath) : '';
  const masterUrl = token ? `${decrypted.file}?token=${token}` : decrypted.file;

  await verifyMegaPlayStream(masterUrl);

  const proxyBase = megavidProxyBase(req);
  const key = await cdnKey().catch(() => null);
  const tracks = (Array.isArray(data.tracks) ? data.tracks : [])
    .filter((t) => t && t.file)
    .map((t) => ({
      ...t,
      file: megaplayProxyUrl(proxyBase, t.file, key),
    }));

  const userToken = (req && req.query && req.query.token) || '';
  const src = megavidProxyUrl(proxyBase, masterUrl);
  return {
    playerHtml: hlsPlayerHtml({
      src,
      tracks,
      title: `Episode ${ep}`,
      token: userToken,
      ep,
      audio: isDub,
    }),
  };
}

const proxyAnime = cappedHttps(20, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');
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
    res.status(401).send(failHtml('Unauthorized', 'Authentication required.'));
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'proxyAnime', limit: 60, windowMs: 60000, uid: authed.uid || '' })) return;
  const cacheControl = 'private, no-store';

  const params = validateAnimeParams(req.query || {});
  if (params.error) {
    res.status(400).send(failHtml('Bad request', params.error));
    return;
  }
  const { source, anilistId, malId, ep, audio } = params;

  res.set(
    'Content-Security-Policy',
    "frame-ancestors 'self' https://everglow-1c6db.web.app https://everglow-1c6db.firebaseapp.com",
  );
  const sendFail = (msg) => {
    console.warn(`[proxyAnime] ${source} ep=${ep}: ${msg}`);
    res.status(502).send(failHtml('Episode unavailable', msg));
  };

  if (source === 'megavid') {
    try {
      const out = await resolveMegavid(anilistId, malId, ep, audio, req);
      res.set('Content-Type', 'text/html; charset=utf-8');
      res.set('Cache-Control', cacheControl);
      res.status(200).send(out.playerHtml);
      return;
    } catch (e) {
      sendFail('No stream found — try another server.');
      return;
    }
  }

  if (source === 'megaplay' || source === 'everglow') {
    try {
      const out = await resolveMegaPlay(anilistId, malId, ep, audio, req);
      res.set('Content-Type', 'text/html; charset=utf-8');
      res.set('Cache-Control', cacheControl);
      res.status(200).send(out.playerHtml);
      return;
    } catch (e) {
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
    res.set('Cache-Control', cacheControl);
    res
      .status(200)
      .send(hlsPlayerHtml({ src: seg, title: titles[0], tracks: [], ep }));
  } catch (e) {
    sendFail('No stream found — try another server.');
  }
});

const proxyMegavidHls = cappedHttps(30, async (req, res) => {
  applyCors(req, res, 'GET, HEAD, OPTIONS');
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
  const authed = await verifyToken(req);
  if (!authed) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'proxyMegavidHls', limit: 240, windowMs: 60000, uid: authed.uid || '' })) return;

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
  const stamped =
    !isAnimeCdnHost(parsed.hostname) &&
    typeof req.query.s === 'string' &&
    validCdnStamp(await cdnKey().catch(() => null), targetUrl, req.query.s);
  if (parsed.protocol !== 'https:' || !(isAnimeCdnHost(parsed.hostname) || stamped)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }
  const megaplay = stamped || isMegaPlayHost(parsed.hostname);
  if (!(await isPublicDnsHost(parsed.hostname))) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }
  try {
    const headers = megaplay ? megaplayHeaders() : megavidHeaders();
    const range = req.get('Range') || req.headers.range;
    if (range && typeof range === 'string') headers.Range = range;
    const upstream = await common.fetchPublicUrl(targetUrl, {
      method: req.method === 'HEAD' ? 'HEAD' : 'GET',
      headers,
      signal: AbortSignal.timeout(25000),
      httpsOnly: true,
      ...(stamped ? {} : { isAllowedUrl: (u) => isAnimeCdnHost(u.hostname) }),
    });
    if (!upstream.ok && upstream.status !== 206) {
      await upstream.body?.cancel().catch(() => {});
      res.status(upstream.status).json({ error: `Upstream ${upstream.status}` });
      return;
    }
    const upstreamCt = (upstream.headers.get('content-type') || '').toLowerCase();
    const looksLikePlaylist =
      upstreamCt.includes('mpegurl') ||
      upstreamCt.includes('x-mpegurl') ||
      parsed.pathname.toLowerCase().includes('.m3u8');
    if (req.method === 'HEAD') {
      await upstream.body?.cancel().catch(() => {});
      const headCt = looksLikePlaylist
        ? 'application/vnd.apple.mpegurl'
        : (() => {
            const rawCt = (upstream.headers.get('content-type') || 'application/octet-stream').split(';')[0].trim().toLowerCase();
            return /^(text\/html|application\/xhtml\+xml|image\/svg\+xml|text\/javascript|application\/javascript)$/.test(rawCt)
              ? 'application/octet-stream'
              : (upstream.headers.get('content-type') || 'application/octet-stream');
          })();
      res.set('Content-Type', headCt);
      res.set('X-Content-Type-Options', 'nosniff');
      res.set('Content-Security-Policy', "default-src 'none'; sandbox");
      res.set('Cache-Control', looksLikePlaylist ? 'private, max-age=30' : 'public, max-age=3600');
      const acceptRanges = upstream.headers.get('accept-ranges');
      if (acceptRanges) res.set('Accept-Ranges', acceptRanges);
      const contentRange = upstream.headers.get('content-range');
      if (contentRange) res.set('Content-Range', contentRange);
      const contentLength = upstream.headers.get('content-length');
      if (contentLength && !looksLikePlaylist) res.set('Content-Length', contentLength);
      res.status(upstream.status === 206 ? 206 : 200).send('');
      return;
    }
    let consumed = null;
    if (looksLikePlaylist) {
      const text = await common.readLimitedText(upstream.body, 2 * 1024 * 1024);
      if (text && text.includes('#EXTM3U')) {
        const proxyBase = megavidProxyBase(req);
        const isAllowed = megaplay ? isMegaPlayHost : isMegavidHost;
        const stampKey = megaplay ? await cdnKey().catch(() => null) : null;
        const rewritten = rewritePlaylistWithHosts(
          text,
          targetUrl,
          proxyBase,
          isAllowed,
          stampKey,
        );
        res.set('Content-Type', 'application/vnd.apple.mpegurl');
        res.set('X-Content-Type-Options', 'nosniff');
        res.set('Content-Security-Policy', "default-src 'none'; sandbox");
        res.set('Cache-Control', 'private, max-age=30');
        res.status(200).send(rewritten);
        return;
      }
      consumed = text;
    }
    const rawCt = (upstream.headers.get('content-type') || 'application/octet-stream').split(';')[0].trim().toLowerCase();
    const ct = /^(text\/html|application\/xhtml\+xml|image\/svg\+xml|text\/javascript|application\/javascript)$/.test(rawCt)
      ? 'application/octet-stream'
      : (upstream.headers.get('content-type') || 'application/octet-stream');
    res.set('Content-Type', ct);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', "default-src 'none'; sandbox");
    res.set('Cache-Control', 'public, max-age=3600');
    const acceptRanges = upstream.headers.get('accept-ranges');
    if (acceptRanges) res.set('Accept-Ranges', acceptRanges);
    const contentRange = upstream.headers.get('content-range');
    if (contentRange) res.set('Content-Range', contentRange);
    const contentLength = upstream.headers.get('content-length');
    if (contentLength && consumed === null) res.set('Content-Length', contentLength);
    if (req.method === 'HEAD') {
      await upstream.body?.cancel().catch(() => {});
      res.status(upstream.status === 206 ? 206 : 200).send('');
      return;
    }
    const status = upstream.status === 206 ? 206 : 200;
    if (consumed !== null) {
      res.status(status).send(consumed);
      return;
    }
    if (upstream.body && typeof upstream.body.getReader === 'function') {
      res.status(status);
      await streamMediaBody(upstream.body, res);
      return;
    }
    res.status(status).send(Buffer.from(await upstream.arrayBuffer()));
  } catch (e) {
    console.warn(`[proxyMegavidHls] failed (${parsed.hostname}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

const proxyAnimeSegment = cappedHttps(30, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyAnimeSegment', limit: 240, windowMs: 60000, uid: authed.uid || '' })) return;

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
  const isAllowedSegment = (u) => {
    const h = u.hostname.toLowerCase();
    return [...SEGMENT_HOSTS].some((allow) => h === allow || h.endsWith(`.${allow}`));
  };
  if (parsed.protocol !== 'https:' || !isAllowedSegment(parsed)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }
  if (!(await isPublicDnsHost(host))) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await common.fetchPublicUrl(targetUrl, {
      headers: {
        'User-Agent': DESKTOP_UA,
        Accept: '*/*',
        Referer: 'https://kwik.cx/',
      },
      signal: AbortSignal.timeout(30000),
      httpsOnly: true,
      isAllowedUrl: isAllowedSegment,
    });
    if (!upstream.ok) {
      await upstream.body?.cancel().catch(() => {});
      res.status(upstream.status).json({ error: `Upstream ${upstream.status}` });
      return;
    }
    const rawSegCt = (upstream.headers.get('content-type') || 'application/octet-stream').split(';')[0].trim().toLowerCase();
    const segCt = /^(text\/html|application\/xhtml\+xml|image\/svg\+xml|text\/javascript|application\/javascript)$/.test(rawSegCt)
      ? 'application/octet-stream'
      : (upstream.headers.get('content-type') || 'application/octet-stream');
    res.set('Content-Type', segCt);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', "default-src 'none'; sandbox");
    res.set('Cache-Control', 'public, max-age=300');
    if (upstream.body && typeof upstream.body.getReader === 'function') {
      await streamMediaBody(upstream.body, res);
      return;
    }
    res.status(200).send(Buffer.from(await upstream.arrayBuffer()));
  } catch (e) {
    console.warn(`[proxyAnimeSegment] failed (${host}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = {
  proxyAnime,
  proxyAnimeSegment,
  proxyMegavidHls,
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
  isMegaPlayHost,
  isAnimeCdnHost,
  megavidProxyUrl,
  rewriteMegavidPlaylist,
  rewritePlaylistWithHosts,
  megaplayProxyUrl,
  cdnStamp,
  validCdnStamp,
  megavidHeaders,
  megaplayHeaders,
  MEGAVID_ORIGIN,
  MEGAPLAY_ORIGIN,
  MEGAPLAY_HOSTS,
  resolveMegaPlay,
  decryptMegaPlayPayload,
  makeMegaPlayToken,
  verifyMegaPlayStream,
  verifyStream,
}
