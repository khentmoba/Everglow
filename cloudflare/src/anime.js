// Everglow streaming resolvers on Cloudflare Workers.
//
// Ported from functions/anime.js. Same routes, same player page, same
// stamps — only the runtime changed: WebCrypto instead of node:crypto,
// Response/ReadableStream instead of Express, and a Worker secret instead
// of the Firestore stamp key.
//
// Deliberately NOT ported:
//   - AnimePahe (needs a self-hosted API base; the app no longer offers it)
//   - proxyAnimeSegment (Kwik only, same reason)
//   - Firebase ID-token verification (optional before, and the app never
//     sends a token to these routes)
//   - DNS-based SSRF checks (no resolver in Workers; the signed stamps and
//     host allowlists already pin every URL to one we handed out)
//   - per-IP rate limiting (two viewers; add Durable Objects if that changes)

const DESKTOP_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/** Marker text the app probe recognizes as "try the next server". */
const NO_SOURCE_MARKER = 'no playable stream sources';

const MEGAVID_ORIGIN = 'https://megavid.buzz';
const MEGAPLAY_ORIGIN = 'https://megaplay.buzz';
const FMOV_ORIGIN = 'https://fmov.my';
const VIDBOLT_ORIGIN = 'https://vidbolt.xyz';

const MEGAVID_HOSTS = new Set(['megavid.buzz', 'cdn.api-webs.com', 'megavid.se']);
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

const CINEMA_PROVIDERS = new Set(['fmov', 'vidbolt']);

const MEGAPLAY_ENC_KEY = 'i?LMTAx0Q6,:}50U';
const MEGAPLAY_ENC_IV = "W0;27ToaUpl_P%'c";
const MEGAPLAY_HMAC_SECRET = 'MpCdnT0k3n!9f2K#xQ7vL5mR8wN1pY4s';

/** Hard ceiling for one Cinema resolve. The app treats a player page that
 *  has not loaded in 15 s as dead and moves to CineSrc, so a slow-but-healthy
 *  answer after that is wasted. Every source races inside this budget. */
const CINEMA_BUDGET_MS = 10000;

const enc = new TextEncoder();
const dec = new TextDecoder();

// ─── Small runtime helpers ───────────────────────────────

/** fetch with a hard timeout. Workers have no AbortSignal.timeout on every
 *  compatibility date, and a leaked timer keeps the isolate awake. */
async function fetchT(url, init, ms) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    return await fetch(url, { ...(init || {}), signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
  }
}

