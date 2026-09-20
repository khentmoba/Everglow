'use strict';

// Everglow Cloud Functions — Motchi memory group.
// Fact extraction, hallucination guard, embeddings, and memory ranking.
// Pure scoring lives in motchi_core.js; Firestore + LLM wiring lives here.

const {
  getAdmin,
  getDb,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
} = require('./common.js');
const {
  parseFactStructure,
  findContradiction,
  rankMemories,
  simpleEmbedding,
  isNearDuplicate,
  shouldExtractMemory,
} = require('./motchi_core.js');
const { getTmdbKey } = require('./motchi_context.js');

// ── Embeddings (hybrid retrieval) ───────────────────────────────
// Remote Agnes vectors when the endpoint answers, local 64-dim hash
// vectors otherwise. Stored facts may carry either space; rankMemories
// compares each fact in the space it shares with the query vector.
async function getRemoteEmbedding(text) {
  const normalized = String(text||'').trim();
  if (!normalized) return null;
  const apiKey = process.env.AGNES_API_KEY;
  if (!apiKey) return null;
  try {
    const resp = await fetch('https://apihub.agnes-ai.com/v1/embeddings', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'text-embedding-3-small', input: normalized }),
      signal: AbortSignal.timeout(8000),
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    const emb = data.data?.[0]?.embedding || data.embedding;
    if (!Array.isArray(emb) || emb.length === 0) return null;
    const norm = Math.sqrt(emb.reduce((s,v)=>s+v*v,0));
    return norm ? emb.map(v=>v/norm) : emb;
  } catch (_) {
    return null;
  }
}

async function getEmbedding(text) {
  const normalized = String(text||'').trim();
  if (!normalized) return null;
  const remote = await getRemoteEmbedding(normalized);
  if (remote) return remote;
  try { return simpleEmbedding(normalized, 64); } catch (_) { return null; }
}

// ── Extraction throttle ──────────────────────────────────────
// Memory extraction costs an LLM call per exchange. Throttle to one
// extraction per caller per window: rapid-fire chats are usually one
// topic, so later exchanges in the window add little. In-memory only —
// a cold instance simply extracts again (today's behavior), and no
// reads or writes are added to the chat path. Explicit remember_fact
// tool calls bypass this entirely.
const EXTRACT_THROTTLE_MS = 30 * 60 * 1000;
const _extractThrottle = new Map(); // lowercased caller -> last epoch ms

function claimMemoryExtractSlot(caller, nowMs = Date.now(), windowMs = EXTRACT_THROTTLE_MS) {
  const key = String(caller || '').toLowerCase();
  const last = _extractThrottle.get(key) || 0;
  if (nowMs - last < windowMs) return false;
  _extractThrottle.set(key, nowMs);
  return true;
}

async function serverExtractAndSaveMemory(userMessage, motchiReply, callerUsername) {
  try {
    if (!userMessage || !motchiReply) return;
    if (!shouldExtractMemory(userMessage, motchiReply)) return;
    if (!claimMemoryExtractSlot(callerUsername)) return;
    const trimmedUser = String(userMessage).slice(0, 800).trim();
    const trimmedReply = String(motchiReply).slice(0, 1200).trim();
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
        model: 'agnes-3.0-flash',
        messages: [
          {
            role: 'system',
            content: 'Extract up to 3 personal facts about Khent or Clair from this exchange. Reply with each fact on its own line in format: CATEGORY|FACT (e.g., "preference|Khent prefers black coffee"). Categories: fact, preference, dislike, goal, date, habit. If nothing worth remembering, reply with exactly: NONE. Prioritize new, specific, durable facts over generic chatter.',
          },
          { role: 'user', content: `User: ${trimmedUser}\nAssistant: ${trimmedReply}` },
        ],
        max_tokens: 250,
        temperature: 0.2,
        stream: false,
      }),
      signal: AbortSignal.timeout(15000),
    });
    if (!resp.ok) return;
    const data = await resp.json();
    const raw = (data.choices?.[0]?.message?.content || '').trim();
    if (!raw || raw === 'NONE') return;
    const lines = raw.split('\n').map(s=>s.trim()).filter(s=>s && s !== 'NONE').slice(0,3);
    if (lines.length === 0) return;
    const db = getDb();
    // Fetch recent facts for semantic dedupe (last 30 — extraction only
    // needs the fresh window; older dupes are harmless).
    let recentDocs = [];
    try {
      const snap = await db.collection('ai_memories').doc('shared').collection('facts').orderBy('createdAt','desc').limit(30).get();
      recentDocs = snap.docs.map(d => ({ id: d.id, fact: d.data().fact || '' })).filter(x => x.fact);
    } catch (_) {}
    for (const line of lines) {
      let fact = line.trim();
      if (!fact || fact.length > 280) continue;
      let category = 'fact';
      if (fact.includes('|')) {
        const parts = fact.split('|');
        category = parts[0].trim().toLowerCase();
        fact = parts.slice(1).join('|').trim();
        if (!['fact','preference','dislike','goal','date','habit'].includes(category)) category = 'fact';
      }
      if (!fact) continue;
      // Semantic dedupe
      let isDup = false;
      for (const existing of recentDocs) {
        if (existing.fact.toLowerCase() === fact.toLowerCase()) { isDup = true; break; }
        try { if (isNearDuplicate(existing.fact, fact, 0.85)) { isDup = true; break; } } catch (_) {}
      }
      if (isDup) continue;
      // (No exact-match query: the semantic pass above already skips
      // case-insensitive duplicates, saving a read per candidate.)
      const parsed = parseFactStructure(fact);
      // Contradiction: same subject + relation, different object —
      // update the stale fact instead of adding a twin.
      const hit = findContradiction(parsed, fact, recentDocs);
      if (hit && hit.id) {
        try {
          await db.collection('ai_memories').doc('shared').collection('facts').doc(hit.id).update({
            fact,
            category,
            object: parsed.object || null,
            confidence: 1.0,
            updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
          });
        } catch (_) {}
        hit.fact = fact;
        continue;
      }
      // Remote-first embedding (local fallback): rankMemories compares
      // each fact in the space it shares with the query vector.
      let embedding = null;
      try { embedding = await getEmbedding(fact); } catch (_) {}
      try {
        const ref = await db.collection('ai_memories').doc('shared').collection('facts').add({
        fact,
        category,
        subject: parsed.subject || null,
        relation: parsed.relation || null,
        object: parsed.object || null,
        addedBy: callerUsername || 'motchi',
        createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
        confidence: 1.0,
        accessCount: 0,
        lastAccessed: null,
        pinned: false,
        source: callerUsername || 'motchi',
        embedding,
        });
        recentDocs.unshift({ id: ref.id, fact });
      } catch (_) {
        recentDocs.unshift({ id: null, fact });
      }
    }
  } catch (e) {
    console.warn('[memoryExtract] failed:', e.message);
  }
}

