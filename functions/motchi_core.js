'use strict';

/**
 * Pure Motchi intelligence helpers shared by the proxy and scheduled
 * functions. Kept dependency-free so `node --test` can verify retrieval,
 * trivia, insights, context selection, and recap composition without
 * Firestore or an LLM.
 */

function tokenize(text) {
  const matches = String(text || '').toLowerCase().match(/[a-z0-9]{3,}/g);
  return matches ? [...new Set(matches)] : [];
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value === 'number') return new Date(value);
  if (value.toDate && typeof value.toDate === 'function') return value.toDate();
  return null;
}

/**
 * Best-effort inference of subject/relation/object from a plain fact.
 */
function parseFactStructure(fact) {
  const trimmed = String(fact || '').trim();
  const match = trimmed.match(
    /^(Khent and Clair|Clair and Khent|Khent|Clair|Dada|Mama)\s+(prefers?|loves?|likes?|dislikes?|hates?|wants?|enjoys?|studies?|rides?|plays?|watched?|watches?|read|reads?|went to|visited?|dreams? of|is|was|has|had|works at|started|finished|learned|learnt)\s+(.+)$/i
  );
  if (!match) return { subject: null, relation: null, object: null };
  return { subject: match[1], relation: match[2], object: match[3] };
}

function normalizeFact(fact) {
  return {
    fact: String(fact.fact || ''),
    category: fact.category || 'fact',
    subject: fact.subject || null,
    relation: fact.relation || null,
    object: fact.object || null,
    occurredAt: toDate(fact.occurredAt),
    createdAt: toDate(fact.createdAt),
    confidence: Number(fact.confidence ?? 1),
    pinned: fact.pinned === true,
  };
}

function scoreMemory(rawFact, tokens, now) {
  const fact = normalizeFact(rawFact);
  const current = now || new Date();
  let score = Math.min(Math.max(fact.confidence, 0.1), 1);
  if (fact.pinned) score += 2;

  if (fact.createdAt) {
    const ageDays = (current - fact.createdAt) / 86400000;
    if (ageDays >= 0 && ageDays <= 30) score += 1;
  }

  if (fact.occurredAt) {
    const sameDay =
      fact.occurredAt.getUTCMonth() === current.getUTCMonth() &&
      fact.occurredAt.getUTCDate() === current.getUTCDate();
    if (sameDay) score += 3;
  }

  if (tokens.length === 0) return score;

  const haystack = [
    fact.fact,
    fact.subject || '',
    fact.relation || '',
    fact.object || '',
    fact.category,
  ].join(' ').toLowerCase();
  const subject = String(fact.subject || '').toLowerCase();
  const object = String(fact.object || '').toLowerCase();

  for (const token of tokens) {
    if (haystack.includes(token)) score += 1.5;
    if (subject.includes(token) || object.includes(token)) score += 2;
  }
  return score;
}