function bytesToHex(buf) {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function bytesToBase64Url(buf) {
  const bytes = new Uint8Array(buf);
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlToBytes(str) {
  let b64 = String(str || '').replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4) b64 += '=';
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** Constant-time compare for equal-length hex strings. */
function safeEqualHex(a, b) {
  const x = String(a || '');
  const y = String(b || '');
  if (x.length !== y.length || x.length === 0) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x.charCodeAt(i) ^ y.charCodeAt(i);
  return diff === 0;
}

async function hmacSha256(secret, message) {
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(String(secret)),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return crypto.subtle.sign('HMAC', key, enc.encode(String(message)));
}

/** Pads or truncates a string to exactly [len] bytes, like the Node
 *  padKeyBytes it replaces. */
function padKeyBytes(str, len) {
  const raw = enc.encode(String(str));
  const out = new Uint8Array(len);
  out.set(raw.subarray(0, Math.min(raw.length, len)));
  return out;
}

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

// ─── Host predicates ─────────────────────────────────────

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

function megavidHeaders(extra) {
  return {
    'User-Agent': DESKTOP_UA,
    Accept: '*/*',
    Referer: `${MEGAVID_ORIGIN}/`,
    Origin: MEGAVID_ORIGIN,
    ...(extra || {}),
  };
}

function megaplayHeaders(extra) {
  return {
    'User-Agent': DESKTOP_UA,
    Accept: '*/*',
    Referer: `${MEGAPLAY_ORIGIN}/`,
    Origin: MEGAPLAY_ORIGIN,
    ...(extra || {}),
  };
}

function fmovHeaders(extra) {
  return {
    'User-Agent': DESKTOP_UA,
    Accept: '*/*',
    Referer: `${FMOV_ORIGIN}/`,
    Origin: FMOV_ORIGIN,
    ...(extra || {}),
  };
}

function vidboltHeaders(extra) {
  return {
    'User-Agent': DESKTOP_UA,
    Accept: '*/*',
    Referer: `${VIDBOLT_ORIGIN}/`,
    Origin: VIDBOLT_ORIGIN,
    ...(extra || {}),
  };
}

function cinemaHeaders(provider, extra) {
  return provider === 'vidbolt' ? vidboltHeaders(extra) : fmovHeaders(extra);
}

function streamHostPrefix(url) {
  try {
    if (isMegaPlayHost(new URL(url).hostname)) return 'megaplay';
  } catch (_) {}
  return 'megavid';
}

// ─── Stamps ──────────────────────────────────────────────

/** Signs one URL. [key] is the CDN_STAMP_KEY Worker secret. */
async function cdnStamp(key, url) {
  return bytesToHex(await hmacSha256(key, url));
}

async function validCdnStamp(key, url, stamp) {
  if (!key || !/^[a-f0-9]{64}$/.test(String(stamp || ''))) return false;
  return safeEqualHex(await cdnStamp(key, url), stamp);
}

/** What a Cinema stamp signs. The provider is part of the message, so a
 *  MegaPlay stamp (bare URL) can never pass as a Cinema one, and a VidBolt
 *  stamp can never switch a URL to Fmov's headers. */
function cinemaStampMessage(provider, url) {
  return `cinema:${provider}|${url}`;
}

/** Builds our same-origin proxy URL for one upstream file. Token-free on
 *  purpose: the player sends identity as a header, never in media URLs. */
function proxyUrl(proxyBase, absUrl) {
  return `${proxyBase}?u=${encodeURIComponent(absUrl)}`;
}

/** Proxy URL for a file a Cinema provider pointed us at. Always stamped:
 *  Cinema has no host allowlist, so an unstamped URL is refused. */
async function cinemaProxyUrl(proxyBase, absUrl, provider, key) {
  const stamp = await cdnStamp(key, cinemaStampMessage(provider, absUrl));
  return `${proxyUrl(proxyBase, absUrl)}&p=${provider}&s=${stamp}`;
}

/** Proxy URL for a file MegaPlay pointed us at: plain for listed hosts,
 *  stamped for its rotating CDNs. */
async function megaplayProxyUrl(proxyBase, absUrl, key) {
  const url = proxyUrl(proxyBase, absUrl);
  let host = '';
  try {
    host = new URL(absUrl).hostname;
  } catch (_) {}
  if (!key || isAnimeCdnHost(host)) return url;
  return `${url}&s=${await cdnStamp(key, absUrl)}`;
}

// ─── Playlist helpers ────────────────────────────────────

/** Resolves a possibly-relative playlist URI against its playlist URL.
 *  Preserves same-origin `api_key` / `apikey` params (VidBolt's Orion CDN
 *  needs them on child variant, audio, and subtitle playlists). */
function resolvePlaylistUrl(ref, base) {
  try {
    const r = String(ref || '').trim();
    if (!r || r.startsWith('#')) return null;
    const u = new URL(r, base);
    if (u.protocol !== 'https:' && u.protocol !== 'http:') return null;
    try {
      const b = new URL(base);
      if (u.origin === b.origin) {
        for (const k of ['api_key', 'apikey']) {
          const v = b.searchParams.get(k);
          if (v && !u.searchParams.has(k)) u.searchParams.set(k, v);
        }
      }
    } catch (_) {}
    return u.toString();
  } catch (_) {
    return null;
  }
}

/** Non-comment URIs from an HLS playlist. With [variantsOnly], only URIs
 *  following an `#EXT-X-STREAM-INF` line are returned. */
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

/** Total seconds of content in a media playlist. */
function playlistDuration(text) {
  let total = 0;
  for (const line of String(text || '').split(/\r?\n/)) {
    const m = line.trim().match(/^#EXTINF:\s*([0-9]+(?:\.[0-9]+)?)/);
    if (m) total += Number.parseFloat(m[1]);
  }
  return total;
}

/** Minimum seconds for a playlist to plausibly be a full episode or movie. */
const MIN_MEGAVID_SECONDS = 120;

/** Maps every URI in an HLS playlist through [rewriteAbs], which may be
 *  async. A null result leaves the URI untouched. */
async function mapPlaylistUris(text, playlistUrl, rewriteAbs) {
  const lines = String(text || '').split(/\r?\n/);
  const refs = [];
  for (const line of lines) {
    const t = line.trim();
    if (!t) continue;
    if (t.startsWith('#')) {
      for (const m of t.matchAll(/URI="([^"]+)"/g)) refs.push(m[1]);
    } else {
      refs.push(t);
    }
  }
  const unique = [...new Set(refs)];
  const pairs = await Promise.all(
    unique.map(async (ref) => {
      const abs = resolvePlaylistUrl(ref, playlistUrl);
      if (!abs) return [ref, null];
      try {
        return [ref, await rewriteAbs(abs)];
      } catch (_) {
        return [ref, null];
      }
    }),
  );
  const map = new Map(pairs);
  return lines
    .map((line) => {
      const t = line.trim();
      if (!t) return line;
      if (t.startsWith('#')) {
        if (!t.includes('URI="')) return line;
        return line.replace(/URI="([^"]+)"/g, (m, uri) => {
          const out = map.get(uri);
          return out ? `URI="${out}"` : m;
        });
      }
      return map.get(t) || line;
    })
    .join('\n');
}

