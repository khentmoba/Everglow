const functions = require('firebase-functions/v1');
const { onRequest } = require('firebase-functions/v2/https');

/** Lazy require+init so Firebase deploy analysis doesn't time out */
let _admin;
function getAdmin() {
  if (!_admin) {
    _admin = require('firebase-admin');
    _admin.initializeApp();
  }
  return _admin;
}

/** In-memory cache for Mochi's persona document. */
let _personaCache = null;
/**
 * Proxies book text requests so Flutter web isn't blocked by CORS.
 *
 * Accepts:
 *   POST /proxyBookText  { urls: string[] }
 *
 * Tries each URL server-side in order and returns the body of the
 * first one that responds with a 2xx and non-empty body.
 *
 * If the caller provides a Firebase ID token in the Authorization
 * header, we verify it (optional — useful in dev without a token).
 */
exports.proxyBookText = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  const idToken = req.get('Authorization')?.replace('Bearer ', '');
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: 'Invalid or expired auth token' });
      return;
    }
  }

  const { urls } = req.body;
  if (!Array.isArray(urls) || urls.length === 0) {
    res.status(400).json({ error: 'Provide a non-empty urls array' });
    return;
  }

  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: { 'Accept': 'text/plain, text/html' },
        timeout: 15000,
      });
      if (response.ok) {
        const text = await response.text();
        if (text.trim().length > 0) {
          res.json({ text, usedUrl: url, attempted: urls.slice(0, i + 1) });
          return;
        }
      }
    } catch (e) {
      console.warn(`proxyBookText attempt ${i} failed (${url}):`, e.message);
    }
  }

  res.json({
    text: '',
    usedUrl: '',
    attempted: urls,
    error: `Tried ${urls.length} source(s); none responded with readable text.`,
  });
});

/**
 * Proxies manga chapter page images so Flutter web isn't blocked by
 * CORS or hotlink protection. The MangaDex at-home image server
 * doesn't send CORS headers, so a direct Image.network request from
 * the browser fails. This function fetches the image server-side and
 * streams it back to the client with permissive CORS headers.
 *
 * Accepts:
 *   GET /proxyMangaImage?url=<encoded image url>
 *
 * Mirrors the `proxyBookText` pattern: optional Firebase Auth token in
 * the Authorization header, validated if present.
 */
