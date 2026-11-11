// YumeZone resolver protocol.
//
// YumeZone (yumezone.live) keys its catalog on AniList ids, which is exactly
// what our anime player already has, so it drops in beside MegaPlay/Megavid.
//
// Everything here is the wire protocol and nothing else: the signature, the
// response cipher, the server table, and the request headers. Orchestration
// (verify, proxy, stamp) lives in anime.js so this module never imports it.
//
// The site's own client signs every source lookup. Its `sig` is a SHA-256 over
// a reversed `animeId:episode:ts:salt` string plus a `_yume` tail, and the
// response body is XORed with that same hex string. Both are reproduced below
// so the Worker can talk to the API without shipping a browser.

const YUME_ORIGIN = 'https://yumezone.live';

const DESKTOP_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/** Every server YumeZone offers that speaks real HLS.
 *
 *  The site also lists seven iframe-only embeds (Cosmic, Vortex, Zoko, Dexter,
 *  Megaplay, Animo, Nest). Those return no playlist of their own, so they can
 *  never be played by our player and are left out on purpose — a server that
 *  only ever fails is worse than no server.
 *
 *  Order is hardsub first: our player renders `<track>` captions only as
 *  WebVTT, and YumeZone ships ASS/SRT, so a softsub server would play with no
 *  subtitles at all. The hardsub servers have them baked into the picture.
 *  `label` is what Clair reads, so it is short, warm and light-themed to
 *  match Everglow, and deliberately says nothing about the upstream: the
 *  provider name is ours to know, not something the browser needs. */
const YUME_SERVERS = [
  { id: 'yume-1', label: 'Dawn', provider: 'Karl - 3', hardsub: true },
  { id: 'yume-2', label: 'Ember', provider: 'Goku', hardsub: true },
  { id: 'yume-3', label: 'Aurora', provider: 'Nexus', hardsub: true },
  { id: 'yume-4', label: 'Lumen', provider: 'Karl - 1', hardsub: false },
  { id: 'yume-5', label: 'Halo', provider: 'Karl - 2', hardsub: false },
  { id: 'yume-6', label: 'Comet', provider: 'Rin', hardsub: false },
  { id: 'yume-7', label: 'Prism', provider: 'Koto', hardsub: false },
  { id: 'yume-8', label: 'Zenith', provider: 'Riko', hardsub: false },
  { id: 'yume-9', label: 'Solstice', provider: 'Rudra (Multi)', hardsub: false },
];

const YUME_SERVER_IDS = new Set(YUME_SERVERS.map((s) => s.id));

function yumeServer(id) {
  return YUME_SERVERS.find((s) => s.id === id) || null;
}

/** Servers in the order a resolve should try them.
 *
 *  Subbed viewers get the hardsub servers first: our player renders `<track>`
 *  captions only as WebVTT and YumeZone ships ASS/SRT, so a softsub server
 *  would play with no subtitles at all. Dubbed viewers want the opposite —
 *  burned-in English over English audio is noise. */
function yumeServerOrder(audio) {
  const dub = String(audio || 'sub').toLowerCase() === 'dub';
  return dub
    ? [...YUME_SERVERS.filter((s) => !s.hardsub), ...YUME_SERVERS.filter((s) => s.hardsub)]
    : [...YUME_SERVERS.filter((s) => s.hardsub), ...YUME_SERVERS.filter((s) => !s.hardsub)];
}

function yumeHeaders(extra) {
  return {
    'User-Agent': DESKTOP_UA,
    Accept: '*/*',
    Referer: `${YUME_ORIGIN}/`,
    Origin: YUME_ORIGIN,
    ...(extra || {}),
  };
}