/** Rewrites every URI in a Cinema playlist to a stamped proxy URL for the
 *  same provider. Everything it points at came from a playlist we already
 *  vouched for, so the stamp chain never reaches a caller-chosen URL. */
async function rewriteCinemaPlaylist(text, playlistUrl, proxyBase, provider, key) {
  return mapPlaylistUris(text, playlistUrl, (abs) =>
    abs.startsWith('https://')
      ? cinemaProxyUrl(proxyBase, abs, provider, key)
      : null,
  );
}

/** Rewrites every allowed URI to our proxy. Unlisted hosts are left
 *  untouched so a mixed playlist can never turn us into an open relay —
 *  unless [stampKey] is given (MegaPlay playlists only). */
async function rewritePlaylistWithHosts(text, playlistUrl, proxyBase, isAllowed, stampKey) {
  return mapPlaylistUris(text, playlistUrl, async (abs) => {
    let allowed = false;
    try {
      allowed = isAllowed(new URL(abs).hostname);
    } catch (_) {
      return null;
    }
    if (!allowed) return stampKey ? megaplayProxyUrl(proxyBase, abs, stampKey) : null;
    return proxyUrl(proxyBase, abs);
  });
}

// ─── Stream verification ─────────────────────────────────

async function fetchPlaylist(url, timeoutMs, label, headers = megavidHeaders()) {
  const res = await fetchT(url, { headers }, timeoutMs);
  const prefix = streamHostPrefix(url);
  if (!res.ok) throw new Error(`${prefix} ${label} ${res.status}`);
  const text = await res.text();
  if (!text || !text.includes('#EXTM3U')) {
    throw new Error(`${prefix} ${label} is not a playlist`);
  }
  return text;
}

/** Downloads just the first bytes of a segment, key, or init map: proves
 *  the file exists without pulling megabytes when the CDN ignores Range. */