function hashToken(token) {
  let h = 2166136261;
  for (let i = 0; i < token.length; i++) {
    h ^= token.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function simpleEmbedding(text, dim = 64) {
  const tokens = tokenize(String(text || '').toLowerCase());
  if (tokens.length === 0) return null;
  const vec = new Array(dim).fill(0);
  for (const tok of tokens) {
    const h = hashToken(tok);
    const idx = h % dim;
    vec[idx] += 1;
    vec[(h * 31) % dim] += 0.5;
  }
  const norm = Math.sqrt(vec.reduce((s, v) => s + v * v, 0));
  if (norm === 0) return null;
  return vec.map(v => v / norm);
}

function cosineSimilarity(a, b) {
  if (!a || !b || a.length !== b.length) return 0;
  let dot = 0;
  for (let i = 0; i < a.length; i++) dot += a[i] * b[i];
  return dot;
}

function rankMemories(facts, query, maxResults = 30, now = new Date()) {
  const tokens = tokenize(query);
  const current = now || new Date();
  const queryEmb = simpleEmbedding(query);
  const scored = (facts || [])
    .filter((f) => f && String(f.fact || '').trim())
    .map((fact) => {
      let score = scoreMemory(fact, tokens, current);
      try {
        const factEmb = fact.embedding ? fact.embedding : simpleEmbedding(fact.fact || '');
        if (queryEmb && factEmb && factEmb.length === queryEmb.length) {
          const cos = cosineSimilarity(queryEmb, factEmb);
          score += cos * 2;
          fact._cos = cos;
        }
      } catch (_) {}
      return { fact, score };
    });
  scored.sort((a, b) => b.score - a.score || String(a.fact.fact).localeCompare(String(b.fact.fact)));
  return scored.slice(0, maxResults).map((entry) => entry.fact);
}

/**
 * True when a stored memory embedding can't match the local query
 * vector (missing, malformed, or built with other dimensions, e.g. the
 * retired remote vectors). The nightly sweep recomputes those locally.
 */
function needsEmbeddingBackfill(embedding, dim = 64) {
  return !Array.isArray(embedding) || embedding.length !== dim;
}

function isNearDuplicate(a, b, threshold = 0.88) {
  const embA = simpleEmbedding(a);
  const embB = simpleEmbedding(b);
  if (!embA || !embB) {
    const na = a.toLowerCase().replace(/[^a-z0-9\s]/g,'').trim();
    const nb = b.toLowerCase().replace(/[^a-z0-9\s]/g,'').trim();
    return na === nb || na.includes(nb) || nb.includes(na);
  }
  return cosineSimilarity(embA, embB) >= threshold;
}
// ── Context block pre-selection ────────────────────────────────
// Picks which Firestore-backed context blocks to fetch BEFORE any read
// happens, so a chat turn fetches ~8 small blocks instead of ~20.
// Single words match whole words (case-insensitive); entries with a
// space match as phrases. Kept generous: a spurious block costs one
// cached read, a missed block costs Motchi her awareness.
const CONTEXT_BLOCK_KEYWORDS = {
  mood: ['mood', 'moods', 'feeling', 'feelings', 'feel', 'felt', 'emotion', 'emotions', 'happy', 'sad', 'stressed', 'tired', 'excited', 'anxious', 'lonely', 'pattern', 'patterns'],
  watchlist: ['movie', 'movies', 'film', 'films', 'watch', 'watched', 'watching', 'watchlist', 'show', 'shows', 'series', 'episode', 'episodes', 'cinema', 'tv', 'drama', 'netflix'],
  books: ['book', 'books', 'read', 'reading', 'author', 'authors', 'novel', 'novels', 'chapter', 'chapters', 'library'],
  starlight: ['starlight', 'jar', 'grateful', 'gratitude', 'thankful', 'note', 'notes'],
  chat: ['chat', 'sanctuary', 'said', 'say', 'tell', 'told', 'message', 'messages', 'talk', 'talked', 'talking', 'convo'],
  music: ['music', 'song', 'songs', 'spotify', 'playlist', 'play', 'playing', 'artist', 'artists', 'album', 'track', 'tracks', 'listen', 'listening', 'karaoke', 'jukebox'],
  garden: ['garden', 'plant', 'plants', 'planted', 'flower', 'flowers', 'lily', 'lilies', 'bloom', 'blooms'],
  canvas: ['draw', 'drawing', 'drawings', 'canvas', 'art', 'sketch', 'sketches', 'paint', 'painting'],
  play_zone: ['game', 'games', 'gaming', 'score', 'scores', 'playzone', 'play', 'win', 'won', 'rank', 'ranked'],
  relationship: ['anniversary', 'together', 'relationship', 'couple', 'pattern', 'patterns', 'stats', 'days'],
  activity: ['did', 'today', 'yesterday', 'activity', 'activities', 'been'],
  sessions: ['remember', 'memory', 'memories', 'history', 'past', 'earlier', 'before', 'yesterday', 'last week', 'recap', 'conversation', 'conversations', 'previously', 'start', 'started', 'beginning'],
  calendar: ['calendar', 'schedule', 'scheduled', 'schedules', 'upcoming', 'coming up', 'tomorrow', 'event', 'events', 'this month', 'this week', 'plan', 'plans', 'planning', 'date', 'dates', 'dating', 'anniversary', 'dinner'],
  journal: ['journal', 'diary', 'diaries', 'reflect', 'reflection', 'entry', 'entries', 'wrote', 'write', 'writing'],
  bucket: ['bucket', 'dream', 'dreams', 'wish', 'wishes', 'goal', 'goals', 'someday'],
  travel: ['trip', 'trips', 'travel', 'travels', 'vacation', 'getaway', 'itinerary', 'flight', 'flights', 'hotel', 'hotels'],
  wellness: ['habit', 'habits', 'streak', 'streaks', 'workout', 'workouts', 'gym', 'routine', 'routines', 'health', 'exercise', 'run', 'running'],
  budget: ['budget', 'spend', 'spent', 'spending', 'money', 'expense', 'expenses', 'peso', 'pesos', 'php', 'cost', 'costs', 'price', 'prices', 'bought', 'buy'],
};

// Awareness set: fetched when the query names nothing in particular.
// The pricey `sessions` scan is deliberately NOT here — it only runs
// when the message asks about history, memory, or the past.
const DEFAULT_CONTEXT_KEYS = ['chat', 'mood', 'activity', 'watchlist', 'starlight', 'books', 'calendar'];

/** Block keys to fetch for a query: keyword hits first, defaults fill. */
function selectBlockKeys(query, maxKeys = 7) {
  const lowered = String(query || '').toLowerCase();
  const words = new Set(lowered.split(/[^a-z0-9]+/).filter(Boolean));
  const scored = Object.keys(CONTEXT_BLOCK_KEYWORDS).map((key) => {
    let score = 0;
    for (const kw of CONTEXT_BLOCK_KEYWORDS[key]) {
      if (kw.includes(' ')) {
        if (lowered.includes(kw)) score += 2;
      } else if (words.has(kw)) {
        score += 2;
      }
    }
    const rank = DEFAULT_CONTEXT_KEYS.indexOf(key);
    return { key, score, rank: rank === -1 ? 100 : rank };
  });
  scored.sort((a, b) => b.score - a.score || a.rank - b.rank || (a.key < b.key ? -1 : 1));
  return scored.slice(0, maxKeys).map((s) => s.key);
}

function selectContextBlocks(blocks, query, maxBlocks = 6, alwaysKeep = 'proactive') {
  const list = (blocks || []).filter((b) => b && b.key);
  if (list.length === 0) return [];
  const tokens = tokenize(query);
  if (tokens.length === 0) return list.slice(0, maxBlocks);

  const score = (block) => {
    const haystack = `${block.key} ${block.value || ''}`.toLowerCase();
    let value = 0;
    for (const token of tokens) {
      if (haystack.includes(token)) value += 1.5;
    }
    return value;
  };

  const sorted = [...list].sort(
    (a, b) => score(b) - score(a) || String(a.key).localeCompare(String(b.key))
  );
  const always = sorted.filter((b) => b.key === alwaysKeep);
  const rest = sorted.filter((b) => b.key !== alwaysKeep);
  return [...always, ...rest].slice(0, maxBlocks);
}

/**
 * Deterministic memory trivia: blank the object of real facts and use
 * other objects/subjects as distractors.
 */
function generateTrivia(facts, count = 5, random = Math.random) {
  const normalized = (facts || [])
    .map(normalizeFact)
    .filter((f) => f.fact && f.object && f.object.trim());

  const shuffled = [...normalized].sort(() => random() - 0.5);
  const selected = shuffled.slice(0, count);
  const pool = [
    ...normalized.map((f) => f.object.trim()).filter(Boolean),
    ...normalized.map((f) => f.subject).filter(Boolean),
  ];

  return selected.map((fact) => {
    const subject = fact.subject || 'Motchi';
    const object = fact.object.trim();
    const question = `${subject} ${fact.relation || ''} _____`
      .replace(/\s+/g, ' ')
      .trim();
    const choices = [object];
    const candidates = [...new Set(pool)].filter((c) => c !== object);
    candidates.sort(() => random() - 0.5);
    for (const candidate of candidates) {
      if (choices.length >= 4) break;
      choices.push(candidate);
    }
    const answerIndex = choices.indexOf(object);
    return {
      question,
      choices,
      answerIndex,
      explanation: fact.fact,
    };
  });
}

/**
 * Explainable pattern insights from mood and activity logs.
 */
function computeInsights({ moods = [], activities = [] } = {}) {
  const insights = [];
  const moodCounts = {};
  for (const mood of moods || []) {
    const key = String(mood || '').trim().toLowerCase();
    if (!key) continue;
    moodCounts[key] = (moodCounts[key] || 0) + 1;
  }
  const moodEntries = Object.entries(moodCounts);
  if (moodEntries.length > 0) {
    const top = moodEntries.reduce((a, b) => (a[1] >= b[1] ? a : b));
    insights.push({
      title: 'Mood signal',
      detail: `"${top[0]}" shows up most often in recent check-ins.`,
      category: 'mood',
    });
  }

  const categoryCounts = {};
  for (const activity of activities || []) {
    const lower = String(activity || '').toLowerCase();
    if (/movie|watch|anime/.test(lower)) {
      categoryCounts['movie night'] = (categoryCounts['movie night'] || 0) + 1;
    } else if (/game|valorant|mobile legends/.test(lower)) {
      categoryCounts['gaming'] = (categoryCounts['gaming'] || 0) + 1;
    } else if (/food|eat|cook/.test(lower)) {
      categoryCounts['food'] = (categoryCounts['food'] || 0) + 1;
    } else if (/date/.test(lower)) {
      categoryCounts['date'] = (categoryCounts['date'] || 0) + 1;
    }
  }
  const activityEntries = Object.entries(categoryCounts);
  if (activityEntries.length > 0) {
    const top = activityEntries.reduce((a, b) => (a[1] >= b[1] ? a : b));
    insights.push({
      title: 'Shared rhythm',
      detail: `Recent activity leans toward ${top[0]}.`,
      category: 'activity',
    });
  }
  return insights;
}

function firstDateOf(value) {
  const date = toDate(value);
  return date ? date.toISOString().slice(0, 10) : '';
}

/**
 * Compose a warm, data-grounded "today" recap. Used by the Motchi Today
 * tool and as the fallback body when the scheduled LLM digest fails.
 */
function composeTodayRecap({
  dateLabel = '',
  moods = [],
  activities = [],
  watchlist = [],
  starlight = [],
  memories = [],
  insights = [],
  now,
} = {}) {
  const parts = [];
  const date = dateLabel || new Date().toISOString().slice(0, 10);
  parts.push(`Today is ${date}.`);

  if (moods && moods.length > 0) {
    const moodLine = moods
      .map((m) => `${m.uid || 'someone'} feels ${m.mood || 'okay'}`)
      .join(', ');
    parts.push(`${moodLine}.`);
  } else {
    parts.push('No mood logged yet today.');
  }

  if (activities && activities.length > 0) {
    parts.push(`Recently: ${activities.slice(0, 3).join(', ')}.`);
  }

  if (starlight && starlight.length > 0) {
    parts.push(`A star in the jar: "${starlight[0]}".`);
  }

  if (watchlist && watchlist.length > 0) {
    parts.push(`On the watchlist: ${watchlist.slice(0, 2).join(', ')}.`);
  }

  const onThisDay = (memories || []).filter((m) => {
    const occurred = toDate(m.occurredAt);
    if (!occurred) return false;
    const current = now ? toDate(now) : new Date();
    return (
      occurred.getUTCMonth() === current.getUTCMonth() &&
      occurred.getUTCDate() === current.getUTCDate()
    );
  });
  if (onThisDay.length > 0) {
    parts.push(`On this day: ${onThisDay[0].fact}.`);
  }

  if (insights && insights.length > 0) {
    parts.push(insights[0].detail);
  }
  parts.push('Have a beautiful day together!');
  return parts.join(' ');
}

/// Flattens an Agnes message content block (string or parts array) to text.
function getMessageText(content) {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => (typeof part === 'string' ? part : (part?.text || '')))
      .join(' ');
  }
  return '';
}

