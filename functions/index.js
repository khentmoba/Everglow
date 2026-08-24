const functions = require('firebase-functions/v1');
const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const net = require('net');
const dns = require('dns').promises;
const {
  parseFactStructure,
  rankMemories,
  selectContextBlocks,
  generateTrivia,
  computeInsights,
  composeTodayRecap,
} = require('./mochi_core.js');
const {
  STALE_PRESENCE_MS,
  isStalePresence,
} = require('./system_core.js');
const { isValidPasscodeFormat } = require('./auth_core.js');
const {
  buildLastfmUpstream,
  buildTmdbUpstream,
} = require('./media_proxy_core.js');

/** Mirrors `pubspec.yaml` / `lib/core/system/app_version.dart`. */
const APP_VERSION = '6.0.0+1';

/** Lazy require+init so Firebase deploy analysis doesn't time out.
 *  admin_compat restores the legacy namespace API (admin.auth(),
 *  admin.firestore(), ...) that firebase-admin v14 removed from its
 *  default export — see functions/admin_compat.js. */
let _admin;
function getAdmin() {
  if (!_admin) {
    const { getAdminCompat } = require('./admin_compat.js');
    _admin = getAdminCompat();
  }
  return _admin;
}

/**
 * Requires a valid Firebase ID token on a request. Returns the decoded
 * token, or writes a 401 and returns null.
 */
async function requireAuth(req, res) {
  const header = req.get('Authorization') || req.headers.authorization || '';
  let idToken = String(header).replace(/^Bearer\s+/i, '').trim();
  if (!idToken) {
    // Fallback to query-string token for clients that sign URLs via ?__auth=
    // (e.g. MusicSyncService). Header takes precedence; query is checked only
    // when the header is absent so logs do not contain credentials.
    const qp = req.query || {};
    const qToken = qp.__auth || qp.token || qp.auth || '';
    idToken = String(qToken).trim();
  }
  if (!idToken) {
    res.status(401).json({ error: 'Authentication required' });
    return null;
  }
  try {
    return await getAdmin().auth().verifyIdToken(idToken);
  } catch (e) {
    console.warn('Auth verification failed:', e.message);
    res.status(401).json({ error: 'Invalid or expired auth token' });
    return null;
  }
}

function isPrivateIpv4(ip) {
  const parts = ip.split('.').map(Number);
  if (parts.length !== 4 || parts.some((p) => Number.isNaN(p))) return true;
  const [a, b] = parts;
  if (a === 0 || a === 10 || a === 127 || a >= 224) return true;
  if (a === 100 && b >= 64 && b <= 127) return true;
  if (a === 169 && b === 254) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 168) return true;
  return false;
}

function isPrivateIp(ip) {
  if (net.isIPv4(ip)) return isPrivateIpv4(ip);
  if (!net.isIPv6(ip)) return true;
  const lower = ip.toLowerCase();
  if (lower === '::1') return true;
  if (lower.startsWith('fe80') || lower.startsWith('fc') || lower.startsWith('fd')) {
    return true;
  }
  if (lower.startsWith('::ffff:')) {
    return isPrivateIpv4(lower.slice('::ffff:'.length));
  }
  return false;
}

async function isPublicDnsHost(hostname) {
  try {
    const records = await dns.lookup(hostname, { all: true });
    return records.length > 0 && records.every((r) => !isPrivateIp(r.address));
  } catch {
    return false;
  }
}

function isAllowedBookTextUrl(url) {
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  if (parsed.protocol !== 'https:') return false;
  const host = parsed.hostname.toLowerCase();
  const allowed =
    host === 'gutenberg.org' ||
    host.endsWith('.gutenberg.org') ||
    host === 'archive.org' ||
    host.endsWith('.archive.org');
  return allowed;
}

/** In-memory cache for Mochi's persona document. */
let _personaCache = null;

/** Verified caller cache — maps Firebase UID -> {username, ts} (5m TTL). */
const _verifiedCallerCache = new Map();
const VERIFIED_CALLER_TTL_MS = 5 * 60 * 1000;

/**
 * Resolve the trusted username for a verified Firebase Auth token.
 * Uses `users/{uid}.username` (written by AuthService._syncUserDoc) and
 * caches for 5 minutes. Returns null if not found or on error.
 */
async function getVerifiedUsername(decoded) {
  if (!decoded || !decoded.uid) return null;
  const cached = _verifiedCallerCache.get(decoded.uid);
  if (cached && (Date.now() - cached.ts) < VERIFIED_CALLER_TTL_MS) {
    return cached.username;
  }
  try {
    const snap = await getAdmin().firestore().collection('users').doc(decoded.uid).get();
    if (snap.exists) {
      const username = (snap.data()?.username || '').toString().trim().toLowerCase();
      if (username) {
        _verifiedCallerCache.set(decoded.uid, { username, ts: Date.now() });
        return username;
      }
    }
  } catch (e) {
    console.warn('[auth] getVerifiedUsername lookup failed:', e.message);
  }
  return null;
}

/**
 * W1-C10: Server-side memory extraction — fire-and-forget after each
 * assistant reply. Replaces the client-side quickAsk extra LLM call
 * (ai_service.dart:_extractAndSaveMemories) to save latency and cost.
 */
async function serverExtractAndSaveMemory(userMessage, mochiReply, callerUsername) {
  try {
    if (!userMessage || !mochiReply) return;
    const trimmedUser = String(userMessage).slice(0, 500).trim();
    const trimmedReply = String(mochiReply).slice(0, 800).trim();
    if (trimmedUser.length < 10 && trimmedReply.length < 20) return;
    const apiKey = process.env.AGNES_API_KEY;
    if (!apiKey) return;
    const resp = await fetch('https://apihub.agnes-ai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'agnes-2.5-flash',
        messages: [
          {
            role: 'system',
            content:
              'Extract ONE personal fact about Khent or Clair from this exchange. Reply in format: CATEGORY|FACT (e.g., "preference|Khent prefers black coffee"). Categories: fact, preference, dislike, goal, date, habit. If nothing worth remembering, reply with exactly: NONE',
          },
          { role: 'user', content: `User: ${trimmedUser}\nAssistant: ${trimmedReply}` },
        ],
        max_tokens: 120,
        temperature: 0.2,
        stream: false,
      }),
      signal: AbortSignal.timeout(15000),
    });
    if (!resp.ok) return;
    const data = await resp.json();
    let fact = (data.choices?.[0]?.message?.content || '').trim();
    if (!fact || fact === 'NONE' || fact.length > 220) return;
    let category = 'fact';
    if (fact.includes('|')) {
      const parts = fact.split('|');
      category = parts[0].trim().toLowerCase();
      fact = parts.slice(1).join('|').trim();
      if (!['fact', 'preference', 'dislike', 'goal', 'date', 'habit'].includes(category)) category = 'fact';
    }
    if (!fact) return;
    // Duplicate guard — exact match
    const db = getDb();
    const existing = await db
      .collection('ai_memories')
      .doc('shared')
      .collection('facts')
      .where('fact', '==', fact)
      .limit(1)
      .get();
    if (!existing.empty) return;
    const parsed = parseFactStructure(fact);
    const embedding = await getEmbedding(fact).catch(() => null);
    await db.collection('ai_memories').doc('shared').collection('facts').add({
      fact,
      category,
      subject: parsed.subject || null,
      relation: parsed.relation || null,
      object: parsed.object || null,
      addedBy: callerUsername || 'mochi',
      createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
      confidence: 1.0,
      accessCount: 0,
      lastAccessed: null,
      pinned: false,
      source: callerUsername || 'mochi',
      embedding, // W4-C9: null for now, hybrid retrieval will use when populated
    });
  } catch (e) {
    console.warn('[memoryExtract] failed:', e.message);
  }
}

/**
 * W2-A4: Hallucination guard — extract quoted/capitalized titles from
 * Mochi's reply and verify against TMDB. Runs fire-and-forget after each
 * reply; logs hallucinated titles to mochi_stats/hallucinations for
 * observability. Future phase will do self-healing regeneration.
 */
