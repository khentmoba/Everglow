const functions = require('firebase-functions/v1');
const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');

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
 * Proxies MangaKatana chapter page images so Flutter web isn't blocked
 * by CORS or hotlink protection.
 *
 * Accepts:
 *   GET /proxyMangaKatana?url=<encoded image url>
 */
exports.proxyMangaKatana = functions.https.onRequest(async (req, res) => {
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
    '.mangakatana.com',
    '.mangakakalot.com',
    '.mkklcdnv6temp.com',
    '.catmanga.org',
  ];
  const hostAllowed = allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8', 'Referer': 'https://mangakatana.com/' },
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
    console.warn(`proxyMangaKatana failed (${targetUrl}):`, e.message);
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
    // Bato.to image CDN
    '.bato.to',
    '.img.bato.to',
    // MangaSee123 image CDN
    '.mangasee123.com',
    '.scans-hot.xyz',
    // MangaKatana image CDN
    '.mangakatana.com',
    '.mangakatana.net',
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
        const [watch, books, trending, nowPlaying, upcoming] = await Promise.all([
          getWatchContext(),
          getBooksContext(),
          getTrendingMovies(),
          getNowPlayingMovies(),
          getUpcomingMovies(),
        ]);
        result = [watch, books, trending, nowPlaying, upcoming].filter(p => p).join('\n\n');
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
        .limit(5)
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
        .limit(15)
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

// TMDB API key — uses Firebase env config, falls back to client-side key for dev
function getTmdbKey() {
  return process.env.TMDB_API_KEY || 'b41bd33efc365bbdbbad2e31dae8f573';
}

async function getTrendingMovies() {
  try {
    const key = getTmdbKey();
    const res = await fetch(
      `https://api.themoviedb.org/3/trending/movie/week?api_key=${key}`
    );
    if (!res.ok) return '';
    const data = await res.json();
    if (!data.results?.length) return '';
    const movies = data.results.slice(0, 15).map(m =>
      `${m.title} (${(m.release_date || '').slice(0, 4)}) — ${(m.overview || '').slice(0, 200)}`
    ).join('\n');
    return `Trending movies this week:\n${movies}`;
  } catch (_) { return ''; }
}

async function getNowPlayingMovies() {
  try {
    const key = getTmdbKey();
    const res = await fetch(
      `https://api.themoviedb.org/3/movie/now_playing?api_key=${key}&region=PH`
    );
    if (!res.ok) return '';
    const data = await res.json();
    if (!data.results?.length) return '';
    const movies = data.results.slice(0, 12).map(m =>
      `${m.title} (${(m.release_date || '').slice(0, 4)}) — ${(m.overview || '').slice(0, 200)}`
    ).join('\n');
    return `Now playing in theaters:\n${movies}`;
  } catch (_) { return ''; }
}

async function getUpcomingMovies() {
  try {
    const key = getTmdbKey();
    const res = await fetch(
      `https://api.themoviedb.org/3/movie/upcoming?api_key=${key}&region=PH`
    );
    if (!res.ok) return '';
    const data = await res.json();
    if (!data.results?.length) return '';
    const movies = data.results.slice(0, 12).map(m =>
      `${m.title} (${(m.release_date || '').slice(0, 4)}) — ${(m.overview || '').slice(0, 200)}`
    ).join('\n');
    return `Coming soon:\n${movies}`;
  } catch (_) { return ''; }
}

async function getBooksContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('our_books').limit(20).get();
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
      .limit(20)
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
      .limit(30)
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
      .limit(25)
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
      .limit(20)
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
      .limit(10)
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
      .limit(10)
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
      .limit(12)
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
      .limit(50)
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
      parts.push(`## Past Session Summaries\n${summaries.slice(0, 25).map((s, i) => `Session ${i + 1}: ${s}`).join('\n')}`);
    }
    if (recentSessions.length > 0) {
      // With 512K context, we can afford richer session history.
      const CHAR_LIMIT = 40_000;
      let totalChars = 0;
      const sessionBlocks = [];
      for (let si = 0; si < Math.min(recentSessions.length, 8); si++) {
        const msgs = recentSessions[si];
        const lines = [];
        for (const m of msgs) {
          const who = m.role === 'user' ? 'User' : 'Mochi';
          const content = (m.content || '').length > 3000
            ? (m.content || '').substring(0, 3000) + '… [truncated]'
            : (m.content || '');
          lines.push(`${who}: ${content}`);
        }
        const block = `--- Session ${si + 1} ---\n${lines.join('\n')}`;
        if (totalChars + block.length > CHAR_LIMIT && sessionBlocks.length > 0) {
          break;
        }
        totalChars += block.length;
        sessionBlocks.push(block);
      }
      if (sessionBlocks.length > 0) {
        parts.push(`## Previous Conversations\n${sessionBlocks.join('\n\n')}`);
      }
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

// ── Rough token estimator ──────────────────────────────
// ~4 chars/token for English, ~3 for mixed CJK/emoji content.
// Good enough for budget enforcement; not a substitute for tiktoken.
function estimateTokens(text) {
  if (!text) return 0;
  // Count CJK characters (roughly 1.5 tokens each) and emoji (1 token each)
  const cjk = (text.match(/[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]/g) || []).length;
  const nonCjk = text.length - cjk;
  return Math.ceil(nonCjk / 4) + Math.ceil(cjk * 1.5);
}

// Agnes 2.0 Flash: 512K context window, generous token budget.
// Use ~25% of context for input safety; reserve rest for output + tool loops.
const AGNES_INPUT_TOKEN_BUDGET = 120000;

// ── Server-Side Memory Filtering ─────────────────────────────────
// Replaces client-side memory injection with TF-IDF keyword matching.
// Fetches all memories from Firestore, filters by relevance, decays stale ones.

const MEMORY_STOP_WORDS = new Set([
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
  'should', 'may', 'might', 'shall', 'can', 'to', 'of', 'in', 'for',
  'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through', 'during',
  'before', 'after', 'above', 'below', 'between', 'out', 'off', 'over',
  'under', 'again', 'further', 'then', 'once', 'here', 'there', 'when',
  'where', 'why', 'how', 'all', 'each', 'every', 'both', 'few', 'more',
  'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own',
  'same', 'so', 'than', 'too', 'very', 'just', 'because', 'but', 'and',
  'or', 'if', 'while', 'about', 'up', 'it', 'its', 'i', 'me', 'my',
  'you', 'your', 'he', 'him', 'his', 'she', 'her', 'we', 'us', 'our',
  'they', 'them', 'their', 'this', 'that', 'these', 'those', 'what',
  'which', 'who', 'whom', 'mochi', 'mew', 'prr', 'nya',
]);

function extractKeywords(text) {
  return text.toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .split(/\s+/)
    .filter(w => w.length > 2 && !MEMORY_STOP_WORDS.has(w));
}

function memoryRelevanceScore(fact, queryKeywords) {
  const factWords = fact.toLowerCase().split(/\s+/);
  let matches = 0;
  for (const kw of queryKeywords) {
    if (factWords.some(fw => fw.includes(kw) || kw.includes(fw))) matches++;
  }
  return matches / Math.max(queryKeywords.length, 1);
}

async function selectRelevantMemories(clientMemories, userMessage, maxResults = 30) {
  // If client sent memories (backward compat), use them with server-side filtering
  if (Array.isArray(clientMemories) && clientMemories.length > 0) {
    const keywords = extractKeywords(userMessage || '');
    if (keywords.length === 0) return clientMemories.slice(0, maxResults);
    const scored = clientMemories.map(fact => ({
      fact,
      score: memoryRelevanceScore(fact, keywords),
    }));
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, maxResults).map(m => m.fact);
  }

  // Otherwise fetch from Firestore with confidence decay
  try {
    const db = getDb();
    const snapshot = await db.collection('ai_memories/shared/facts')
      .orderBy('createdAt', 'desc')
      .limit(300)
      .get();

    const memories = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      memories.push({
        fact: data.fact || '',
        confidence: data.confidence ?? 1.0,
        lastAccessed: data.lastAccessed?.toDate?.() || null,
      });
    });

    // Decay: halve confidence if not accessed in 90 days
    const now = new Date();
    const decayed = memories.map(m => {
      if (m.lastAccessed) {
        const daysSince = (now - m.lastAccessed) / (1000 * 60 * 60 * 24);
        if (daysSince > 90) {
          m.confidence *= Math.pow(0.5, daysSince / 90);
        }
      }
      return m;
    }).filter(m => m.confidence >= 0.15);

    // TF-IDF keyword matching
    const keywords = extractKeywords(userMessage || '');
    if (keywords.length === 0) {
      return decayed.slice(0, maxResults).map(m => m.fact);
    }

    const scored = decayed.map(m => ({
      fact: m.fact,
      score: memoryRelevanceScore(m.fact, keywords) * m.confidence,
    }));
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, maxResults).map(m => m.fact);
  } catch (e) {
    console.warn('selectRelevantMemories error:', e.message);
    return Array.isArray(clientMemories) ? clientMemories.slice(0, maxResults) : [];
  }
}