/// Rough input-token estimate for Agnes prompts.
/// Counts CJK characters (roughly 1.5 tokens each); the rest ~4 chars/token.
function estimateTokens(text) {
  if (!text) return 0;
  // Count CJK characters (roughly 1.5 tokens each) and emoji (1 token each)
  const cjk = (text.match(/[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]/g) || []).length;
  const nonCjk = text.length - cjk;
  return Math.ceil(nonCjk / 4) + Math.ceil(cjk * 1.5);
}

// ── Philippine-time dates ──────────────────────────────────────
// Cloud Run thinks in UTC but Khent and Clair live in PHT (UTC+8, no
// daylight saving — the offset never changes). Day-keyed records
// (moods, digests) use PHT so late-night entries land on the right day.
const PHT_OFFSET_MS = 8 * 60 * 60 * 1000;

/** YYYY-MM-DD of the PHT calendar day containing `nowMs`. */
function phtDateString(nowMs = Date.now()) {
  return new Date(nowMs + PHT_OFFSET_MS).toISOString().slice(0, 10);
}

/**
 * UTC instants bounding the PHT calendar day containing `nowMs`:
 * { start, end } as Dates (end is the last millisecond of the day).
 */
function phtDayBounds(nowMs = Date.now()) {
  const pht = new Date(nowMs + PHT_OFFSET_MS);
  const startMs = Date.UTC(pht.getUTCFullYear(), pht.getUTCMonth(), pht.getUTCDate()) - PHT_OFFSET_MS;
  return { start: new Date(startMs), end: new Date(startMs + 24 * 60 * 60 * 1000 - 1) };
}