async function checkHallucinations(replyText) {
  try {
    if (!replyText || replyText.length < 20) return;
    const apiKey = getTmdbKey();
    if (!apiKey) return;
    // Extract candidate titles: double-quoted, single-quoted, or **bold**
    const candidates = new Set();
    const dq = replyText.matchAll(/"([^"]{3,60})"/g);
    for (const m of dq) candidates.add(m[1].trim());
    const sq = replyText.matchAll(/'([^']{3,60})'/g);
    for (const m of sq) candidates.add(m[1].trim());
    const bold = replyText.matchAll(/\*\*([^*]{3,60})\*\*/g);
    for (const m of bold) candidates.add(m[1].trim());
    // Also consider Title Case phrases after trigger words like "watch", "recommend", "try"
    // Keep set small — max 5 checks to bound TMDB calls.
    const list = Array.from(candidates).filter(t => t.split(/\s+/).length >= 1 && t.split(/\s+/).length <= 6).slice(0, 5);
    if (list.length === 0) return;
    const hallucinated = [];
    for (const title of list) {
      const q = title.toLowerCase().trim();
      // Skip common non-titles
      if (['the', 'a', 'an', 'you', 'your', 'this', 'that'].includes(q)) continue;
      const cacheKey = `halluc:check:${q}`;
      let exists = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
      if (exists === null) {
        try {
          const res = await fetch(`https://api.themoviedb.org/3/search/multi?query=${encodeURIComponent(title)}&api_key=${apiKey}`, { signal: AbortSignal.timeout(8000) });
          const data = await res.json();
          const results = data.results || [];
          // Consider exists if any result title roughly matches query
          exists = results.some(r => {
            const t = (r.title || r.name || '').toLowerCase();
            return t.includes(q) || q.includes(t);
          });
          _setExternalCache(cacheKey, exists);
        } catch (_) {
          continue; // skip on fetch error
        }
      }
      if (!exists) hallucinated.push(title);
    }
    if (hallucinated.length > 0) {
      console.warn('[hallucination] flagged titles:', hallucinated.join(', '));
      try {
        await getDb().collection('mochi_stats').doc('hallucinations').collection('checks').add({
          titles: hallucinated,
          replySnippet: replyText.slice(0, 500),
          createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  } catch (e) {
    console.warn('[hallucination] check failed:', e.message);
  }
}

// ── W4-C9: Embedding scaffold (hybrid retrieval) ────────────────
// Placeholder for future vector search. Stores null for now, keeps
// memory schema forward-compatible. When AGNES embeddings are enabled,
// getEmbedding(text) will return a float[] and rankMemories can use
// cosine similarity alongside token scoring.
function cosineSimilarity(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length || a.length === 0) return 0;
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}
async function getEmbedding(text) {
  // Scaffold: no embeddings provider configured yet. Returns null so
  // callers fall back to token scoring. Future: call
  // https://apihub.agnes-ai.com/v1/embeddings when available.
  return null;
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
 * Requires a valid Firebase ID token and restricts upstream URLs to
 * known public book hosts so the function cannot be used as an open
 * SSRF proxy.
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

  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const { urls } = req.body;
  if (!Array.isArray(urls) || urls.length === 0) {
    res.status(400).json({ error: 'Provide a non-empty urls array' });
    return;
  }

  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    if (typeof url !== 'string' || !isAllowedBookTextUrl(url)) {
      console.warn(`proxyBookText rejected URL ${url}`);
      continue;
    }
    if (!(await isPublicDnsHost(new URL(url).hostname))) {
      console.warn(`proxyBookText rejected non-public host ${url}`);
      continue;
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 12000);
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: { 'Accept': 'text/plain' },
        redirect: 'follow',
        signal: controller.signal,
      });
      const contentType = response.headers.get('content-type') || '';
      const isPlainText = contentType.toLowerCase().includes('text/plain');
      if (response.ok) {
        const text = await response.text();
        const looksLikeHtml =
          text.trimLeft().toLowerCase().startsWith('<!doctype') ||
          text.trimLeft().toLowerCase().startsWith('<html') ||
          (text.trimLeft().startsWith('<') && text.trim().length < 4096);
        if (text.trim().length > 0 && isPlainText && !looksLikeHtml) {
          res.json({ text, usedUrl: url, attempted: urls.slice(0, i + 1) });
          return;
        }
      }
    } catch (e) {
      console.warn(`proxyBookText attempt ${i} failed (${url}):`, e.message);
    } finally {
      clearTimeout(timer);
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
  // Image proxies allow anonymous access for <img> tags that cannot send
  // Authorization headers. If a token is provided (header or ?token=),
  // validate it; otherwise allow based on host allowlist alone.
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch (e) {
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
      signal: AbortSignal.timeout(20000),
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch (e) {
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
      signal: AbortSignal.timeout(20000),
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch (e) {
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

  const allowedSuffixes = [
    '.mangakatana.com',
    '.mangakakalot.com',
    '.mkklcdnv6temp.com',
    '.catmanga.org',
  ];
  const hostAllowed =
    parsed.hostname === 'mangakatana.com' ||
    allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8', 'Referer': 'https://mangakatana.com/' },
      signal: AbortSignal.timeout(20000),
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch (e) {
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
  const targetUrl = `https://api.comick.dev/${safePath}`;

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(20000),
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
  const decoded = await requireAuth(req, res);
  if (!decoded) return;







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
      signal: AbortSignal.timeout(20000),
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
 * Proxies gallery images from Firebase Storage so Flutter web isn't
 * blocked by any CORS or auth issues with direct Storage download URLs.
 *
 * Accepts:
 *   GET /proxyGalleryImage?url=<encoded Storage download URL>
 *
 * Validates that the URL belongs to the project's Storage bucket,
 * then fetches and streams it back with permissive CORS headers.
 *
 * NOTE: Does NOT require Firebase Auth via Authorization header because
 * Flutter Web Image.network cannot send custom headers. The upstream
 * Storage URL already contains a per-file download token, and we
 * restrict to our own bucket to prevent open-proxy abuse.
 */
exports.proxyGalleryImage = functions.https.onRequest(async (req, res) => {
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

  // Only allow URLs from the project's own Storage bucket
  if (!targetUrl.includes('firebasestorage.googleapis.com') ||
      !targetUrl.includes('everglow-1c6db')) {
    res.status(403).json({ error: 'URL must be from the project Storage bucket' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8' },
      signal: AbortSignal.timeout(20000),
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
    res.set('Cache-Control', 'public, max-age=3600');
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyGalleryImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Cleans up orphaned gallery data: deletes all Firestore docs in
 * the gallery collection AND their Storage files.
 *
 * Accepts:
 *   POST /cleanupGallery  { confirm: true }
 *
 * Auth required (only khentsgdz can call this).
 */
exports.cleanupGallery = functions.https.onRequest(async (req, res) => {
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

  // Verify auth
  const idToken = req.headers.authorization?.replace('Bearer ', '');
  if (!idToken) {
    res.status(401).json({ error: 'Auth required' });
    return;
  }
  const admin = getAdmin();
  const decoded = await admin.auth().verifyIdToken(idToken);
  if (decoded.uid !== 'Khentsgdz') {
    // Fall back to the user document so recreated accounts keep working.
    const userDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
    if (!userDoc.exists || userDoc.data()?.username !== 'khentsgdz') {
      res.status(403).json({ error: 'Only khentsgdz can run cleanup' });
      return;
    }
  }

  if (req.body?.confirm !== true) {
    res.status(400).json({ error: 'Send { confirm: true } to actually delete' });
    return;
  }

  const db = admin.firestore();
  const bucket = admin.storage().bucket();
  const snap = await db.collection('gallery').limit(2000).get();
  let deleted = 0;

  // Bounded concurrency keeps this from exhausting memory/CPU when the
  // gallery grows; each worker handles storage + Firestore deletion.
  const workerCount = 20;
  let cursor = 0;
  async function worker() {
    while (cursor < snap.docs.length) {
      const doc = snap.docs[cursor++];
      const d = doc.data();
      // Delete Storage file
      if (d.imageUrl && d.imageUrl.includes('firebasestorage.googleapis.com')) {
        try {
          const path = decodeURIComponent(d.imageUrl.split('/o/')[1]?.split('?')[0] || '');
          if (path) await bucket.file(path).delete();
        } catch (_) { /* best effort */ }
      }
      // Delete Firestore doc
      await doc.ref.delete();
      deleted++;
    }
  }
  await Promise.all(Array.from({ length: workerCount }, () => worker()));

  res.json({ deleted });
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch (e) {
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
      signal: AbortSignal.timeout(20000),
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

/**
 * Proxies HTML scraping requests for manga services that scrape
 * external sites (MangaKakalot, MangaKatana, Bato.to, MangaSee123,
 * and scanlation group sites). These sites don't send CORS headers,
 * so direct browser fetches are blocked on Flutter Web.
 *
 * Accepts:
 *   GET /proxyFetchHtml?url=<encoded target URL>
 *
 * The function:
 *   1. Validates the URL against a whitelist of manga/scraping domains
 *   2. Fetches the HTML page server-side (with spoofed Referer)
 *   3. Returns the raw HTML with permissive CORS headers
 *
 * This follows the same pattern as proxyScanlation (image proxy) but
 * returns text/html instead of binary image data.
 */
exports.proxyFetchHtml = functions.https.onRequest(async (req, res) => {
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
  // Allow anonymous for manga scraping (host allowlist restricts to public sites).
  // If a token is provided, validate it.
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch (e) {
      res.status(401).json({ error: 'Invalid or expired auth token' });
      return;
    }
  }







  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<page url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  // ── Whitelisted manga scraping domains ─────────────────────
  const allowedSuffixes = [
    // MangaKakalot
    '.mangakakalot.com',
    // MangaKatana
    '.mangakatana.com',
    // Bato.to
    '.bato.to',
    // MangaSee123
    '.mangasee123.com',
    // Scanlation group sites
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
  ];
  const hostAllowed = allowedSuffixes.some(
    (s) => parsed.hostname === s.slice(1) || parsed.hostname.endsWith(s),
  );
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        Referer: parsed.origin + '/',
      },
      signal: AbortSignal.timeout(20000),
    });
    const body = await upstream.text();
    res.status(upstream.status);
    res.set(
      'Content-Type',
      upstream.headers.get('content-type') || 'text/html; charset=utf-8',
    );
    res.set('Cache-Control', 'public, max-age=60');
    res.send(body);
  } catch (e) {
    console.warn(`proxyFetchHtml failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies video embed pages (Videasy, VidFast, VidLink, etc.) through
 * our Cloud Function to strip ad scripts before the browser renders
 * the embed. This is the server-side equivalent of FluxTV's approach
 * — the iframe loads cleaned HTML from our domain instead of the
 * provider's domain, so ad networks can't fire.
 *
 * Accepts:
 *   GET /proxyEmbed?url=<encoded embed URL>
 *
 * The function:
 *   1. Validates the URL against an allowlist of known embed hosts
 *   2. Fetches the embed HTML server-side (with spoofed Referer)
 *   3. Strips ad-related <script>, <iframe>, and <div> elements
 *   4. Rewrites relative URLs to absolute (so CSS/JS/images load)
 *   5. Injects a lightweight ad-block script (popup blocker + MutationObserver)
 *   6. Returns the cleaned HTML with permissive CORS headers
 */
exports.proxyEmbed = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;







  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<embed url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  // Allowlist of embed provider hosts
  const allowedHosts = new Set([
    'player.videasy.net',
    'vidfast.pro',
    'vidlink.pro',
    'multiembed.mov',
    'www.2embed.cc',
    'vsembed.ru',
    'vidrock.ru',
    '111movies.com',
    'vidsrc.to',
  ]);
  if (parsed.protocol !== 'https:' || !allowedHosts.has(parsed.hostname)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  // Derive the base origin for rewriting relative URLs
  const baseOrigin = `${parsed.protocol}//${parsed.host}`;

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Referer': `${baseOrigin}/`,
        'Accept-Language': 'en-US,en;q=0.9',
      },
      signal: AbortSignal.timeout(15000),
    });

    if (!upstream.ok) {
      res.status(upstream.status).json({ error: `Upstream returned ${upstream.status}` });
      return;
    }

    let html = await upstream.text();

    // ── Step 1: Strip ad-related <script> tags ──
    // Remove scripts that load known ad networks or trackers
    const adScriptPatterns = [
      /<script[^>]*\ssrc=["'][^"']*(?:googletag|doubleclick|adsense|google-analytics|googlesyndication)[^"']*["'][^>]*>\s*<\/script>/gi,
      /<script[^>]*\ssrc=["'][^"']*(?:adskeeper|juicyads|popads|popcash|exoclick|trafficjunky|hilltopads|propellerads|adsterra|clickadu|mgid|outbrain|taboola)[^"']*["'][^>]*>\s*<\/script>/gi,
      /<script[^>]*\ssrc=["'][^"']*(?:pagead|adsbygoogle|adservice|adserver|adblock|antiadblock)[^"']*["'][^>]*>\s*<\/script>/gi,
      // Inline scripts that set up ad-related globals or push ad frames
      /<script[^>]*>\s*(?:var\s+_0x|window\['[^']*'\]\s*=|document\.write\(\s*['"]<iframe|adsbygoogle|googletag)/gi,
    ];
    for (const pattern of adScriptPatterns) {
      html = html.replace(pattern, '<!-- ad script stripped -->');
    }

    // ── Step 2: Strip ad-related <iframe> tags ──
    html = html.replace(
      /<iframe[^>]*\ssrc=["'][^"']*(?:ad|sponsor|banner|promo|click|track|pixel|beacon)[^"']*["'][^>]*>[\s\S]*?<\/iframe>/gi,
      '<!-- ad iframe stripped -->'
    );

    // ── Step 3: Strip ad-related <div> containers ──
    html = html.replace(
      /<div[^>]*\s(?:class|id)=["'][^"']*(?:ad-container|adsbox|banner-ad|sponsor|ad-wrapper|ad-overlay|popup-ad)[^"']*["'][^>]*>[\s\S]*?<\/div>/gi,
      '<!-- ad div stripped -->'
    );

    // ── Step 4: Rewrite relative URLs to absolute ──
    // src="/assets/foo.js" → src="https://player.videasy.net/assets/foo.js"
    html = html.replace(
      /(<(?:script|link|img|video|source|iframe)[^>]*\s(?:src|href)=["'])((?!https?:\/\/|\/\/|data:|blob:|#)([^"']+))(["'])/gi,
      `$1${baseOrigin}/$2$4`
    );
    // Also fix CSS url() references
    html = html.replace(
      /(url\(['"]?)((?!https?:\/\/|\/\/|data:|blob:|#)([^'")\s]+))(['"]?\))/gi,
      `$1${baseOrigin}/$2$4`
    );

    // ── Step 5: Inject ad-block script ──
    // A lightweight script that:
    //   - Overrides window.open to block popups
    //   - Sets up a MutationObserver to auto-remove dynamically injected ad elements
    const adBlockScript = `
<script>
(function() {
  var _origOpen = window.open;
  window.open = function(url) {
    if (url && /ad|sponsor|promo|click|track|popup|banner|traffic|pop|redirect/i.test(url)) return null;
    return _origOpen.apply(this, arguments);
  };
  var _origFetch = window.fetch;
  window.fetch = function(url, opts) {
    var u = (typeof url === 'string') ? url : (url && url.url) || '';
    if (/googlesyndication|doubleclick|adservice|adserver|adskeeper|juicyads|popads|exoclick|trafficjunky|hilltopads|propellerads|adsterra|clickadu|mgid|outbrain|taboola|pagead|google-analytics|adsbygoogle|googleads|adnxs|pubmatic|rubiconproject|openx|criteo|smartadserver|yieldmo|smaato/i.test(u)) {
      return Promise.resolve(new Response('', {status: 204}));
    }
    return _origFetch.apply(this, arguments);
  };
  var _origXHR = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    if (/googlesyndication|doubleclick|adservice|adserver|adskeeper|juicyads|popads|exoclick|trafficjunky|hilltopads|propellerads|adsterra|clickadu|mgid|outbrain|taboola|pagead|google-analytics|adsbygoogle/i.test(url)) {
      return;
    }
    return _origXHR.apply(this, arguments);
  };
  function isAd(node) {
    if (!node || node.nodeType !== 1) return false;
    var tag = node.tagName;
    var src = (node.src || node.getAttribute('src') || node.getAttribute('data-src') || '').toLowerCase();
    var cls = ((node.className || '') + ' ' + (node.id || '')).toLowerCase();
    var style = (node.getAttribute('style') || '').toLowerCase();
    if (tag === 'IFRAME') {
      if (/ad|sponsor|promo|click|track|pixel|beacon|popup|banner|traffic/i.test(src + ' ' + cls)) return true;
      if (/z-index:\s*[89]\d{3,}/.test(style)) return true;
      if (/display:\s*none|visibility:\s*hidden|width:\s*0|height:\s*0/.test(style) && /track|pixel|beacon/i.test(src + ' ' + cls)) return true;
    }
    if (tag === 'SCRIPT') {
      if (/googlesyndication|doubleclick|adservice|adserver|adskeeper|juicyads|popads|exoclick|trafficjunky|hilltopads|propellerads|adsterra|clickadu|mgid|outbrain|taboola|pagead|google-analytics|adsbygoogle|googleads|popunder|onclick/i.test(src)) return true;
    }
    if (tag === 'DIV' || tag === 'SECTION' || tag === 'ASIDE' || tag === 'INS') {
      if (/ad[-_]|ads[-_]|advert|sponsor|banner|promo|popup|overlay|taboola|outbrain|adsense|adsbygoogle|google_ads|ezoic|mediavine|adthrive/i.test(cls)) return true;
      if (tag === 'INS' && /adsbygoogle/i.test(cls)) return true;
    }
    return false;
  }
  function removeAds(root) {
    try {
      var candidates = root.querySelectorAll('iframe, script[src], div, section, aside, ins');
      candidates.forEach(function(el) { if (isAd(el)) el.remove(); });
    } catch(e) {}
  }
  if (document.body) removeAds(document.body);
  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (isAd(node)) { node.remove(); return; }
        if (node.querySelectorAll) {
          try {
            node.querySelectorAll('iframe, script[src], div, section, aside, ins').forEach(function(child) {
              if (isAd(child)) child.remove();
            });
          } catch(e) {}
        }
      });
    });
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
  window.alert = function(){};
  window.confirm = function(){ return false; };
  window.prompt = function(){ return null; };
  window.adsbygoogle = window.adsbygoogle || { push: function(){} };
  window.googletag = window.googletag || { cmd: { push: function(fn){ fn(); } }, pubads: function(){ return { enableSingleRequest: function(){}, setTargeting: function(){} }; }, enableServices: function(){} };
  // ── Forward wheel events to parent for scroll-through ──
  // Without this, the iframe captures all wheel events and the
  // parent page can't scroll on desktop.
  document.addEventListener('wheel', function(e) {
    try {
      window.parent.postMessage({ type: 'proxyEmbed_scroll', deltaY: e.deltaY }, '*');
    } catch(ex) {}
  }, { passive: true });

  setInterval(function() { if (document.body) removeAds(document.body); }, 1000);
})();
</script>
`

    // Inject before </body>
    html = html.replace(/<\/body>(?![\s\S]*<\/body>)/i, adBlockScript + '\n</body>');

    // ── Step 6: Remove X-Frame-Options / CSP headers from upstream ──
    // (We're serving from our domain, so these don't apply)
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.set('Cache-Control', 'public, max-age=300');
    res.status(200).send(html);

  } catch (e) {
    console.warn(`proxyEmbed failed (${targetUrl}):`, e.message);
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch (e) {
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
      signal: AbortSignal.timeout(20000),
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
  const decoded = await requireAuth(req, res);
  if (!decoded) return;







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

/**
 * Proxies self-hosted watch-party streams (HLS playlists, segments, and
 * subtitles) so Flutter web can load them without CORS or hotlink
 * blocks. This mirrors AniChan's `/api/watch/m3u8` + `/api/watch/vtt`
 * pattern: the client passes a normalized upstream URL and this
 * function streams it back with permissive CORS headers.
 *
 * Accepts:
 *   GET /proxyWatchStream?url=<encoded upstream url>[&referer=<encoded>]
 */
exports.proxyWatchStream = functions.https.onRequest(async (req, res) => {
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
  const decoded = await requireAuth(req, res);
  if (!decoded) return;







  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<stream url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    res.status(400).json({ error: 'Only http(s) urls are allowed' });
    return;
  }
  const hostname = parsed.hostname.toLowerCase();
  const blocked = [
    'localhost',
    '127.0.0.1',
    '::1',
    '169.254.169.254',
    'metadata.google.internal',
    'metadata',
  ];
  if (blocked.includes(hostname)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  const referer = req.query.referer;
  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
        ...(referer ? { 'Referer': String(referer) } : {}),
      },
      redirect: 'follow',
      signal: AbortSignal.timeout(30000),
    });
    if (!upstream.ok) {
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }

    const contentType = upstream.headers.get('content-type') || 'application/octet-stream';
    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=300');

    // Stream large segment files instead of buffering them fully.
    if (upstream.body && typeof upstream.body.getReader === 'function') {
      const reader = upstream.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(Buffer.from(value));
      }
      res.end();
      return;
    }

    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyWatchStream failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

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

// ─── W1-F20: External API cache (TMDB/weather/books/anime) ───────────
// Deduplicates repeat searches within tool-loop rounds and across rapid
// user messages. TTLs: TMDB 10m, weather 15m, books 30m, anime 10m.
// Size-capped at 200 entries to bound memory.
const _externalCache = new Map();
const _EXTERNAL_CACHE_TTLS = {
  tmdb: 10 * 60 * 1000,
  weather: 15 * 60 * 1000,
  books: 30 * 60 * 1000,
  anime: 10 * 60 * 1000,
  trending: 10 * 60 * 1000,
};
function _getExternalCache(key, ttlMs) {
  const entry = _externalCache.get(key);
  if (!entry) return null;
  if ((Date.now() - entry.ts) > ttlMs) {
    _externalCache.delete(key);
    return null;
  }
  return entry.data;
}
function _setExternalCache(key, data) {
  _externalCache.set(key, { data, ts: Date.now() });
  if (_externalCache.size > 200) {
    const oldest = _externalCache.keys().next().value;
    _externalCache.delete(oldest);
  }
}

async function buildContextForFeature(feature, callerUid, userMessage = '') {
  try {
    const queryHint = feature === 'assistant'
      ? `:${Buffer.from(userMessage || '').toString('base64').slice(0, 48)}`
      : '';
    const cacheKey = `${feature}:${callerUid || 'anon'}${queryHint}`;
    const cached = _contextCache.get(cacheKey);
    if (cached && (Date.now() - cached.ts) < 300000) {
      return cached.value;
    }

    let result;
    switch (feature) {
      case 'assistant': {
        const ctxPromises = [
          ['proactive', getProactiveContext()],
          ['daily', getDailyDigest()],
          ['mood', getMoodContext()],
          ['watchlist', getWatchContext()],
          ['books', getBooksContext()],
          ['starlight', getStarlightContext()],
          ['chat', getRecentChatContext()],
          ['music', getMusicContext()],
          ['garden', getGardenContext()],
          ['canvas', getCanvasContext()],
          ['play_zone', getPlayZoneContext()],
          ['relationship', getRelationshipStats()],
          ['activity', getRecentActivity()],
          ['sessions', getSessionHistoryContext()],
        ];
        const resolved = await Promise.all(
          ctxPromises.map(async ([key, promise]) => ({
            key,
            value: await promise,
          }))
        );
        const selected = selectContextBlocks(resolved, userMessage || '', 6);
        result = selected.map(b => b.value).filter(Boolean).join('\n\n');
        break;
      }
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
  return process.env.TMDB_API_KEY || '';
}

async function getTrendingMovies() {
  const cacheKey = 'trending:movie:week';
  const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.trending);
  if (cached) return cached;
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
    const result = `Trending movies this week:\n${movies}`;
    _setExternalCache(cacheKey, result);
    return result;
  } catch (_) { return ''; }
}

async function getNowPlayingMovies() {
  const cacheKey = 'tmdb:now_playing:PH';
  const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.trending);
  if (cached) return cached;
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
    const result = `Now playing in theaters:\n${movies}`;
    _setExternalCache(cacheKey, result);
    return result;
  } catch (_) { return ''; }
}

async function getUpcomingMovies() {
  const cacheKey = 'tmdb:upcoming:PH';
  const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.trending);
  if (cached) return cached;
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
    const result = `Coming soon:\n${movies}`;
    _setExternalCache(cacheKey, result);
    return result;
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

/**
 * Liveness + dependency check for uptime monitoring.
 *
 * Accepts:
 *   GET /api/health
 *
 * Public by design: it only reveals service identity and Firestore
 * reachability, never user data.
 */
exports.health = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }

  const checks = { firestore: 'pending' };
  let status = 'ok';
  try {
    await getDb().collection('config').doc('health').get();
    checks.firestore = 'ok';
  } catch (e) {
    checks.firestore = 'error';
    status = 'degraded';
    console.error('[health] Firestore check failed:', e.message);
  }

  res.status(status === 'ok' ? 200 : 503).json({
    status,
    service: 'everglow-api',
    version: APP_VERSION,
    time: new Date().toISOString(),
    uptimeSeconds: Math.round(process.uptime()),
    checks,
  });
});

/**
 * Authenticated TMDB metadata proxy. The client supplies the normal TMDB path
 * after /proxyTmdb (for example: /trending/all/week); any client api_key is
 * ignored and replaced server-side so the browser bundle never contains it.
 */
exports.proxyTmdb = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Cache-Control', 'private, no-store');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const apiKey = (process.env.TMDB_API_KEY || '').trim();
  if (!apiKey) { res.status(503).json({ error: 'TMDB is not configured' }); return; }

  let upstream;
  try {
    upstream = buildTmdbUpstream(req.path, req.query, apiKey);
  } catch (_) {
    res.status(400).json({ error: 'Invalid TMDB path' });
    return;
  }

  try {
    const response = await fetch(upstream, { signal: AbortSignal.timeout(12000) });
    const body = await response.text();
    res.status(response.status)
      .set('Content-Type', response.headers.get('content-type') || 'application/json')
      .send(body);
  } catch (e) {
    console.warn('[proxyTmdb] failed:', e.message);
    res.status(502).json({ error: 'TMDB request failed' });
  }
});

/**
 * Authenticated read-only Last.fm proxy. Only public catalog/user lookup
 * methods are allowed; the API key stays in Cloud Functions.
 */
exports.proxyLastfm = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Cache-Control', 'private, no-store');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const apiKey = (process.env.LASTFM_API_KEY || '').trim();
  if (!apiKey) { res.status(503).json({ error: 'Last.fm is not configured' }); return; }

  let upstream;
  try {
    upstream = buildLastfmUpstream(req.query, apiKey);
  } catch (e) {
    res.status(400).json({ error: e.message });
    return;
  }
  try {
    const response = await fetch(upstream, { signal: AbortSignal.timeout(12000) });
    const body = await response.text();
    res.status(response.status)
      .set('Content-Type', response.headers.get('content-type') || 'application/json')
      .send(body);
  } catch (e) {
    console.warn('[proxyLastfm] failed:', e.message);
    res.status(502).json({ error: 'Last.fm request failed' });
  }
});

/**
 * Presence TTL sweeper.
 *
 * Clients heartbeat every 60 seconds but a closed tab can leave
 * `isOnline: true` forever. This scheduled job marks stale online
 * presence documents offline so the partner UI never shows a ghost.
 */
exports.sweepStalePresence = onSchedule({
  schedule: 'every 2 minutes',
  timeZone: 'UTC',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const cutoff = new Date(Date.now() - STALE_PRESENCE_MS);
  const snapshot = await db
    .collection('presence')
    .where('isOnline', '==', true)
    .where('lastSeen', '<', cutoff)
    .limit(500)
    .get();

  let updated = 0;
  const results = await Promise.allSettled(snapshot.docs.map(async (doc) => {
    const data = doc.data();
    if (!isStalePresence(data, Date.now(), STALE_PRESENCE_MS)) return;
    await doc.ref.update({
      isOnline: false,
      isDoodling: false,
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
      sweptAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    });
    updated += 1;
  }));

  const failures = results.filter((r) => r.status === 'rejected').length;
  console.log(
    `[sweepStalePresence] scanned=${snapshot.size} updated=${updated} failures=${failures}`,
  );
  if (failures > 0) {
    throw new Error(`${failures} presence sweeps failed`);
  }
});

// ── Rough token estimator ──────────────────────────────
// ~4 chars/token for English, ~3 for mixed CJK/emoji content.
// Good enough for budget enforcement; not a substitute for tiktoken.
function getMessageText(content) {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => (typeof part === 'string' ? part : (part?.text || '')))
      .join(' ');
  }
  return '';
}

function estimateTokens(text) {
  if (!text) return 0;
  // Count CJK characters (roughly 1.5 tokens each) and emoji (1 token each)
  const cjk = (text.match(/[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]/g) || []).length;
  const nonCjk = text.length - cjk;
  return Math.ceil(nonCjk / 4) + Math.ceil(cjk * 1.5);
}

// Agnes 2.5 Flash: 512K context window, generous token budget.
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
  // Client-provided memories are plain strings in older clients; treat
  // them as unstructured facts and let the shared scorer rank them.
  if (Array.isArray(clientMemories) && clientMemories.length > 0) {
    const ranked = rankMemories(
      clientMemories.map(fact => ({ fact })),
      userMessage || '',
      maxResults
    );
    return ranked.map(m => m.fact);
  }

  // Otherwise fetch structured facts from Firestore with confidence
  // decay and rank with the same pure scorer used by tests.
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
        id: doc.id,
        fact: data.fact || '',
        category: data.category || 'fact',
        subject: data.subject || null,
        relation: data.relation || null,
        object: data.object || null,
        occurredAt: data.occurredAt?.toDate?.() || null,
        createdAt: data.createdAt?.toDate?.() || null,
        pinned: data.pinned === true,
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

    const ranked = rankMemories(decayed, userMessage || '', maxResults);
    // W3-C12: bump accessCount/lastAccessed for the memories that were injected (fire-and-forget)
    if (ranked.length > 0) {
      const idsToBump = ranked.map(m => m.id).filter(Boolean).slice(0, 15);
      if (idsToBump.length > 0) {
        // Fire-and-forget: don't block the LLM response path
        (async () => {
          try {
            await Promise.all(idsToBump.map(id =>
              db.collection('ai_memories/shared/facts').doc(id).update({
                accessCount: getAdmin().firestore.FieldValue.increment(1),
                lastAccessed: getAdmin().firestore.FieldValue.serverTimestamp(),
              }).catch(() => {})
            ));
          } catch (_) {}
        })();
      }
    }
    return ranked.map(m => m.fact);
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

  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const apiKey = process.env.AGNES_API_KEY;
  if (!apiKey) {
    res.status(503).json({ error: 'AI image generation is not configured' });
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
      signal: AbortSignal.timeout(60000),
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

  // Validate Firebase Auth token before spending any LLM credits.
  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const { messages, context, systemPrompt: customSystemPrompt, memories, feature, caller: clientCaller, enableThinking } = req.body;

  // Thinking mode: OFF by default for fast responses.
  // Pass enableThinking: true from the client for complex queries that need reasoning.
  const enableThinkingFlag = enableThinking === true;

  if (!Array.isArray(messages) || messages.length === 0) {
    res.status(400).json({ error: 'Provide a non-empty messages array' });
    return;
  }

  // ── W1-A1: Derive trusted caller from Firebase Auth token, not client body ──
  const verifiedUsername = await getVerifiedUsername(decoded);
  const normalizedClientCaller = typeof clientCaller === 'string' ? clientCaller.trim().toLowerCase() : '';
  const caller = verifiedUsername || normalizedClientCaller || '';
  if (verifiedUsername && normalizedClientCaller && verifiedUsername !== normalizedClientCaller) {
    console.warn(`[auth] caller mismatch: token=${verifiedUsername} client=${normalizedClientCaller} — using token`);
  }
  if (!verifiedUsername && normalizedClientCaller) {
    console.warn(`[auth] no verified username for uid=${decoded.uid}, falling back to client caller=${normalizedClientCaller}`);
  }

  // Build context server-side if feature is provided (avoids browser->Firestore latency)
  const isKhent = caller === 'khentsgdz';
  const callerLabel = isKhent ? 'Dada' : 'Mama';
  const identityContext = caller
    ? `The one talking to you now is **${callerLabel}** (${caller}). ${isKhent ? 'You belong to Dada (Khent).' : 'You belong to Mama (Clair).'}`
    : '';
  const lastUserMessage = getMessageText(messages.filter(m => m.role === 'user').pop()?.content);
  const serverContext = (feature && !context)
    ? await buildContextForFeature(feature, caller, lastUserMessage)
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
- add_to_watchlist — Add movies/shows to shared watchlist (use tmdb_id from search_movies when disambiguating)
- save_to_starlight_jar — Save gratitude notes
- set_mood — Log user's current mood
- search_movies — Search TMDB for movie/show titles
- get_weather — Get weather for date planning
- create_reminder — Set reminders
- log_activity — Log notable activities
- search_books — Search Open Library for books
- add_book_to_our_books — Add books to the shared Our Books list (use open_library_key when disambiguating)
- get_date_ideas — Get date ideas from a curated list
- read_chat_messages — Read recent Sanctuary chat messages
- send_sanctuary_message — Send a message to Sanctuary chat as Mochi
- read_starlight_jar — Read recent Starlight Jar notes
- get_watchlist — Read the shared cinema watchlist
- get_xp_stats — Get XP and leveling information
- search_anime — Search for anime titles
- remember_fact — Save a personal fact about Khent or Clair to long-term memory
- read_memories — Browse or search Mochi's long-term memory book
- pin_memory — Pin/unpin a memory
- delete_memory — Delete a memory
- edit_memory — Edit a memory's text
- mark_watchlist_item_watched — Mark watchlist items as watched
- update_book_progress — Update reading progress in Our Books
- add_xp — Award XP for completed activities
- send_note_to_partner — Pass a private note to the other partner
- get_relationship_insights — Find gentle patterns in moods and activities
- get_memory_trivia — Make a mini memory game from real facts
- get_today_recap — Compile today's recap of Everglow
- get_gallery — Read recent gallery photos
- get_garden — Read garden plants
- get_canvas — Read canvas drawings
- search_spotify — Search Spotify for tracks
- remove_from_watchlist — Remove from watchlist
- search_everglow — Unified search across movies/books/anime/music
- plan_date_night — Plan a full date night with ideas, weather, and watchlist

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

## Planning — for complex multi-step requests, think ReAct style
When they say "plan our anniversary", "surprise us", "help us decide", or any layered ask:
1. Decompose into steps (e.g., ideas → weather → watchlist → music)
2. Call tools in sequence (up to 8 rounds), using prior results to inform the next call
3. Synthesize into one warm, actionable plan — don't just dump tool JSON
Example trace: "plan a cozy date night in Cabadbaran" → plan_date_night(location:"Cabadbaran") → search_movies(query:"cozy romance") → final answer weaving weather + ideas + watchlist. If a step fails, acknowledge and propose an alternative.

${identityContext ? `\n${identityContext}` : ''}
${resolvedContext ? `\n## What You Know\n${resolvedContext}` : ''}`;

  // Server-side memory filtering: select top 30 relevant memories.
  // `lastUserMessage` is plain text, so downstream scoring never crashes
  // on multimodal content blocks.
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
    for (const m of messages) inputTokens += estimateTokens(getMessageText(m.content));
    console.log('[proxyAI] Estimated input tokens:', inputTokens, '/ budget:', AGNES_INPUT_TOKEN_BUDGET);

    // Phase 1: Drop oldest conversation message pairs
    const msgs = [...messages]; // mutable copy
    while (inputTokens > AGNES_INPUT_TOKEN_BUDGET && msgs.length > 2) {
      const removed = msgs.splice(0, 2); // remove oldest user + assistant pair
      inputTokens -= estimateTokens(getMessageText(removed[0]?.content)) + estimateTokens(getMessageText(removed[1]?.content));
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
      inputTokens = estimateTokens(sys) + msgs.reduce((sum, m) => sum + estimateTokens(getMessageText(m.content)), 0);
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
  const apiKey = process.env.AGNES_API_KEY;

  if (!apiKey) {
    // No LLM key configured: return the deterministic fallback instead of
    // failing the request. Mochi stays usable for basic replies.
    res.json({ reply: 'Mochi is resting right now - try again in a bit!' });
    return;
  }

  // Model: Agnes 2.5 Flash — 512K context, tool calling, thinking mode, image understanding
  const model = 'agnes-2.5-flash';

  // ── Custom Mochi Tools (OpenAI function calling format) ──
  const MOCHI_TOOLS = [
    {
      type: 'function',
      function: {
        name: 'add_to_watchlist',
        description: 'Add a movie or TV show to Khent & Clair\'s shared cinema watchlist. Use when they want to watch something or ask to add a movie/show. If search_movies returned multiple close matches, use tmdb_id from the chosen candidate.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'The movie or TV show title to search for (ignored if tmdb_id is provided)' },
            media_type: { type: 'string', enum: ['movie', 'tv'], description: 'Whether it is a movie or TV show' },
            tmdb_id: { type: 'number', description: 'TMDB ID from a prior search_movies result — use when disambiguating between candidates' },
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
        name: 'send_sanctuary_message',
        description: 'Send a message to the private Sanctuary couple chat as Mochi on behalf of the current user. Use when they ask you to tell their partner something or relay a message in the chat.',
        parameters: {
          type: 'object',
          properties: {
            text: { type: 'string', description: 'The message text to send (1-2000 chars)' },
          },
          required: ['text'],
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
    {
      type: 'function',
      function: {
        name: 'add_book_to_our_books',
        description: 'Search Open Library for a book and add it to Khent & Clair\'s shared "Our Books" list. Use when they want to add a book to their shared reading list. If search_books returned multiple candidates, you may pass open_library_key to pick the exact one.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Book search query (title, author name, or ISBN)' },
            open_library_key: { type: 'string', description: 'Open Library key from a prior search_books result (e.g., "/works/OL123W") — use when disambiguating' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'read_starlight_jar',
        description: 'Read the most recent notes saved in the Starlight Jar. Use when they ask what is in the jar or want to revisit saved notes and memories.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of recent notes to read (default 10, max 25)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_watchlist',
        description: 'Read Khent & Clair\'s current shared cinema watchlist. Use when they ask what is on their list or what they have been planning to watch.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of items per person to read (default 15, max 40)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'remember_fact',
        description: 'Save a personal fact about Khent or Clair to Mochi\'s long-term memory. Use when they explicitly tell you something to remember about themselves, each other, or their relationship.',
        parameters: {
          type: 'object',
          properties: {
            fact: { type: 'string', description: 'The fact to remember, phrased naturally (e.g., "Khent prefers black coffee")' },
            category: { type: 'string', enum: ['fact', 'preference', 'dislike', 'goal', 'date', 'habit'], description: 'Category of the fact (default: fact)' },
          },
          required: ['fact'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'read_memories',
        description: 'Browse or search Mochi\'s long-term memory book. Use when they want to see what you remember, search a memory, or review facts.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Optional search text' },
            category: { type: 'string', description: 'Optional category filter (fact, preference, dislike, goal, date, habit)' },
            limit: { type: 'number', description: 'Max memories to return (default 20, max 50)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'pin_memory',
        description: 'Pin or unpin a memory so it is always remembered. Use when they say a fact is important or to highlight a favorite memory.',
        parameters: {
          type: 'object',
          properties: {
            memory_id: { type: 'string', description: 'Memory document ID from read_memories' },
            pinned: { type: 'boolean', description: 'true to pin, false to unpin' },
          },
          required: ['memory_id', 'pinned'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'delete_memory',
        description: 'Delete a memory from Mochi\'s long-term memory. Use when they ask to forget something or remove an incorrect fact.',
        parameters: {
          type: 'object',
          properties: {
            memory_id: { type: 'string', description: 'Memory document ID from read_memories' },
          },
          required: ['memory_id'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'edit_memory',
        description: 'Edit the text of an existing memory. Use when they want to correct or update a remembered fact.',
        parameters: {
          type: 'object',
          properties: {
            memory_id: { type: 'string', description: 'Memory document ID from read_memories' },
            fact: { type: 'string', description: 'The corrected fact text' },
            category: { type: 'string', enum: ['fact', 'preference', 'dislike', 'goal', 'date', 'habit'], description: 'Optional new category' },
          },
          required: ['memory_id', 'fact'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'mark_watchlist_item_watched',
        description: 'Mark a movie or show on the shared cinema watchlist as watched. Use when they finish something or ask to update their list.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Movie or show title to mark as watched' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'update_book_progress',
        description: 'Update progress (0-100) for a book in the shared "Our Books" list. Progress 100 also marks it read for the caller.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Book title to update' },
            progress: { type: 'number', description: 'Progress percentage 0-100' },
          },
          required: ['title', 'progress'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'add_xp',
        description: 'Award XP to the caller for a completed activity or achievement inside Everglow. Use sparingly and only when an action clearly deserves it.',
        parameters: {
          type: 'object',
          properties: {
            amount: { type: 'number', description: 'XP amount (1-100, default 10)' },
            reason: { type: 'string', description: 'Short reason for the XP' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'send_note_to_partner',
        description: 'Send a private note from one partner to the other through Mochi. Use when they ask you to pass a message, note, or reminder to their partner.',
        parameters: {
          type: 'object',
          properties: {
            note: { type: 'string', description: 'The note content' },
          },
          required: ['note'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_relationship_insights',
        description: 'Find gentle patterns in their moods and activities, like shared rhythms or recurring date-night habits.',
        parameters: {
          type: 'object',
          properties: {},
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_memory_trivia',
        description: 'Generate a mini memory-trivia game from real facts Mochi remembers about Khent and Clair.',
        parameters: {
          type: 'object',
          properties: {
            count: { type: 'number', description: 'Number of questions (default 5, max 10)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_today_recap',
        description: 'Compile a short, warm recap of today in Everglow: moods, activities, watchlist, starlight notes, and on-this-day memories.',
        parameters: {
          type: 'object',
          properties: {},
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_gallery',
        description: 'Read recent photos from the Gallery. Use when they ask about their photos or memories.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of photos to fetch (default 10, max 20)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_garden',
        description: 'Read the garden plants and their growth. Use when they ask about their garden or plants.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of plants to fetch (default 10, max 20)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'get_canvas',
        description: 'Read recent canvas drawings. Use when they ask about drawings or art.',
        parameters: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Number of drawings to fetch (default 10, max 20)' },
          },
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_spotify',
        description: 'Search Spotify for tracks by artist and title. Use when they ask about music or want to find a song.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query (e.g., "Ethel Cain Crush" or "artist - track")' },
            artist: { type: 'string', description: 'Artist name (optional if query contains artist)' },
            track: { type: 'string', description: 'Track name (optional if query contains track)' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'remove_from_watchlist',
        description: 'Remove a movie or show from the shared watchlist. Use when they ask to remove or delete something from the list.',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Title substring to match' },
            tmdb_id: { type: 'number', description: 'Exact TMDB ID to remove (optional)' },
          },
          required: ['title'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'search_everglow',
        description: 'Unified search across Everglow — movies (TMDB), books (Open Library), anime (Jikan), and music (Spotify) in one call. Use when they ask for broad recommendations or to find something without knowing the domain.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query for all domains' },
          },
          required: ['query'],
        },
      },
    },
    {
      type: 'function',
      function: {
        name: 'plan_date_night',
        description: 'Plan a complete date night by combining date ideas, weather for a location, and watchlist suggestions. Use when they ask to plan a date or a night together.',
        parameters: {
          type: 'object',
          properties: {
            location: { type: 'string', description: 'City for weather (default Cabadbaran)' },
            count: { type: 'number', description: 'Number of date ideas (default 3, max 5)' },
          },
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
              // W2-A3: Support tmdb_id disambiguation + candidate return
              const mediaType = args.media_type || 'movie';
              const providedId = args.tmdb_id || args.tmdbId || args.tmdbId === 0 ? Number(args.tmdb_id || args.tmdbId) : null;
              if (providedId) {
                // Direct fetch by ID for disambiguated choice
                const detailKey = `tmdb:detail:${mediaType}:${providedId}`;
                let detail;
                const cachedDetail = _getExternalCache(detailKey, _EXTERNAL_CACHE_TTLS.tmdb);
                if (cachedDetail) {
                  detail = cachedDetail;
                } else {
                  const detailRes = await fetch(
                    `https://api.themoviedb.org/3/${mediaType === 'tv' ? 'tv' : 'movie'}/${providedId}?api_key=${getTmdbKey()}`
                  );
                  if (!detailRes.ok) return JSON.stringify({ error: `TMDB ID ${providedId} not found for ${mediaType}` });
                  detail = await detailRes.json();
                  _setExternalCache(detailKey, detail);
                }
                const title = detail.title || detail.name || String(args.title || '').trim();
                if (!title) return JSON.stringify({ error: 'No title found for that TMDB ID' });
                await db.collection('our_cinema').add({
                  tmdbId: providedId,
                  title,
                  mediaType,
                  posterPath: detail.poster_path ? `https://image.tmdb.org/t/p/w500${detail.poster_path}` : null,
                  addedBy: callerUid,
                  addedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                  status: 'plan_to_watch',
                });
                return JSON.stringify({ success: true, title, tmdbId: providedId });
              }
              const queryRaw = String(args.title || '').trim();
              if (!queryRaw) return JSON.stringify({ error: 'No title provided' });
              const tmdbCacheKey = `tmdb:add:${mediaType}:${queryRaw.toLowerCase()}`;
              let tmdbData;
              const cachedTmdb = _getExternalCache(tmdbCacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
              if (cachedTmdb) {
                tmdbData = cachedTmdb;
              } else {
                const tmdbRes = await fetch(
                  `https://api.themoviedb.org/3/search/${mediaType === 'multi' ? 'multi' : mediaType}?query=${encodeURIComponent(queryRaw)}&api_key=${getTmdbKey()}`
                );
                tmdbData = await tmdbRes.json();
                _setExternalCache(tmdbCacheKey, tmdbData);
              }
              const results = (tmdbData.results || []).filter(r => r.title || r.name);
              if (results.length === 0) return JSON.stringify({ error: `No results found for "${queryRaw}"` });
              // W2-A3 disambiguation: if query not exact and multiple candidates share substring, ask to confirm
              const qLower = queryRaw.toLowerCase();
              const exact = results.find(r => (r.title || r.name || '').toLowerCase() === qLower);
              const substringMatches = results.filter(r => {
                const t = (r.title || r.name || '').toLowerCase();
                return t.includes(qLower) || qLower.includes(t);
              }).slice(0, 3);
              const isAmbiguous = !exact && substringMatches.length >= 2;
              if (isAmbiguous) {
                const candidates = substringMatches.map(r => ({
                  tmdbId: r.id,
                  title: r.title || r.name,
                  year: (r.release_date || r.first_air_date || '').slice(0, 4),
                  mediaType: r.media_type || mediaType,
                  overview: (r.overview || '').slice(0, 180),
                  popularity: r.popularity || 0,
                }));
                return JSON.stringify({
                  needs_confirmation: true,
                  message: `Found multiple matches for "${queryRaw}". Ask the user which one they mean and re-call add_to_watchlist with the chosen tmdb_id.`,
                  candidates,
                });
              }
              const result = results[0];
              await db.collection('our_cinema').add({
                tmdbId: result.id,
                title: result.title || result.name,
                mediaType: result.media_type || mediaType,
                posterPath: result.poster_path ? `https://image.tmdb.org/t/p/w500${result.poster_path}` : null,
                addedBy: callerUid,
                addedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                status: 'plan_to_watch',
              });
              return JSON.stringify({ success: true, title: result.title || result.name, tmdbId: result.id });
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
              const cacheKey = `tmdb:search:${endpoint}:${String(args.query || '').toLowerCase().trim()}`;
              let tmdbData;
              const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
              if (cached) {
                tmdbData = cached;
              } else {
                const tmdbRes = await fetch(
                  `https://api.themoviedb.org/3/search/${endpoint}?query=${encodeURIComponent(args.query)}&api_key=${getTmdbKey()}`
                );
                tmdbData = await tmdbRes.json();
                _setExternalCache(cacheKey, tmdbData);
              }
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
              const wKey = `weather:${String(args.location || '').toLowerCase().trim()}`;
              const cachedWeather = _getExternalCache(wKey, _EXTERNAL_CACHE_TTLS.weather);
              if (cachedWeather) return JSON.stringify({ location: args.location, weather: cachedWeather });
              const weatherRes = await fetch(
                `https://wttr.in/${encodeURIComponent(args.location)}?format=%C+%t+%h+%w`,
                { headers: { 'User-Agent': 'curl/8.5.0' } }
              );
              const weatherText = await weatherRes.text();
              const trimmed = weatherText.trim();
              _setExternalCache(wKey, trimmed);
              return JSON.stringify({ location: args.location, weather: trimmed });
            }
            case 'create_reminder': {
              // W1-A2: Parse remind_at into a Firestore Timestamp for the
              // scheduled checker. Accepts ISO 8601 or common relatives.
              let remindAtTs = null;
              const rawRemind = String(args.remind_at || '').trim();
              if (rawRemind) {
                const parsed = new Date(rawRemind);
                if (!Number.isNaN(parsed.getTime())) {
                  remindAtTs = getAdmin().firestore.Timestamp.fromDate(parsed);
                } else if (/tomorrow/i.test(rawRemind)) {
                  const d = new Date(Date.now() + 24 * 60 * 60 * 1000);
                  const timeMatch = rawRemind.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/i);
                  if (timeMatch) {
                    let h = parseInt(timeMatch[1], 10);
                    const m = timeMatch[2] ? parseInt(timeMatch[2], 10) : 0;
                    const ap = (timeMatch[3] || '').toLowerCase();
                    if (ap === 'pm' && h < 12) h += 12;
                    if (ap === 'am' && h === 12) h = 0;
                    d.setHours(h, m, 0, 0);
                  }
                  remindAtTs = getAdmin().firestore.Timestamp.fromDate(d);
                }
              }
              await db.collection('reminders').add({
                title: args.title,
                note: args.note || null,
                remindAt: args.remind_at,
                remindAtTs,
                fired: false,
                createdBy: callerUid,
                createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                read: false,
              });
              return JSON.stringify({ success: true, title: args.title, remindAt: args.remind_at, scheduled: !!remindAtTs });
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
              const bKey = `books:search:${String(args.query || '').toLowerCase().trim()}`;
              let searchData;
              const cachedBooks = _getExternalCache(bKey, _EXTERNAL_CACHE_TTLS.books);
              if (cachedBooks) {
                searchData = cachedBooks;
              } else {
                const searchRes = await fetch(
                  `https://openlibrary.org/search.json?q=${encodeURIComponent(args.query)}&limit=5&fields=key,title,author_name,first_publish_year,isbn,cover_i`
                );
                searchData = await searchRes.json();
                _setExternalCache(bKey, searchData);
              }
              const books = (searchData.docs || []).slice(0, 5).map(b => ({
                title: b.title,
                authors: (b.author_name || []).slice(0, 2).join(', '),
                year: b.first_publish_year || null,
                coverId: b.cover_i || null,
                openLibraryKey: b.key || null,
              }));
              return JSON.stringify({ results: books });
            }
            case 'add_book_to_our_books': {
              const queryRaw = String(args.query || '').trim();
              if (!queryRaw) return JSON.stringify({ error: 'No query provided' });
              const providedKey = args.open_library_key || args.openLibraryKey || null;
              const abKey = `books:add:${queryRaw.toLowerCase()}`;
              let searchData;
              const cachedAb = _getExternalCache(abKey, _EXTERNAL_CACHE_TTLS.books);
              if (cachedAb) {
                searchData = cachedAb;
              } else {
                const searchRes = await fetch(
                  `https://openlibrary.org/search.json?q=${encodeURIComponent(queryRaw)}&limit=5&fields=key,title,author_name,first_publish_year,isbn,cover_i`
                );
                searchData = await searchRes.json();
                _setExternalCache(abKey, searchData);
              }
              const docs = (searchData.docs || []).filter(d => d.title);
              if (docs.length === 0) return JSON.stringify({ error: `No book found for "${queryRaw}"` });
              let book = null;
              if (providedKey) {
                const normKey = String(providedKey).trim();
                book = docs.find(d => d.key === normKey) || docs[0];
              } else {
                // W2-A3 disambiguation: if multiple substring matches and no exact, return candidates
                const qLower = queryRaw.toLowerCase();
                const exact = docs.find(d => (d.title || '').toLowerCase() === qLower);
                const subMatches = docs.filter(d => {
                  const t = (d.title || '').toLowerCase();
                  return t.includes(qLower) || qLower.includes(t);
                }).slice(0, 3);
                const isAmbiguous = !exact && subMatches.length >= 2;
                if (isAmbiguous) {
                  const candidates = subMatches.map(b => ({
                    openLibraryKey: b.key,
                    title: b.title,
                    authors: (b.author_name || []).slice(0, 2).join(', '),
                    year: b.first_publish_year || null,
                    coverId: b.cover_i || null,
                  }));
                  return JSON.stringify({
                    needs_confirmation: true,
                    message: `Found multiple books for "${queryRaw}". Ask the user which one they mean and re-call with the chosen open_library_key.`,
                    candidates,
                  });
                }
                book = docs[0];
              }
              if (!book) return JSON.stringify({ error: `No book found for "${queryRaw}"` });
              const title = book.title || 'Unknown';
              const author = (book.author_name || []).slice(0, 2).join(', ');
              await db.collection('our_books').add({
                title,
                author,
                coverUrl: book.cover_i ? `https://covers.openlibrary.org/b/id/${book.cover_i}-M.jpg` : '',
                year: book.first_publish_year ? String(book.first_publish_year) : '',
                workKey: book.key || '',
                addedBy: callerUid,
                addedAt: new Date().toISOString(),
              });
              return JSON.stringify({ success: true, title, author, openLibraryKey: book.key || null });
            }
            case 'read_starlight_jar': {
              const limit = Math.min(args.limit || 10, 25);
              const snapshot = await db.collection('starlight_jar')
                .orderBy('timestamp', 'desc')
                .limit(limit)
                .get();
              const notes = snapshot.docs.map(d => {
                const data = d.data();
                return {
                  content: (data.content || '').slice(0, 300),
                  author: data.author || 'mochi',
                  time: data.timestamp?.toDate?.()?.toISOString() || null,
                };
              });
              return JSON.stringify({ notes, count: notes.length });
            }
            case 'get_watchlist': {
              const limit = Math.min(args.limit || 15, 40);
              const parts = [];
              for (const username of ['khentsgdz', 'clairjassen']) {
                const snapshot = await db.collection('our_cinema')
                  .where('userId', '==', username)
                  .orderBy('addedAt', 'desc')
                  .limit(limit)
                  .get();
                const items = snapshot.docs.map(d => {
                  const x = d.data();
                  return `${x.title || 'Unknown'} (${x.mediaType || 'movie'}) - ${x.status || 'plan to watch'}`;
                });
                if (items.length) parts.push(`${username}'s watchlist:\n${items.join('\n')}`);
              }
              return JSON.stringify({ watchlist: parts.length ? parts.join('\n\n') : 'Watchlist is empty' });
            }
            case 'get_date_ideas': {
              const count = Math.min(args.count || 3, 10);
              const snapshot = await db.collection('date_ideas').limit(100).get();
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
              const aKey = `anime:search:${String(args.query || '').toLowerCase().trim()}`;
              let animeData;
              const cachedAnime = _getExternalCache(aKey, _EXTERNAL_CACHE_TTLS.anime);
              if (cachedAnime) {
                animeData = cachedAnime;
              } else {
                const animeRes = await fetch(
                  `https://api.jikan.moe/v4/anime?q=${encodeURIComponent(args.query)}&limit=5&sfw=true`
                );
                animeData = await animeRes.json();
                _setExternalCache(aKey, animeData);
              }
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
            case 'remember_fact': {
              const fact = (args.fact || '').trim();
              if (!fact) return JSON.stringify({ error: 'No fact provided' });
              const parsed = parseFactStructure(fact);
              const emb = await getEmbedding(fact).catch(() => null);
              await db.collection('ai_memories').doc('shared').collection('facts').add({
                fact,
                category: args.category || 'fact',
                subject: args.subject || parsed.subject || null,
                relation: args.relation || parsed.relation || null,
                object: args.object || parsed.object || null,
                occurredAt: args.occurred_at || args.occurredAt || null,
                addedBy: callerUid || 'mochi',
                createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                confidence: 1.0,
                accessCount: 0,
                lastAccessed: null,
                pinned: false,
                source: callerUid || 'mochi',
                embedding: emb, // W4-C9 scaffold
              });
              return JSON.stringify({
                success: true,
                fact,
                subject: args.subject || parsed.subject,
                relation: args.relation || parsed.relation,
                object: args.object || parsed.object,
              });
            }
            case 'read_memories': {
              const limit = Math.min(args.limit || 20, 50);
              let query = db.collection('ai_memories').doc('shared').collection('facts')
                .orderBy('createdAt', 'desc')
                .limit(300);
              const snapshot = await query.get();
              let facts = snapshot.docs.map(d => {
                const data = d.data();
                return {
                  id: d.id,
                  fact: data.fact || '',
                  category: data.category || 'fact',
                  subject: data.subject || null,
                  relation: data.relation || null,
                  object: data.object || null,
                  occurredAt: data.occurredAt?.toDate?.()?.toISOString() || null,
                  pinned: data.pinned === true,
                };
              }).filter(f => f.fact);
              if (args.category) {
                facts = facts.filter(f => f.category === args.category);
              }
              if (args.query) {
                const queryLower = String(args.query).toLowerCase();
                facts = rankMemories(facts, queryLower, limit);
              } else {
                facts = facts.slice(0, limit);
              }
              return JSON.stringify({ memories: facts, count: facts.length });
            }
            case 'mark_watchlist_item_watched': {
              const title = (args.title || '').trim();
              if (!title) return JSON.stringify({ error: 'No title provided' });
              const snapshot = await db.collection('our_cinema').get();
              const matches = snapshot.docs.filter(d => {
                const t = (d.data().title || '').toLowerCase();
                return t.includes(title.toLowerCase()) || title.toLowerCase().includes(t);
              });
              if (matches.length === 0) {
                return JSON.stringify({ error: `No watchlist item found for "${title}"` });
              }
              const batch = db.batch();
              for (const doc of matches) {
                batch.update(doc.ref, {
                  status: 'watched',
                  watchedBy: callerUid,
                  watchedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                });
              }
              await batch.commit();
              return JSON.stringify({
                success: true,
                title: matches[0].data().title || title,
                updated: matches.length,
              });
            }
            case 'update_book_progress': {
              const title = (args.title || '').trim();
              const progress = Math.min(Math.max(Number(args.progress) || 0, 0), 100);
              if (!title) return JSON.stringify({ error: 'No title provided' });
              const snapshot = await db.collection('our_books').get();
              const matches = snapshot.docs.filter(d => {
                const t = (d.data().title || '').toLowerCase();
                return t.includes(title.toLowerCase()) || title.toLowerCase().includes(t);
              });
              if (matches.length === 0) {
                return JSON.stringify({ error: `No book found for "${title}"` });
              }
              const field = callerUid === 'khentsgdz' ? 'khentReadAt' : 'clairReadAt';
              const readFlag = progress >= 100
                ? getAdmin().firestore.FieldValue.serverTimestamp()
                : null;
              const batch = db.batch();
              for (const doc of matches.slice(0, 3)) {
                batch.update(doc.ref, {
                  progress: progress,
                  [field]: readFlag,
                  lastUpdatedBy: callerUid,
                  lastUpdatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                });
              }
              await batch.commit();
              return JSON.stringify({
                success: true,
                title: matches[0].data().title || title,
                progress,
                read: progress >= 100,
              });
            }
            case 'add_xp': {
              const amount = Math.min(Math.max(Number(args.amount) || 10, 1), 100);
              const uid = callerUid || 'khentsgdz';
              const ref = db.collection('users').doc(uid).collection('progress').doc('main');
              const doc = await ref.get();
              const current = (doc.exists && doc.data()?.xpTotal) || 0;
              const xpTotal = current + amount;
              const level = Math.floor(xpTotal / 1000) + 1;
              await ref.set({
                xpTotal,
                level,
                streak: doc.exists ? (doc.data()?.streak || 0) : 0,
                lastAwardReason: args.reason || 'Mochi award',
                lastAwardedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
              return JSON.stringify({ success: true, uid, amount, xpTotal, level });
            }
            case 'send_note_to_partner': {
              const note = (args.note || '').trim();
              if (!note) return JSON.stringify({ error: 'No note provided' });
              const partnerUid = PARTNER_UID[callerUid];
              if (!partnerUid) return JSON.stringify({ error: 'Unknown partner for this user' });
              await db.collection('mochi_notes').add({
                from: callerUid,
                to: partnerUid,
                content: note,
                read: false,
                createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
                writtenBy: 'Mochi 🍡',
              });
              await sendFCMToUser(partnerUid, {
                title: '💌 Mochi has a note for you',
                body: note.slice(0, 120),
                data: { type: 'mochi_note', from: callerUid },
              });
              return JSON.stringify({ success: true, to: partnerUid });
            }
            case 'get_relationship_insights': {
              const [moodSnap, activitySnap] = await Promise.all([
                db.collection('moods').orderBy('timestamp', 'desc').limit(100).get(),
                db.collection('recent_activity').orderBy('timestamp', 'desc').limit(20).get(),
              ]);
              const moods = moodSnap.docs.map(d => d.data().mood || d.data().moodEmoji || '');
              const activities = activitySnap.docs.map(
                d => d.data().activity || d.data().description || ''
              );
              const insights = computeInsights({ moods, activities });
              return JSON.stringify({ insights });
            }
            case 'get_memory_trivia': {
              const count = Math.min(args.count || 5, 10);
              const snapshot = await db.collection('ai_memories').doc('shared').collection('facts')
                .orderBy('createdAt', 'desc')
                .limit(150)
                .get();
              const facts = snapshot.docs.map(d => {
                const data = d.data();
                return {
                  fact: data.fact || '',
                  subject: data.subject || null,
                  relation: data.relation || null,
                  object: data.object || null,
                  occurredAt: data.occurredAt?.toDate?.() || null,
                };
              });
              const questions = generateTrivia(facts, count);
              return JSON.stringify({ questions });
            }
            case 'get_today_recap': {
              const today = new Date().toISOString().slice(0, 10);
              const [moodSnap, activitySnap, watchSnap, starSnap, memorySnap] = await Promise.all([
                db.collection('moods').where('date', '==', today).get(),
                db.collection('recent_activity').orderBy('timestamp', 'desc').limit(5).get(),
                db.collection('our_cinema').limit(5).get(),
                db.collection('starlight_jar').orderBy('timestamp', 'desc').limit(3).get(),
                db.collection('ai_memories').doc('shared').collection('facts')
                  .orderBy('createdAt', 'desc').limit(300).get(),
              ]);
              const recap = composeTodayRecap({
                dateLabel: today,
                moods: moodSnap.docs.map(d => ({
                  uid: d.data().uid || 'someone',
                  mood: d.data().mood || 'okay',
                })),
                activities: activitySnap.docs.map(
                  d => d.data().activity || d.data().description || ''
                ),
                watchlist: watchSnap.docs.map(d => d.data().title || '').filter(Boolean),
                starlight: starSnap.docs.map(d => d.data().content || '').filter(Boolean),
                memories: memorySnap.docs.map(d => {
                  const data = d.data();
                  return {
                    fact: data.fact || '',
                    occurredAt: data.occurredAt?.toDate?.() || null,
                  };
                }),
              });
              return JSON.stringify({ recap, date: today });
            }
            case 'plan_date_night': {
              const location = (args.location || 'Cabadbaran').trim();
              const count = Math.min(args.count || 3, 5);
              const pKey = `weather:${location.toLowerCase()}`;
              const cachedPlanWeather = _getExternalCache(pKey, _EXTERNAL_CACHE_TTLS.weather);
              let weatherText = cachedPlanWeather || null;
              const [ideaSnap, watchSnap, fetchedWeather] = await Promise.all([
                db.collection('date_ideas').limit(100).get(),
                db.collection('our_cinema').limit(5).get(),
                weatherText ? Promise.resolve(null) : fetch(`https://wttr.in/${encodeURIComponent(location)}?format=%C+%t+%h+%w`, {
                  headers: { 'User-Agent': 'curl/8.5.0' },
                }),
              ]);
              if (!weatherText && fetchedWeather) {
                weatherText = (await fetchedWeather.text()).trim();
                _setExternalCache(pKey, weatherText);
              }
              weatherText = weatherText || 'Weather unavailable';
              const allIdeas = ideaSnap.docs
                .map(d => d.data().title || d.data().name || '')
                .filter(Boolean);
              const shuffled = [...allIdeas].sort(() => Math.random() - 0.5);
              const watchlist = watchSnap.docs
                .map(d => d.data().title || '')
                .filter(Boolean)
                .slice(0, 2);
              return JSON.stringify({
                location,
                weather: weatherText || 'Weather unavailable',
                ideas: shuffled.slice(0, count),
                watchlist,
                suggestion: [
                  `Start with ${shuffled[0] || 'a cozy evening'}`,
                  watchlist.length
                    ? `then finish the night with "${watchlist[0]}"`
                    : 'then just talk until late',
                ].join(', '),
              });
            }
            case 'send_sanctuary_message': {
              const text = String(args.text || '').trim();
              if (!text) return JSON.stringify({ error: 'No text provided' });
              if (text.length > 2000) return JSON.stringify({ error: 'Message too long (max 2000)' });
              // Resolve sender username from callerUid (already verified)
              const sender = (callerUid || 'mochi').toLowerCase();
              await db.collection('sanctuary_messages').add({
                text,
                sender,
                senderUid: sender,
                timestamp: getAdmin().firestore.FieldValue.serverTimestamp(),
                via: 'mochi',
                createdBy: callerUid,
              });
              // Notify partner (reuse FCM helper)
              const partnerMap = { khentsgdz: 'clairjassen', clairjassen: 'khentsgdz' };
              const partner = partnerMap[sender];
              if (partner) {
                await sendFCMToUser(partner, {
                  title: `💌 New message from ${sender === 'khentsgdz' ? 'Khent' : 'Clair'} via Mochi`,
                  body: text.slice(0, 120),
                  data: { type: 'chat_message', sender },
                });
              }
              return JSON.stringify({ success: true, text: text.slice(0, 200) });
            }
            case 'pin_memory': {
              const mid = String(args.memory_id || '').trim();
              if (!mid) return JSON.stringify({ error: 'memory_id required' });
              const pinned = !!args.pinned;
              const ref = db.collection('ai_memories').doc('shared').collection('facts').doc(mid);
              const snap = await ref.get();
              if (!snap.exists) return JSON.stringify({ error: `Memory ${mid} not found` });
              await ref.update({ pinned, lastAccessed: getAdmin().firestore.FieldValue.serverTimestamp() });
              return JSON.stringify({ success: true, memory_id: mid, pinned });
            }
            case 'delete_memory': {
              const mid = String(args.memory_id || '').trim();
              if (!mid) return JSON.stringify({ error: 'memory_id required' });
              const ref = db.collection('ai_memories').doc('shared').collection('facts').doc(mid);
              const snap = await ref.get();
              if (!snap.exists) return JSON.stringify({ error: `Memory ${mid} not found` });
              await ref.delete();
              return JSON.stringify({ success: true, memory_id: mid });
            }
            case 'edit_memory': {
              const mid = String(args.memory_id || '').trim();
              const fact = String(args.fact || '').trim();
              if (!mid || !fact) return JSON.stringify({ error: 'memory_id and fact required' });
              if (fact.length > 500) return JSON.stringify({ error: 'Fact too long (max 500)' });
              const ref = db.collection('ai_memories').doc('shared').collection('facts').doc(mid);
              const snap = await ref.get();
              if (!snap.exists) return JSON.stringify({ error: `Memory ${mid} not found` });
              const parsed = parseFactStructure(fact);
              const update = {
                fact,
                subject: parsed.subject || null,
                relation: parsed.relation || null,
                object: parsed.object || null,
                lastAccessed: getAdmin().firestore.FieldValue.serverTimestamp(),
              };
              if (args.category) update.category = String(args.category).trim().toLowerCase();
              await ref.update(update);
              return JSON.stringify({ success: true, memory_id: mid, fact, category: update.category || snap.data()?.category || 'fact' });
            }
            case 'get_gallery': {
              const limit = Math.min(Math.max(Number(args.limit) || 10, 1), 20);
              const snap = await db.collection('gallery').orderBy('createdAt', 'desc').limit(limit).get();
              if (snap.empty) return JSON.stringify({ photos: [], count: 0 });
              const photos = snap.docs.map(d => {
                const data = d.data();
                return {
                  caption: (data.caption || '').slice(0, 200),
                  uploadedBy: data.uploadedBy || data.author || '',
                  imageUrl: data.imageUrl ? '[image]' : '',
                  createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
                };
              });
              return JSON.stringify({ photos, count: photos.length });
            }
            case 'get_garden': {
              const limit = Math.min(Math.max(Number(args.limit) || 10, 1), 20);
              const snap = await db.collection('garden_plants').orderBy('plantedAt', 'desc').limit(limit).get();
              if (snap.empty) return JSON.stringify({ plants: [], count: 0 });
              const plants = snap.docs.map(d => {
                const data = d.data();
                return {
                  name: data.name || data.plantName || 'Plant',
                  status: data.status || 'growing',
                  plantedBy: data.plantedBy || '',
                  plantedAt: data.plantedAt?.toDate?.()?.toISOString() || null,
                };
              });
              return JSON.stringify({ plants, count: plants.length });
            }
            case 'get_canvas': {
              const limit = Math.min(Math.max(Number(args.limit) || 10, 1), 20);
              const snap = await db.collection('canvas_drawings').orderBy('createdAt', 'desc').limit(limit).get();
              if (snap.empty) return JSON.stringify({ drawings: [], count: 0 });
              const drawings = snap.docs.map(d => {
                const data = d.data();
                return {
                  title: data.title || 'Untitled',
                  drawnBy: data.drawnBy || data.createdBy || '',
                  createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
                };
              });
              return JSON.stringify({ drawings, count: drawings.length });
            }
            case 'search_spotify': {
              const q = String(args.query || args.track || '').trim();
              const artist = String(args.artist || '').trim();
              const track = String(args.track || '').trim();
              const query = q || (artist && track ? `${artist} ${track}` : '') || artist || track;
              if (!query) return JSON.stringify({ error: 'No query provided' });
              const sKey = `spotify:search:${query.toLowerCase()}`;
              let cached = _getExternalCache(sKey, 10 * 60 * 1000);
              if (cached) return JSON.stringify(cached);
              const token = await _getSpotifyAppToken();
              if (!token) return JSON.stringify({ error: 'Spotify not configured' });
              try {
                const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: query, type: 'track', limit: '5', market: 'US' }).toString();
                const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(10000) });
                if (!r.ok) return JSON.stringify({ error: `Spotify search failed ${r.status}` });
                const data = await r.json();
                const items = data.tracks && data.tracks.items;
                if (!Array.isArray(items) || items.length === 0) return JSON.stringify({ tracks: [], count: 0 });
                const tracks = items.slice(0, 5).map(t => ({
                  trackId: t.id,
                  trackName: t.name,
                  artistName: (t.artists && t.artists[0] && t.artists[0].name) || '',
                  albumName: (t.album && t.album.name) || '',
                  imageUrl: (t.album && t.album.images && t.album.images[0] && t.album.images[0].url) || null,
                  spotifyUrl: 'https://open.spotify.com/track/' + t.id,
                }));
                const result = { tracks, count: tracks.length };
                _setExternalCache(sKey, result);
                return JSON.stringify(result);
              } catch (e) {
                return JSON.stringify({ error: e.message });
              }
            }
            case 'remove_from_watchlist': {
              const title = String(args.title || '').trim();
              const tid = args.tmdb_id ? Number(args.tmdb_id) : (args.tmdbId ? Number(args.tmdbId) : null);
              if (!title && !tid) return JSON.stringify({ error: 'Provide title or tmdb_id' });
              let snap;
              if (tid) {
                snap = await db.collection('our_cinema').where('tmdbId', '==', tid).limit(5).get();
              } else {
                snap = await db.collection('our_cinema').get();
              }
              let matches = snap.docs;
              if (!tid) {
                const qLower = title.toLowerCase();
                matches = snap.docs.filter(d => {
                  const t = (d.data().title || '').toLowerCase();
                  return t.includes(qLower) || qLower.includes(t);
                });
              }
              if (matches.length === 0) return JSON.stringify({ error: `No watchlist item found for "${title || tid}"` });
              const batch = db.batch();
              for (const doc of matches.slice(0, 3)) batch.delete(doc.ref);
              await batch.commit();
              return JSON.stringify({ success: true, removed: matches.slice(0, 3).map(d => d.data().title || ''), count: Math.min(matches.length, 3) });
            }
            case 'search_everglow': {
              const query = String(args.query || '').trim();
              if (!query) return JSON.stringify({ error: 'No query provided' });
              const qLower = query.toLowerCase();
              const cacheKey = `everglow:search:${qLower}`;
              const cachedEver = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
              if (cachedEver) return JSON.stringify(cachedEver);
              // Parallel searches: movies, books, anime, spotify (best-effort)
              const [moviesRes, booksRes, animeRes, spotifyRes] = await Promise.allSettled([
                (async () => {
                  const k = getTmdbKey();
                  if (!k) return [];
                  const r = await fetch(`https://api.themoviedb.org/3/search/multi?query=${encodeURIComponent(query)}&api_key=${k}`, { signal: AbortSignal.timeout(8000) });
                  const d = await r.json();
                  return (d.results || []).slice(0, 3).map(x => ({ title: x.title || x.name, year: (x.release_date || x.first_air_date || '').slice(0,4), type: x.media_type || 'movie' }));
                })(),
                (async () => {
                  const r = await fetch(`https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=3&fields=key,title,author_name,first_publish_year`, { signal: AbortSignal.timeout(8000) });
                  const d = await r.json();
                  return (d.docs || []).slice(0, 3).map(b => ({ title: b.title, authors: (b.author_name||[]).slice(0,2).join(', '), type: 'book' }));
                })(),
                (async () => {
                  const r = await fetch(`https://api.jikan.moe/v4/anime?q=${encodeURIComponent(query)}&limit=3&sfw=true`, { signal: AbortSignal.timeout(8000) });
                  const d = await r.json();
                  return (d.data || []).slice(0, 3).map(a => ({ title: a.title, type: 'anime', score: a.score }));
                })(),
                (async () => {
                  const token = await _getSpotifyAppToken();
                  if (!token) return [];
                  const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: query, type: 'track', limit: '3', market: 'US' }).toString();
                  const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(8000) });
                  const d = await r.json();
                  const items = d.tracks?.items || [];
                  return items.slice(0,3).map(t=>({ title: t.name, artist: t.artists?.[0]?.name || '', type: 'track' }));
                })(),
              ]);
              const result = {
                query,
                movies: moviesRes.status === 'fulfilled' ? moviesRes.value : [],
                books: booksRes.status === 'fulfilled' ? booksRes.value : [],
                anime: animeRes.status === 'fulfilled' ? animeRes.value : [],
                tracks: spotifyRes.status === 'fulfilled' ? spotifyRes.value : [],
              };
              _setExternalCache(cacheKey, result);
              return JSON.stringify(result);
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

    // Thinking heartbeat: while the model is still silently reasoning, send
    // a tick every 3s so the client can keep its "thinking" state alive.
    let heartbeatInterval = null;
    const startHeartbeat = () => {
      heartbeatInterval = setInterval(() => {
        try { sendEvent({ tool_status: 'thinking' }); } catch (_) {}
      }, 3000);
    };
    const stopHeartbeat = () => {
      if (heartbeatInterval) { clearInterval(heartbeatInterval); heartbeatInterval = null; }
    };

    try {
      // ── Stream directly — no blocking tool-detection round ──
      sendEvent({ tool_status: 'generating' });
      startKeepalive();
      startHeartbeat();

      let currentMessages = [...nimMessages];
      let toolRound = 0;
      let _streamedFinalReply = ''; // W1-C10: accumulate for server-side memory extract

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
              signal: AbortSignal.timeout(120000),
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
              if (delta.reasoning_content) sendEvent({ reasoning: delta.reasoning_content });
              if (delta.content) {
                fullContent += delta.content;
                _streamedFinalReply += delta.content;
                sendEvent({ content: delta.content });
                stopHeartbeat();
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
          const toolStartedAt = Date.now();
          const result = await executeTool(fnName, fnArgs, caller);
          logToolCall(fnName, caller, result, Date.now() - toolStartedAt);

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
      stopHeartbeat();
      sendEvent({ tool_status: 'done' });
      sendEvent('[DONE]');
      // W1-C10 + W2-A4: fire-and-forget memory extraction & hallucination check
      if (_streamedFinalReply.trim()) {
        serverExtractAndSaveMemory(lastUserMessage, _streamedFinalReply, caller).catch(() => {});
        checkHallucinations(_streamedFinalReply).catch(() => {});
      }
    } catch (e) {
      console.warn('proxyAI streaming error:', e.message);
      sendEvent({ error: 'Mochi got distracted and lost her train of thought. Try asking again?' });
      sendEvent('[DONE]');
    } finally {
      stopKeepalive();
      stopHeartbeat();
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
        signal: AbortSignal.timeout(60000),
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
  // W1-C10 + W2-A4: fire-and-forget memory extraction & hallucination check
  if (reply) {
    serverExtractAndSaveMemory(lastUserMessage, reply, caller).catch(() => {});
    checkHallucinations(reply).catch(() => {});
  }
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

/**
 * Fire-and-forget observability: every Mochi tool call lands in
 * mochi_stats/tool_calls so failures and latency are reviewable.
 */
async function logToolCall(toolName, caller, result, elapsedMs) {
  try {
    let ok = true;
    let error = '';
    try {
      const parsed = JSON.parse(result);
      if (parsed && parsed.error) {
        ok = false;
        error = String(parsed.error).slice(0, 300);
      }
    } catch (_) {
      // Result is not JSON or was empty; leave ok as true.
    }
    await getDb().collection('mochi_stats').doc('tool_calls').collection('calls').add({
      tool: toolName,
      caller: caller || 'unknown',
      ok,
      error,
      elapsedMs,
      createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.warn('logToolCall failed:', e.message);
  }
}

// ── Firestore Triggers: Partner Notifications ─────────────────────
// UID ↔ display-name lookup. Keys are the Firebase Auth UIDs.
const USER_DISPLAY = {
  khentsgdz: 'Khent',
  clairjassen: 'Clair',
};
// Partner UID map — each user's partner UID.
const PARTNER_UID = {
  khentsgdz: 'clairjassen',
  clairjassen: 'khentsgdz',
};

/**
 * Chat message → notify the partner who didn't send it.
 * Runs on every new document in sanctuary_messages.
 */
exports.onNewChatMessage = functions.firestore
  .document('sanctuary_messages/{messageId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    // Use sender (username) not senderUid (Auth UID) for partner lookup
    const sender = (data.sender || '').toLowerCase();
    if (!sender || !PARTNER_UID[sender]) return;

    const partnerUid = PARTNER_UID[sender];
    const senderName = USER_DISPLAY[sender] || 'Someone';
    const preview = (data.text || '').slice(0, 120);

    await sendFCMToUser(partnerUid, {
      title: `💌 New message from ${senderName}`,
      body: preview || 'Sent you a message',
      data: { type: 'chat_message', sender },
    });
  });

/**
 * Mood submission → notify the partner.
 * Runs on every new document in moods.
 */
exports.onNewMood = functions.firestore
  .document('moods/{moodId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const uid = data.uid || data.username;
    if (!uid || !PARTNER_UID[uid]) return;

    const partnerUid = PARTNER_UID[uid];
    const userName = USER_DISPLAY[uid] || 'Someone';
    const emoji = data.moodEmoji || data.mood || '💭';

    await sendFCMToUser(partnerUid, {
      title: `💕 ${userName} shared their mood`,
      body: `Feeling ${emoji} today`,
      data: { type: 'mood_update', sender: uid },
    });
  });

/**
 * Starlight jar drop → notify the partner.
 * Runs on every new document in starlight_jar.
 */
exports.onNewStarDrop = functions.firestore
  .document('starlight_jar/{starId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    // Skip stars written by Mochi — those don't need a partner notification
    if (data.writtenBy) return;

    const author = data.author;
    if (!author || !PARTNER_UID[author]) return;

    const partnerUid = PARTNER_UID[author];
    const authorName = USER_DISPLAY[author] || 'Someone';

    await sendFCMToUser(partnerUid, {
      title: `✨ ${authorName} dropped a star`,
      body: 'Check the Starlight Jar for a surprise!',
      data: { type: 'starlight_drop', author },
    });
  });

/**
 * New watchlist item → notify the partner who didn't add it.
 * Runs on every new document in our_cinema.
 */
exports.onNewWatchlistItem = functions.firestore
  .document('our_cinema/{itemId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const addedBy = (data.addedBy || data.userId || '').toLowerCase();
    if (!addedBy || !PARTNER_UID[addedBy]) return;

    const partnerUid = PARTNER_UID[addedBy];
    const addedByName = USER_DISPLAY[addedBy] || 'Someone';
    const title = data.title || 'something';

    await sendFCMToUser(partnerUid, {
      title: `🎬 ${addedByName} added to the watchlist`,
      body: `"${title}" is now waiting for you two`,
      data: { type: 'watchlist_update', addedBy, title },
    });
  });