async function fetchSegmentHead(url, timeoutMs, label, headers = megavidHeaders()) {
  const res = await fetchT(
    url,
    { headers: { ...headers, Range: 'bytes=0-1023' } },
    timeoutMs,
  );
  const prefix = streamHostPrefix(url);
  if (!res.ok) throw new Error(`${prefix} ${label} ${res.status}`);
  if (!res.body) {
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

/** First segment bytes must look like MPEG-TS (sync byte 0x47) when the URL
 *  points at a .ts file, or a MegaPlay .jpg / VidBolt .png disguised TS
 *  segment. CDNs answer 200 with an HTML error page for removed files —
 *  fetchable, but it can never play. Other containers only need bytes. */
function assertPlayableHead(chunk, url, label) {
  const path = String(url).split('?')[0].toLowerCase();
  const prefix = streamHostPrefix(url);
  if (path.endsWith('.ts') && chunk[0] !== 0x47) {
    throw new Error(`${prefix} ${label} is not video data`);
  }
  if (path.endsWith('.jpg') && chunk[0] !== 0x47) {
    throw new Error(`${prefix} ${label} is not video data`);
  }
  if (path.endsWith('.png') && chunk[0] !== 0x47) {
    throw new Error(`${prefix} ${label} is not video data`);
  }
}

/** Proves an HLS stream is actually playable before we serve our player
 *  page: master playlist, every variant, key / init map when present, and
 *  each variant's first segment must fetch with playable bytes. Anything
 *  dead throws, and the endpoint answers with the failover marker so the
 *  app advances to the next server instead of stalling on a spinner. */
async function verifyStream(masterUrl, headers = megavidHeaders()) {
  const prefix = streamHostPrefix(masterUrl);
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
      if (!segments.length) throw new Error(`${prefix}: playlist has no segments`);
      const head = await fetchSegmentHead(segments[0], 10000, 'segment', headers);
      assertPlayableHead(head, segments[0], 'segment');
    }),
  );
  const firstSegments = playlistUris(first.text, first.url);
  return { variantUrl: first.url, segmentUrl: firstSegments[0] };
}

function verifyMegavidStream(masterUrl) {
  return verifyStream(masterUrl, megavidHeaders());
}

function verifyMegaPlayStream(masterUrl) {
  return verifyStream(masterUrl, megaplayHeaders());
}

function verifyCinemaStream(masterUrl, provider) {
  return verifyStream(masterUrl, cinemaHeaders(provider));
}

// ─── Upstream resolvers ──────────────────────────────────

async function decryptMegaPlayPayload(encStr) {
  const keyBytes = padKeyBytes(MEGAPLAY_ENC_KEY, 32);
  const iv = padKeyBytes(MEGAPLAY_ENC_IV, 16);
  const key = await crypto.subtle.importKey('raw', keyBytes, { name: 'AES-CBC' }, false, [
    'decrypt',
  ]);
  const plain = await crypto.subtle.decrypt(
    { name: 'AES-CBC', iv },
    key,
    base64UrlToBytes(encStr),
  );
  return JSON.parse(dec.decode(plain));
}

async function makeMegaPlayToken(path) {
  const exp = Math.floor(Date.now() / 1000) + 90;
  const payload = `${exp}|${path}`;
  const sig = await hmacSha256(MEGAPLAY_HMAC_SECRET, payload);
  return `${bytesToBase64Url(enc.encode(payload))}.${bytesToBase64Url(sig)}`;
}

async function resolveMegavid(anilistId, malId, ep, audio, proxyBase) {
  const isDub = audio === 'dub' ? 'dub' : 'sub';
  const url =
    anilistId > 0
      ? `https://megavid.buzz/ani/${anilistId}/${ep}/${isDub}/source`
      : `https://megavid.buzz/mal/${malId}/${ep}/${isDub}/source`;
  const res = await fetchT(
    url,
    { headers: megavidHeaders({ Accept: 'application/json' }) },
    10000,
  );
  if (!res.ok) throw new Error(`megavid ${res.status}`);
  const data = await res.json();
  if (data.status !== 'ok' || !data.source) throw new Error('megavid: no stream');
  await verifyMegavidStream(data.source);
  const tracks = (Array.isArray(data.tracks) ? data.tracks : [])
    .filter((t) => t && t.file)
    .map((t) => ({ ...t, file: proxyUrl(proxyBase, t.file) }));
  return { src: proxyUrl(proxyBase, data.source), tracks, title: `Episode ${ep}`, ep };
}