/** The site's own 32-bit PRNG, used to build the timestamp salt. */
function yumePrng(seed) {
  let o = seed;
  return () => {
    let t = (o += 1831565813);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** `salt(ts)` — 20 pseudo-random printable characters masked by the
 *  timestamp, a colon, then 20 more. Deterministic in `ts` alone. */
function yumeSalt(ts) {
  const a = yumePrng(20260620);
  const b = yumePrng(98765432);
  let head = '';
  let tail = '';
  for (let i = 0; i < 20; i++) {
    head += String.fromCharCode(33 + Math.floor(a() * 90));
    tail += String.fromCharCode(33 + Math.floor(b() * 90));
  }
  const mask = ts ^ 8272540;
  const masked = head
    .split('')
    .map((c, i) => String.fromCharCode(c.charCodeAt(0) ^ ((mask >> (i % 16)) & 7)))
    .join('');
  return `${masked}:${tail}`;
}

/** SHA-256 hex of the reversed `animeId:episode:ts:salt` plus `_yume`. */
async function yumeSig(animeId, episode, ts) {
  const raw = `${animeId}:${episode}:${ts}:${yumeSalt(ts)}`.split('').reverse().join('') + '_yume';
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(raw));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** The `client_cipher_token` the site sends beside `sig`: the hex signature
 *  reversed and base64'd. Not a secret — it is derived from `sig`. */
function yumeCipherToken(sig) {
  return btoa([...sig].reverse().join(''));
}

/** Decrypts a `{"ct": "..."}` body. The key is the hex `sig` itself, applied
 *  byte-wise with a stride-3 counter folded in. */
function yumeDecrypt(ct, sig) {
  const key = new TextEncoder().encode(String(sig || ''));
  if (!key.length) throw new Error('yumezone: empty cipher key');
  let payload;
  try {
    payload = atob(String(ct || ''));
  } catch (e) {
    throw new Error(`yumezone: payload is not base64 (${e.message})`);
  }
  const out = new Uint8Array(payload.length);
  for (let i = 0; i < payload.length; i++) {
    out[i] = payload.charCodeAt(i) ^ key[i % key.length] ^ ((i * 3) % 256);
  }
  try {
    return JSON.parse(new TextDecoder().decode(out));
  } catch (e) {
    throw new Error(`yumezone: undecryptable payload (${e.message})`);
  }
}

/** Asks the API what one server has for one episode, decrypted.
 *
 *  Returns the decrypted payload whatever it says; callers decide whether an
 *  `available: false` answer is fatal. Throws only when the transport itself
 *  fails, so a dead server is distinguishable from a broken request. */
async function yumeSources({ animeId, episode, language, provider, signal, timeoutMs = 9000 }) {
  const ts = Math.floor(Date.now() / 1000);
  const sig = await yumeSig(animeId, episode, ts);
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  const onAbort = () => ctrl.abort();
  if (signal) {
    if (signal.aborted) ctrl.abort();
    else signal.addEventListener('abort', onAbort, { once: true });
  }
  let res;
  try {
    res = await fetch(`${YUME_ORIGIN}/api/yume/watch/sources`, {
      method: 'POST',
      headers: yumeHeaders({ 'Content-Type': 'application/json', Accept: 'application/json' }),
      body: JSON.stringify({
        anime_id: String(animeId),
        episode_number: episode,
        language: language === 'dub' ? 'dub' : 'sub',
        provider,
        sig,
        ts,
        client_cipher_token: yumeCipherToken(sig),
      }),
      signal: ctrl.signal,
    });
  } finally {
    clearTimeout(timer);
    if (signal) signal.removeEventListener('abort', onAbort);
  }
  if (!res.ok) throw new Error(`yumezone ${provider} ${res.status}`);
  const body = await res.json();
  const sealed = body && (body.ct || body.encrypted);
  // An unencrypted body is the API's own error shape; hand it back as-is.
  if (!sealed) return body && typeof body === 'object' ? body : {};
  return yumeDecrypt(sealed, sig);
}

/** The first playable HLS master in a decrypted payload, made absolute. */
function yumeMasterUrl(payload) {
  const list = Array.isArray(payload && payload.hls_sources) ? payload.hls_sources : [];
  for (const source of list) {
    const raw = source && (source.url || source.file);
    if (!raw) continue;
    try {
      const abs = new URL(raw, YUME_ORIGIN);
      if (abs.protocol === 'https:') return abs.href;
    } catch {
      // A malformed entry is not a reason to give up on the next one.
    }
  }
  return '';
}

export {
  YUME_ORIGIN,
  YUME_SERVERS,
  YUME_SERVER_IDS,
  yumeCipherToken,
  yumeDecrypt,
  yumeHeaders,
  yumeMasterUrl,
  yumeSalt,
  yumeServer,
  yumeServerOrder,
  yumeSig,
  yumeSources,
};