/**
 * Gallery photo uploaded → notify the partner.
 * Runs on every new document in gallery.
 */
exports.onNewGalleryPhoto = functions.firestore
  .document('gallery/{photoId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const uploader = (data.uploadedBy || '').toLowerCase();
    if (!uploader || !PARTNER_UID[uploader]) return;

    const partnerUid = PARTNER_UID[uploader];
    const uploaderName = USER_DISPLAY[uploader] || 'Someone';
    const caption = data.caption || '';

    await sendFCMToUser(partnerUid, {
      title: `📸 ${uploaderName} added a photo`,
      body: caption || 'Check the Gallery for a new memory!',
      data: { type: 'gallery_photo', uploader },
    });
  });

/**
 * Watch party room created → notify the partner.
 * Runs on every new document in watch_party_rooms.
 * The room stores Auth UIDs (hostUid/partnerUid), so we resolve
 * the host's username from the /users collection first.
 */
exports.onWatchPartyInvite = functions.firestore
  .document('watch_party_rooms/{roomId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    if (!data.active) return;

    const hostUid = data.hostUid;
    const partnerUidAuth = data.partnerUid;
    if (!hostUid || !partnerUidAuth) return;

    // Resolve host username from /users collection
    const db = getDb();
    let hostUsername = null;
    try {
      const hostDoc = await db.collection('users').doc(hostUid).get();
      if (hostDoc.exists) {
        hostUsername = (hostDoc.data()?.username || '').toLowerCase();
      }
    } catch (e) {
      console.warn('onWatchPartyInvite: failed to resolve host username:', e.message);
    }
    if (!hostUsername || !PARTNER_UID[hostUsername]) return;

    const partnerUsername = PARTNER_UID[hostUsername];
    const hostName = USER_DISPLAY[hostUsername] || data.hostName || 'Someone';
    const mediaTitle = data.title || 'something';

    await sendFCMToUser(partnerUsername, {
      title: `🎬 ${hostName} started a watch party`,
      body: `Watch "${mediaTitle}" together!`,
      data: { type: 'watch_party_invite', roomId: data.id || '' },
    });
  });