/**
 * Heuristic gate to avoid calling the memory extraction LLM on casual
 * chatter, greetings, search commands, or questions that contain no
 * personal facts about Khent or Clair.
 */
function shouldExtractMemory(userMessage, motchiReply) {
  const user = String(userMessage || '').trim();
  const reply = String(motchiReply || '').trim();
  if (user.length < 8 || reply.length < 10) return false;

  const lower = user.toLowerCase();

  // Explicit memory cues always pass (English + Bisaya + Tagalog)
  if (/remember\b|don't forget|keep in mind|note that|our anniversary|my birthday|her birthday|his birthday|hinumdumi|tandaan/i.test(lower)) {
    return true;
  }

  // Pure commands / lookups without personal signals should not trigger extraction
  if (/^(search|find|play|what is the weather|what's the weather|how's the weather|show me|list|give me)\b/i.test(lower)) {
    return false;
  }

  // Casual greetings and acknowledgments without substantive info
  if (/^(hi|hello|hey|good morning|good afternoon|good evening|good night|bye|thanks|thank you|ok|okay|got it|cool|nice|yes|no|yep|nope)[!.,\s]*$/i.test(lower)) {
    return false;
  }

  // Must have a personal subject marker (Khent, Clair, I, my, we, our,
  // plus Bisaya/Tagalog pronouns so code-switched chat is remembered too)
  const hasSubject = /\b(i|my|i'm|im|i've|ive|i'd|we|our|khent|clair|dada|mama|ako|ko|nako|mi|namo|amo|kami|kita|ta|siya|iya|mo|ikaw|ka)\b/i.test(lower);
  if (!hasSubject) return false;

  // Must have a durable fact/preference/habit/milestone indicator
  // (English + Bisaya/Tagalog: gusto, paborito, kanunay, eskwela…)
  const hasSignal = /\b(prefer|prefers|preference|love|loves|like|likes|hate|hates|dislike|dislikes|favorite|favourite|always|never|started|finished|bought|studies|study|school|college|csucc|ustp|works?|job|dream|dreams|hope|goals?|habit|habits|gym|bike|rides?|rode|winner x|fuji|camera|coffee|food|allergic|allergy|fears?|scared of|miss|missing|gusto|ganahan|paborito|mahal|lami|kanunay|pirme|ayaw|eskwela|trabaho|damgo|hadlok|nahadlok|gimingaw|mingaw|palit|sugod|human)\b/i.test(lower);

  if (hasSignal) return true;

  // Longer multi-sentence reflective exchanges (> 120 chars) with personal subject
  return user.length >= 120;
}

// Agnes 3.0 Flash: 512K context window, generous token budget.
// Use ~25% of context for input safety; reserve rest for output + tool loops.
const AGNES_INPUT_TOKEN_BUDGET = 120000;

/**
 * Parses a reminder/casual date phrase into a UTC instant. Accepts ISO
 * 8601 plus "today/tonight/tomorrow [at H[:MM] am/pm]", "in N
 * minutes/hours/days/weeks", and "next week". Clock times are read as
 * Philippine wall time (the server runs on UTC, but Khent and Clair live
 * in PHT) — "tomorrow at 3pm" means 3pm in Cabadbaran, not 3pm UTC.
 * Returns null when nothing parseable is found.
 */
function parseReminderDate(raw, nowMs = Date.now()) {
  const text = String(raw || '').trim();
  if (!text) return null;
  const lower = text.toLowerCase();
  // Phrases first: the lenient Date parser below mangles inputs like
  // "tonight at 8" into nonsense years, so known relatives win.

  const parseClock = () => {
    const m = lower.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/);
    if (!m) return null;
    let h = parseInt(m[1], 10);
    const min = m[2] ? parseInt(m[2], 10) : 0;
    const ap = (m[3] || '').toLowerCase();
    if (ap === 'pm' && h < 12) h += 12;
    if (ap === 'am' && h === 12) h = 0;
    if (h > 23 || min > 59) return null;
    return { h, min, explicit: ap === 'am' || ap === 'pm' };
  };
  // PHT calendar day `dayOffset` from now, at h:min Philippine wall time.
  const phtWall = (dayOffset, h, min) => {
    const phtNow = new Date(nowMs + PHT_OFFSET_MS);
    const utcMidnight = Date.UTC(phtNow.getUTCFullYear(), phtNow.getUTCMonth(), phtNow.getUTCDate());
    return new Date(utcMidnight + dayOffset * 86400000 + (h * 60 + min) * 60000 - PHT_OFFSET_MS);
  };

  const rel = lower.match(/in\s+(\d+)\s*(minute|min|hour|hr|day|week)/);
  if (rel) {
    const n = parseInt(rel[1], 10);
    const unit = rel[2].startsWith('min') ? 60000
      : (rel[2].startsWith('hour') || rel[2] === 'hr') ? 3600000
      : rel[2].startsWith('week') ? 7 * 86400000 : 86400000;
    return new Date(nowMs + n * unit);
  }
  if (/\btomorrow\b/.test(lower)) {
    const clock = parseClock();
    if (clock) return phtWall(1, clock.h, clock.min);
    return new Date(nowMs + 24 * 3600000);
  }
  if (/\btonight\b/.test(lower)) {
    const clock = parseClock();
    if (!clock) return phtWall(0, 20, 0);
    let h = clock.h;
    // Bare hours at night mean evening: "tonight at 8" is 8pm.
    if (!clock.explicit) {
      if (h >= 1 && h <= 11) h += 12;
      else if (h === 12) h = 0;
    }
    return phtWall(0, h, clock.min);
  }
  if (/\btoday\b/.test(lower)) {
    const clock = parseClock();
    if (clock) {
      const d = phtWall(0, clock.h, clock.min);
      // That time already passed today — they mean tomorrow.
      return d.getTime() <= nowMs ? phtWall(1, clock.h, clock.min) : d;
    }
    return new Date(nowMs + 3600000);
  }
  if (/next week/.test(lower)) return new Date(nowMs + 7 * 86400000);
  // Last resort: ISO 8601 and other directly parseable dates.
  const direct = new Date(text);
  if (!Number.isNaN(direct.getTime())) return direct;
  return null;
}

