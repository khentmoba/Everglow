import { hlsPlayerHtml } from '../../functions/hls_player.js';
import {
  YUME_SERVER_IDS,
  yumeHeaders,
  yumeMasterUrl,
  yumeServer,
  yumeServerOrder,
  yumeSources,
} from './yumezone.js';

const DESKTOP_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

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

const CINEMA_SERVERS = [
  { id: 'cine-1', label: 'Reel', provider: 'fmov', key: 'valence' },
  { id: 'cine-2', label: 'Matinee', provider: 'fmov', key: 'vector' },
  { id: 'cine-3', label: 'Marquee', provider: 'fmov', key: 'core' },
  { id: 'cine-4', label: 'Encore', provider: 'fmov', key: 'titan' },
  { id: 'cine-5', label: 'Premiere', provider: 'vidbolt', key: '' },
];

const CINEMA_SERVER_IDS = new Set(CINEMA_SERVERS.map((s) => s.id));

const MEGAPLAY_ENC_KEY = 'i?LMTAx0Q6,:}50U';
const MEGAPLAY_ENC_IV = "W0;27ToaUpl_P%'c";
const MEGAPLAY_HMAC_SECRET = 'MpCdnT0k3n!9f2K#xQ7vL5mR8wN1pY4s';

const CINEMA_BUDGET_MS = 10000;
const CINEMA_PICK_BUDGET_MS = 15000;
const CINEMA_PICK_PLAYLIST_MS = 12000;
const YUME_BUDGET_MS = 12000;
const EVERGLOW_BUDGET_MS = 12000;

const enc = new TextEncoder();
const dec = new TextDecoder();

async function fetchT(url, init, ms, outer) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  const onAbort = () => ctrl.abort();
  if (outer) {
    if (outer.aborted) ctrl.abort();
    else outer.addEventListener('abort', onAbort, { once: true });
  }
  try {
    return await fetch(url, { ...(init || {}), signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
    if (outer) outer.removeEventListener('abort', onAbort);
  }
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
  if (provider === 'vidbolt') return vidboltHeaders(extra);
  return fmovHeaders(extra);
}

function streamHostPrefix(url) {
  try {
    if (isMegaPlayHost(new URL(url).hostname)) return 'megaplay';
  } catch {}
  return 'megavid';
}

const SEAL_AAD = 'everglow.seal.v1';
const sealCiphers = new Map();

async function sealCipher(key) {
  const raw = String(key || '');
  if (!raw) return null;
  let cipher = sealCiphers.get(raw);
  if (!cipher) {
    const digest = await crypto.subtle.digest('SHA-256', enc.encode(raw));
    cipher = crypto.subtle.importKey('raw', digest, { name: 'AES-GCM' }, false, [
      'encrypt',
      'decrypt',
    ]);
    sealCiphers.set(raw, cipher);
  }
  return cipher;
}

const SEAL_TTL_MS = 6 * 60 * 60 * 1000;

async function sealTarget(key, payload) {
  const cipher = await sealCipher(key);
  if (!cipher) return '';
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const wrapped = {
    ...payload,
    exp: typeof payload?.exp === 'number' ? payload.exp : Date.now() + SEAL_TTL_MS,
  };
  const body = enc.encode(JSON.stringify(wrapped));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv, additionalData: enc.encode(SEAL_AAD) },
      await cipher,
      body,
    ),
  );
  const out = new Uint8Array(iv.length + ct.length);
  out.set(iv, 0);
  out.set(ct, iv.length);
  return bytesToBase64Url(out);
}

async function openSeal(key, token) {
  const cipher = await sealCipher(key);
  if (!cipher || !token) return null;
  let raw;
  try {
    raw = base64UrlToBytes(token);
  } catch {
    return null;
  }
  if (raw.length < 29) return null;
  try {
    const plain = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: raw.subarray(0, 12), additionalData: enc.encode(SEAL_AAD) },
      await cipher,
      raw.subarray(12),
    );
    const obj = JSON.parse(dec.decode(plain));
    if (!obj || typeof obj !== 'object') return null;
    if (typeof obj.exp !== 'number' || Date.now() > obj.exp) return null;
    return obj;
  } catch {
    return null;
  }
}

function isRelayHost(hostname) {
  const h = String(hostname || '').toLowerCase();
  return h === 'fmov.my' || h.endsWith('.fmov.my') || h.endsWith('.workers.dev');
}