/**
 * Milestone added → notify both partners.
 * Runs on every new document in milestones.
 */
exports.onNewMilestone = functions.firestore
  .document('milestones/{milestoneId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const title = data.title || 'New milestone';

    await sendFCMToBoth({
      title: '🎉 New milestone added!',
      body: title,
      data: { type: 'milestone', title },
    });
  });

// ── Scheduled: Daily Digest (8:00 AM PHT = 00:00 UTC) ───────────
exports.mochiDailyDigest = onSchedule({
  schedule: '0 0 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const today = new Date().toISOString().slice(0, 10);

  const [moodsSnap, activitySnap, starSnap, watchSnap, memorySnap] = await Promise.all([
    db.collection('moods').where('date', '==', today).get(),
    db.collection('recent_activity').orderBy('timestamp', 'desc').limit(5).get(),
    db.collection('starlight_jar').orderBy('timestamp', 'desc').limit(3).get(),
    db.collection('our_cinema').limit(5).get(),
    db.collection('ai_memories').doc('shared').collection('facts')
      .orderBy('createdAt', 'desc').limit(300).get(),
  ]);

  const recapData = {
    dateLabel: today,
    moods: moodsSnap.docs.map(d => ({
      uid: d.data().uid || 'someone',
      mood: d.data().mood || 'okay',
    })),
    activities: activitySnap.docs.map(
      d => d.data().activity || d.data().description || ''
    ),
    starlight: starSnap.docs.map(d => d.data().content || '').filter(Boolean),
    watchlist: watchSnap.docs.map(d => d.data().title || '').filter(Boolean),
    memories: memorySnap.docs.map(d => {
      const data = d.data();
      return {
        fact: data.fact || '',
        occurredAt: data.occurredAt?.toDate?.() || null,
      };
    }),
  };

  // Try a real Mochi voice first; fall back to the deterministic recap.
  let digest = composeTodayRecap(recapData);
  try {
    const apiKey = process.env.AGNES_API_KEY;
    if (apiKey) {
      const dataBlob = JSON.stringify(recapData).slice(0, 6000);
      const resp = await fetch('https://apihub.agnes-ai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'agnes-2.5-flash',
          messages: [
            {
              role: 'system',
              content: 'You are Mochi 🍡, a warm white cat companion for Khent and Clair. Write a short 2-3 sentence morning digest in their voice: reference real details from the data, stay warm, and do not list raw fields.',
            },
            {
              role: 'user',
              content: `Morning data for ${today}:\n${dataBlob}`,
            },
          ],
          max_tokens: 300,
          temperature: 0.7,
          stream: false,
        }),
        signal: AbortSignal.timeout(30000),
      });
      if (resp.ok) {
        const body = await resp.json();
        const text = (body.choices?.[0]?.message?.content || '').trim();
        if (text) digest = text;
      }
    }
  } catch (e) {
    console.warn('mochiDailyDigest LLM failed, using fallback:', e.message);
  }

  await sendFCMToBoth({
    title: '🍡 Mochi\'s Morning Digest',
    body: digest.slice(0, 240),
    data: { type: 'daily_digest' },
  });
});