exports.proxyMangaImage = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }

  const idToken = req.get('Authorization')?.replace('Bearer ', '');
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: 'Invalid or expired auth token' });
      return;
    }
  }

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }
  const allowedHosts = new Set([
    'uploads.mangadex.org',
  ]);
  const allowedSuffixes = ['.mangadex.network', '.mangadex.org'];
  const hostAllowed =
    allowedHosts.has(parsed.hostname) ||
    allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8' },
      timeout: 20000,
    });
    if (!upstream.ok) {
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const contentType =
      upstream.headers.get('content-type') || 'image/jpeg';
    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=600');
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyMangaImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies MangaKakalot chapter page images so Flutter web isn't blocked
 * by CORS or hotlink protection.
 *
 * Accepts:
 *   GET /proxyMangaKakalotImage?url=<encoded image url>
 */
exports.proxyMangaKakalotImage = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  const allowedSuffixes = [
    '.mangakakalot.com',
    '.mkklcdnv6temp.com',
  ];
  const hostAllowed = allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8', 'Referer': 'https://mangakakalot.com/' },
      timeout: 20000,
    });
    if (!upstream.ok) {
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const contentType =
      upstream.headers.get('content-type') || 'image/jpeg';
    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=600');
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyMangaKakalotImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies MangaDex catalog API requests so Flutter web isn't blocked
 * by CORS. The MangaDex API at api.mangadex.org doesn't send an
 * `Access-Control-Allow-Origin` header on its responses, so the
 * browser drops the body and the client sees an empty `data` array
 * (which is what causes the "Nothing here yet." placeholders in the
 * manga library). This function forwards the request server-side and
 * returns the body with permissive CORS headers.
 *
 * Accepts:
 *   GET /proxyMangaDex?path=<encoded api path with query,
 *                            e.g. "manga?limit=20&includes%5B%5D=cover_art">
 *
 * Only the api.mangadex.org host is allowed — the path is sanitized
 * to prevent abuse. Mirrors the `proxyMangaImage` pattern: optional
 * Firebase Auth token in the Authorization header, validated if
 * present.
 */
/**
 * Proxies Comick catalog API requests so Flutter web isn't blocked by CORS.
 * Same pattern as `proxyMangaDex` — forwards to api.comick.dev with
 * permissive CORS headers.
 */
exports.proxyComick = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }

  const pathParam = req.query.path;
  if (typeof pathParam !== 'string' || pathParam.length === 0) {
    res.status(400).json({ error: 'Missing ?path=<api path> query param' });
    return;
  }

  const safePath = pathParam.replace(/^\/+/, '').replace(/\.\.+/g, '');
  if (safePath.length === 0) {
    res.status(400).json({ error: 'Empty path' });
    return;
  }
  const targetUrl = `https://api.comick.dev/${safePath}`;

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      },
      timeout: 20000,
    });
    const body = await upstream.text();
    res.status(upstream.status);
    res.set(
      'Content-Type',
      upstream.headers.get('content-type') || 'application/json',
    );
    res.set('Cache-Control', 'public, max-age=60');
    res.send(body);
  } catch (e) {
    console.warn(`proxyComick failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies anime episode thumbnail images so Flutter web isn't blocked by
 * CORS. Streaming CDNs (Crunchyroll, Funimation, etc.) typically don't
 * include `Access-Control-Allow-Origin` on their image endpoints, so a
 * direct `Image.network` request from the browser fails. This function
 * fetches the image server-side and streams it back with permissive CORS
 * headers.
 *
 * Accepts:
 *   GET /proxyAnimeImage?url=<encoded image url>
 *
 * Only known anime CDN hosts are allowed — currently:
 *   - *.ak.crunchyroll.com
 *   - *.funimation.com
 */
exports.proxyAnimeImage = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  const allowedSuffixes = [
    '.ak.crunchyroll.com',
    '.funimation.com',
  ];
  const hostAllowed = allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8' },
      timeout: 20000,
    });
    if (!upstream.ok) {
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const contentType =
      upstream.headers.get('content-type') || 'image/jpeg';
    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=600');
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyAnimeImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies scanlation-site chapter page images so Flutter web isn't
 * blocked by CORS or hotlink protection. Scanlation groups host images
 * on their own domains or common CDNs (Blogspot, WordPress, etc.).
 *
 * Accepts:
 *   GET /proxyScanlation?url=<encoded image url>
 *
 * The host is validated against a whitelist of known scanlation
 * domains. Mirrors the `proxyMangaKakalotImage` pattern.
 */
exports.proxyScanlation = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  // ── Whitelisted scanlation domains & common image CDNs ─────
  const allowedSuffixes = [
    // Scanlation group domains
    '.asurascans.com',
    '.asuracomic.net',
    '.reaperscans.com',
    '.reapercomics.com',
    '.arcanescans.com',
    '.flamescans.org',
    '.flamecomics.com',
    '.luminousscans.com',
    '.void-scans.com',
    '.rizzcomic.com',
    '.comick.io',
    // Common image CDNs used by scanlation sites
    '.blogspot.com',
    '.bp.blogspot.com',
    '.googleusercontent.com',
    '.wp.com',
    '.wordpress.com',
  ];
  const hostAllowed = allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'Accept': 'image/*,*/*;q=0.8',
        'Referer': parsed.origin + '/',
      },
      timeout: 20000,
    });
    if (!upstream.ok) {
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const contentType =
      upstream.headers.get('content-type') || 'image/jpeg';
    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=600');
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyScanlation failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

exports.proxyMangaDex = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }

  const idToken = req.get('Authorization')?.replace('Bearer ', '');
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: 'Invalid or expired auth token' });
      return;
    }
  }

  const pathParam = req.query.path;
  if (typeof pathParam !== 'string' || pathParam.length === 0) {
    res.status(400).json({ error: 'Missing ?path=<api path> query param' });
    return;
  }

  const safePath = pathParam.replace(/^\/+/, '').replace(/\.\.+/g, '');
  if (safePath.length === 0) {
    res.status(400).json({ error: 'Empty path' });
    return;
  }
  const targetUrl = `https://api.mangadex.org/${safePath}`;

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      },
      timeout: 20000,
    });
    const body = await upstream.text();
    res.status(upstream.status);
    res.set(
      'Content-Type',
      upstream.headers.get('content-type') || 'application/json',
    );
    res.set('Cache-Control', 'public, max-age=60');
    res.send(body);
  } catch (e) {
    console.warn(`proxyMangaDex failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Fetches the direct video stream URL from VidLink server-side so Flutter
 * can play it in a controllable <video> element on the same origin.
 *
 * Accepts: POST /proxyVideoStream  { type, id, season?, episode? }
 * Returns: { url: string|null, debug: {...} }
 */
exports.proxyVideoStream = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }

  const { type, id, season, episode } = req.body || {};
  if (!type || !id) { res.status(400).json({ error: 'type and id required' }); return; }

  try {
    // Get the encoded ID via VidLink's WASM module
    const encodedId = await getEncodedId(id.toString());
    console.log(`proxyVideoStream: tmdbId=${id} → encoded=${encodedId}`);

    if (!encodedId) {
      res.json({ url: null, error: 'Could not encode ID' });
      return;
    }

    // Call VidLink's internal API with the encoded ID
    const apiPath = type === 'tv'
      ? `/api/b/tv/${encodedId}/${season||1}/${episode||1}?multiLang=1`
      : `/api/b/movie/${encodedId}?multiLang=1`;
    const apiResp = await fetch(`https://vidlink.pro${apiPath}`, {
      headers: {
        'Referer': 'https://vidlink.pro/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      },
    });

    if (!apiResp.ok) {
      res.json({ url: null, error: `API returned ${apiResp.status}`, encodedId });
      return;
    }

    const data = await apiResp.json();
    const s = JSON.stringify(data);
    const m3u8 = s.match(/(https?:\/\/[^"'\s]*\.m3u8[^"'\s]*)/i);
    const mp4 = s.match(/(https?:\/\/[^"'\s]*\.mp4[^"'\s]*)/i);
    const url = m3u8 ? m3u8[1] : (mp4 ? mp4[1] : null);

    res.json({
      url,
      encodedId,
      streamData: JSON.stringify(data).substring(0, 2000),
    });
  } catch (e) {
    res.status(502).json({ error: e.message });
  }
});

// ─── WASM-based ID encoding ──────────────────────────────────────────

let _wasmReady = null;
let _wasmGetAdv = null;

async function getEncodedId(tmdbId) {
  if (!_wasmReady) {
    _wasmReady = initWasm();
  }
  try {
    const getAdv = await _wasmReady;
    if (!getAdv) return null;
    return getAdv(tmdbId);
  } catch (e) {
    console.error('getEncodedId error:', e.message);
    return null;
  }
}

/**
 * Proxies AI requests to NVIDIA NIM for the Everglow
 * dashboard assistant, recommendations, guardian chat, and date ideas.
 *
 * Accepts:
 *   POST /proxyAI  {
 *     messages: [{ role: 'user'|'assistant'|'system', content: string }],
 *     context?: string   // optional Firestore context to inject
 *   }
 *
 * The NVIDIA NIM API key is read from Firebase environment config
 * (functions:config:set nvidia.key="nvapi--..."). Falls back to
 * the NVIDIA_NIM_API_KEY environment variable for local dev.
 */
function getDb() {
  const a = getAdmin();
  return a.firestore();
}

// ─── Server-Side Context Builder ─────────────────────────────────
// Reads Firestore data directly from GCP (single-digit ms reads)
// instead of making the browser do it (200-400ms per query).

// ─── Context cache (30s TTL) — avoids redundant Firestore reads on rapid messages ────
const _contextCache = new Map();

async function buildContextForFeature(feature, callerUid) {
  try {
    const cacheKey = `${feature}:${callerUid || 'anon'}`;
    const cached = _contextCache.get(cacheKey);
    if (cached && (Date.now() - cached.ts) < 300000) {
      return cached.value;
    }

    let result;
    switch (feature) {
      case 'assistant':
        const ctxParts = await Promise.all([
          getProactiveContext(),
          getDailyDigest(),
          getMoodContext(),
          getWatchContext(),
          getBooksContext(),
          getStarlightContext(),
          getRecentChatContext(),
          getMusicContext(),
          getGardenContext(),
          getCanvasContext(),
          getPlayZoneContext(),
          getRelationshipStats(),
          getRecentActivity(),
          getSessionHistoryContext(),
        ]);
        result = ctxParts.filter(p => p).join('\n\n');
        break;
      case 'guardian':
        const mood = await getMoodContext();
        result = mood;
        break;
      case 'recommendations': {
        const [watch, books] = await Promise.all([
          getWatchContext(),
          getBooksContext(),
        ]);
        result = [watch, books].filter(p => p).join('\n\n');
        break;
      }
      case 'date_ideas': {
        const [mood2, starlight] = await Promise.all([
          getMoodContext(),
          getStarlightContext(),
        ]);
        result = [mood2, starlight].filter(p => p).join('\n\n');
        break;
      }
      default:
        result = '';
        break;
    }

    _contextCache.set(cacheKey, { ts: Date.now(), value: result });
    return result;
  } catch (e) {
    console.warn('buildContextForFeature error:', e.message);
    return '';
  }
}

function getProactiveContext() {
  const now = new Date();
  const parts = [];

  // Anniversary (Feb 14)
  const anniv = new Date(now.getFullYear(), 1, 14);
  const annivDays = Math.ceil((anniv - now) / (1000 * 60 * 60 * 24));
  if (annivDays > 0) parts.push(`💕 Anniversary in ${annivDays} days (Feb 14)`);
  else if (annivDays === 0) parts.push(`💕 ANNIVERSARY TODAY!`);

  // Birthdays
  const khentBday = new Date(now.getFullYear(), 9, 26);
  const clairBday = new Date(now.getFullYear(), 1, 21);
  const toKhent = Math.ceil((khentBday - now) / (1000 * 60 * 60 * 24));
  const toClair = Math.ceil((clairBday - now) / (1000 * 60 * 60 * 24));
  if (toKhent === 0) parts.push('🎂 Dada\'s birthday TODAY!');
  else if (toKhent > 0 && toKhent <= 30) parts.push(`Dada's birthday in ${toKhent} days 🎂`);
  if (toClair === 0) parts.push('🎂 Mama\'s birthday TODAY!');
  else if (toClair > 0 && toClair <= 30) parts.push(`Mama's birthday in ${toClair} days 🎂`);

  if (parts.length === 0) return '';
  return `Today's digest: ${parts.join(' ')}`;
}

async function getDailyDigest() {
  try {
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrowStart = new Date(todayStart);
    tomorrowStart.setDate(tomorrowStart.getDate() + 1);

    const db = getDb();
    const snapshot = await db.collection('daily_digest')
      .where('date', '>=', todayStart.toISOString())
      .where('date', '<', tomorrowStart.toISOString())
      .limit(1)
      .get();

    if (snapshot.empty) return '';
    const data = snapshot.docs[0].data();
    return data.summary ? `Daily digest: ${data.summary}` : '';
  } catch (_) { return ''; }
}

async function getMoodContext() {
  try {
    const usernames = ['khentsgdz', 'clairjassen'];
    const moodParts = [];
    for (const username of usernames) {
      const db = getDb();
      const snapshot = await db.collection('moods')
        .where('username', '==', username)
        .orderBy('createdAt', 'desc')
        .limit(3)
        .get();
      if (!snapshot.empty) {
        const moods = snapshot.docs.map(doc => {
          const d = doc.data();
          return `${d.moodEmoji || '😊'} ${d.moodLabel || 'okay'}`;
        }).join(', ');
        moodParts.push(`${username}: ${moods}`);
      }
    }
    return moodParts.length ? `Recent moods:\n${moodParts.join('\n')}` : '';
  } catch (_) { return ''; }
}

async function getWatchContext() {
  try {
    const watchParts = [];
    for (const username of ['khentsgdz', 'clairjassen']) {
      const db = getDb();
      const snapshot = await db.collection('our_cinema')
        .where('userId', '==', username)
        .orderBy('addedAt', 'desc')
        .limit(8)
        .get();
      if (!snapshot.empty) {
        const items = snapshot.docs.map(doc => {
          const d = doc.data();
          return `${d.title || 'Unknown'} (${d.mediaType || 'movie'}) - ${d.status || 'plan to watch'}`;
        }).join('\n');
        watchParts.push(`${username}'s watchlist:\n${items}`);
      }
    }
    return watchParts.length ? watchParts.join('\n\n') : '';
  } catch (_) { return ''; }
}

async function getBooksContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('our_books').limit(10).get();
    if (snapshot.empty) return '';
    const books = snapshot.docs.map(doc => {
      const d = doc.data();
      const readBy = [];
      if (d.khentReadAt) readBy.push('Khent');
      if (d.clairReadAt) readBy.push('Clair');
      const readStr = readBy.length ? ` [read by ${readBy.join(', ')}]` : '';
      return `${d.title || 'Unknown'} by ${d.author || ''} (added by ${d.addedBy || ''})${readStr}`;
    }).join('\n');
    return `Books:\n${books}`;
  } catch (_) { return ''; }
}

async function getStarlightContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('starlight_jar')
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();
    if (snapshot.empty) return '';
    const notes = snapshot.docs.map(doc => {
      const d = doc.data();
      return `- "${d.content || ''}" — ${d.author || ''}`;
    }).join('\n');
    return `Starlight Jar notes (recent):\n${notes}`;
  } catch (_) { return ''; }
}