// ── Context-block trimming (C1: slim prompt) ────────────────────
// Pure formatters for the two biggest context blocks (sanctuary chat
// history and archived sessions). The live conversation already carries
// recent turns, so these blocks keep a short tail + a count line
// instead of full history — roughly half the tokens, same awareness.
const CHAT_CONTEXT_SHOWN = 12;
const CHAT_MESSAGE_CHARS = 400;
const SESSION_SUMMARY_SHOWN = 6;
const SESSION_SUMMARY_CHARS = 600;
const SESSION_BLOCKS_SHOWN = 3;
const SESSION_CHAR_LIMIT = 8000;
const SESSION_MESSAGE_CHARS = 1500;

function truncateText(text, max) {
  const s = String(text || '');
  if (s.length <= max) return s;
  return s.slice(0, max) + '… [truncated]';
}

/**
 * Formats sanctuary chat lines (chronological "who: text" strings).
 * Keeps the newest `shown` lines, capped per line, plus a count of the
 * older messages Motchi can still pull via read_chat_messages.
 */
function formatChatContext(lines, shown = CHAT_CONTEXT_SHOWN, perMessage = CHAT_MESSAGE_CHARS) {
  const list = (lines || []).filter((l) => String(l || '').trim());
  if (list.length === 0) return '';
  const tail = list.slice(-shown).map((l) => truncateText(l, perMessage));
  const older = list.length - tail.length;
  const head = older > 0 ? `…plus ${older} earlier messages (use read_chat_messages for more)\n` : '';
  return `Recent sanctuary chat:\n${head}${tail.join('\n')}`;
}