async function resolveMegaPlay(anilistId, malId, ep, audio, proxyBase, key) {
  const isDub = audio === 'dub' ? 'dub' : 'sub';
  const pageUrl =
    anilistId > 0
      ? `https://megaplay.buzz/stream/ani/${anilistId}/${ep}/${isDub}`
      : `https://megaplay.buzz/stream/mal/${malId}/${ep}/${isDub}`;
  const pageRes = await fetchT(pageUrl, { headers: megaplayHeaders() }, 10000);
  if (!pageRes.ok) throw new Error(`megaplay page ${pageRes.status}`);
  const html = await pageRes.text();
  const idMatch = html.match(
    /id=["']megaplay-player["'][^>]*data-id=["']([0-9a-zA-Z_-]+)["']/i,
  );
  if (!idMatch) throw new Error('megaplay: data-id not found');
  const dataId = idMatch[1];

  const sourcesRes = await fetchT(
    `https://megaplay.buzz/stream/getSources?id=${dataId}&platform=OTHER`,
    { headers: megaplayHeaders({ 'X-Requested-With': 'XMLHttpRequest' }) },
    10000,
  );
  if (!sourcesRes.ok) throw new Error(`megaplay sources ${sourcesRes.status}`);
  const data = await sourcesRes.json();
  if (!data || !data.enc) throw new Error('megaplay: no enc payload');

  const decrypted = await decryptMegaPlayPayload(data.enc);
  if (!decrypted || !decrypted.file) throw new Error('megaplay: decrypted no file');

  const m = decrypted.file.match(/\/anime\/([^/]+\/[^/]+)\/master\.m3u8/);
  const streamPath = m ? m[1] : '';
  const token = streamPath ? await makeMegaPlayToken(streamPath) : '';
  const masterUrl = token ? `${decrypted.file}?token=${token}` : decrypted.file;

  await verifyMegaPlayStream(masterUrl);

  const tracks = await Promise.all(
    (Array.isArray(data.tracks) ? data.tracks : [])
      .filter((t) => t && t.file)
      .map(async (t) => ({ ...t, file: await megaplayProxyUrl(proxyBase, t.file, key) })),
  );
  return { src: proxyUrl(proxyBase, masterUrl), tracks, title: `Episode ${ep}`, ep };
}

/**
 * Picks up to 8 WebVTT subtitle tracks, ordering clean English captions
 * first and deduplicating numbered mirrors so English never gets pushed off
 * the 8-track cap by alphabetical lists.
 */
function selectCinemaSubtitleTracks(rawTracks, baseOrigin = FMOV_ORIGIN) {
  if (!Array.isArray(rawTracks)) return [];
  const candidates = [];
  for (const t of rawTracks) {
    if (!t) continue;
    const abs = resolvePlaylistUrl(t.file || t.url || t.src || '', baseOrigin);
    if (!abs) continue;
    const type = String(t.type || '').toLowerCase();
    const path = abs.split('?')[0].toLowerCase();
    if (type && type !== 'vtt' && !path.endsWith('.vtt')) continue;
    if (path.endsWith('.srt') || path.endsWith('.ass') || path.endsWith('.ssa')) continue;
    const rawLabel = String(t.label || t.lang || t.language || 'Subtitles').trim();
    const norm = rawLabel.toLowerCase();
    let rank = 2;
    if (norm === 'english' || norm === 'en') rank = 0;
    else if (/^english\b|^en[-_]/i.test(norm)) rank = 1;
    const dedupeKey = norm.replace(/\s*\d+$/, '').replace(/\s+/g, ' ').trim();
    candidates.push({ file: abs, label: rawLabel, rank, dedupeKey });
  }
  candidates.sort((a, b) => a.rank - b.rank);
  const seen = new Set();
  const out = [];
  for (const c of candidates) {
    if (seen.has(c.dedupeKey)) continue;
    seen.add(c.dedupeKey);
    out.push({ file: c.file, label: c.label });
    if (out.length >= 8) break;
  }
  return out;
}

function hlsCandidates(sources, kindKey, baseOrigin) {
  const out = [];
  for (const s of Array.isArray(sources) ? sources : []) {
    if (!s || !s.url) continue;
    const kind = String(s[kindKey] || 'hls').toLowerCase();
    if (kind !== 'hls' && !String(s.url).includes('.m3u8')) continue;
    const abs = resolvePlaylistUrl(s.url, baseOrigin);
    if (abs && abs.startsWith('https://')) out.push(abs);
  }
  return out;
}

async function firstPlayable(masterUrls, provider) {
  for (const masterUrl of masterUrls) {
    try {
      await verifyCinemaStream(masterUrl, provider);
      return masterUrl;
    } catch (_) {}
  }
  throw new Error(`cinema ${provider}: no playable source`);
}

async function resolveFmov(apiPath, srcKey) {
  const res = await fetchT(
    `${FMOV_ORIGIN}/api/stream/${apiPath}?source=${srcKey}`,
    { headers: fmovHeaders({ Accept: 'application/json' }) },
    6000,
  );
  if (!res.ok) throw new Error(`fmov ${srcKey} ${res.status}`);
  const data = await res.json();
  if (!data || !data.success) throw new Error(`fmov ${srcKey} miss`);
  const sources =
    Array.isArray(data.sources) && data.sources.length > 0
      ? data.sources
      : data.url
        ? [{ url: data.url, type: data.type || 'hls' }]
        : [];
  const masterUrl = await firstPlayable(hlsCandidates(sources, 'type', FMOV_ORIGIN), 'fmov');
  return { provider: 'fmov', masterUrl, subtitles: data.subtitles, baseOrigin: FMOV_ORIGIN };
}

async function resolveVidBolt(mediaType, tmdbId, season, ep) {
  const isTv = mediaType === 'tv';
  const query = isTv
    ? `type=tv&id=${tmdbId}&season=${season}&episode=${ep}`
    : `type=movie&id=${tmdbId}`;
  const referer = isTv
    ? `${VIDBOLT_ORIGIN}/tv/${tmdbId}/${season}/${ep}`
    : `${VIDBOLT_ORIGIN}/movie/${tmdbId}`;
  const res = await fetchT(
    `${VIDBOLT_ORIGIN}/api/resolve?${query}`,
    {
      headers: vidboltHeaders({
        Accept: 'application/json',
        Referer: referer,
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
      }),
    },
    6000,
  );
  if (!res.ok) throw new Error(`vidbolt ${res.status}`);
  const data = await res.json();
  const stream = data && data.stream;
  if (!stream) throw new Error('vidbolt miss');
  const masterUrl = await firstPlayable(
    hlsCandidates(stream.sources, 'kind', VIDBOLT_ORIGIN),
    'vidbolt',
  );
  return {
    provider: 'vidbolt',
    masterUrl,
    subtitles: stream.subtitles,
    baseOrigin: VIDBOLT_ORIGIN,
  };
}

/** Resolves a TMDB movie or episode to our ad-free HLS player page.
 *  Fmov's sources and VidBolt race in parallel; the first verified stream
 *  wins. Throws (so the app moves on to CineSrc) when nothing verifies
 *  within the budget or the stamp key is unavailable. */
async function resolveCinema(mediaType, tmdbId, season, ep, proxyBase, key, opts = {}) {
  const isTv = mediaType === 'tv';
  const budgetMs = opts.budgetMs || CINEMA_BUDGET_MS;
  if (!key) throw new Error('cinema: stamp key unavailable');
  const apiPath = isTv ? `tv/${tmdbId}/${season}/${ep}` : `movie/${tmdbId}`;
  const fmovSources = isTv
    ? ['vector', 'core', 'titan', 'valence']
    : ['valence', 'vector', 'core', 'titan'];
  const attempts = [
    ...fmovSources.map((srcKey) => resolveFmov(apiPath, srcKey)),
    resolveVidBolt(mediaType, tmdbId, season, ep),
  ];
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error('cinema: timed out')), budgetMs);
  });
  let hit;
  try {
    hit = await Promise.race([Promise.any(attempts), deadline]);
  } catch (e) {
    throw new Error('cinema: no playable stream', { cause: e });
  } finally {
    clearTimeout(timer);
  }

  const tracks = await Promise.all(
    selectCinemaSubtitleTracks(hit.subtitles, hit.baseOrigin)
      .filter((t) => t.file.startsWith('https://'))
      .map(async (t) => ({
        ...t,
        file: await cinemaProxyUrl(proxyBase, t.file, hit.provider, key),
      })),
  );
  return {
    src: await cinemaProxyUrl(proxyBase, hit.masterUrl, hit.provider, key),
    tracks,
    title: isTv ? `S${season} E${ep}` : 'Movie',
    ep: isTv ? ep : 1,
  };
}

