'use strict';

// Everglow Cloud Functions — Mochi memory group.
// Fact extraction, hallucination guard, embeddings, and memory ranking.
// Pure scoring lives in mochi_core.js; Firestore + LLM wiring lives here.

const {
  getAdmin,
  getDb,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
} = require('./common.js');
const {
  parseFactStructure,
  rankMemories,
  simpleEmbedding,
  isNearDuplicate,
} = require('./mochi_core.js');
const { getTmdbKey } = require('./mochi_context.js');

// ── W4-C9: Embedding scaffold (hybrid retrieval) ────────────────
// Placeholder for future vector search. Stores null for now, keeps
// memory schema forward-compatible. When AGNES embeddings are enabled,
// getEmbedding(text) will return a float[] and rankMemories can use
// cosine similarity alongside token scoring.
async function getEmbedding(text) {
  const normalized = String(text||'').trim();
  if (!normalized) return null;
  const apiKey = process.env.AGNES_API_KEY;
  if (apiKey) {
    try {
      const resp = await fetch('https://apihub.agnes-ai.com/v1/embeddings', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: 'text-embedding-3-small', input: normalized }),
        signal: AbortSignal.timeout(8000),
      });
      if (resp.ok) {
        const data = await resp.json();
        const emb = data.data?.[0]?.embedding || data.embedding;
        if (Array.isArray(emb) && emb.length > 0) {
          const norm = Math.sqrt(emb.reduce((s,v)=>s+v*v,0));
          return norm ? emb.map(v=>v/norm) : emb;
        }
      }
    } catch (_) {}
  }
  try { return simpleEmbedding(normalized, 64); } catch (_) { return null; }
}

async function serverExtractAndSaveMemory(userMessage, mochiReply, callerUsername) {
  try {
    if (!userMessage || !mochiReply) return;
    const trimmedUser = String(userMessage).slice(0, 800).trim();
    const trimmedReply = String(mochiReply).slice(0, 1200).trim();
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
    // Fetch recent facts for semantic dedupe (last 100)
    let recentFacts = [];
    try {
      const snap = await db.collection('ai_memories').doc('shared').collection('facts').orderBy('createdAt','desc').limit(100).get();
      recentFacts = snap.docs.map(d => d.data().fact || '').filter(Boolean);
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
      for (const existing of recentFacts) {
        if (existing.toLowerCase() === fact.toLowerCase()) { isDup = true; break; }
        try { if (isNearDuplicate(existing, fact, 0.85)) { isDup = true; break; } } catch (_) {}
      }
      if (isDup) continue;
      // Double-check exact Firestore match
      try {
        const existing = await db.collection('ai_memories').doc('shared').collection('facts').where('fact','==',fact).limit(1).get();
        if (!existing.empty) continue;
      } catch (_) {}
      const parsed = parseFactStructure(fact);
      let embedding = null;
      try { embedding = await getEmbedding(fact); } catch (_) {}
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
        embedding,
      });
      recentFacts.unshift(fact);
    }
  } catch (e) {
    console.warn('[memoryExtract] failed:', e.message);
  }
}

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
    const snapshot = await db.collection('ai_memories').doc('shared').collection('facts')
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
  serverExtractAndSaveMemory,
  checkHallucinations,
  selectRelevantMemories,
};