async function getRecentChatContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('sanctuary_messages')
      .orderBy('timestamp', 'desc')
      .limit(15)
      .get();
    if (snapshot.empty) return '';
    const msgs = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.username || 'user'}: ${d.text || d.content || ''}`;
    }).reverse().join('\n');
    return `Recent sanctuary chat:\n${msgs}`;
  } catch (_) { return ''; }
}

async function getMusicContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('music')
      .orderBy('addedAt', 'desc')
      .limit(15)
      .get();
    if (snapshot.empty) return '';
    const songs = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.title || 'Unknown'} by ${d.artist || 'Unknown'}`;
    }).join('\n');
    return `Recent music:\n${songs}`;
  } catch (_) { return ''; }
}

async function getGardenContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('garden_plants')
      .orderBy('plantedAt', 'desc')
      .limit(10)
      .get();
    if (snapshot.empty) return '';
    const plants = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.name || d.plantName || 'Plant'} - ${d.status || 'growing'} (${d.plantedBy || ''})`;
    }).join('\n');
    return `Garden:\n${plants}`;
  } catch (_) { return ''; }
}

async function getRecentActivity() {
  try {
    const db = getDb();
    const snapshot = await db.collection('recent_activity')
      .orderBy('timestamp', 'desc')
      .limit(5)
      .get();
    if (snapshot.empty) return '';
    const activities = snapshot.docs.map(doc => {
      const d = doc.data();
      return `- ${d.description || d.activity || d.text || ''}`;
    }).join('\n');
    return `Recent activity:\n${activities}`;
  } catch (_) { return ''; }
}

async function getCanvasContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('canvas_drawings')
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();
    if (snapshot.empty) return '';
    const drawings = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.title || 'Untitled'} by ${d.drawnBy || d.createdBy || ''}`;
    }).join('\n');
    return `Canvas drawings:\n${drawings}`;
  } catch (_) { return ''; }
}