function hasUrlParam(absUrl) {
  const q = absUrl.indexOf('?');
  return q >= 0 && /(?:^|&)[^=&#]*=(?:https?:|https?%3a)/i.test(absUrl.slice(q + 1));
}

function stampParts(absUrl) {
  const clean = String(absUrl || '').split('#')[0];
  const q = clean.indexOf('?');
  if (q >= 0) {
    const query = clean.slice(q + 1);
    const pairs = query.split('&');
    const urls = pairs.filter((kv) => /^url=/i.test(kv));
    let inner = null;
    if (urls.length === 1) {
      try {
        inner = decodeURIComponent(urls[0].slice(4));
      } catch {
        return null;
      }
    }
    if (inner !== null && /^https?:\/\//i.test(inner)) {
      for (const kv of pairs) {
        if (/^url=/i.test(kv)) continue;
        const eq = kv.indexOf('=');
        const name = (eq < 0 ? kv : kv.slice(0, eq)).toLowerCase();
        const value = eq < 0 ? '' : kv.slice(eq + 1);
        if (/^https?(:|%3a)/i.test(value) && name !== 'referer' && name !== 'origin') return null;
      }
      if (hasUrlParam(inner)) return null;
      return { relay: clean.slice(0, q), inner };
    }
    if (urls.length > 1) return null;
  }
  let host = '';
  try {
    host = new URL(clean).hostname;
  } catch {
    return null;
  }
  if (isRelayHost(host) || hasUrlParam(clean)) return null;
  return { relay: '', inner: clean };
}

function safeRemainder(rel) {
  if (!rel) return null;
  let decoded;
  try {
    decoded = decodeURIComponent(rel);
  } catch {
    return null;
  }
  if (decoded[0] === '/' || decoded.includes('://')) return null;
  if (decoded.split(/[/\\]/).some((seg) => seg === '..' || seg === '.')) return null;
  return rel;
}

async function sealedUrl(proxyBase, absUrl, provider, key) {
  const parts = stampParts(absUrl);
  if (!parts) return null;
  const sp = splitForTransport(absUrl);
  if (!sp) {
    if (parts.relay) return null;
    const whole = await sealTarget(key, { p: provider, u: parts.inner });
    return whole ? `${proxyBase}?t=${whole}` : null;
  }
  let scope;
  try {
    scope = sp.relay ? decodeURIComponent(sp.encFolder) : sp.folder;
  } catch {
    return null;
  }
  const token = await sealTarget(key, { p: provider, s: scope, r: sp.relay || '' });
  if (!token) return null;
  if (sp.relay) {
    return (
      `${proxyBase}?t=${token}&rr=${encodeURIComponent(sp.rr)}` +
      `${sp.rq ? `&rq=${encodeURIComponent(sp.rq)}` : ''}`
    );
  }
  return `${proxyBase}?t=${token}&r=${encodeURIComponent(sp.r)}`;
}

async function scopedUrl(proxyBase, absUrl, provider, key) {
  return sealedUrl(proxyBase, absUrl, provider, key);
}

function cinemaProxyUrl(proxyBase, absUrl, provider, key) {
  return scopedUrl(proxyBase, absUrl, provider, key);
}

const AD_URL_RE =
  /(?:https?:\/\/|www\.)\S+|\b[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:ru|com|net|org|to|tv|io|me|xyz|site|live|cc|info|biz|co)\b/i;

function stripAdCues(vtt) {
  if (typeof vtt !== 'string' || !vtt.includes('-->')) return vtt;
  const blocks = vtt.split(/\r?\n\r?\n/);
  const kept = [];
  let dropped = 0;
  for (const block of blocks) {
    if (!block.trim()) continue;
    const lines = block.split(/\r?\n/);
    const arrow = lines.findIndex((l) => l.includes('-->'));
    if (arrow >= 0 && AD_URL_RE.test(lines.slice(arrow + 1).join(' '))) {
      dropped += 1;
      continue;
    }
    kept.push(block);
  }
  if (dropped === 0) return vtt;
  return `${kept.join('\n\n')}\n`;
}

async function megaplayProxyUrl(proxyBase, absUrl, key) {
  return scopedUrl(proxyBase, absUrl, 'megaplay', key);
}

async function scopedTarget(params, key) {
  const sealed = await openSeal(key, params.get('t') || '');
  if (!sealed) return null;
  const provider = String(sealed.p || '');
  if (!provider) return null;
  const scope = String(sealed.s || '');
  const relay = String(sealed.r || '');
  let target = String(sealed.u || '');
  if (!target) {
    if (!scope.startsWith('https://') || !scope.endsWith('/')) return null;
    if (relay) {
      const rr = safeRemainder(params.get('rr'));
      const rq = params.get('rq') || '';
      if (rr === null) return null;
      target = `${relay}?url=${encodeURIComponent(scope)}${rr}${rq ? `&${rq}` : ''}`;
    } else {
      const rel = safeRemainder(params.get('r'));
      if (rel === null) return null;
      target = scope + rel;
    }
  }
  const parts = stampParts(target);
  if (!parts) return null;
  let innerHref;
  try {
    innerHref = new URL(parts.inner).href;
  } catch {
    return null;
  }
  if (scope && !innerHref.startsWith(normalizeHref(scope))) return null;
  if (relay && parts.relay !== relay) return null;
  return { provider, target, relay: parts.relay, scope };
}

function normalizeHref(url) {
  try {
    return new URL(url).href;
  } catch {
    return url;
  }
}

function baseContext(base) {
  let b;
  try {
    b = new URL(base);
  } catch {
    b = new URL('https://invalid.example/');
  }
  return {
    href: b.href,
    origin: b.origin,
    apiKey: b.searchParams.get('api_key') || b.searchParams.get('apikey') || '',
  };
}

function resolveWithContext(ctx, ref) {
  const r = String(ref || '').trim();
  if (!r || r.startsWith('#')) return null;
  if (r.startsWith('https://') || r.startsWith('http://')) {
    if (!ctx.apiKey) return r;
    if (
      r.startsWith(`${ctx.origin}/`) &&
      !r.includes('api_key=') &&
      !r.includes('apikey=')
    ) {
      return `${r}${r.includes('?') ? '&' : '?'}api_key=${encodeURIComponent(ctx.apiKey)}`;
    }
    return r;
  }
  try {
    const u = new URL(r, ctx.href);
    if (u.protocol !== 'https:' && u.protocol !== 'http:') return null;
    if (ctx.apiKey && u.origin === ctx.origin && !u.searchParams.has('api_key')) {
      u.searchParams.set('api_key', ctx.apiKey);
    }
    return u.toString();
  } catch {
    return null;
  }
}

function resolvePlaylistUrl(ref, base) {
  try {
    return resolveWithContext(baseContext(base), ref);
  } catch {
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

function playlistDuration(text) {
  let total = 0;
  for (const line of String(text || '').split(/\r?\n/)) {
    const m = line.trim().match(/^#EXTINF:\s*([0-9]+(?:\.[0-9]+)?)/);
    if (m) total += Number.parseFloat(m[1]);
  }
  return total;
}

const MIN_MEGAVID_SECONDS = 120;


function splitForTransport(abs) {
  const hash = abs.indexOf('#');
  const clean = hash < 0 ? abs : abs.slice(0, hash);
  const q = clean.indexOf('?');
  if (q >= 0) {
    const query = clean.slice(q + 1);
    const at = query.startsWith('url=') ? 0 : query.indexOf('&url=') + 1;
    if (at > 0 || query.startsWith('url=')) {
      const start = at + 4;
      const amp = query.indexOf('&', start);
      const raw = amp < 0 ? query.slice(start) : query.slice(start, amp);
      if (/^https?%3A%2F%2F/i.test(raw)) {
        const rest = amp < 0 ? '' : query.slice(amp + 1);
        const rawPath = raw.split(/%3F/i)[0];
        const cut = rawPath.toUpperCase().lastIndexOf('%2F');
        if (cut < 0) return null;
        const encFolder = raw.slice(0, cut + 3);
        const before = at > 0 ? query.slice(0, at - 1) : '';
        return {
          relay: clean.slice(0, q),
          group: `${clean.slice(0, q)}|${encFolder}`,
          encFolder,
          rr: raw.slice(encFolder.length),
          rq: rest,
          lossless: !before && hash < 0,
        };
      }
    }
  }
  const path = q < 0 ? clean : clean.slice(0, q);
  const slash = path.lastIndexOf('/');
  if (slash < 8) return null;
  const hostEnd = clean.indexOf('/', 8);
  if (isRelayHost(clean.slice(8, hostEnd < 0 ? undefined : hostEnd).split(':')[0])) return null;
  const folder = clean.slice(0, slash + 1);
  return { relay: '', group: `|${folder}`, folder, r: clean.slice(slash + 1), lossless: hash < 0 };
}

async function rewriteScopedPlaylist(text, playlistUrl, proxyBase, provider, key) {
  const ctx = baseContext(playlistUrl);
  const lines = String(text || '').split(/\r?\n/);

  const items = new Map();
  const consider = (ref) => {
    if (items.has(ref)) return;
    const abs = resolveWithContext(ctx, ref);
    if (!abs || !abs.startsWith('https://')) return items.set(ref, null);
    const split = splitForTransport(abs);
    items.set(ref, split ? { abs, split } : null);
  };
  for (const line of lines) {
    const t = line.trim();
    if (!t) continue;
    if (t[0] === '#') {
      if (t.includes('URI="')) for (const m of t.matchAll(/URI="([^"]+)"/g)) consider(m[1]);
    } else {
      consider(t);
    }
  }

  const groups = new Map();
  for (const item of items.values()) {
    if (!item || groups.has(item.split.group)) continue;
    const sp = item.split;
    if (!sp.lossless) continue;
    let scope;
    try {
      scope = sp.relay ? decodeURIComponent(sp.encFolder) : sp.folder;
    } catch {
      groups.set(sp.group, null);
      continue;
    }
    const token = await sealTarget(key, { p: provider, s: scope, r: sp.relay || '' });
    groups.set(sp.group, token ? { t: token } : null);
  }

  const emit = async (ref) => {
    const item = items.get(ref);
    if (!item) return null;
    const sp = item.split;
    const g = sp.lossless ? groups.get(sp.group) : null;
    if (!g) {
      const token = await sealTarget(key, { p: provider, u: item.abs });
      return token ? `${proxyBase}?t=${token}` : null;
    }
    if (sp.relay) {
      return (
        `${proxyBase}?t=${g.t}&rr=${encodeURIComponent(sp.rr)}` +
        `${sp.rq ? `&rq=${encodeURIComponent(sp.rq)}` : ''}`
      );
    }
    return `${proxyBase}?t=${g.t}&r=${encodeURIComponent(sp.r)}`;
  };

  const dead = `${proxyBase}?t=0`;
  const out = [];
  for (const line of lines) {
    const t = line.trim();
    if (!t) {
      out.push(line);
      continue;
    }
    if (t[0] === '#') {
      let replaced = line;
      if (t.includes('URI="')) {
        for (const m of [...t.matchAll(/URI="([^"]+)"/g)]) {
          const r = await emit(m[1]);
          if (r) replaced = replaced.replace(`URI="${m[1]}"`, `URI="${r}"`);
          else if (m[1].startsWith('http')) replaced = replaced.replace(`URI="${m[1]}"`, `URI="${dead}"`);
        }
      }
      out.push(replaced);
      continue;
    }
    const sealed = await emit(t);
    if (sealed) out.push(sealed);
    else out.push(t.startsWith('http') ? dead : t);
  }
  return out.join('\n');
}

function rewriteCinemaPlaylist(text, playlistUrl, proxyBase, provider, key) {
  return rewriteScopedPlaylist(text, playlistUrl, proxyBase, provider, key);
}

function rewritePlaylistWithHosts(text, playlistUrl, proxyBase, provider, stampKey) {
  return rewriteScopedPlaylist(text, playlistUrl, proxyBase, provider, stampKey);
}

async function fetchPlaylist(url, timeoutMs, label, headers = megavidHeaders(), signal) {
  const res = await fetchT(url, { headers }, timeoutMs, signal);
  const prefix = streamHostPrefix(url);
  if (!res.ok) throw new Error(`${prefix} ${label} ${res.status}`);
  const text = await res.text();
  if (!text || !text.includes('#EXTM3U')) {
    throw new Error(`${prefix} ${label} is not a playlist`);
  }
  return text;
}

async function fetchSegmentHead(url, timeoutMs, label, headers = megavidHeaders(), signal) {
  const res = await fetchT(
    url,
    { headers: { ...headers, Range: 'bytes=0-1023' } },
    timeoutMs,
    signal,
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
    } catch {}
  }
}

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

function parseMediaPlaylist(text, { stopAfterSeconds = 0 } = {}) {
  let duration = 0;
  const uris = [];
  for (const line of String(text || '').split(/\r?\n/)) {
    const t = line.trim();
    if (!t) continue;
    if (t[0] === '#') {
      if (t.startsWith('#EXTINF:')) {
        const d = t.match(/^#EXTINF:\s*([0-9]+(?:\.[0-9]+)?)/);
        if (d) duration += Number.parseFloat(d[1]);
      }
      continue;
    }
    uris.push(t);
    if (stopAfterSeconds > 0 && duration >= stopAfterSeconds) break;
  }
  return { duration, uris };
}

async function verifyStream(masterUrl, headers = megavidHeaders(), signal, opts = {}) {
  const prefix = streamHostPrefix(masterUrl);
  const playlistMs = opts.playlistMs || 8000;
  const segmentMs = opts.segmentMs || 10000;
  const masterText = await fetchPlaylist(masterUrl, playlistMs, 'playlist', headers, signal);
  const variants = playlistUris(masterText, masterUrl, { variantsOnly: true });
  const medias =
    variants.length > 0
      ? await Promise.all(
          variants.slice(0, 1).map(async (v) => ({
            url: v,
            text: await fetchPlaylist(v, playlistMs, 'variant', headers, signal),
          })),
        )
      : [{ url: masterUrl, text: masterText }];
  const first = medias[0];
  const firstParsed = parseMediaPlaylist(first.text, {
    stopAfterSeconds: MIN_MEGAVID_SECONDS,
  });
  const keyMatch = first.text.match(/#EXT-X-KEY[^\r\n]*URI="([^"]+)"/);
  if (keyMatch) {
    const keyUrl = resolvePlaylistUrl(keyMatch[1], first.url);
    if (keyUrl) await fetchSegmentHead(keyUrl, segmentMs, 'key', headers, signal);
  }
  const mapMatch = first.text.match(/#EXT-X-MAP[^\r\n]*URI="([^"]+)"/);
  if (mapMatch) {
    const mapUrl = resolvePlaylistUrl(mapMatch[1], first.url);
    if (mapUrl) await fetchSegmentHead(mapUrl, segmentMs, 'init map', headers, signal);
  }
  await Promise.all(
    medias.map(async ({ url: mediaUrl, text: mediaText }) => {
      const parsed =
        mediaText === first.text
          ? firstParsed
          : parseMediaPlaylist(mediaText, {
              stopAfterSeconds: MIN_MEGAVID_SECONDS,
            });
      if (parsed.duration < MIN_MEGAVID_SECONDS) {
        throw new Error(`${prefix}: playlist too short to be the episode`);
      }
      if (!parsed.uris.length) throw new Error(`${prefix}: playlist has no segments`);
      const segment = resolvePlaylistUrl(parsed.uris[0], mediaUrl);
      if (!segment) throw new Error(`${prefix}: playlist has no segments`);
      const head = await fetchSegmentHead(segment, segmentMs, 'segment', headers, signal);
      assertPlayableHead(head, segment, 'segment');
      return true;
    }),
  );
  return {
    variantUrl: first.url,
    segmentUrl: resolvePlaylistUrl(firstParsed.uris[0], first.url),
  };
}

function verifyMegavidStream(masterUrl, signal) {
  return verifyStream(masterUrl, megavidHeaders(), signal);
}

function verifyMegaPlayStream(masterUrl, signal) {
  return verifyStream(masterUrl, megaplayHeaders(), signal);
}

function verifyCinemaStream(masterUrl, provider, signal, opts) {
  return verifyStream(masterUrl, cinemaHeaders(provider), signal, opts);
}

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
  try {
    return JSON.parse(dec.decode(plain));
  } catch (e) {
    throw new Error(`megaplay: undecryptable payload (${e.message})`);
  }
}

async function makeMegaPlayToken(path) {
  const exp = Math.floor(Date.now() / 1000) + 90;
  const payload = `${exp}|${path}`;
  const sig = await hmacSha256(MEGAPLAY_HMAC_SECRET, payload);
  return `${bytesToBase64Url(enc.encode(payload))}.${bytesToBase64Url(sig)}`;
}

async function resolveMegavid(anilistId, malId, ep, audio, proxyBase, key, opts = {}) {
  const isDub = audio === 'dub' ? 'dub' : 'sub';
  const url =
    anilistId > 0
      ? `https://megavid.buzz/ani/${anilistId}/${ep}/${isDub}/source`
      : `https://megavid.buzz/mal/${malId}/${ep}/${isDub}/source`;
  const res = await fetchT(
    url,
    { headers: megavidHeaders({ Accept: 'application/json' }) },
    10000,
    opts.signal,
  );
  if (!res.ok) throw new Error(`megavid ${res.status}`);
  const data = await res.json();
  if (data.status !== 'ok' || !data.source) throw new Error('megavid: no stream');
  await verifyMegavidStream(data.source, opts.signal);
  const tracks = await Promise.all(
    (Array.isArray(data.tracks) ? data.tracks : [])
      .filter((t) => t && t.file)
      .map(async (t) => ({ ...t, file: await sealedUrl(proxyBase, t.file, 'megavid', key) })),
  );
  const src = await sealedUrl(proxyBase, data.source, 'megavid', key);
  if (!src) throw new Error('megavid: stream cannot be sealed');
  return {
    src,
    tracks: tracks.filter((t) => t.file),
    title: `Episode ${ep}`,
    ep,
    server: 'megavid',
    servers: everglowServerLinks(proxyBase, { anilistId, malId, ep, audio }),
  };
}

async function resolveMegaPlay(anilistId, malId, ep, audio, proxyBase, key, opts = {}) {
  const isDub = audio === 'dub' ? 'dub' : 'sub';
  const pageUrl =
    anilistId > 0
      ? `https://megaplay.buzz/stream/ani/${anilistId}/${ep}/${isDub}`
      : `https://megaplay.buzz/stream/mal/${malId}/${ep}/${isDub}`;
  const pageRes = await fetchT(
    pageUrl,
    { headers: megaplayHeaders() },
    10000,
    opts.signal,
  );
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
    opts.signal,
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

  await verifyMegaPlayStream(masterUrl, opts.signal);

  const tracks = await Promise.all(
    (Array.isArray(data.tracks) ? data.tracks : [])
      .filter((t) => t && t.file)
      .map(async (t) => ({ ...t, file: await megaplayProxyUrl(proxyBase, t.file, key) })),
  );
  return {
    src: await sealedUrl(proxyBase, masterUrl, 'megaplay', key),
    tracks: tracks.filter((t) => t.file),
    title: `Episode ${ep}`,
    ep,
    server: 'megaplay',
    servers: everglowServerLinks(proxyBase, { anilistId, malId, ep, audio }),
  };
}

const EVERGLOW_DIRECT_SERVERS = [
  { id: 'megaplay', label: 'Nova', source: 'megaplay' },
  { id: 'megavid', label: 'Iris', source: 'megavid' },
];

function everglowServerList(audio, { anilistId = 0 } = {}) {
  const list = EVERGLOW_DIRECT_SERVERS.map((s) => ({ ...s }));
  if (anilistId > 0) {
    for (const server of yumeServerOrder(audio)) {
      list.push({ id: server.id, label: server.label, source: 'yumezone' });
    }
  }
  return list;
}

function everglowServerLinks(proxyBase, { anilistId, malId, ep, audio }) {
  let origin;
  try {
    origin = new URL(proxyBase).origin;
  } catch {
    return [];
  }
  const language = audio === 'dub' ? 'dub' : 'sub';
  return everglowServerList(audio, { anilistId }).map((server) => ({
    id: server.id,
    label: server.label,
    url:
      `${origin}/proxyAnime?source=${server.source}&format=json` +
      `&anilistId=${anilistId}&malId=${malId}&ep=${ep}&audio=${language}` +
      (server.source === 'yumezone' ? `&server=${server.id}` : ''),
  }));
}

async function resolveEverglow(
  anilistId,
  malId,
  ep,
  audio,
  serverId,
  proxyBase,
  key,
  opts = {},
) {
  const list = everglowServerList(audio, { anilistId });
  const order = serverId ? list.filter((s) => s.id === serverId) : list;
  if (!order.length) throw new Error(`everglow: unknown server ${serverId}`);
  const budgetMs = opts.budgetMs || EVERGLOW_BUDGET_MS;
  const deadline = Date.now() + budgetMs;
  const ctrl = new AbortController();
  const budgetTimer = setTimeout(() => ctrl.abort(), budgetMs);
  let lastError = null;
  try {
    for (const server of order) {
      if (Date.now() >= deadline) {
        lastError = new Error('everglow: out of time');
        break;
      }
      try {
        let out;
        if (server.source === 'yumezone') {
          out = await resolveYumeZone(anilistId, ep, audio, server.id, proxyBase, key, {
            signal: ctrl.signal,
            budgetMs: Math.max(1, deadline - Date.now()),
          });
        } else if (server.source === 'megavid') {
          out = await resolveMegavid(anilistId, malId, ep, audio, proxyBase, key, {
            signal: ctrl.signal,
          });
        } else {
          out = await resolveMegaPlay(anilistId, malId, ep, audio, proxyBase, key, {
            signal: ctrl.signal,
          });
        }
        if (!out || !out.src) {
          lastError = new Error(`everglow: ${server.id} returned no src`);
          continue;
        }
        return out;
      } catch (e) {
        lastError = e;
      }
    }
  } finally {
    clearTimeout(budgetTimer);
  }
  throw new Error('everglow: no playable stream', { cause: lastError });
}

async function resolveYumeZone(anilistId, ep, audio, serverId, proxyBase, key, opts = {}) {
  if (!anilistId || anilistId <= 0) throw new Error('yumezone: needs an AniList id');
  if (!key) throw new Error('yumezone: seal key unavailable');
  let order = yumeServerOrder(audio);
  if (serverId) {
    const picked = yumeServer(serverId);
    if (!picked) throw new Error(`yumezone: unknown server ${serverId}`);
    order = [picked];
  }
  const budgetMs = opts.budgetMs || YUME_BUDGET_MS;
  const deadline = Date.now() + budgetMs;
  const ctrl = new AbortController();
  const budgetTimer = setTimeout(() => ctrl.abort(), budgetMs);
  const outer = opts.signal;
  const onAbort = () => ctrl.abort();
  if (outer) {
    if (outer.aborted) ctrl.abort();
    else outer.addEventListener('abort', onAbort, { once: true });
  }
  let lastError = null;
  try {
    for (const server of order) {
      if (Date.now() >= deadline) {
        lastError = new Error('yumezone: out of time');
        break;
      }
      try {
        const payload = await yumeSources({
          animeId: anilistId,
          episode: ep,
          language: audio,
          provider: server.provider,
          signal: ctrl.signal,
        });
        if (!payload || payload.available === false) {
          lastError = new Error(payload && payload.message ? payload.message : 'no sources');
          continue;
        }
        const master = yumeMasterUrl(payload);
        if (!master) {
          lastError = new Error('no master playlist');
          continue;
        }
        await verifyStream(master, yumeHeaders(), ctrl.signal);
        const src = await sealedUrl(proxyBase, master, 'yumezone', key);
        if (!src) throw new Error('yumezone: master URL cannot be sealed');
        return {
          src,
          tracks: [],
          title: `Episode ${ep}`,
          ep,
          server: server.id,
          servers: everglowServerLinks(proxyBase, { anilistId, malId: 0, ep, audio }),
        };
      } catch (e) {
        lastError = e;
      }
    }
  } finally {
    clearTimeout(budgetTimer);
    if (outer) outer.removeEventListener('abort', onAbort);
  }
  throw new Error('yumezone: no playable stream', { cause: lastError });
}

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

async function firstPlayable(masterUrls, provider, signal, opts) {
  for (const masterUrl of masterUrls) {
    try {
      await verifyCinemaStream(masterUrl, provider, signal, opts);
      return masterUrl;
    } catch {}
  }
  throw new Error(`cinema ${provider}: no playable source`);
}

async function resolveFmov(apiPath, srcKey, signal) {
  const res = await fetchT(
    `${FMOV_ORIGIN}/api/stream/${apiPath}?source=${srcKey}`,
    { headers: fmovHeaders({ Accept: 'application/json' }) },
    6000,
    signal,
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
  return {
    key: srcKey,
    provider: 'fmov',
    masterUrls: hlsCandidates(sources, 'type', FMOV_ORIGIN),
    subtitles: data.subtitles,
    baseOrigin: FMOV_ORIGIN,
  };
}

async function resolveVidBolt(mediaType, tmdbId, season, ep, signal) {
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
    signal,
  );
  if (!res.ok) throw new Error(`vidbolt ${res.status}`);
  const data = await res.json();
  const stream = data && data.stream;
  if (!stream) throw new Error('vidbolt miss');
  return {
    key: 'vidbolt',
    provider: 'vidbolt',
    masterUrls: hlsCandidates(stream.sources, 'kind', VIDBOLT_ORIGIN),
    subtitles: stream.subtitles,
    baseOrigin: VIDBOLT_ORIGIN,
  };
}

function fmovSourceOrder(isTv) {
  return isTv
    ? ['vector', 'core', 'titan', 'valence']
    : ['valence', 'vector', 'core', 'titan'];
}

function cinemaServer(id) {
  return CINEMA_SERVERS.find((s) => s.id === id) || null;
}

function cinemaServerId(hit) {
  const row = CINEMA_SERVERS.find(
    (s) => s.provider === hit.provider && (hit.provider === 'vidbolt' || s.key === hit.key),
  );
  return row ? row.id : '';
}

function cinemaServerLinks(proxyBase, mediaType, tmdbId, season, ep) {
  let origin;
  try {
    origin = new URL(proxyBase).origin;
  } catch {
    return [];
  }
  const tail =
    mediaType === 'tv'
      ? `&type=tv&tmdbId=${tmdbId}&s=${season}&e=${ep}`
      : `&type=movie&tmdbId=${tmdbId}`;
  return CINEMA_SERVERS.map((server) => ({
    id: server.id,
    label: server.label,
    url: `${origin}/proxyAnime?source=cinema&format=json${tail}&server=${server.id}`,
  }));
}

async function resolveCinema(mediaType, tmdbId, season, ep, proxyBase, key, opts = {}) {
  const isTv = mediaType === 'tv';
  if (!key) throw new Error('cinema: stamp key unavailable');
  const apiPath = isTv ? `tv/${tmdbId}/${season}/${ep}` : `movie/${tmdbId}`;
  const picked = opts.server ? cinemaServer(opts.server) : null;
  if (opts.server && !picked) throw new Error('cinema: unknown server');
  const budgetMs = opts.budgetMs || (picked ? CINEMA_PICK_BUDGET_MS : CINEMA_BUDGET_MS);
  const verifyOpts = picked ? { playlistMs: CINEMA_PICK_PLAYLIST_MS } : undefined;
  const remaining = picked
    ? [picked.provider === 'fmov' ? picked.key : picked.provider]
    : [...fmovSourceOrder(isTv), 'vidbolt'];
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error('cinema: timed out')), budgetMs);
  });
  const budgetCtrl = new AbortController();
  const budgetTimer = setTimeout(() => budgetCtrl.abort(), budgetMs);
  let hit = null;
  let masterUrl = null;
  let lastError = null;
  try {
    while (remaining.length > 0) {
      const losers = new AbortController();
      const attempts = remaining.slice(0, 6).map((srcKey) => {
        if (srcKey === 'vidbolt') {
          return resolveVidBolt(mediaType, tmdbId, season, ep, losers.signal);
        }
        return resolveFmov(apiPath, srcKey, losers.signal);
      });
      let candidate;
      try {
        candidate = await Promise.race([Promise.any(attempts), deadline]);
      } catch (e) {
        lastError = e;
        break;
      } finally {
        losers.abort();
        for (const a of attempts) a.catch(() => {});
      }
      const at = remaining.indexOf(candidate.key);
      if (at >= 0) remaining.splice(at, 1);
      try {
        masterUrl = await firstPlayable(
          candidate.masterUrls,
          candidate.provider,
          budgetCtrl.signal,
          verifyOpts,
        );
        hit = candidate;
        break;
      } catch (e) {
        lastError = e;
      }
    }
    if (!hit) throw lastError || new Error('cinema: all providers missed');
  } catch (e) {
    throw new Error('cinema: no playable stream', { cause: e });
  } finally {
    clearTimeout(timer);
    clearTimeout(budgetTimer);
  }

  const tracks = (
    await Promise.all(
      selectCinemaSubtitleTracks(hit.subtitles, hit.baseOrigin)
        .filter((t) => t.file.startsWith('https://'))
        .map(async (t) => ({
          ...t,
          file: await cinemaProxyUrl(proxyBase, t.file, hit.provider, key),
        })),
    )
  ).filter((t) => t.file);
  const src = await cinemaProxyUrl(proxyBase, masterUrl, hit.provider, key);
  if (!src) throw new Error('cinema: master URL cannot be stamped');
  return {
    src,
    tracks,
    title: isTv ? `S${season} E${ep}` : 'Movie',
    ep: isTv ? ep : 1,
    servers: cinemaServerLinks(proxyBase, mediaType, tmdbId, season, ep),
    server: cinemaServerId(hit),
  };
}

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
    source !== 'cinema' &&
    source !== 'yumezone'
  ) {
    return { error: 'source must be megavid, megaplay, everglow, cinema, or yumezone' };
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
    const rawServer = String(query.server || '').trim();
    if (rawServer && !CINEMA_SERVER_IDS.has(rawServer)) {
      return { error: 'unknown server' };
    }
    return { source, mediaType, tmdbId, season, ep, server: rawServer };
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
  const rawServer = String(query.server || '').trim();
  const pinnedDirect =
    source === 'everglow' && EVERGLOW_DIRECT_SERVERS.some((s) => s.id === rawServer);
  if (rawServer && !YUME_SERVER_IDS.has(rawServer) && !pinnedDirect) {
    return { error: 'unknown server' };
  }
  return { source, anilistId, malId, ep, audio, server: rawServer };
}

export {
  normTitle,
  validateAnimeParams,
  failHtml,
  hlsPlayerHtml,
  firstM3u8,
  resolvePlaylistUrl,
  baseContext,
  resolveWithContext,
  playlistUris,
  playlistDuration,
  parseMediaPlaylist,
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
  CINEMA_SERVERS,
  CINEMA_SERVER_IDS,
  cinemaServer,
  cinemaServerId,
  cinemaServerLinks,
  fmovSourceOrder,
  sealTarget,
  openSeal,
  sealedUrl,
  scopedUrl,
  stampParts,
  scopedTarget,
  isRelayHost,
  cinemaProxyUrl,
  stripAdCues,
  megaplayProxyUrl,
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
  everglowServerList,
  everglowServerLinks,
  resolveEverglow,
  resolveMegavid,
  resolveMegaPlay,
  resolveYumeZone,
  resolveCinema,
};