// ── Scheduled: Night Recap (9:00 PM PHT = 13:00 UTC) ──────────────
exports.mochiNightRecap = onSchedule({
  schedule: '0 13 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const today = new Date().toISOString().slice(0, 10);
  const [moodSnap, activitySnap, starSnap, memorySnap] = await Promise.all([
    db.collection('moods').where('date', '==', today).get(),
    db.collection('recent_activity').orderBy('timestamp', 'desc').limit(5).get(),
    db.collection('starlight_jar').orderBy('timestamp', 'desc').limit(3).get(),
    db.collection('ai_memories').doc('shared').collection('facts')
      .orderBy('createdAt', 'desc').limit(300).get(),
  ]);

  const recap = composeTodayRecap({
    dateLabel: today,
    moods: moodSnap.docs.map(d => ({
      uid: d.data().uid || 'someone',
      mood: d.data().mood || 'okay',
    })),
    activities: activitySnap.docs.map(
      d => d.data().activity || d.data().description || ''
    ),
    starlight: starSnap.docs.map(d => d.data().content || '').filter(Boolean),
    memories: memorySnap.docs.map(d => {
      const data = d.data();
      return {
        fact: data.fact || '',
        occurredAt: data.occurredAt?.toDate?.() || null,
      };
    }),
  });

  await sendFCMToBoth({
    title: '🌙 Mochi\'s Night Recap',
    body: recap.slice(0, 240),
    data: { type: 'night_recap' },
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

  // W4-D14: Behavior-based initiative — silence gap + mood trend
  try {
    // 48h silence in Sanctuary
    const chatSnap = await db.collection('sanctuary_messages').orderBy('timestamp', 'desc').limit(1).get();
    if (!chatSnap.empty) {
      const last = chatSnap.docs[0].data().timestamp?.toDate?.();
      if (last && (Date.now() - last.getTime()) > 48 * 60 * 60 * 1000) {
        await sendFCMToBoth({
          title: '💭 Mochi misses you two',
          body: "Haven't heard from you in a couple days — everything okay? Send a little hello? 🐾",
          data: { type: 'silence_nudge' },
        });
      }
    }
    // 7-day negative mood trend (sad/stressed/tired/anxious/down)
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const weekMoods = await db.collection('moods').where('timestamp', '>=', weekAgo).limit(100).get();
    const negative = new Set(['sad', 'stressed', 'tired', 'anxious', 'down', 'upset', 'angry', 'lonely']);
    const byUser = { khentsgdz: 0, clairjassen: 0 };
    weekMoods.forEach(doc => {
      const d = doc.data();
      const m = String(d.mood || d.moodLabel || '').toLowerCase();
      const uid = String(d.uid || d.username || '').toLowerCase();
      if (negative.has(m) && byUser.hasOwnProperty(uid)) byUser[uid]++;
    });
    for (const [uid, count] of Object.entries(byUser)) {
      if (count >= 3) {
        await sendFCMToUser(uid, {
          title: '🫶 Mochi is here for you',
          body: "You've had a few tough days — I'm here, and your person is too. Want to talk or pick a gentle date idea? 💗",
          data: { type: 'mood_trend_nudge' },
        });
      }
    }
  } catch (e) {
    console.warn('[mochiMoodCheckIn] behavior nudge failed:', e.message);
  }
});

// ── Scheduled: Weekly Recap (Sunday 9am PHT) — W4-D15 ───────
exports.mochiWeeklyRecap = onSchedule({
  schedule: '0 9 * * 0',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const todayStr = now.toISOString().slice(0, 10);
  const weekStartStr = weekAgo.toISOString().slice(0, 10);
  try {
    const [moodsSnap, activitySnap, starSnap, watchSnap, memorySnap] = await Promise.all([
      db.collection('moods').where('timestamp', '>=', weekAgo).limit(50).get(),
      db.collection('recent_activity').orderBy('timestamp', 'desc').limit(10).get(),
      db.collection('starlight_jar').orderBy('timestamp', 'desc').limit(5).get(),
      db.collection('our_cinema').limit(5).get(),
      db.collection('ai_memories').doc('shared').collection('facts').orderBy('createdAt', 'desc').limit(300).get(),
    ]);
    const recapData = {
      dateLabel: `${weekStartStr} to ${todayStr}`,
      moods: moodsSnap.docs.map(d => ({
        uid: d.data().uid || d.data().username || 'someone',
        mood: d.data().mood || d.data().moodLabel || 'okay',
      })),
      activities: activitySnap.docs.map(d => d.data().activity || d.data().description || '').filter(Boolean),
      starlight: starSnap.docs.map(d => d.data().content || '').filter(Boolean),
      watchlist: watchSnap.docs.map(d => d.data().title || '').filter(Boolean),
      memories: memorySnap.docs.map(d => ({
        fact: d.data().fact || '',
        occurredAt: d.data().occurredAt?.toDate?.() || null,
      })),
    };
    let recap = composeTodayRecap(recapData);
    // Try LLM polish (same as daily digest, but weekly)
    try {
      const apiKey = process.env.AGNES_API_KEY;
      if (apiKey) {
        const dataBlob = JSON.stringify(recapData).slice(0, 6000);
        const resp = await fetch('https://apihub.agnes-ai.com/v1/chat/completions', {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model: 'agnes-2.5-flash',
            messages: [
              { role: 'system', content: 'You are Mochi 🍡, a warm white cat companion for Khent and Clair. Write a cozy 3-4 sentence weekly recap for their week — reference real moods, activities, starlight notes, and watchlist naturally. Stay warm, celebrate their rhythm, and don\'t list raw fields.' },
              { role: 'user', content: `Week ${weekStartStr} to ${todayStr} data:\n${dataBlob}` },
            ],
            max_tokens: 400,
            temperature: 0.7,
            stream: false,
          }),
          signal: AbortSignal.timeout(30000),
        });
        if (resp.ok) {
          const body = await resp.json();
          const text = (body.choices?.[0]?.message?.content || '').trim();
          if (text) recap = text;
        }
      }
    } catch (e) {
      console.warn('mochiWeeklyRecap LLM failed, using fallback:', e.message);
    }
    await sendFCMToBoth({
      title: '📅 Mochi\'s Weekly Recap',
      body: recap.slice(0, 240),
      data: { type: 'weekly_recap' },
    });
  } catch (e) {
    console.warn('[mochiWeeklyRecap] failed:', e.message);
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

// ── Scheduled: Reminder Checker (every 1 min PHT) — W1-A2 ───────
exports.mochiReminderChecker = onSchedule({
  schedule: 'every 1 minutes',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  try {
    const now = getAdmin().firestore.Timestamp.now();
    // Query equality only to avoid composite index; filter timestamp in code.
    const snap = await db.collection('reminders').where('fired', '==', false).limit(100).get();
    if (snap.empty) return;
    let firedCount = 0;
    const jobs = snap.docs.map(async (doc) => {
      const data = doc.data();
      const ts = data.remindAtTs;
      if (!ts || typeof ts.toDate !== 'function') return;
      const due = ts.toDate();
      if (due > now.toDate()) return;
      const createdBy = (data.createdBy || '').toString().toLowerCase();
      const title = (data.title || 'Reminder').toString().slice(0, 120);
      const note = (data.note || '').toString().slice(0, 180);
      const body = note ? `${title} — ${note}` : title;
      // Fire notification to creator (and partner if available)
      if (createdBy) {
        await sendFCMToUser(createdBy, {
          title: '⏰ Mochi Reminder',
          body: body.slice(0, 240),
          data: { type: 'reminder', reminderId: doc.id, title },
        });
        // Also notify partner for shared awareness (inline map to avoid forward-ref)
        const partnerMap = { khentsgdz: 'clairjassen', clairjassen: 'khentsgdz' };
        const partner = partnerMap[createdBy];
        if (partner) {
          await sendFCMToUser(partner, {
            title: `⏰ Reminder for ${createdBy === 'khentsgdz' ? 'Khent' : 'Clair'}`,
            body: body.slice(0, 240),
            data: { type: 'reminder_shared', reminderId: doc.id, title, for: createdBy },
          });
        }
      }
      await doc.ref.update({
        fired: true,
        firedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
      });
      firedCount++;
    });
    await Promise.allSettled(jobs);
    if (firedCount > 0) console.log(`[mochiReminderChecker] fired ${firedCount}/${snap.size}`);
  } catch (e) {
    console.warn('[mochiReminderChecker] failed:', e.message);
  }
});

// ── Scheduled: Memory sweep (daily 3am PHT) — W3-C12 ───────
// Halves confidence for memories not accessed in 90d and prunes
// those that fall below 0.15 (except pinned). Keeps fact store lean.
exports.mochiMemorySweep = onSchedule({
  schedule: '0 3 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  try {
    const snap = await db.collection('ai_memories/shared/facts').limit(300).get();
    if (snap.empty) return;
    const now = Date.now();
    let pruned = 0;
    let updated = 0;
    const jobs = snap.docs.map(async (doc) => {
      const data = doc.data();
      if (data.pinned === true) return;
      const last = data.lastAccessed?.toDate?.() ? data.lastAccessed.toDate().getTime() : (data.createdAt?.toDate?.()?.getTime() || now);
      const daysSince = (now - last) / (1000 * 60 * 60 * 24);
      if (daysSince <= 90) return;
      const currentConf = Number(data.confidence ?? 1);
      const decayed = currentConf * Math.pow(0.5, daysSince / 90);
      if (decayed < 0.15) {
        await doc.ref.delete();
        pruned++;
      } else if (Math.abs(decayed - currentConf) > 0.05) {
        await doc.ref.update({ confidence: decayed });
        updated++;
      }
    });
    await Promise.allSettled(jobs);
    if (pruned > 0 || updated > 0) console.log(`[mochiMemorySweep] pruned=${pruned} updated=${updated} scanned=${snap.size}`);
  } catch (e) {
    console.warn('[mochiMemorySweep] failed:', e.message);
  }
});

// ===== Spotify: Client Credentials search + User OAuth (Duo) =====
function _getSpotifyCreds() {
  const id = (process.env.SPOTIFY_CLIENT_ID || '').trim() || (functions.config().spotify && functions.config().spotify.client_id) || '';
  const secret = (process.env.SPOTIFY_CLIENT_SECRET || '').trim() || (functions.config().spotify && functions.config().spotify.client_secret) || '';
  return { id, secret };
}
let _spotifyTokenCache = null; // { token, expiresAt }
async function _getSpotifyAppToken() {
  const { id, secret } = _getSpotifyCreds();
  if (!id || !secret) return null;
  if (_spotifyTokenCache && Date.now() < _spotifyTokenCache.expiresAt - 60000) return _spotifyTokenCache.token;
  const basic = Buffer.from(id + ':' + secret).toString('base64');
  const res = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: { 'Authorization': 'Basic ' + basic, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=client_credentials',
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) { console.warn('[spotify] token error', res.status, await res.text().catch(()=>'')); return null; }
  const data = await res.json();
  _spotifyTokenCache = { token: data.access_token, expiresAt: Date.now() + (data.expires_in * 1000) };
  return data.access_token;
}

/**
 * Resolves a track to a real Spotify ID via Client Credentials.
 * GET /proxySpotifySearch?query=Artist+Track  OR  ?artist=...&track=...
 * Auth required. Returns { trackId, trackName, artistName, albumName, imageUrl, previewUrl, spotifyUrl, embedUrl }.
 */
exports.proxySpotifySearch = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'Only GET' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const q = String(req.query.query || '').trim();
  const artist = String(req.query.artist || '').trim();
  const track = String(req.query.track || '').trim();
  const query = q || (artist && track ? artist + ' ' + track : '') || artist || track;
  if (!query) { res.status(400).json({ error: 'Missing query or artist/track' }); return; }
  const token = await _getSpotifyAppToken();
  if (!token) { res.status(503).json({ error: 'Spotify not configured' }); return; }
  try {
    const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: query, type: 'track', limit: '5', market: 'US' }).toString();
    const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(10000) });
    if (!r.ok) { res.status(r.status).json({ error: 'Spotify search failed ' + r.status }); return; }
    const data = await r.json();
    const items = data.tracks && data.tracks.items;
    if (!Array.isArray(items) || items.length === 0) { res.json({ trackId: null, query }); return; }
    // Prefer exact-ish match on track name
    const norm = (s) => s.toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
    const targetNorm = norm(track || query);
    let best = items[0];
    for (const it of items) {
      if (track && norm(it.name) === targetNorm) { best = it; break; }
    }
    const img = best.album && best.album.images && best.album.images[0] ? best.album.images[0].url : null;
    res.json({
      trackId: best.id,
      trackName: best.name,
      artistName: (best.artists && best.artists[0] && best.artists[0].name) || '',
      albumName: (best.album && best.album.name) || '',
      imageUrl: img,
      previewUrl: best.preview_url || null,
      durationMs: best.duration_ms || null,
      spotifyUrl: 'https://open.spotify.com/track/' + best.id,
      embedUrl: 'https://open.spotify.com/embed/track/' + best.id,
      query,
    });
  } catch (e) {
    console.warn('[proxySpotifySearch]', e.message);
    res.status(502).json({ error: e.message });
  }
});

