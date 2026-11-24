'use strict';

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
const { memoryEvidence } = require('./motchi_agent.js');

const FACTS_CACHE_TTL_MS = 90 * 1000;
let _factsCache = { at: 0, facts: null };

function invalidateMemoryCache() {
  _factsCache = { at: 0, facts: null };
}

const EXTRACT_THROTTLE_MS = 30 * 60 * 1000;
const _extractThrottle = new Map();

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
    if (trimmedUser.length < 10) return;
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
            content: `Extract up to 3 durable personal facts from ONLY the user's words. The speaker is ${callerUsername === 'clairjassen' ? 'Clair' : 'Khent'}. Return a JSON array of {fact, category, quote}; quote must be an exact excerpt supporting the fact. Start fact with its owner (Khent or Clair). Distinguish a report about the partner from the speaker's own preference. Do not extract suggestions, questions, guesses, hypothetical plans or temporary moods. Categories: fact, preference, dislike, goal, date, habit. Return [] if nothing qualifies.`,
          },
          { role: 'user', content: trimmedUser },
        ],
        max_tokens: 500,
        temperature: 0.2,
        stream: false,
        chat_template_kwargs: { enable_thinking: false },
      }),
      signal: AbortSignal.timeout(15000),
    });
    if (!resp.ok) return;
    const data = await resp.json();
    const raw = (data.choices?.[0]?.message?.content || '').trim();
    if (!raw) return;
    let candidates;
    try { candidates = JSON.parse(raw.replace(/^```(?:json)?\s*|\s*```$/g, '')); } catch (_) { return; }
    if (!Array.isArray(candidates)) return;
    const evidence = candidates.slice(0, 3).map((c) => memoryEvidence(c, trimmedUser, callerUsername)).filter(Boolean);
    if (!evidence.length) return;
    const db = getDb();
    let recentDocs = [];
    try {
      if (_factsCache.db === db && _factsCache.facts && Date.now() - _factsCache.at < FACTS_CACHE_TTL_MS) {
        recentDocs = _factsCache.facts;
      }
      else {
        const snap = await db.collection('ai_memories').doc('shared').collection('facts').orderBy('createdAt', 'desc').limit(30).get();
        recentDocs = snap.docs.map((d) => ({ ...d.data(), id: d.id }));
      }
    } catch (e) { console.warn('[memoryExtract] dedupe unavailable:', e.message); return; }
    for (const item of evidence) {
      const { fact, category } = item;
      let isDup = false;
      for (const existing of recentDocs) {
        if (String(existing.fact || '').toLowerCase() === fact.toLowerCase()) { isDup = true; break; }
        try { if (isNearDuplicate(existing.fact, fact, 0.85)) { isDup = true; break; } } catch (_) {}
      }
      if (isDup) continue;
      const parsed = parseFactStructure(fact);
      const hit = findContradiction(parsed, fact, recentDocs);
      if (hit && hit.id && hit.provenance === 'explicit') continue;
      if (hit && hit.id) {
        try {
          await db.collection('ai_memories').doc('shared').collection('facts').doc(hit.id).update({
            fact,
            category,
            object: parsed.object || null,
            ...item,
            embedding: simpleEmbedding(fact),
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
        ...item,
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
    if (!/recommend|watch|movie|film|\bshow\b|series|anime|cinema|episode/i.test(replyText)) return;
    if (rand() >= 0.5) return;
    const apiKey = getTmdbKey();
    if (!apiKey) return;
    const candidates = new Set();
    const dq = replyText.matchAll(/"([^"]{3,60})"/g);
    for (const m of dq) candidates.add(m[1].trim());
    const sq = replyText.matchAll(/'([^']{3,60})'/g);
    for (const m of sq) candidates.add(m[1].trim());
    const bold = replyText.matchAll(/\*\*([^*]{3,60})\*\*/g);
    for (const m of bold) candidates.add(m[1].trim());
    const list = Array.from(candidates).filter(t => t.split(/\s+/).length >= 1 && t.split(/\s+/).length <= 6).slice(0, 3);
    if (list.length === 0) return;
    const hallucinated = [];
    for (const title of list) {
      const q = title.toLowerCase().trim();
      if (['the', 'a', 'an', 'you', 'your', 'this', 'that'].includes(q)) continue;
      const cacheKey = `halluc:check:${q}`;
      let exists = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.tmdb);
      if (exists === null) {
        try {
          const res = await fetch(`https://api.themoviedb.org/3/search/multi?query=${encodeURIComponent(title)}&api_key=${apiKey}`, { signal: AbortSignal.timeout(8000) });
          if (!res.ok) {
            await res.body?.cancel?.().catch(() => {});
            continue;
          }
          const data = await res.json();
          const results = data.results || [];
          exists = results.some(r => {
            const t = (r.title || r.name || '').trim().toLowerCase();
            return t.length > 0 && (t.includes(q) || q.includes(t));
          });
          _setExternalCache(cacheKey, exists);
        } catch (_) {
          continue;
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

async function selectRelevantMemoryFacts(userMessage, maxResults = 10, db = getDb()) {
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
    const accessed = _factsCache.accessed;
    for (const m of ranked) {
      if (accessed?.has(m.id)) continue;
      accessed?.add(m.id);
      db.collection('ai_memories').doc('shared').collection('facts').doc(m.id).update({
        accessCount: getAdmin().firestore.FieldValue.increment(1),
        lastAccessed: getAdmin().firestore.FieldValue.serverTimestamp(),
      }).catch((e) => console.warn('[memory] access update failed:', e.message));
    }
    return ranked;
  } catch (e) {
    console.warn('selectRelevantMemories error:', e.message);
    return [];
  }
}

async function selectRelevantMemories(userMessage, maxResults = 10, db = getDb()) {
  return (await selectRelevantMemoryFacts(userMessage, maxResults, db)).map((m) => m.fact);
}

async function selectCoreProfileNotes(db = getDb(), structured = false) {
  try {
    const memories = await loadMemoryFacts(db);
    return memories
      .filter((m) => m.pinned === true && m.category === 'profile' && String(m.fact || '').trim())
      .sort((a, b) => (a.createdAt?.getTime?.() || 0) - (b.createdAt?.getTime?.() || 0))
      .slice(0, 8)
      .map((m) => structured ? m : String(m.fact).trim());
  } catch (e) {
    console.warn('selectCoreProfileNotes error:', e.message);
    return [];
  }
}

module.exports = {
  invalidateMemoryCache,
  serverExtractAndSaveMemory,
  checkHallucinations,
  selectRelevantMemories,
  selectRelevantMemoryFacts,
  selectCoreProfileNotes,
  loadMemoryFacts,
  claimMemoryExtractSlot,
  EXTRACT_THROTTLE_MS,
};