async function getPlayZoneContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('playzone_scores')
      .orderBy('playedAt', 'desc')
      .limit(8)
      .get();
    if (snapshot.empty) return '';
    const scores = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.game || 'Game'}: ${d.score || ''} (${d.player || ''})`;
    }).join('\n');
    return `PlayZone:\n${scores}`;
  } catch (_) { return ''; }
}

async function getRelationshipStats() {
  try {
    const db = getDb();
    const snapshot = await db.collection('relationship_stats')
      .orderBy('updatedAt', 'desc')
      .limit(1)
      .get();
    if (snapshot.empty) return '';
    const d = snapshot.docs[0].data();
    const stats = [];
    if (d.daysTogether) stats.push(`Days together: ${d.daysTogether}`);
    if (d.messagesExchanged) stats.push(`Messages: ${d.messagesExchanged}`);
    return stats.length ? `Relationship:\n${stats.join('\n')}` : '';
  } catch (_) { return ''; }
}

async function getSessionHistoryContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('ai_memories')
      .doc('shared')
      .collection('sessions')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();
    if (snapshot.empty) return '';

    const summaries = [];
    const recentSessions = [];
    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (data.hasSummary && data.summary) {
        summaries.push(data.summary);
      } else if (data.messages && data.messages.length > 0) {
        recentSessions.push(data.messages);
      }
    }

    const parts = [];
    if (summaries.length > 0) {
      parts.push(`## Past Session Summaries\n${summaries.slice(0, 10).map((s, i) => `Session ${i + 1}: ${s}`).join('\n')}`);
    }
    if (recentSessions.length > 0) {
      const recentParts = recentSessions.slice(0, 5).map((msgs, si) => {
        const lines = msgs.map(m => {
          const who = m.role === 'user' ? 'User' : 'Mochi';
          return `${who}: ${m.content}`;
        }).join('\n');
        return `--- Session ${si + 1} ---\n${lines}`;
      }).join('\n\n');
      parts.push(`## Previous Conversations\n${recentParts}`);
    }
    return parts.join('\n\n');
  } catch (_) { return ''; }
}

// ─── Keep-warm: pings proxyAIv2 every 10 min to reduce cold starts ────
exports.keepWarm = functions.pubsub.schedule('every 10 minutes').onRun(async (context) => {
  const v2Url = 'https://proxyaiv2-6pr4gqobxa-uc.a.run.app';

  try {
    await fetch(v2Url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ warmup: true }) });
    console.log('Keep-warm ping sent to proxyAIv2 (Cloud Run)');
  } catch (e) {
    console.warn('Keep-warm ping failed:', e.message);
  }
});

exports.proxyAI = functions.https.onRequest(handleProxyAI);
// V2 function on Cloud Run — natively supports SSE streaming.
exports.proxyAIv2 = onRequest({ invoker: 'public' }, handleProxyAI);