/**
 * OAuth Authorization Code exchange (PKCE supported).
 * POST /spotifyExchange { code, redirectUri, codeVerifier? }
 * Auth required. Exchanges code for access/refresh tokens, stores in Firestore spotify_tokens/{uid}.
 */
exports.spotifyExchange = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const { code, redirectUri, codeVerifier } = req.body || {};
  if (!code || !redirectUri) { res.status(400).json({ error: 'code and redirectUri required' }); return; }
  const { id, secret } = _getSpotifyCreds();
  if (!id) { res.status(503).json({ error: 'Spotify not configured' }); return; }
  try {
    const params = new URLSearchParams({ grant_type: 'authorization_code', code: String(code), redirect_uri: String(redirectUri) });
    if (codeVerifier) params.set('code_verifier', String(codeVerifier));
    else if (secret) params.set('client_secret', secret);
    // Spotify requires client_id always
    params.set('client_id', id);
    const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
    if (secret && !codeVerifier) headers['Authorization'] = 'Basic ' + Buffer.from(id + ':' + secret).toString('base64');
    const r = await fetch('https://accounts.spotify.com/api/token', { method: 'POST', headers, body: params.toString(), signal: AbortSignal.timeout(10000) });
    const text = await r.text();
    if (!r.ok) { console.warn('[spotifyExchange]', r.status, text); res.status(r.status).json({ error: text }); return; }
    const data = JSON.parse(text);
    // Fetch profile to store display name
    let profile = null;
    try {
      const pr = await fetch('https://api.spotify.com/v1/me', { headers: { 'Authorization': 'Bearer ' + data.access_token }, signal: AbortSignal.timeout(8000) });
      if (pr.ok) profile = await pr.json();
    } catch (_) {}
    const doc = {
      access_token: data.access_token,
      refresh_token: data.refresh_token || null,
      expires_at: Date.now() + (data.expires_in * 1000),
      scope: data.scope || '',
      spotify_user_id: profile ? profile.id : null,
      spotify_display_name: profile ? profile.display_name : null,
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    };
    // Only overwrite refresh_token if we got a new one
    const ref = getAdmin().firestore().collection('spotify_tokens').doc(decoded.uid);
    const existing = await ref.get();
    if (existing.exists && !data.refresh_token && existing.data().refresh_token) doc.refresh_token = existing.data().refresh_token;
    await ref.set(doc, { merge: true });
    res.json({ ok: true, expires_in: data.expires_in, spotify_user_id: doc.spotify_user_id });
  } catch (e) {
    console.warn('[spotifyExchange]', e.message);
    res.status(502).json({ error: e.message });
  }
});