/**
 * Formats archived session summaries + raw session blocks with hard
 * bounds. Summaries are cheapest (one line each); raw blocks are
 * capped by count, chars, and per-message length.
 */
function formatSessionContext(summaries, sessions, opts = {}) {
  const {
    summaryShown = SESSION_SUMMARY_SHOWN,
    summaryChars = SESSION_SUMMARY_CHARS,
    blocksShown = SESSION_BLOCKS_SHOWN,
    charLimit = SESSION_CHAR_LIMIT,
    perMessage = SESSION_MESSAGE_CHARS,
  } = opts;
  const parts = [];
  const sums = (summaries || []).filter((s) => String(s || '').trim());
  if (sums.length > 0) {
    const lines = sums.slice(0, summaryShown).map(
      (s, i) => `Session ${i + 1}: ${truncateText(s, summaryChars)}`
    );
    parts.push(`## Past Session Summaries\n${lines.join('\n')}`);
  }
  const blocks = [];
  let totalChars = 0;
  for (const msgs of (sessions || []).slice(0, blocksShown)) {
    const lines = (msgs || []).map((m) => {
      const who = m && m.role === 'user' ? 'User' : 'Motchi';
      return `${who}: ${truncateText(m && m.content, perMessage)}`;
    });
    const block = `--- Session ${blocks.length + 1} ---\n${lines.join('\n')}`;
    if (totalChars + block.length > charLimit && blocks.length > 0) break;
    totalChars += block.length;
    blocks.push(block);
  }
  if (blocks.length > 0) {
    parts.push(`## Previous Conversations\n${blocks.join('\n\n')}`);
  }
  return parts.join('\n\n');
}

module.exports = {
  tokenize,
  parseFactStructure,
  truncateText,
  formatChatContext,
  formatSessionContext,
  CHAT_CONTEXT_SHOWN,
  SESSION_BLOCKS_SHOWN,
  scoreMemory,
  rankMemories,
  simpleEmbedding,
  isNearDuplicate,
  needsEmbeddingBackfill,
  selectContextBlocks,
  selectBlockKeys,
  CONTEXT_BLOCK_KEYWORDS,
  DEFAULT_CONTEXT_KEYS,
  shouldExtractMemory,
  generateTrivia,
  computeInsights,
  composeTodayRecap,
  getMessageText,
  estimateTokens,
  phtDateString,
  phtDayBounds,
  PHT_OFFSET_MS,
  parseReminderDate,
  AGNES_INPUT_TOKEN_BUDGET,
};
