//
// Everglow Cloud Functions - composition root.
// Function groups live in dedicated modules; this file imports them
// and re-exports the same names so deploy analysis + client contract
// stay unchanged.
//
'use strict';

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

const {
  APP_VERSION,
  getAdmin,
  getDb,
  requireAuth,
  getVerifiedUsername,
  isPrivateIpv4,
  isPrivateIp,
  isPublicDnsHost,
  isAllowedBookTextUrl,
} = require('./common.js');

const {
  proxyBookText,
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyAnimeImage,
  proxyGalleryImage,
  cleanupGallery,
  proxyScanlation,
  proxyFetchHtml,
  proxyEmbed,
  proxyMangaDex,
  proxyVideoStream,
  proxyWatchStream,
  initWasm,
} = require('./media_proxies.js');

const { sendFCMToUser, sendFCMToBoth, logToolCall } = require('./triggers.js');
const {
  onNewChatMessage,
  onNewMood,
  onNewStarDrop,
  onNewWatchlistItem,
  onNewGalleryPhoto,
  onWatchPartyInvite,
  onNewMilestone,
} = require('./triggers.js');

const { proxySpotifySearch, spotifyExchange, spotifyRefresh, spotifyCurrentlyPlaying } = require('./spotify.js');
const { verifyPasscode } = require('./passcode.js');

/** In-memory cache for Mochi's persona document. */
let _personaCache = null;

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
exports.proxyTmdb = functions.runWith({ minInstances: 1 }).https.onRequest(async (req, res) => {
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
exports.proxyLastfm = functions.runWith({ minInstances: 1 }).https.onRequest(async (req, res) => {
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

// Re-exports: keep the deploy surface identical.
module.exports = Object.assign({}, module.exports, {
  proxyBookText,
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyAnimeImage,
  proxyGalleryImage,
  cleanupGallery,
  proxyScanlation,
  proxyFetchHtml,
  proxyEmbed,
  proxyMangaDex,
  proxyVideoStream,
  proxyWatchStream,
  proxySpotifySearch,
  spotifyExchange,
  spotifyRefresh,
  spotifyCurrentlyPlaying,
  verifyPasscode,
  onNewChatMessage,
  onNewMood,
  onNewStarDrop,
  onNewWatchlistItem,
  onNewGalleryPhoto,
  onWatchPartyInvite,
  onNewMilestone,
});