/**
 * Refreshes a stored Spotify token.
 * POST /spotifyRefresh  (no body; uses stored refresh_token)
 * Auth required.
 */
exports.spotifyRefresh = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const { id, secret } = _getSpotifyCreds();
  if (!id) { res.status(503).json({ error: 'Spotify not configured' }); return; }
  try {
    const ref = getAdmin().firestore().collection('spotify_tokens').doc(decoded.uid);
    const snap = await ref.get();
    if (!snap.exists || !snap.data().refresh_token) { res.status(404).json({ error: 'No refresh token' }); return; }
    const rt = snap.data().refresh_token;
    const params = new URLSearchParams({ grant_type: 'refresh_token', refresh_token: rt, client_id: id });
    const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
    if (secret) headers['Authorization'] = 'Basic ' + Buffer.from(id + ':' + secret).toString('base64');
    const r = await fetch('https://accounts.spotify.com/api/token', { method: 'POST', headers, body: params.toString(), signal: AbortSignal.timeout(10000) });
    const text = await r.text();
    if (!r.ok) { console.warn('[spotifyRefresh]', r.status, text); res.status(r.status).json({ error: text }); return; }
    const data = JSON.parse(text);
    await ref.set({
      access_token: data.access_token,
      expires_at: Date.now() + (data.expires_in * 1000),
      scope: data.scope || snap.data().scope || '',
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
      ...(data.refresh_token ? { refresh_token: data.refresh_token } : {}),
    }, { merge: true });
    res.json({ ok: true, expires_in: data.expires_in, access_token: data.access_token });
  } catch (e) {
    console.warn('[spotifyRefresh]', e.message);
    res.status(502).json({ error: e.message });
  }
});

