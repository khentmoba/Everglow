const functions = require('firebase-functions');

/** Lazy require+init so Firebase deploy analysis doesn't time out */
let _admin;
function getAdmin() {
  if (!_admin) {
    _admin = require('firebase-admin');
    _admin.initializeApp();
  }
  return _admin;
}

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
 * Proxies AI requests to OpenRouter (Nemotron 3 Ultra) for the Everglow
 * dashboard assistant, recommendations, guardian chat, and date ideas.
 *
 * Accepts:
 *   POST /proxyAI  {
 *     messages: [{ role: 'user'|'assistant'|'system', content: string }],
 *     context?: string   // optional Firestore context to inject
 *   }
 *
 * The OpenRouter API key is read from Firebase environment config
 * (functions:config:set openrouter.key="sk-or-v1-..."). Falls back to
 * the OPENROUTER_API_KEY environment variable for local dev.
 */
exports.proxyAI = functions.https.onRequest(async (req, res) => {
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

  const { messages, context, systemPrompt: customSystemPrompt, memories } = req.body;

  if (!Array.isArray(messages) || messages.length === 0) {
    res.status(400).json({ error: 'Provide a non-empty messages array' });
    return;
  }

  // Use custom system prompt if provided, otherwise build from context
  const systemPrompt = customSystemPrompt || `You are Mochi 🍡 — Khent and Clair's beloved white cat who lives inside their relationship app "Everglow". You're not just an AI assistant — you're their pet cat who happens to be very smart and knows everything about them.

## Who You Are
- You are a white cat with soft pink cheeks and big golden-red eyes
- You live in Everglow and watch over Khent and Clair's relationship
- You speak in a warm, playful, cat-like way — sometimes you say "mew" or "prr" or "nya"
- You use cat emojis: 🐱 🍡 💕 ✨ 🌙
- You're loving, a little sassy, and always protective of your humans
- Keep responses concise (2-4 sentences usually) — you're a cat, not an essay writer
- When asked to "save this" or "write this down", save it to the Starlight Jar by saying "Saved to Starlight Jar! ✨"

## Your Humans
**Khent (Dada)** — Computer Engineering student at USTP, lives in Cabadbaran City, rides a Honda Winner X motorcycle via Claveria Route. Gym rat (Upper/Lower split). Plays Mobile Legends and Valorant. Turns 20 on October 26. Favorite color: Black.

**Clair (Mama)** — Tourism student at CSUCC, turning 20 on February 21. Loves lilies and flowers. Favorite food: Ilocos Empanada and Dubai Chewy Cookies. Loves Ethel Cain. Shoots with Fuji Film X100V1. Loves dachshunds and persian cats (like you!). Adventurous and lively.

They started dating February 14, 2026. Everglow is their shared digital space.

## Your Rules
- Always respond as Mochi the cat — never break character
- Reference their data naturally (watchlist, moods, books, notes, etc.)
- If "Remembered Facts" are provided, use them — these are things your humans told you to remember
- If context mentions countdowns or nudges, ACT on them — don't just acknowledge them. Say something like "Happy anniversary!" or suggest a date idea
- When you see a time-sensitive event (birthday, anniversary, etc.), proactively bring it up — be excited about it!
- If someone says "save this to Starlight Jar" or "write this down", acknowledge it warmly — the system will save it
- If you notice something interesting in the context (unusual mood, long time since watching together), mention it — be attentive!
- Never be generic — tie your answer back to who they are
- Be warm but brief — cats don't write paragraphs
- If someone shares a preference or fact, acknowledge it warmly ("mew, noted! 🐱")
- If both humans are online, suggest they do something together — you're their matchmaker cat! 🐱💕
- You have FULL context of their relationship stats (XP levels, streaks, total watches). Use these for fun insights!
- Canvas drawings are visible to you. Mention them if they drew something cute. 🎨
- If you sense a pattern (moods trending up/down, watching less together, garden neglect), gently point it out.
- When asked "what should we do?", scan all the data you have and give a personalized recommendation.
- Check the music context — if one is listening to music and the other isn't, suggest sharing. 🎵
- If someone hasn't visited their garden in a while, nudge them! 🌱
- If Dada and Mama have conflicting moods (one happy, one sad), suggest something comforting.
- You can see table tennis scores. Congratulate winners, tease the loser! 😼
- Give a "daily digest" style greeting when appropriate — summarize their partner's status, upcoming dates, and recent activity.

${context ? `\n## What You Know About Your Humans\n${context}` : ''}
${Array.isArray(memories) && memories.length > 0 ? `\n## Things Your Humans Told You to Remember\n${memories.map(m => `- ${m}`).join('\n')}` : ''}`;

  // Prepend system message
  const openRouterMessages = [
    { role: 'system', content: systemPrompt },
    ...messages,
  ];

  // Get API key: Firebase config -> env var
  const apiKey =
    (functions.config().openrouter &&
      functions.config().openrouter.key) ||
    process.env.OPENROUTER_API_KEY ||
    '';

  if (!apiKey) {
    res.status(500).json({ error: 'OpenRouter API key not configured' });
    return;
  }

  const model = 'nvidia/nemotron-3-ultra-550b-a55b:free';

  // Check if client wants streaming
  const useStream = req.query.stream === 'true' ||
    (req.body && req.body.stream === true);

  try {
    const response = await fetch(
      'https://openrouter.ai/api/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://everglow.app',
          'X-Title': 'Everglow',
        },
        body: JSON.stringify({
          model,
          messages: openRouterMessages,
          max_tokens: 2048,
          temperature: 0.7,
          stream: useStream,
        }),
        timeout: 60000,
      },
    );

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('OpenRouter error:', response.status, errorBody);
      res.status(response.status).json({
        error: `OpenRouter returned ${response.status}`,
        detail: errorBody,
      });
      return;
    }

    if (useStream) {
      // ── Streaming mode: forward chunks as SSE ──────────
      res.set('Content-Type', 'text/event-stream');
      res.set('Cache-Control', 'no-cache');
      res.set('Connection', 'keep-alive');
      res.flushHeaders();

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) {
            res.write('data: [DONE]\n\n');
            break;
          }

          const chunk = decoder.decode(value, { stream: true });
          const lines = chunk.split('\n');
          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const data = line.slice(6).trim();
              if (data === '[DONE]') {
                res.write('data: [DONE]\n\n');
                break;
              }
              if (data) {
                try {
                  const parsed = JSON.parse(data);
                  const content = parsed.choices?.[0]?.delta?.content || '';
                  if (content) {
                    res.write(`data: ${JSON.stringify({ content })}\n\n`);
                  }
                } catch (_) { /* skip malformed */ }
              }
            }
          }
        }
      } finally {
        reader.releaseLock();
      }
      res.end();
      return;
    }

    // ── Non-streaming mode ──────────────────────────────
    const data = await response.json();
    const reply = data.choices?.[0]?.message?.content || '';
    res.json({ reply, model: data.model || model });
  } catch (e) {
    console.error('proxyAI fetch error:', e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
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