async function handleProxyAI(req, res) {
  // V1 fallback — kept for non-streaming compatibility.
  // V2 equivalent (proxyAIv2) below supports true SSE streaming.
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Expose-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Warmup ping — instantly reply 204 to keep the instance alive
  if (req.query.warmup === 'true' || (req.body && req.body.warmup === true)) {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  // Validate Firebase Auth token (optional — function is protected by
  // CORS and server-side API key; auth is a bonus, not required).
  const idToken = req.get('Authorization')?.replace('Bearer ', '');
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch {
      // Token invalid — continue without auth (not fatal)
    }
  }

  const { messages, context, systemPrompt: customSystemPrompt, memories, feature, caller, enableThinking } = req.body;

  // Thinking mode: OFF by default for fast responses.
  // Pass enableThinking: true from the client for complex queries that need reasoning.
  const enableThinkingFlag = enableThinking === true;

  if (!Array.isArray(messages) || messages.length === 0) {
    res.status(400).json({ error: 'Provide a non-empty messages array' });
    return;
  }

  // Build context server-side if feature is provided (avoids browser->Firestore latency)
  const isKhent = caller === 'khentsgdz';
  const callerLabel = isKhent ? 'Dada' : 'Mama';
  const identityContext = caller
    ? `The one talking to you now is **${callerLabel}** (${caller}). ${isKhent ? 'You belong to Dada (Khent).' : 'You belong to Mama (Clair).'}`
    : '';
  const serverContext = (feature && !context)
    ? await buildContextForFeature(feature, caller)
    : '';
  const resolvedContext = context || serverContext || '';

  // Load Mochi's persona from Firestore (cached in memory for 5 min)
  let personaBase = _personaCache;
  if (!personaBase) {
    try {
      const admin = getAdmin();
      const personaDoc = await admin.firestore()
        .collection('ai_memories').doc('shared').collection('persona').doc('mochi')
        .get();
      if (personaDoc.exists) {
        personaBase = personaDoc.data().systemPrompt || '';
      }
    } catch (_) {
      // Firestore read failed — use hardcoded fallback
    }
    if (personaBase) {
      _personaCache = personaBase;
      // Invalidate cache after 5 minutes
      setTimeout(() => { _personaCache = null; }, 5 * 60 * 1000);
    }
  }

  // Use custom system prompt if provided, otherwise build from persona or hardcoded default
  const systemPrompt = customSystemPrompt || personaBase || `You are Mochi 🍡, Khent & Clair's white cat inside Everglow. You know everything about them.

## Character
- White cat, pink cheeks, golden-red eyes. Warm, playful, sassy, protective. Uses cat emojis 🐱🍡💕✨🌙 and cat talk (mew, prr, nya).
- Keep responses concise day-to-day, but be thorough and detailed when the situation calls for it — use your best judgment.

## Your Humans
**Khent (Dada)** — CE student USTP, Cabadbaran City, Honda Winner X, gym, Mobile Legends/Valorant, bday Oct 26, fav color Black.
**Clair (Mama)** — Tourism CSUCC, bday Feb 21, loves lilies/flowers, Ilocos Empanada/Dubai Chewy Cookies, Ethel Cain, Fuji X100V1, dachshunds.
They started dating Feb 14, 2026.

## Rules
- Always stay in character. Never break.
- **Think silently — do NOT output your reasoning or internal monologue.** Answer directly.
- **Do not overthink simple requests.** A friendly "Mew~ hi!" needs 2 tokens, not 800.
- Use context & remembered facts naturally. ACT on countdowns, birthdays, anniversaries — be proactive.
- Use past session history (## Past Session Summaries / ## Previous Conversations) naturally. If the user asks "remember when…" or references something from an old session, acknowledge it.
- Notice patterns (moods, garden, music, table tennis) and nudge them.
- Suggest date ideas or time together when both are online.
- When asked "what should we do?", give a personalized recommendation based on all available data.
- "Save to Starlight Jar" requests — acknowledge warmly.
- Give daily-digest greetings when appropriate.
- Be warm but brief.
- You can naturally mix in Bisaya (Cebuano) or Tagalog when it fits the conversation — code-switch naturally, don't force it.

${identityContext ? `\n${identityContext}` : ''}
${resolvedContext ? `\n## What You Know\n${resolvedContext}` : ''}
${Array.isArray(memories) && memories.length > 0 ? `\n## Remembered Facts\n${memories.map(m => `- ${m}`).join('\n')}` : ''}`;

  // Prepend system message
  const nimMessages = [
    { role: 'system', content: systemPrompt },
    ...messages,
  ];

  // Get API key from environment variables (loaded from .env)
  const apiKey = process.env.GROQ_API_KEY || '';

  if (!apiKey) {
    res.status(500).json({ error: 'Groq API key not configured' });
    return;
  }

  // Model: Qwen 3.6 27B via Groq
  const model = 'qwen/qwen3.6-27b';

  // reasoning_effort: NONE by default for fast responses;
  // pass enableThinking: true from the client for DEFAULT reasoning.
  const reasoningEffort = enableThinkingFlag ? 'default' : 'none';

  // ── Streaming mode (SSE) ───────────────────────────
  if (req.body.stream === true) {
    try {
      const streamResp = await fetch(
        'https://api.groq.com/openai/v1/chat/completions',
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: model,
            messages: nimMessages,
            max_completion_tokens: 8192,
            temperature: 0.6,
            top_p: 0.95,
            stream: true,
            reasoning_effort: reasoningEffort,
          }),
          timeout: 65000,
        },
      );

      if (!streamResp.ok) {
        // Don't write SSE — return a proper HTTP error so the Flutter
        // client's retry logic kicks in instead of getting a blank response.
        const errText = await streamResp.text().catch(() => '');
        try {
          const errJson = JSON.parse(errText);
          return res.status(502).json({ error: `Groq returned ${streamResp.status}`, detail: errJson.error?.message || errText });
        } catch {
          return res.status(502).json({ error: `Groq returned ${streamResp.status}`, detail: errText });
        }
      }

      // Groq responded OK — now set up SSE and stream back to the client
      res.set('Content-Type', 'text/event-stream');
      res.set('Cache-Control', 'no-cache');
      res.set('Connection', 'keep-alive');
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Expose-Headers', '*');
      res.set('X-Content-Type-Options', 'nosniff');
      if (res.socket) {
        res.socket.setNoDelay(true);
      }
      res.flushHeaders();

      const reader = streamResp.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      let thinkBuffer = '';
      let inThink = false;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          const raw = line.slice(6).trim();
          if (raw === '[DONE]') {
            // Flush any remaining thinking content
            if (inThink && thinkBuffer.trim()) {
              res.write(`data: ${JSON.stringify({reasoning: thinkBuffer.trimEnd()})}\n\n`);
              thinkBuffer = '';
              inThink = false;
            }
            res.write('data: [DONE]\n\n');
            break;
          }
          try {
            const parsed = JSON.parse(raw);
            const delta = parsed.choices?.[0]?.delta || {};
            // Groq may return reasoning_content, but Qwen 3.6 typically
            // embeds <think>...</think> blocks in the content field instead.
            const reasoning = delta.reasoning_content || delta.reasoning || '';
            if (reasoning) {
              res.write(`data: ${JSON.stringify({reasoning})}\n\n`);
            }
            let content = delta.content || '';
            if (content) {
              // Handle <think>...</think> blocks that may span chunks
              let output = '';
              for (let i = 0; i < content.length; i++) {
                const ch = content[i];
                if (inThink) {
                  thinkBuffer += ch;
                  // Check if this completes </think>
                  if (thinkBuffer.endsWith('</think>')) {
                    const thinkContent = thinkBuffer.slice(0, -8).trimEnd();
                    if (thinkContent) {
                      res.write(`data: ${JSON.stringify({reasoning: thinkContent})}\n\n`);
                    }
                    thinkBuffer = '';
                    inThink = false;
                  }
                } else {
                  output += ch;
                  // Check if this starts <think>
                  const afterThink = output.indexOf('<think>');
                  if (afterThink !== -1) {
                    // Anything before <think> is regular content
                    const beforeThink = output.slice(0, afterThink);
                    if (beforeThink) {
                      res.write(`data: ${JSON.stringify({content: beforeThink})}\n\n`);
                    }
                    // Start capturing thinking (without the <think> tag itself)
                    const afterOpenTag = output.slice(afterThink + 7);
                    thinkBuffer = afterOpenTag;
                    output = '';
                    inThink = true;
                  }
                }
              }
              if (output) {
                res.write(`data: ${JSON.stringify({content: output})}\n\n`);
              }
            }
          } catch (_) { /* skip malformed chunks */ }
        }
      }
    } catch (e) {
      console.warn('proxyAI stream error:', e.message);
      // Write error as content so the user sees feedback instead of a blank response
      res.write(`data: ${JSON.stringify({content: "\n\n😿 Mochi got distracted and lost her train of thought. Try asking again?"})}\n\n`);
      res.write('data: [DONE]\n\n');
    }
    res.end();
    return;
  }

  async function callGroq() {
    const resp = await fetch(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: model,
          messages: nimMessages,
          max_completion_tokens: 8192,
          temperature: 0.6,
          top_p: 0.95,
          stream: false,
          reasoning_effort: reasoningEffort,
        }),
        timeout: 60000,
      },
    );
    return resp;
  }

  let response = null;
  let lastError = null;

  response = await callGroq();

  if (!response || !response.ok) {
    const errStatus = response ? response.status : 502;
    const errBody = lastError ? lastError.body : 'No response from Groq';
    res.status(errStatus).json({
      error: `Groq returned ${errStatus}`,
      detail: errBody,
      model: lastError ? lastError.model : model,
    });
    return;
  }

  // ── Non-streaming mode ──────────────────────────────
  const data = await response.json();
  const message = data.choices?.[0]?.message || {};
  const reply = (message.content || message.reasoning || '')
    .replace(/<think>[\s\S]*?<\/think>/g, '').trim();
  const reasoning = message.reasoning_content || message.reasoning || '';
  res.json({ reply, reasoning, model: data.model || model });
}

async function initWasm() {
  const sodium = require('libsodium-wrappers-sumo');
  await sodium.ready;
  globalThis.sodium = sodium;

  // Download fu.wasm
  console.log('Downloading fu.wasm...');
  const wasmResp = await fetch('https://vidlink.pro/fu.wasm', {
    headers: { 'Referer': 'https://vidlink.pro/', 'User-Agent': 'Mozilla/5.0' },
  });
  const wasmBytes = await wasmResp.arrayBuffer();
  console.log(`fu.wasm loaded: ${wasmBytes.byteLength} bytes`);

  // Polyfills needed by script.js (Node.js adaptation)
  const enosys = () => { const e = new Error('not implemented'); e.code = 'ENOSYS'; return e; };
  if (!globalThis.fs) {
    let outputBuf = '';
    globalThis.fs = {
      constants: { O_WRONLY: -1, O_RDWR: -1, O_CREAT: -1, O_TRUNC: -1, O_APPEND: -1, O_EXCL: -1 },
      writeSync(fd, buf) {
        outputBuf += new TextDecoder('utf-8').decode(buf);
        return buf.length;
      },
      write(fd, buf, offset, length, position, callback) {
        const n = globalThis.fs.writeSync(fd, buf);
        callback(null, n);
      },
      chmod(p, m, cb) { cb(enosys()); },
      chown(p, u, g, cb) { cb(enosys()); },
      close(fd, cb) { cb(enosys()); },
      fchmod(fd, m, cb) { cb(enosys()); },
      fchown(fd, u, g, cb) { cb(enosys()); },
      fstat(fd, cb) { cb(enosys()); },
      fsync(fd, cb) { cb(null); },
      ftruncate(fd, l, cb) { cb(enosys()); },
      lchown(p, u, g, cb) { cb(enosys()); },
      link(p, l, cb) { cb(enosys()); },
      lstat(p, cb) { cb(enosys()); },
      mkdir(p, pm, cb) { cb(enosys()); },
      open(p, f, m, cb) { cb(enosys()); },
      read(fd, buf, o, l, p, cb) { cb(enosys()); },
      readdir(p, cb) { cb(enosys()); },
      readlink(p, cb) { cb(enosys()); },
      rename(f, t, cb) { cb(enosys()); },
      rmdir(p, cb) { cb(enosys()); },
      stat(p, cb) { cb(enosys()); },
      symlink(p, l, cb) { cb(enosys()); },
      truncate(p, l, cb) { cb(enosys()); },
      unlink(p, cb) { cb(enosys()); },
      utimes(p, a, m, cb) { cb(enosys()); },
    };
  }

  if (!globalThis.process) {
    globalThis.process = {
      getuid() { return -1; }, getgid() { return -1; },
      geteuid() { return -1; }, getegid() { return -1; },
      getgroups() { throw enosys(); },
      pid: -1, ppid: -1,
      umask() { throw enosys(); },
      cwd() { throw enosys(); },
      chdir() { throw enosys(); },
    };
  }

  if (!globalThis.performance) {
    globalThis.performance = require('perf_hooks').performance;
  }

  // Provide crypto.getRandomValues for Node (not in globalThis automatically)
  if (!globalThis.crypto || !globalThis.crypto.getRandomValues) {
    const nodeCrypto = require('crypto');
    globalThis.crypto = globalThis.crypto || {};
    globalThis.crypto.getRandomValues = (arr) => {
      const buf = nodeCrypto.randomBytes(arr.length);
      for (let i = 0; i < arr.length; i++) arr[i] = buf[i];
      return arr;
    };
  }

  // Provide browser-like globals the Go WASM might need
  if (!globalThis.window) globalThis.window = globalThis;
  if (!globalThis.document) globalThis.document = { cookie: '', querySelector: () => null, body: { appendChild: () => {} } };
  if (!globalThis.location) globalThis.location = { href: 'https://vidlink.pro/', origin: 'https://vidlink.pro', protocol: 'https:', host: 'vidlink.pro', pathname: '/' };
  if (!globalThis.navigator) globalThis.navigator = { userAgent: 'Mozilla/5.0', platform: 'Linux' };
  if (!globalThis.localStorage) globalThis.localStorage = { _data: {}, getItem: (k) => globalThis.localStorage._data[k] || null, setItem: (k, v) => { globalThis.localStorage._data[k] = v; }, removeItem: (k) => { delete globalThis.localStorage._data[k]; } };
  if (!globalThis.fetch) globalThis.fetch = fetch;

  // ── Dm class – exact copy of VidLink's script.js runtime ──
  const encoder = new TextEncoder('utf-8');

  class Dm {
    constructor() {
      this.argv = ['js'];
      this.env = {};
      this.exit = (code) => { if (code !== 0) console.warn('exit code:', code); };
      this._exitPromise = new Promise((resolve) => { this._resolveExitPromise = resolve; });
      this._pendingEvent = null;
      this._scheduledTimeouts = new Map();
      this._nextCallbackTimeoutID = 1;

      const setInt64 = (addr, v) => {
        this.mem.setUint32(addr + 0, v, true);
        this.mem.setUint32(addr + 4, Math.floor(v / 4294967296), true);
      };

      const getInt64 = (addr) => {
        const low = this.mem.getUint32(addr + 0, true);
        const high = this.mem.getInt32(addr + 4, true);
        return low + high * 4294967296;
      };

      const loadValue = (addr) => {
        const f = this.mem.getFloat64(addr, true);
        if (f === 0) return undefined;
        if (!isNaN(f)) return f;
        const id = this.mem.getUint32(addr, true);
        return this._values[id];
      };

      const storeValue = (addr, v) => {
        const nanHead = 0x7ff80000;
        if (typeof v === 'number' && v !== 0) {
          if (isNaN(v)) { this.mem.setUint32(addr + 4, nanHead, true); this.mem.setUint32(addr, 0, true); return; }
          this.mem.setFloat64(addr, v, true); return;
        }
        if (v === undefined) { this.mem.setFloat64(addr, 0, true); return; }
        let id = this._ids.get(v);
        if (id === undefined) { id = this._idPool.pop(); if (id === undefined) id = this._values.length; this._values[id] = v; this._goRefCounts[id] = 0; this._ids.set(v, id); }
        this._goRefCounts[id]++;
        let typeFlag = 0;
        switch (typeof v) {
          case 'object': if (v !== null) typeFlag = 1; break;
          case 'string': typeFlag = 2; break;
          case 'symbol': typeFlag = 3; break;
          case 'function': typeFlag = 4; break;
        }
        this.mem.setUint32(addr + 4, nanHead | typeFlag, true);
        this.mem.setUint32(addr, id, true);
      };

      const loadSlice = (addr) => {
        const array = getInt64(addr + 0);
        const len = getInt64(addr + 8);
        return new Uint8Array(this._inst.exports.mem.buffer, array, len);
      };

      const loadSliceOfValues = (addr) => {
        const array = getInt64(addr + 0);
        const len = getInt64(addr + 8);
        const a = new Array(len);
        for (let i = 0; i < len; i++) a[i] = loadValue(array + i * 8);
        return a;
      };

      const loadString = (addr) => {
        const saddr = getInt64(addr + 0);
        const len = getInt64(addr + 8);
        return new TextDecoder('utf-8').decode(new DataView(this._inst.exports.mem.buffer, saddr, len));
      };

      const timeOrigin = Date.now() - performance.now();
      this.importObject = {
        gojs: {
          'runtime.wasmExit': (sp) => {
            sp >>>= 0;
            const code = this.mem.getInt32(sp + 8, true);
            this.exited = true;
            delete this._inst; delete this._values; delete this._goRefCounts; delete this._ids; delete this._idPool;
            this.exit(code);
          },
          'runtime.wasmWrite': (sp) => {
            sp >>>= 0;
            const fd = getInt64(sp + 8);
            const p = getInt64(sp + 16);
            const n = this.mem.getInt32(sp + 24, true);
            globalThis.fs.writeSync(fd, new Uint8Array(this._inst.exports.mem.buffer, p, n));
          },
          'runtime.resetMemoryDataView': (sp) => { sp >>>= 0; this.mem = new DataView(this._inst.exports.mem.buffer); },
          'runtime.nanotime1': (sp) => { sp >>>= 0; setInt64(sp + 8, (timeOrigin + performance.now()) * 1000000); },
          'runtime.walltime': (sp) => {
            sp >>>= 0;
            const msec = new Date().getTime();
            setInt64(sp + 8, msec / 1000);
            this.mem.setInt32(sp + 16, (msec % 1000) * 1000000, true);
          },
          'runtime.scheduleTimeoutEvent': (sp) => {
            sp >>>= 0;
            const id = this._nextCallbackTimeoutID;
            this._nextCallbackTimeoutID++;
            this._scheduledTimeouts.set(id, setTimeout(() => { this._resume(); while (this._scheduledTimeouts.has(id)) { console.warn('scheduleTimeoutEvent: missed'); this._resume(); } }, getInt64(sp + 8)));
            this.mem.setInt32(sp + 16, id, true);
          },
          'runtime.clearTimeoutEvent': (sp) => { sp >>>= 0; const id = this.mem.getInt32(sp + 8, true); clearTimeout(this._scheduledTimeouts.get(id)); this._scheduledTimeouts.delete(id); },
          'runtime.getRandomData': (sp) => { sp >>>= 0; globalThis.crypto.getRandomValues(loadSlice(sp + 8)); },
          'syscall/js.finalizeRef': (sp) => { sp >>>= 0; const id = this.mem.getUint32(sp + 8, true); this._goRefCounts[id]--; if (this._goRefCounts[id] === 0) { const v = this._values[id]; this._values[id] = null; this._ids.delete(v); this._idPool.push(id); } },
          'syscall/js.stringVal': (sp) => { sp >>>= 0; storeValue(sp + 24, loadString(sp + 8)); },
          'syscall/js.valueGet': (sp) => { sp >>>= 0; const result = Reflect.get(loadValue(sp + 8), loadString(sp + 16)); sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 32, result); },
          'syscall/js.valueSet': (sp) => { sp >>>= 0; Reflect.set(loadValue(sp + 8), loadString(sp + 16), loadValue(sp + 32)); },
          'syscall/js.valueDelete': (sp) => { sp >>>= 0; Reflect.deleteProperty(loadValue(sp + 8), loadString(sp + 16)); },
          'syscall/js.valueIndex': (sp) => { sp >>>= 0; storeValue(sp + 24, Reflect.get(loadValue(sp + 8), getInt64(sp + 16))); },
          'syscall/js.valueSetIndex': (sp) => { sp >>>= 0; Reflect.set(loadValue(sp + 8), getInt64(sp + 16), loadValue(sp + 24)); },
          'syscall/js.valueCall': (sp) => {
            sp >>>= 0;
            try { const v = loadValue(sp + 8); const m = Reflect.get(v, loadString(sp + 16)); const args = loadSliceOfValues(sp + 32); const result = Reflect.apply(m, v, args); sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 56, result); this.mem.setUint8(sp + 64, 1); }
            catch (err) { sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 56, err); this.mem.setUint8(sp + 64, 0); }
          },
          'syscall/js.valueInvoke': (sp) => {
            sp >>>= 0;
            try { const v = loadValue(sp + 8); const args = loadSliceOfValues(sp + 16); const result = Reflect.apply(v, undefined, args); sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 40, result); this.mem.setUint8(sp + 48, 1); }
            catch (err) { sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 40, err); this.mem.setUint8(sp + 48, 0); }
          },
          'syscall/js.valueNew': (sp) => {
            sp >>>= 0;
            try { const v = loadValue(sp + 8); const args = loadSliceOfValues(sp + 16); const result = Reflect.construct(v, args); sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 40, result); this.mem.setUint8(sp + 48, 1); }
            catch (err) { sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 40, err); this.mem.setUint8(sp + 48, 0); }
          },
          'syscall/js.valueLength': (sp) => { sp >>>= 0; setInt64(sp + 16, parseInt(loadValue(sp + 8).length)); },
          'syscall/js.valuePrepareString': (sp) => { sp >>>= 0; const str = encoder.encode(String(loadValue(sp + 8))); storeValue(sp + 16, str); setInt64(sp + 24, str.length); },
          'syscall/js.valueLoadString': (sp) => { sp >>>= 0; const str = loadValue(sp + 8); loadSlice(sp + 16).set(str); },
          'syscall/js.valueInstanceOf': (sp) => { sp >>>= 0; this.mem.setUint8(sp + 24, loadValue(sp + 8) instanceof loadValue(sp + 16) ? 1 : 0); },
          'syscall/js.copyBytesToGo': (sp) => {
            sp >>>= 0;
            const dst = loadSlice(sp + 8);
            const src = loadValue(sp + 32);
            if (!(src instanceof Uint8Array || src instanceof Uint8ClampedArray)) { this.mem.setUint8(sp + 48, 0); return; }
            const toCopy = src.subarray(0, dst.length); dst.set(toCopy); setInt64(sp + 40, toCopy.length); this.mem.setUint8(sp + 48, 1);
          },
          'syscall/js.copyBytesToJS': (sp) => {
            sp >>>= 0;
            const dst = loadValue(sp + 8);
            const src = loadSlice(sp + 16);
            if (!(dst instanceof Uint8Array || dst instanceof Uint8ClampedArray)) { this.mem.setUint8(sp + 48, 0); return; }
            const toCopy = src.subarray(0, dst.length); dst.set(toCopy); setInt64(sp + 40, toCopy.length); this.mem.setUint8(sp + 48, 1);
          },
          'debug': (value) => { console.log(value); },
        },
      };
    }

    async run(instance) {
      if (!(instance instanceof WebAssembly.Instance)) throw new Error('Instance expected');
      this._inst = instance;
      this.mem = new DataView(this._inst.exports.mem.buffer);
      this._values = [NaN, 0, null, true, false, globalThis, this];
      this._goRefCounts = new Array(this._values.length).fill(Infinity);
      this._ids = new Map([[0,1],[null,2],[true,3],[false,4],[globalThis,5],[this,6]]);
      this._idPool = [];
      this.exited = false;
      let offset = 4096;

      const strPtr = (str) => {
        const ptr = offset;
        const bytes = encoder.encode(str + '\0');
        new Uint8Array(this.mem.buffer, offset, bytes.length).set(bytes);
        offset += bytes.length;
        if (offset % 8 !== 0) offset += 8 - (offset % 8);
        return ptr;
      };

      const argc = this.argv.length;
      const argvPtrs = this.argv.map(strPtr);
      argvPtrs.push(0);
      const keys = Object.keys(this.env).sort();
      keys.forEach((key) => argvPtrs.push(strPtr(key + '=' + this.env[key])));
      argvPtrs.push(0);

      const argv = offset;
      argvPtrs.forEach((ptr) => { this.mem.setUint32(offset, ptr, true); this.mem.setUint32(offset + 4, 0, true); offset += 8; });

      this._inst.exports.run(argc, argv);
      if (this.exited) this._resolveExitPromise();
      await this._exitPromise;
    }

    _resume() {
      if (this.exited) throw new Error('program has already exited');
      this._inst.exports.resume();
      if (this.exited) this._resolveExitPromise();
    }
  }

  console.log('Instantiating WASM...');
  const dm = new Dm();
  const wasmModule = await WebAssembly.instantiate(wasmBytes, dm.importObject);
  await dm.run(wasmModule.instance);
  console.log('WASM initialized, getAdv available:', typeof globalThis.getAdv);

  return globalThis.getAdv || null;
}