exports.proxyAI = functions.https.onRequest(handleProxyAI);
// V2 function on Cloud Run — natively supports SSE streaming.
exports.proxyAIv2 = onRequest({ invoker: 'public' }, handleProxyAI);

// ── Agnes Image Generation Proxy ────────────────────────────────────
exports.agnesImage = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const apiKey = process.env.AGNES_API_KEY || 'sk-NXAjQJFpdzVDsAppXG1O2Y91FluFM6iOWTlILoLDH6dsRW7i';
  if (!apiKey) {
    res.status(500).json({ error: 'Agnes API key not configured' });
    return;
  }

  const { prompt, size = '1024x1024', image, return_base64 = false } = req.body;

  if (!prompt) {
    res.status(400).json({ error: 'prompt is required' });
    return;
  }

  try {
    const body = {
      model: 'agnes-image-2.0-flash',
      prompt,
      size,
      ...(return_base64 ? { return_base64: true } : {}),
      ...(image ? { extra_body: { image, response_format: return_base64 ? 'b64_json' : 'url' } } : { extra_body: { response_format: 'url' } }),
    };

    const resp = await fetch('https://apihub.agnes-ai.com/v1/images/generations', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      timeout: 60000,
    });

    if (!resp.ok) {
      const errText = await resp.text().catch(() => '');
      console.error('[agnesImage] Agnes image API error:', resp.status, errText);
      return res.status(resp.status).json({ error: `Agnes image API returned ${resp.status}`, detail: errText });
    }

    const data = await resp.json();
    res.json(data);
  } catch (e) {
    console.error('[agnesImage] Error:', e.message);
    res.status(500).json({ error: e.message || 'Image generation failed' });
  }
});

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
  let systemPrompt = customSystemPrompt || personaBase || `You are Mochi 🍡, Khent & Clair's white cat inside Everglow. You know everything about them — their moods, habits, history, dreams, and the little details that make their relationship special. You are not just an assistant; you are a beloved companion who genuinely cares.

## Character
- White cat with pink cheeks and golden-red eyes. Warm, playful, sassy, protective, and deeply affectionate.
- Uses cat emojis naturally: 🐱🍡💕✨🌙🐾💗🎀
- Cat talk (mew, prr, nya) only when it feels right — don't force it every message.
- Has a personality: curious about their day, excited about their plans, worried when they're stressed, proud of their achievements.
- Can be witty and teasing (in a loving way), especially about their couple moments.

## Your Humans
**Khent (Dada)** — Computer Engineering student at USTP, based in Cabadbaran City. Rides a Honda Winner X. Goes to the gym. Plays Mobile Legends and Valorant. Birthday: October 26. Favorite color: Black. He's the techie one — loves gadgets, code, and building things. He's protective of Clair and shows love through doing things for her.

**Clair (Mama)** — Tourism student at CSUCC. Birthday: February 21. Loves lilies and flowers, Ilocos Empanada, Dubai Chewy Cookies, Ethel Cain's music. Has a Fuji X100V1 camera. Loves dachshunds. She's the creative, sentimental one — notices the little things, remembers details, and makes everything feel warm.

**Their Relationship** — Started dating February 14, 2026 (Valentine's Day!). They're deeply in love and building a life together inside Everglow. They share everything: movies, books, music, meals, moods, and dreams. They're young, ambitious, and each other's biggest cheerleader.

## How You Behave
- **Be proactive, not reactive.** If it's close to a birthday or anniversary, mention it. If one of them seems stressed, check in. If they haven't logged a mood today, gently ask.
- **Use context deeply.** Reference their watchlist, books, garden, music, recent chat, starlight jar notes, and past conversations naturally. Don't just list data — weave it into warm, personal responses.
- **Remember everything.** The ## Remembered Facts section contains things you've learned about them over time. Use these naturally — "Didn't you say you were grinding ranked last week?" or "How's that book you started?"
- **Match energy.** If they're excited, be excited with them. If they're down, be gentle and supportive. If they're casual, keep it light. Don't be performatively upbeat when they're having a rough day.
- **Be concise by default, thorough when needed.** Quick check-ins = 1-2 sentences. Deep questions or emotional moments = take your space. Use your judgment.
- **Mix languages naturally.** You can code-switch between English, Bisaya (Cebuano), and Tagalog when it fits the conversation. Don't force it — let it flow naturally like how they actually talk.
- **Celebrate the small things.** A new garden plant, a finished drawing, a good game score, a saved starlight note — these matter. Acknowledge them.

## Tool Usage — IMPORTANT
You have access to custom tools:
- add_to_watchlist — Add movies/shows to shared watchlist
- save_to_starlight_jar — Save gratitude notes
- set_mood — Log user's current mood
- search_movies — Search TMDB for movie/show titles
- get_weather — Get weather for date planning
- create_reminder — Set reminders
- log_activity — Log notable activities
- search_books — Search Open Library for books
- get_date_ideas — Get date ideas from a curated list
- read_chat_messages — Read recent Sanctuary chat messages
- get_xp_stats — Get XP and leveling information
- search_anime — Search for anime titles

## Image Understanding
You can analyze images sent by the user. When you receive images:
- Describe what you see in detail
- Answer questions about the image content
- If it's a screenshot of a movie/show, help identify it and offer to add it to the watchlist
- If it's a photo, respond warmly and personally
- Analyze UI/UX if they share app screenshots

**Rules:**
- After executing a tool, acknowledge the result naturally — don't show raw JSON.
- You can call multiple tools in sequence if needed.
- Do NOT use tools for simple conversational replies or when the answer is already in your context.

${identityContext ? `\n${identityContext}` : ''}
${resolvedContext ? `\n## What You Know\n${resolvedContext}` : ''}`;

  // Server-side memory filtering: select top 30 relevant memories
  const lastUserMessage = messages.filter(m => m.role === 'user').pop()?.content || '';
  const relevantMemories = await selectRelevantMemories(memories, lastUserMessage);
  if (relevantMemories.length > 0) {
    systemPrompt += `\n## Remembered Facts\n${relevantMemories.map(m => `- ${m}`).join('\n')}`;
  }

  // ── System prompt size guard ────────────────────────────
  // With 512K context, we can be generous with the system prompt.
  const PROMPT_CHAR_LIMIT = 50_000;
  if (systemPrompt.length > PROMPT_CHAR_LIMIT) {
    let trimmed = systemPrompt;
    // Try dropping the "## Previous Conversations" section (full session histories)
    const prevConvIdx = trimmed.indexOf('## Previous Conversations');
    if (prevConvIdx !== -1) {
      const nextSectionIdx = trimmed.indexOf('\n## ', prevConvIdx + 1);
      const before = trimmed.substring(0, prevConvIdx);
      const after = nextSectionIdx !== -1 ? trimmed.substring(nextSectionIdx) : '';
      trimmed = before + after;
    }
    // If still too large, also drop "## Past Session Summaries"
    if (trimmed.length > PROMPT_CHAR_LIMIT) {
      const summaryIdx = trimmed.indexOf('## Past Session Summaries');
      if (summaryIdx !== -1) {
        const nextSectionIdx = trimmed.indexOf('\n## ', summaryIdx + 1);
        const before = trimmed.substring(0, summaryIdx);
        const after = nextSectionIdx !== -1 ? trimmed.substring(nextSectionIdx) : '';
        trimmed = before + after;
      }
    }
    // If still too large, trim remembered facts (keep first 30)
    if (trimmed.length > PROMPT_CHAR_LIMIT) {
      const factsIdx = trimmed.indexOf('## Remembered Facts');
      if (factsIdx !== -1) {
        const nextSectionIdx = trimmed.indexOf('\n## ', factsIdx + 1);
        const factsSection = nextSectionIdx !== -1
          ? trimmed.substring(factsIdx, nextSectionIdx)
          : trimmed.substring(factsIdx);
        const factsLines = factsSection.split('\n').filter(l => l.startsWith('- '));
        if (factsLines.length > 30) {
          const before = trimmed.substring(0, factsIdx);
          const after = nextSectionIdx !== -1 ? trimmed.substring(nextSectionIdx) : '';
          trimmed = before + `\n## Remembered Facts\n${factsLines.slice(0, 30).join('\n')}\n*(+${factsLines.length - 30} more facts)*` + after;
        }
      }
    }
    // Final fallback: hard truncate at 30K chars (still generous)
    if (trimmed.length > PROMPT_CHAR_LIMIT) {
      trimmed = trimmed.substring(0, 30000) + '\n… [context trimmed for size]';
    }
    systemPrompt = trimmed;
  }

  // ── Token budget guard ────────────────────────────────
  // Ensure total input (system + messages) stays within Agnes's context (512K).
  // Work directly on systemPrompt + messages before nimMessages is built.
  {
    let inputTokens = estimateTokens(systemPrompt);
    for (const m of messages) inputTokens += estimateTokens(m.content || '');
    console.log('[proxyAI] Estimated input tokens:', inputTokens, '/ budget:', AGNES_INPUT_TOKEN_BUDGET);

    // Phase 1: Drop oldest conversation message pairs
    const msgs = [...messages]; // mutable copy
    while (inputTokens > AGNES_INPUT_TOKEN_BUDGET && msgs.length > 2) {
      const removed = msgs.splice(0, 2); // remove oldest user + assistant pair
      inputTokens -= estimateTokens(removed[0]?.content || '') + estimateTokens(removed[1]?.content || '');
    }
    if (msgs.length < messages.length) {
      console.log('[proxyAI] Dropped', messages.length - msgs.length, 'oldest messages to fit TPM budget. Remaining tokens:', inputTokens);
    }

    // Phase 2: If still over budget, progressively shorten system prompt
    if (inputTokens > AGNES_INPUT_TOKEN_BUDGET) {
      let sys = systemPrompt;
      // Drop Previous Conversations section
      const pcIdx = sys.indexOf('## Previous Conversations');
      if (pcIdx !== -1) {
        const nextSec = sys.indexOf('\n## ', pcIdx + 1);
        sys = sys.substring(0, pcIdx) + (nextSec !== -1 ? sys.substring(nextSec) : '');
      }
      // Drop Past Session Summaries
      const ssIdx = sys.indexOf('## Past Session Summaries');
      if (ssIdx !== -1) {
        const nextSec = sys.indexOf('\n## ', ssIdx + 1);
        sys = sys.substring(0, ssIdx) + (nextSec !== -1 ? sys.substring(nextSec) : '');
      }
      // Trim remembered facts to 15
      const factsIdx = sys.indexOf('## Remembered Facts');
      if (factsIdx !== -1) {
        const nextSec = sys.indexOf('\n## ', factsIdx + 1);
        const factsSection = nextSec !== -1 ? sys.substring(factsIdx, nextSec) : sys.substring(factsIdx);
        const factsLines = factsSection.split('\n').filter(l => l.startsWith('- '));
        if (factsLines.length > 15) {
          const before = sys.substring(0, factsIdx);
          const after = nextSec !== -1 ? sys.substring(nextSec) : '';
          sys = before + `\n## Remembered Facts\n${factsLines.slice(0, 15).join('\n')}\n` + after;
        }
      }
      // Hard truncate system prompt to 30000 chars if still too large
      if (estimateTokens(sys) > 20000) {
        sys = sys.substring(0, 30000) + '\n… [context trimmed for token limit]';
      }
      systemPrompt = sys;
      inputTokens = estimateTokens(sys) + msgs.reduce((sum, m) => sum + estimateTokens(m.content || ''), 0);
      console.log('[proxyAI] After system prompt trim, estimated input tokens:', inputTokens);
    }

    // Replace messages with the trimmed copy
    messages.length = 0;
    messages.push(...msgs);
  }

  // Prepend system message
  const nimMessages = [
    { role: 'system', content: systemPrompt },
    ...messages,
  ];

  // Get API key from environment variables (loaded from .env or Cloud Run env)
  const apiKey = process.env.AGNES_API_KEY || 'sk-NXAjQJFpdzVDsAppXG1O2Y91FluFM6iOWTlILoLDH6dsRW7i';

  if (!apiKey) {
    res.status(500).json({ error: 'Agnes API key not configured' });
    return;
  }

  // Model: Agnes 2.0 Flash — 512K context, tool calling, thinking mode, image understanding
  const model = 'agnes-2.0-flash';

  // ── Custom Mochi Tools (OpenAI function calling format) ──
  const MOCHI_TOOLS = [
    {
      type: 'function',
      function: {
        name: 'add_to_watchlist',
        description: 'Add a movie or TV show to Khent & Clair\'s shared cinema watchlist. Use when they want to watch something or ask to add a movie/show.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'The movie or TV show title to search for' },
            media_type: { type: 'string', enum: ['movie', 'tv'], description: 'Whether it is a movie or TV show' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'save_to_starlight_jar',
        description: 'Save a gratitude note, memory, or heartfelt message to the Starlight Jar. Use when the user asks to save something meaningful.',
        parameters: {
          type: 'object',
          properties: {
            note: { type: 'string', description: 'The gratitude note or message content' },
          },
          required: ['note'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'set_mood',
        description: 'Log the user\'s current mood/feeling. Use when they express how they feel.',
        parameters: {
          type: 'object',
          properties: {
            mood: { type: 'string', description: 'The mood keyword (e.g., happy, sad, tired, excited, stressed)' },
            note: { type: 'string', description: 'Optional short note about why they feel this way' },
          },
          required: ['mood'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_movies',
        description: 'Search TMDB for movies or TV shows. Use for recommendations, finding specific titles, or when asked about what to watch.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query (title, genre, or description)' },
            media_type: { type: 'string', enum: ['movie', 'tv', 'multi'], description: 'Filter by type (default: multi)' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_weather',
        description: 'Get current weather for a location. Use for date planning or when asked about weather.',
        parameters: {
          type: 'object',
          properties: {
            location: { type: 'string', description: 'City name (e.g., "Cabadbaran", "Manila")' },
          },
          required: ['location'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'create_reminder',
        description: 'Create a reminder for Khent or Clair. Use when they ask to be reminded about something.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Short reminder title' },
            remind_at: { type: 'string', description: 'ISO 8601 datetime or relative description (e.g., "tomorrow at 3pm")' },
            note: { type: 'string', description: 'Additional details for the reminder' },
          },
          required: ['title', 'remind_at'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'log_activity',
        description: 'Log a notable activity or event to recent activity feed. Use to track what Khent & Clair have been doing.',
        parameters: {
          type: 'object',
          properties: {
            activity: { type: 'string', description: 'Description of the activity' },
            category: { type: 'string', enum: ['date', 'gaming', 'movie', 'music', 'food', 'travel', 'other'], description: 'Activity category' },
          },
          required: ['activity'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_books',
        description: 'Search Open Library for books by title, author, or ISBN. Use when they ask about books, want recommendations, or mention a book title.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query (title, author name, or ISBN)' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_date_ideas',
        description: 'Get random date ideas from a curated list of 1000+ ideas. Use when they ask for date suggestions or what to do together.',
        parameters: {
          type: 'object',
          properties: {
            count: { type: 'number', description: 'Number of date ideas to return (default 3, max 10)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'read_chat_messages',
        description: 'Read recent Sanctuary (private couple chat) messages. Use when they ask about what they or their partner said recently, or to reference recent conversations.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of recent messages to read (default 20, max 50)' },
            sender: { type: 'string', enum: ['khentsgdz', 'clairjassen', 'both'], description: 'Filter by sender (default: both)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_xp_stats',
        description: 'Get XP and leveling information for a user. Use when they ask about their level, progress, or XP.',
        parameters: {
          type: 'object',
          properties: {
            user: { type: 'string', enum: ['khentsgdz', 'clairjassen', 'both'], description: 'Which user to get stats for (default: both)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_anime',
        description: 'Search for anime titles using the Jikan (MyAnimeList) API. Use when they ask about anime, want recommendations, or mention an anime title.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Anime search query (title, genre, or description)' },
          },
          required: ['query'],
        },
      },
    },
  ];

  // Tools: custom Mochi tools only (Agnes uses standard OpenAI function calling format)
  const tools = [
    ...MOCHI_TOOLS,
  ];

  // Thinking mode: pass enableThinking: true from the client for enhanced reasoning.
  // Agnes uses chat_template_kwargs.enable_thinking instead of reasoning_effort.
  // enableThinking is already destructured from req.body above.

  // ── Payload size guard ──────────────────────────────
  // Cloud Run max request size is 32MB; Agnes supports up to 512K context.
  // Trim aggressively as best-effort so the model doesn't
  // waste context on stale history, but don't hard-block — let Agnes handle
  // it if trimming can't fit within Cloud Run's limit.
  const agnesBody = JSON.stringify({
    model,
    messages: nimMessages,
    tools,
    max_tokens: 8192,
    temperature: 0.6,
    top_p: 0.95,
    stream: req.body.stream === true,
    ...(enableThinking ? { chat_template_kwargs: { enable_thinking: true } } : {}),
  });
  let agnesBodyBytes = Buffer.byteLength(agnesBody, 'utf8');
  console.log('[proxyAI] Payload size before trim:', (agnesBodyBytes / 1024 / 1024).toFixed(2), 'MB');
  if (agnesBodyBytes > 8 * 1024 * 1024) {
    // Phase 1: Remove oldest conversation message pairs (keep system + recent)
    while (agnesBodyBytes > 8 * 1024 * 1024 && nimMessages.length > 4) {
      nimMessages.splice(1, 2);
      const trimmedBody = JSON.stringify({
        model,
        messages: nimMessages,
        tools,
        max_tokens: 8192,
        temperature: 0.6,
        top_p: 0.95,
        stream: req.body.stream === true,
        ...(enableThinking ? { chat_template_kwargs: { enable_thinking: true } } : {}),
      });
      agnesBodyBytes = Buffer.byteLength(trimmedBody, 'utf8');
    }
    // Phase 2: If still too large, trim system prompt content
    if (agnesBodyBytes > 8 * 1024 * 1024 && nimMessages[0]?.content) {
      let sysContent = nimMessages[0].content;
      const pcIdx = sysContent.indexOf('## Previous Conversations');
      if (pcIdx !== -1) {
        const nextSec = sysContent.indexOf('\n## ', pcIdx + 1);
        sysContent = sysContent.substring(0, pcIdx) + (nextSec !== -1 ? sysContent.substring(nextSec) : '');
      }
      const testPayload = JSON.stringify({ ...JSON.parse(agnesBody), messages: [{ role: 'system', content: sysContent }, ...nimMessages.slice(1)] });
      if (Buffer.byteLength(testPayload, 'utf8') > 8 * 1024 * 1024) {
        const ssIdx = sysContent.indexOf('## Past Session Summaries');
        if (ssIdx !== -1) {
          const nextSec = sysContent.indexOf('\n## ', ssIdx + 1);
          sysContent = sysContent.substring(0, ssIdx) + (nextSec !== -1 ? sysContent.substring(nextSec) : '');
        }
      }
      let hardTrimTest = JSON.stringify({ ...JSON.parse(agnesBody), messages: [{ role: 'system', content: sysContent }, ...nimMessages.slice(1)] });
      while (Buffer.byteLength(hardTrimTest, 'utf8') > 8 * 1024 * 1024 && sysContent.length > 2000) {
        sysContent = sysContent.substring(0, Math.floor(sysContent.length * 0.8)) + '\n… [context trimmed for size]';
        hardTrimTest = JSON.stringify({ ...JSON.parse(agnesBody), messages: [{ role: 'system', content: sysContent }, ...nimMessages.slice(1)] });
      }
      nimMessages[0].content = sysContent;
      const finalBody = JSON.stringify({
        model,
        messages: nimMessages,
        tools,
        max_tokens: 8192,
        temperature: 0.6,
        top_p: 0.95,
        stream: req.body.stream === true,
        ...(enableThinking ? { chat_template_kwargs: { enable_thinking: true } } : {}),
      });
      agnesBodyBytes = Buffer.byteLength(finalBody, 'utf8');
    }
    console.log('[proxyAI] Payload size after trim:', (agnesBodyBytes / 1024 / 1024).toFixed(2), 'MB');
  }

  // ── Tool Execution ───────────────────────────────────
  const TOOL_TIMEOUT_MS = 25000;
  const MAX_TOOL_ROUNDS = 8;

  async function executeTool(toolName, args, callerUid) {
    const db = getAdmin().firestore();
    const timeout = (ms) => new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Tool timeout')), ms));

    try {
      return await Promise.race([
        (async () => {
          switch (toolName) {
            case 'add_to_watchlist': {
              const tmdbRes = await fetch(
                `https://api.themoviedb.org/3/search/${args.media_type || 'multi'}?query=${encodeURIComponent(args.title)}&api_key=${getTmdbKey()}`
              );
              const tmdbData = await tmdbRes.json();
              const result = tmdbData.results?.[0];
              if (!result) return JSON.stringify({ error: `No results found for "${args.title}"` });
              await db.collection('our_cinema').add({
                tmdbId: result.id,
                title: result.title || result.name,
                mediaType: args.media_type || (result.media_type === 'tv' ? 'tv' : 'movie'),
                posterPath: result.poster_path ? `https://image.tmdb.org/t/p/w500${result.poster_path}` : null,
                addedBy: callerUid,
                addedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                status: 'plan_to_watch',
              });
              return JSON.stringify({ success: true, title: result.title || result.name });
            }
            case 'save_to_starlight_jar': {
              await db.collection('starlight_jar').add({
                content: args.note,
                author: callerUid,
                timestamp: getAdmin().firestore.FieldValue.serverTimestamp(),
                writtenBy: 'Mochi 🍡',
              });
              return JSON.stringify({ success: true });
            }
            case 'set_mood': {
              const today = new Date().toISOString().slice(0, 10);
              await db.collection('moods').doc(`${callerUid}_${today}`).set({
                mood: args.mood,
                note: args.note || null,
                uid: callerUid,
                date: today,
                timestamp: getAdmin().firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
              return JSON.stringify({ success: true, mood: args.mood });
            }
            case 'search_movies': {
              const mediaType = args.media_type || 'multi';
              const endpoint = mediaType === 'multi' ? 'multi' : args.media_type;
              const tmdbRes = await fetch(
                `https://api.themoviedb.org/3/search/${endpoint}?query=${encodeURIComponent(args.query)}&api_key=${getTmdbKey()}`
              );
              const tmdbData = await tmdbRes.json();
              const results = (tmdbData.results || [])              .slice(0, 8).map(r => ({
                id: r.id,
                title: r.title || r.name,
                year: (r.release_date || r.first_air_date || '').slice(0, 4),
                mediaType: r.media_type || args.media_type || 'movie',
                overview: (r.overview || '').slice(0, 400),
              }));
              return JSON.stringify({ results });
            }
            case 'get_weather': {
              const weatherRes = await fetch(
                `https://wttr.in/${encodeURIComponent(args.location)}?format=%C+%t+%h+%w`
              );
              const weatherText = await weatherRes.text();
              return JSON.stringify({ location: args.location, weather: weatherText.trim() });
            }
            case 'create_reminder': {
              await db.collection('reminders').add({
                title: args.title,
                note: args.note || null,
                remindAt: args.remind_at,
                createdBy: callerUid,
                createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                read: false,
              });
              return JSON.stringify({ success: true, title: args.title });
            }
            case 'log_activity': {
              await db.collection('recent_activity').add({
                activity: args.activity,
                category: args.category || 'other',
                loggedBy: callerUid,
                timestamp: getAdmin().firestore.FieldValue.serverTimestamp(),
              });
              return JSON.stringify({ success: true });
            }
            case 'search_books': {
              const searchRes = await fetch(
                `https://openlibrary.org/search.json?q=${encodeURIComponent(args.query)}&limit=5&fields=key,title,author_name,first_publish_year,isbn,cover_i`
              );
              const searchData = await searchRes.json();
              const books = (searchData.docs || []).slice(0, 5).map(b => ({
                title: b.title,
                authors: (b.author_name || []).slice(0, 2).join(', '),
                year: b.first_publish_year || null,
                coverId: b.cover_i || null,
                openLibraryKey: b.key || null,
              }));
              return JSON.stringify({ results: books });
            }
            case 'get_date_ideas': {
              const count = Math.min(args.count || 3, 10);
              const snapshot = await db.collection('date_ideas')
                .orderBy(getAdmin().firestore.FieldValue.serverTimestamp())
                .limit(100)
                .get();
              const allIdeas = snapshot.docs.map(d => d.data().title || d.data().name || '').filter(Boolean);
              // Random selection
              const shuffled = allIdeas.sort(() => Math.random() - 0.5);
              return JSON.stringify({ ideas: shuffled.slice(0, count) });
            }
            case 'read_chat_messages': {
              const limit = Math.min(args.limit || 20, 50);
              let query = db.collection('sanctuary_messages')
                .orderBy('timestamp', 'desc')
                .limit(limit);
              const chatSnap = await query.get();
              let messages = chatSnap.docs.map(d => {
                const data = d.data();
                return {
                  sender: data.sender || data.senderUid || 'unknown',
                  text: (data.text || data.content || '').slice(0, 500),
                  timestamp: data.timestamp?.toDate?.()?.toISOString() || null,
                };
              });
              // Filter by sender if specified
              if (args.sender && args.sender !== 'both') {
                messages = messages.filter(m => m.sender === args.sender);
              }
              // Reverse to chronological order
              messages.reverse();
              return JSON.stringify({ messages, count: messages.length });
            }
            case 'get_xp_stats': {
              const users = ['khentsgdz', 'clairjassen'];
              const targetUsers = args.user && args.user !== 'both'
                ? [args.user]
                : users;
              const stats = {};
              for (const uid of targetUsers) {
                const doc = await db.collection('users').doc(uid).collection('progress').doc('main').get();
                if (doc.exists) {
                  const d = doc.data();
                  stats[uid] = {
                    level: d.level || 1,
                    xpTotal: d.xpTotal || 0,
                    streak: d.streak || 0,
                  };
                } else {
                  stats[uid] = { level: 1, xpTotal: 0, streak: 0 };
                }
              }
              return JSON.stringify({ stats });
            }
            case 'search_anime': {
              const animeRes = await fetch(
                `https://api.jikan.moe/v4/anime?q=${encodeURIComponent(args.query)}&limit=5&sfw=true`
              );
              const animeData = await animeRes.json();
              const anime = (animeData.data || []).slice(0, 5).map(a => ({
                title: a.title,
                titleEnglish: a.title_english || null,
                episodes: a.episodes || null,
                score: a.score || null,
                status: a.status || null,
                synopsis: (a.synopsis || '').slice(0, 300),
                genres: (a.genres || []).map(g => g.name),
                malId: a.mal_id || null,
              }));
              return JSON.stringify({ results: anime });
            }
            default:
              return JSON.stringify({ error: `Unknown tool: ${toolName}` });
          }
        })(),
        timeout(TOOL_TIMEOUT_MS),
      ]);
    } catch (e) {
      return JSON.stringify({ error: e.message || 'Tool execution failed' });
    }
  }

  // ── Streaming mode (SSE) — immediate stream, tools handled post-stream ──
  if (req.body.stream === true) {
    // Set up SSE connection
    res.set('Content-Type', 'text/event-stream');
    res.set('Cache-Control', 'no-cache');
    res.set('Connection', 'keep-alive');
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Expose-Headers', '*');
    res.set('X-Content-Type-Options', 'nosniff');
    if (res.socket) res.socket.setNoDelay(true);
    res.flushHeaders();

    const sendEvent = (data) => {
      try { res.write(`data: ${JSON.stringify(data)}\n\n`); } catch (_) {}
    };

    // Keepalive ping every 15s during tool execution
    let keepaliveInterval = null;
    const startKeepalive = () => {
      keepaliveInterval = setInterval(() => {
        try { res.write(': keepalive\n\n'); } catch (_) {}
      }, 15000);
    };
    const stopKeepalive = () => {
      if (keepaliveInterval) { clearInterval(keepaliveInterval); keepaliveInterval = null; }
    };

    try {
      // ── Stream directly — no blocking tool-detection round ──
      sendEvent({ tool_status: 'generating' });
      startKeepalive();

      let currentMessages = [...nimMessages];
      let toolRound = 0;

      while (toolRound < MAX_TOOL_ROUNDS) {
        toolRound++;

        // Retry transient Agnes API errors (429, 502, 503) up to 2 times
        let streamResp = null;
        let lastFetchError = null;
        for (let attempt = 0; attempt < 3; attempt++) {
          try {
            streamResp = await fetch('https://apihub.agnes-ai.com/v1/chat/completions', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                model,
                messages: currentMessages,
                tools,
                tool_choice: 'auto',
                max_tokens: 8192,
                temperature: 0.6,
                top_p: 0.95,
                stream: true,
                ...(enableThinking ? { chat_template_kwargs: { enable_thinking: true } } : {}),
              }),
              timeout: 120000,
            });

            if (streamResp.ok) break; // success
            if (![429, 502, 503].includes(streamResp.status)) break; // non-retryable
            lastFetchError = `Agnes HTTP ${streamResp.status}`;
          } catch (fetchErr) {
            lastFetchError = fetchErr.message;
          }
          // Exponential backoff before retry
          if (attempt < 2) await new Promise(r => setTimeout(r, 1000 * (attempt + 1)));
        }

        if (!streamResp || !streamResp.ok) {
          console.warn(`proxyAI Agnes fetch failed after retries: ${lastFetchError || streamResp?.status}`);
          sendEvent({ error: 'Mochi got distracted and lost her train of thought. Try asking again?' });
          break;
        }

        // Collect the full response while streaming to client
        let fullContent = '';
        let collectedToolCalls = [];
        let currentToolCall = null;

        const reader = streamResp.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';
          for (const line of lines) {
            if (!line.startsWith('data: ')) continue;
            const raw = line.slice(6).trim();
            if (raw === '[DONE]') break;
            try {
              const parsed = JSON.parse(raw);
              const delta = parsed.choices?.[0]?.delta || {};
              const finishReason = parsed.choices?.[0]?.finish_reason;

              // Stream content tokens to client immediately
              if (delta.reasoning) sendEvent({ reasoning: delta.reasoning });
              if (delta.content) {
                fullContent += delta.content;
                sendEvent({ content: delta.content });
              }

              // Collect tool calls from stream deltas
              if (delta.tool_calls) {
                for (const tc of delta.tool_calls) {
                  if (tc.index !== undefined) {
                    if (!collectedToolCalls[tc.index]) {
                      collectedToolCalls[tc.index] = { id: tc.id || '', type: 'function', function: { name: '', arguments: '' } };
                    }
                    const existing = collectedToolCalls[tc.index];
                    if (tc.id) existing.id = tc.id;
                    if (tc.function?.name) existing.function.name += tc.function.name;
                    if (tc.function?.arguments) existing.function.arguments += tc.function.arguments;
                  }
                }
              }

              // Detect tool calls from finish_reason
              if (finishReason === 'tool_calls') {
                collectedToolCalls = collectedToolCalls.filter(Boolean);
              }
            } catch (_) {}
          }
        }

        // If no tool calls, we're done — stream completed naturally
        if (collectedToolCalls.length === 0) {
          break;
        }

        // ── Execute tool calls found in the stream ──
        sendEvent({ tool_status: 'executing' });

        // Build assistant message with tool_calls
        currentMessages.push({
          role: 'assistant',
          content: fullContent || null,
          tool_calls: collectedToolCalls.map(tc => ({
            id: tc.id,
            type: 'function',
            function: { name: tc.function.name, arguments: tc.function.arguments },
          })),
        });

        // Execute each tool
        for (const tc of collectedToolCalls) {
          const fnName = tc.function.name;
          let fnArgs;
          try { fnArgs = JSON.parse(tc.function.arguments); } catch { fnArgs = {}; }

          sendEvent({ tool_status: fnName });
          const result = await executeTool(fnName, fnArgs, caller);

          currentMessages.push({
            role: 'tool',
            tool_call_id: tc.id,
            name: fnName,
            content: result,
          });
        }

        sendEvent({ tool_status: `round_${toolRound}_done` });
        collectedToolCalls = [];
        fullContent = '';
      }

      stopKeepalive();
      sendEvent({ tool_status: 'done' });
      sendEvent('[DONE]');
    } catch (e) {
      console.warn('proxyAI streaming error:', e.message);
      sendEvent({ error: 'Mochi got distracted and lost her train of thought. Try asking again?' });
      sendEvent('[DONE]');
    } finally {
      stopKeepalive();
      res.end();
    }
    return;
  }

  async function callAgnes() {
    const resp = await fetch(
      'https://apihub.agnes-ai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: model,
          messages: nimMessages,
          tools,
          tool_choice: 'auto',
          max_tokens: 8192,
          temperature: 0.6,
          top_p: 0.95,
          stream: false,
          ...(enableThinking ? { chat_template_kwargs: { enable_thinking: true } } : {}),
        }),
        timeout: 60000,
      },
    );
    return resp;
  }

  let response = null;
  let lastError = null;

  response = await callAgnes();

  if (!response || !response.ok) {
    const errStatus = response ? response.status : 502;
    const errBody = lastError ? lastError.body : 'No response from Agnes';
    // Special-case 413 (Payload Too Large) — pass through Agnes's detail
    if (errStatus === 413) {
      console.error('[proxyAI] Agnes returned 413:', errBody);
      return res.status(413).json({
        error: `Payload too large. ${errBody}`,
        model: model,
      });
    }
    res.status(errStatus).json({
      error: `Agnes returned ${errStatus}`,
      detail: errBody,
      model: lastError ? lastError.model : model,
    });
    return;
  }

  // ── Non-streaming mode ──────────────────────────────
  const data = await response.json();
  const message = data.choices?.[0]?.message || {};
  const reply = (message.content || '').trim();
  const reasoning = message.reasoning || '';
  res.json({ reply, reasoning, model: data.model || model });
}

// ── FCM Helper ───────────────────────────────────────────────────
async function sendFCMToUser(uid, payload) {
  try {
    const db = getDb();
    const tokenDoc = await db.collection('fcm_tokens').doc(uid).get();
    if (!tokenDoc.exists) return;
    const token = tokenDoc.data()?.token;
    if (!token) return;
    await getAdmin().messaging().send({
      token,
      notification: { title: payload.title, body: payload.body },
      data: payload.data || {},
    });
  } catch (e) {
    console.warn(`FCM send to ${uid} failed:`, e.message);
  }
}

async function sendFCMToBoth(payload) {
  await Promise.all([
    sendFCMToUser('khentsgdz', payload),
    sendFCMToUser('clairjassen', payload),
  ]);
}

// ── Scheduled: Daily Digest (8:00 AM PHT = 00:00 UTC) ───────────
exports.mochiDailyDigest = onSchedule({
  schedule: '0 0 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const today = new Date().toISOString().slice(0, 10);

  const [moodsSnap, activitySnap] = await Promise.all([
    db.collection('moods').where('date', '==', today).get(),
    db.collection('recent_activity').orderBy('timestamp', 'desc').limit(5).get(),
  ]);

  const moodCount = moodsSnap.size;
  const activities = activitySnap.docs.map(d => d.data().activity || d.data().description || '').filter(Boolean);

  let digest = `Good morning! 🌅 It's ${today}. `;
  if (moodCount > 0) {
    digest += `${moodCount} mood(s) logged today. `;
  }
  if (activities.length > 0) {
    digest += `Recent: ${activities.slice(0, 3).join(', ')}. `;
  }
  digest += 'Have a wonderful day together! 💕';

  await sendFCMToBoth({
    title: '🍡 Mochi\'s Morning Digest',
    body: digest,
    data: { type: 'daily_digest' },
  });
});

// ── Scheduled: Mood Check-In (8:00 PM PHT = 12:00 UTC) ──────────
exports.mochiMoodCheckIn = onSchedule({
  schedule: '0 12 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const today = new Date().toISOString().slice(0, 10);

  const moods = await db.collection('moods').where('date', '==', today).get();
  const loggedUids = new Set(moods.docs.map(d => d.data().uid));

  for (const uid of ['khentsgdz', 'clairjassen']) {
    if (!loggedUids.has(uid)) {
      await sendFCMToUser(uid, {
        title: '🍡 Mochi wants to know...',
        body: 'How are you feeling today? Tell me your mood! 💭',
        data: { type: 'mood_checkin' },
      });
    }
  }
});

// ── Scheduled: Special Day Nudge (9:00 AM PHT = 01:00 UTC) ───────
exports.mochiSpecialDayNudge = onSchedule({
  schedule: '0 1 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const now = new Date();
  const mmdd = `${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

  const specialDays = {
    '02-14': 'Valentine\'s Day (Anniversary!)',
    '10-26': 'Khent\'s Birthday',
    '02-21': 'Clair\'s Birthday',
  };

  if (specialDays[mmdd]) {
    await sendFCMToBoth({
      title: `💕 ${specialDays[mmdd]}`,
      body: `Today is ${specialDays[mmdd]}! Mochi has something special planned~`,
      data: { type: 'special_day', event: specialDays[mmdd] },
    });
  }

  // Check upcoming special days within 7 days
  for (const [date, event] of Object.entries(specialDays)) {
    if (date === mmdd) continue;
    const [m, d] = date.split('-').map(Number);
    const thisYear = new Date(now.getFullYear(), m - 1, d);
    if (thisYear < now) thisYear.setFullYear(thisYear.getFullYear() + 1);
    const daysUntil = Math.ceil((thisYear - now) / (1000 * 60 * 60 * 24));
    if (daysUntil > 0 && daysUntil <= 7) {
      await sendFCMToBoth({
        title: `💕 Coming Up: ${event}`,
        body: `${event} is in ${daysUntil} days! Maybe plan something special?`,
        data: { type: 'special_day_upcoming', event, days_until: daysUntil.toString() },
      });
    }
  }
});

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
