'use strict';

/**
 * Pure Mochi intelligence helpers shared by the proxy and scheduled
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
    /^(Khent and Clair|Clair and Khent|Khent|Clair)\s+(prefers?|loves?|likes?|dislikes?|hates?|wants?|enjoys?|studies?|rides?|plays?|watched?|watches?|read|reads?|went to|visited?|dreams? of|is|was|has|had|works at|started|finished|learned|learnt)\s+(.+)$/i
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

function rankMemories(facts, query, maxResults = 30, now = new Date()) {
  const tokens = tokenize(query);
  const current = now || new Date();
  const scored = (facts || [])
    .filter((f) => f && String(f.fact || '').trim())
    .map((fact) => ({ fact, score: scoreMemory(fact, tokens, current) }));
  scored.sort((a, b) => b.score - a.score || String(a.fact.fact).localeCompare(String(b.fact.fact)));
  return scored.slice(0, maxResults).map((entry) => entry.fact);
}

/**
 * Pick the most relevant context blocks for a question. The proactive
 * digest is always kept so Mochi never loses "today" signals.
 */
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
    const subject = fact.subject || 'Mochi';
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
 * Compose a warm, data-grounded "today" recap. Used by the Mochi Today
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

module.exports = {
  tokenize,
  parseFactStructure,
  scoreMemory,
  rankMemories,
  selectContextBlocks,
  generateTrivia,
  computeInsights,
  composeTodayRecap,
};