// ─── Player page ─────────────────────────────────────────

/** Ad-free HLS player with recovery. The video URL must already be playable
 *  from a browser (proxied through us when the upstream needs headers).
 *  Starts playback once the manifest is ready, retries transient failures,
 *  and after repeated fatal errors shows a retry card instead of spinning.
 *  The card deliberately avoids the failover marker text, so the app's
 *  server probe never mistakes a healthy player for a dead one. */
function hlsPlayerHtml({ src, title, tracks, token, ep }) {
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
    '.ov[hidden]{display:none!important}' +
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
    'var episode=' + JSON.stringify(Number.isSafeInteger(ep) && ep > 0 ? ep : null) + ';' +
    'var start=new URLSearchParams(window.location.search).get("start");' +
    'var pendingSeek=start!==null&&/^\\d+(?:\\.\\d+)?$/.test(start)?Number(start):null;' +
    'if(!Number.isFinite(pendingSeek)){pendingSeek=null;}' +
    'var hasMetadata=false;' +
    'function applySeek(){if(!hasMetadata||pendingSeek===null||!Number.isFinite(v.duration)||v.duration<=0){return;}' +
    'try{v.currentTime=Math.min(pendingSeek,v.duration);pendingSeek=null;}catch(e){}}' +
    'v.addEventListener("loadedmetadata",function(){hasMetadata=true;applySeek();});' +
    'v.addEventListener("durationchange",applySeek);' +
    'function trustedParent(origin){return origin==="https://everglow-1c6db.web.app"||' +
    'origin==="https://everglow-1c6db.firebaseapp.com"||' +
    '/^https:\\/\\/everglow-1c6db--[a-z0-9-]+\\.web\\.app$/.test(origin)||' +
    '/^https?:\\/\\/(?:localhost|127\\.0\\.0\\.1|\\[::1\\])(?::[0-9]+)?$/.test(origin);}' +
    'function nativeBridge(){return window.parent===window&&window.EverglowPlayer&&' +
    'window.location.protocol==="https:"&&' +
    'window.location.pathname==="/proxyAnime";}' +
    'window.addEventListener("message",function(e){' +
    'if(e.source!==window.parent||(!trustedParent(e.origin)&&' +
    '!(nativeBridge()&&e.origin===window.location.origin))){return;}' +
    'var d=e.data;if(!d||d.type!=="animex-seek"||typeof d.seconds!=="number"||' +
    '!Number.isFinite(d.seconds)||d.seconds<0){return;}' +
    'pendingSeek=d.seconds;applySeek();});' +
    'function post(data){try{window.parent.postMessage(data,"*");}catch(e){}' +
    'try{if(nativeBridge()){window.EverglowPlayer.postMessage(' +
    'typeof data==="string"?data:JSON.stringify(data));}}catch(e){}}' +
    'var lastProgress=null;' +
    'function progress(force){var position=v.currentTime,duration=v.duration;' +
    'if(!Number.isFinite(position)||position<0||!Number.isFinite(duration)||' +
    'duration<=0||position>duration){return;}' +
    'var now=Date.now();if(!force&&lastProgress!==null&&now-lastProgress<1000){return;}' +
    'lastProgress=now;post({type:"animex-progress",position:position,duration:duration,episode:episode});}' +
    'v.addEventListener("timeupdate",function(){progress(false);});' +
    'v.addEventListener("pause",function(){progress(true);});' +
    'v.addEventListener("ended",function(){progress(true);});' +
    'function hideBoot(){boot.style.display="none";}' +
    'function showTap(){tapw.hidden=false;}' +
    'function tryPlay(){var p;try{p=v.play();}catch(e){showTap();return;}' +
    'if(p&&p.catch){p.catch(function(){showTap();});}}' +
    'function giveUp(){hideBoot();tapw.hidden=true;dead.hidden=false;' +
    'post("animex-content-error");}' +
    'tap.addEventListener("click",function(){tapw.hidden=true;tryPlay();});' +
    'v.addEventListener("playing",function(){hideBoot();tapw.hidden=true;});' +
    'v.addEventListener("waiting",function(){' +
    'if(dead.hidden){boot.style.display="flex";}});' +
    'if(window.Hls&&Hls.isSupported()){' +
    (token
      ? 'var h=new Hls({maxBufferLength:30,xhrSetup:function(x){try{x.setRequestHeader("Authorization","Bearer "+' + JSON.stringify(String(token)) + ');}catch(e){}}});var fatal=0;'
      : 'var h=new Hls({maxBufferLength:30});var fatal=0;') +
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
    '}})();</' + 'script></body></html>'
  );
}

