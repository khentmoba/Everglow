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
  selectPromptMemories,
  simpleEmbedding,
  isNearDuplicate,
  shouldExtractMemory,
} = require('./motchi_core.js');
const { getTmdbKey } = require('./motchi_context.js');

// Memory vectors are local 64-dim hash embeddings (motchi_core.js).
// Nothing on the chat path — or the nightly sweep — spends an
// embedding API call; ranking is keywords plus local cosine.

// ── Facts cache ──────────────────────────────────────────────
// selectRelevantMemories runs every turn but the book barely moves
// (extraction is throttled to one write per 30 min, the rest are
// explicit). Cache the raw fetch briefly; ranking still runs fresh
// per message, and every write path invalidates. In-memory only — a
// cold instance just reads again.
const FACTS_CACHE_TTL_MS = 90 * 1000;
let _factsCache = { at: 0, facts: null };

function invalidateMemoryCache() {
  _factsCache = { at: 0, facts: null };
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
    const apiKey = process.env.TOKENHARBOR_API_KEY;
    if (!apiKey) return;
    const resp = await fetch('https://tokenharbor.ai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'glm-5.3-flash',
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
        enable_thinking: false,
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
          invalidateMemoryCache();
        } catch (_) {}
        hit.fact = fact;
        continue;
      }
      let embedding = null;
      try { embedding = simpleEmbedding(fact); } catch (_) {}
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
        invalidateMemoryCache();
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

// Shared by prompt retrieval and read_memories. Preserve the app's former
// 150-fact coverage, plus old pins; cache structured facts, not plain text.
async function loadMemoryFacts(db = getDb()) {
  if (_factsCache.db === db && _factsCache.facts && Date.now() - _factsCache.at < FACTS_CACHE_TTL_MS) {
    return _factsCache.facts;
  }
  const factsCol = db.collection('ai_memories').doc('shared').collection('facts');
  const [recent, pinned] = await Promise.all([
    factsCol.orderBy('createdAt', 'desc').limit(150).get(),
    factsCol.where('pinned', '==', true).limit(20).get(),
  ]);
  const facts = new Map();
  for (const snap of [recent, pinned]) {
    for (const doc of snap.docs) {
      const data = doc.data();
      facts.set(doc.id, {
        ...data,
        id: doc.id,
        fact: data.fact || '',
        createdAt: data.createdAt?.toDate?.() || null,
        occurredAt: data.occurredAt?.toDate?.() || null,
        lastAccessed: data.lastAccessed?.toDate?.() || null,
      });
    }
  }
  const memories = [...facts.values()].filter((f) => f.fact);
  _factsCache = { at: Date.now(), facts: memories, db, accessed: new Set() };
  return memories;
}

async function selectRelevantMemories(userMessage, maxResults = 10, db = getDb()) {
  try {
    const memories = await loadMemoryFacts(db);
    const now = new Date();
    const decayed = memories.map((m) => {
      const c = { ...m };
      if (!c.pinned && c.lastAccessed) {
        const days = (now - c.lastAccessed) / 86400000;
        if (days > 90) c.confidence = (c.confidence ?? 1) * Math.pow(0.5, days / 90);
      }
      return c;
    }).filter((m) => m.pinned || (m.confidence ?? 1) >= 0.15);
    const ranked = selectPromptMemories(decayed, userMessage || '', maxResults);
    // At most one access write per selected fact per cache window.
    for (const m of ranked) {
      if (_factsCache.accessed.has(m.id)) continue;
      _factsCache.accessed.add(m.id);
      db.collection('ai_memories').doc('shared').collection('facts').doc(m.id).update({
        accessCount: getAdmin().firestore.FieldValue.increment(1),
        lastAccessed: getAdmin().firestore.FieldValue.serverTimestamp(),
      }).catch((e) => console.warn('[memory] access update failed:', e.message));
    }
    return ranked.map((m) => m.fact);
  } catch (e) {
    console.warn('selectRelevantMemories error:', e.message);
    return [];
  }
}

module.exports = {
  invalidateMemoryCache,
  serverExtractAndSaveMemory,
  checkHallucinations,
  selectRelevantMemories,
  loadMemoryFacts,
  claimMemoryExtractSlot,
  EXTRACT_THROTTLE_MS,
};