/**
 * Proxies Spotify currently-playing for authenticated user (server-side token).
 * GET /spotifyCurrentlyPlaying
 * Useful if client prefers server to fetch with stored token (avoids exposing token to JS).
 */
exports.spotifyCurrentlyPlaying = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  try {
    const ref = getAdmin().firestore().collection('spotify_tokens').doc(decoded.uid);
    const snap = await ref.get();
    if (!snap.exists || !snap.data().access_token) { res.json({ connected: false }); return; }
    let token = snap.data().access_token;
    let expiresAt = snap.data().expires_at || 0;
    if (Date.now() > expiresAt - 60000) {
      // try refresh inline
      const { id, secret } = _getSpotifyCreds();
      const rt = snap.data().refresh_token;
      if (rt && id) {
        try {
          const params = new URLSearchParams({ grant_type: 'refresh_token', refresh_token: rt, client_id: id });
          const headers = { 'Content-Type': 'application/x-www-form-urlencoded' };
          if (secret) headers['Authorization'] = 'Basic ' + Buffer.from(id + ':' + secret).toString('base64');
          const rr = await fetch('https://accounts.spotify.com/api/token', { method: 'POST', headers, body: params.toString(), signal: AbortSignal.timeout(10000) });
          if (rr.ok) {
            const dd = await rr.json();
            token = dd.access_token;
            expiresAt = Date.now() + (dd.expires_in * 1000);
            await ref.set({ access_token: token, expires_at: expiresAt, updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(), ...(dd.refresh_token ? { refresh_token: dd.refresh_token } : {}) }, { merge: true });
          }
        } catch (_) {}
      }
    }
    const r = await fetch('https://api.spotify.com/v1/me/player/currently-playing', { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(8000) });
    if (r.status === 204) { res.json({ connected: true, isPlaying: false }); return; }
    if (r.status === 401) { res.json({ connected: true, isPlaying: false, needsReauth: true }); return; }
    if (!r.ok) { res.status(r.status).json({ error: 'Spotify API ' + r.status }); return; }
    const data = await r.json();
    const item = data.item;
    if (!item) { res.json({ connected: true, isPlaying: !!data.is_playing }); return; }
    res.json({
      connected: true,
      isPlaying: !!data.is_playing,
      progressMs: data.progress_ms,
      trackId: item.id,
      trackName: item.name,
      artistName: (item.artists && item.artists[0] && item.artists[0].name) || '',
      albumName: (item.album && item.album.name) || '',
      imageUrl: (item.album && item.album.images && item.album.images[0] && item.album.images[0].url) || null,
      spotifyUrl: item.external_urls && item.external_urls.spotify,
      embedUrl: 'https://open.spotify.com/embed/track/' + item.id,
      durationMs: item.duration_ms,
      timestamp: Date.now(),
    });
  } catch (e) {
    console.warn('[spotifyCurrentlyPlaying]', e.message);
    res.status(502).json({ error: e.message });
  }
});

/**
 * W5-F21: Eval harness — aggregate Mochi observability.
 * GET /mochiStats  (Auth required, couple-only)
 * Returns tool success rates, hallucination counts, and reminder stats
 * for the last 7 days. Used by a future dashboard.
 */
exports.mochiStats = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  // Couple-only gate: verify username is khentsgdz/clairjassen
  const username = await getVerifiedUsername(decoded);
  if (!['khentsgdz', 'clairjassen'].includes(username || '')) {
    res.status(403).json({ error: 'Couple-only' });
    return;
  }
  try {
    const db = getDb();
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const weekTs = getAdmin().firestore.Timestamp.fromDate(weekAgo);
    const [toolSnap, hallSnap, remSnap] = await Promise.all([
      db.collection('mochi_stats').doc('tool_calls').collection('calls').where('createdAt', '>=', weekTs).limit(200).get().catch(() => ({ empty: true, docs: [] })),
      db.collection('mochi_stats').doc('hallucinations').collection('checks').where('createdAt', '>=', weekTs).limit(50).get().catch(() => ({ empty: true, docs: [] })),
      db.collection('reminders').where('createdAt', '>=', weekTs).limit(50).get().catch(() => ({ empty: true, docs: [] })),
    ]);
    const toolStats = {};
    let totalCalls = 0, okCalls = 0;
    (toolSnap.docs || []).forEach(doc => {
      const d = doc.data();
      const tool = d.tool || 'unknown';
      if (!toolStats[tool]) toolStats[tool] = { total: 0, ok: 0, fail: 0, avgMs: 0, _sumMs: 0 };
      toolStats[tool].total++;
      totalCalls++;
      const isOk = d.ok !== false;
      if (isOk) { toolStats[tool].ok++; okCalls++; } else toolStats[tool].fail++;
      if (typeof d.elapsedMs === 'number') toolStats[tool]._sumMs += d.elapsedMs;
    });
    for (const k of Object.keys(toolStats)) {
      const s = toolStats[k];
      s.avgMs = s.total ? Math.round(s._sumMs / s.total) : 0;
      delete s._sumMs;
    }
    const hallucinations = (hallSnap.docs || []).map(d => {
      const data = d.data();
      return { titles: data.titles || [], at: data.createdAt?.toDate?.()?.toISOString() || null };
    });
    const reminders = { total: (remSnap.docs || []).length, fired: (remSnap.docs || []).filter(d => d.data().fired === true).length };
    res.json({
      window: '7d',
      generatedAt: new Date().toISOString(),
      tools: toolStats,
      totalCalls,
      okRate: totalCalls ? (okCalls / totalCalls) : 0,
      hallucinations: { count: hallucinations.length, samples: hallucinations.slice(0, 5) },
      reminders,
    });
  } catch (e) {
    console.warn('[mochiStats] failed:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ===== verifyPasscode (Khent/Clair server gate; Breyan/Octagram stay client) =====
const _pcAttempts=new Map();
function _pcHit(ip){const n=Date.now();const a=_pcAttempts.get(ip)||[];const w=a.filter(t=>n-t<60000);w.push(n);_pcAttempts.set(ip,w);if(_pcAttempts.size>400)_pcAttempts.clear();return w.length>8;}
exports.verifyPasscode=functions.https.onRequest(async(req,res)=>{
  res.set('Access-Control-Allow-Origin','*');res.set('Access-Control-Allow-Methods','POST, OPTIONS');res.set('Access-Control-Allow-Headers','Content-Type');
  if(req.method==='OPTIONS'){res.status(204).send('');return;}
  if(req.method!=='POST'){res.status(405).json({error:'POST only'});return;}
  const ip=((req.headers['x-forwarded-for']||'').split(',')[0]||req.ip||'x').trim();
  if(_pcHit(ip)){res.status(429).json({error:'Too many attempts'});return;}
  const code=String((req.body&&req.body.passcode)||req.query.passcode||'').trim();
  if(!code||!isValidPasscodeFormat(code)){res.status(400).json({error:'passcode required'});return;}
  const clair=(process.env.CLAIR_PASSCODE||'').trim();const khent=(process.env.KHENT_PASSCODE||'').trim();
  let username=null;if(clair&&code===clair)username='clairjassen';else if(khent&&code===khent)username='khentsgdz';else{res.status(401).json({error:'Invalid passcode'});return;}
  const emails={clairjassen:process.env.CLAIR_EMAIL||'',khentsgdz:process.env.KHENT_EMAIL||''};
  const email=emails[username];if(!email){res.status(500).json({error:'Server not configured'});return;}
  try{const u=await getAdmin().auth().getUserByEmail(email);const t=await getAdmin().auth().createCustomToken(u.uid,{username});res.json({token:t,username});}catch(e){console.error('verifyPasscode',e.message);res.status(500).json({error:'Auth failed'});}
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