/** [notify] also posts `animex-content-error` to the embedding app. Cinema
 *  needs it: its player has no dead-server probe reading the marker text, so
 *  without the message it would sit on this page until its load timer. */
function failHtml(title, detail, { notify = false } = {}) {
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
    (notify
      ? '<script>(function(){try{if(window.parent&&window.parent!==window){' +
        'window.parent.postMessage("animex-content-error","*");}}catch(e){}' +
        'try{if(window.EverglowPlayer&&window.EverglowPlayer.postMessage){' +
        'window.EverglowPlayer.postMessage("animex-content-error");}}catch(e){}})();</script>'
      : '') +
    '</body></html>'
  );
}

function validateAnimeParams(query) {
  const source = String(query.source || '').toLowerCase();
  if (
    source !== 'megavid' &&
    source !== 'megaplay' &&
    source !== 'everglow' &&
    source !== 'cinema'
  ) {
    return { error: 'source must be megavid, megaplay, everglow, or cinema' };
  }
  if (source === 'cinema') {
    const mediaType = String(query.type || 'movie').toLowerCase();
    if (mediaType !== 'movie' && mediaType !== 'tv') {
      return { error: 'type must be movie or tv' };
    }
    const tmdbId = Number.parseInt(String(query.tmdbId || '0'), 10) || 0;
    if (tmdbId <= 0 || tmdbId > 100000000) {
      return { error: 'tmdbId is required' };
    }
    const rawS = query.s == null || query.s === '' ? '1' : String(query.s);
    const season = mediaType === 'tv' ? Number.parseInt(rawS, 10) : 1;
    if (!Number.isFinite(season) || season < 1 || season > 500) {
      return { error: 's must be 1..500' };
    }
    const rawEp =
      query.e != null && query.e !== ''
        ? String(query.e)
        : query.ep == null || query.ep === ''
          ? '1'
          : String(query.ep);
    const ep = mediaType === 'tv' ? Number.parseInt(rawEp, 10) : 1;
    if (!Number.isFinite(ep) || ep < 1 || ep > 5000) {
      return { error: 'e must be 1..5000' };
    }
    return { source, mediaType, tmdbId, season, ep };
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

export {
  // pure helpers (unit-tested)
  normTitle,
  validateAnimeParams,
  failHtml,
  hlsPlayerHtml,
  firstM3u8,
  resolvePlaylistUrl,
  playlistUris,
  playlistDuration,
  MIN_MEGAVID_SECONDS,
  NO_SOURCE_MARKER,
  isMegavidHost,
  isMegaPlayHost,
  isAnimeCdnHost,
  megavidHeaders,
  megaplayHeaders,
  fmovHeaders,
  vidboltHeaders,
  cinemaHeaders,
  MEGAVID_ORIGIN,
  MEGAPLAY_ORIGIN,
  MEGAPLAY_HOSTS,
  MEGAVID_HOSTS,
  FMOV_ORIGIN,
  VIDBOLT_ORIGIN,
  CINEMA_PROVIDERS,
  proxyUrl,
  cinemaProxyUrl,
  cinemaStampMessage,
  megaplayProxyUrl,
  cdnStamp,
  validCdnStamp,
  rewritePlaylistWithHosts,
  rewriteCinemaPlaylist,
  assertPlayableHead,
  verifyStream,
  verifyMegavidStream,
  verifyMegaPlayStream,
  verifyCinemaStream,
  decryptMegaPlayPayload,
  makeMegaPlayToken,
  selectCinemaSubtitleTracks,
  resolveMegavid,
  resolveMegaPlay,
  resolveCinema,
};