async function checkHallucinations(replyText, rand = Math.random) {
  try {
    if (!replyText || replyText.length < 20) return;
    // Only media replies can hallucinate titles — skip the TMDB lookups
    // for journal quotes, chat quotes, and everyday chatter.
    if (!/recommend|watch|movie|film|\bshow\b|series|anime|cinema|episode/i.test(replyText)) return;
    // Sampled telemetry: this only feeds the review log, so checking
    // half the replies still surfaces systemic invention at half price.
    if (rand() >= 0.5) return;
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
    // Keep set small — max 3 checks to bound TMDB calls.
    const list = Array.from(candidates).filter(t => t.split(/\s+/).length >= 1 && t.split(/\s+/).length <= 6).slice(0, 3);
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
        await getDb().collection('motchi_stats').doc('hallucinations').collection('checks').add({
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

// ── Server-Side Memory Filtering ─────────────────────────────────
// Replaces client-side memory injection with TF-IDF keyword matching.
// Fetches all memories from Firestore, filters by relevance, decays stale ones.

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
    // Slim: 60 freshest + pinned top-up (was: 150 freshest). Pinned facts
    // ride their own tiny query so an old pin can never fall off the
    // tail when the book grows past the fresh window.
    const factsCol = db.collection('ai_memories').doc('shared').collection('facts');
    const [snapshot, pinnedSnap] = await Promise.all([
      factsCol.orderBy('createdAt', 'desc').limit(60).get(),
      factsCol.where('pinned', '==', true).limit(20).get(),
    ]);

    const memories = [];
    const seenIds = new Set();
    for (const snap of [snapshot, pinnedSnap]) {
    snap.forEach(doc => {
      if (seenIds.has(doc.id)) return;
      seenIds.add(doc.id);
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
    }

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

    // One remote query vector per turn when the endpoint answers;
    // facts stored in the remote space then match semantically instead
    // of by hash overlap. Fails soft to local-only ranking.
    let remoteQueryEmb = null;
    try { remoteQueryEmb = await getRemoteEmbedding(userMessage || ''); } catch (_) {}
    const ranked = rankMemories(decayed, userMessage || '', maxResults, undefined, remoteQueryEmb);
    // W3-C12: bump accessCount/lastAccessed for the memories that were injected (fire-and-forget)
    if (ranked.length > 0) {
      const idsToBump = ranked.map(m => m.id).filter(Boolean).slice(0, 15);
      if (idsToBump.length > 0) {
        // Fire-and-forget: don't block the LLM response path
        (async () => {
          try {
            await Promise.all(idsToBump.map(id =>
              db.collection('ai_memories').doc('shared').collection('facts').doc(id).update({
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

module.exports = {
  getEmbedding,
  getRemoteEmbedding,
  serverExtractAndSaveMemory,
  checkHallucinations,
  selectRelevantMemories,
  claimMemoryExtractSlot,
  EXTRACT_THROTTLE_MS,
};
