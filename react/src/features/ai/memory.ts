// Port of lib/features/ai/domain/memory: memory_fact.dart, memory_retrieval.dart and today_recap.dart.

export type MemoryFact = {
  id: string;
  fact: string;
  category: string;
  subject: string | null;
  relation: string | null;
  object: string | null;
  occurredAt: Date | null;
  createdAt: Date | null;
  confidence: number;
  pinned: boolean;
  accessCount: number;
  source: string;
};

const nullableStr = (v: unknown) => (typeof v === 'string' ? v : null);

function parseDate(v: unknown): Date | null {
  if (v == null) return null;
  if (v instanceof Date) return v;
  if (typeof v === 'string' && v !== '') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

export function memoryFactFromJson(json: Record<string, unknown>, id = ''): MemoryFact {
  return {
    id: nullableStr(json.id) ?? id,
    fact: nullableStr(json.fact) ?? '',
    category: nullableStr(json.category) ?? 'fact',
    subject: nullableStr(json.subject),
    relation: nullableStr(json.relation),
    object: nullableStr(json.object),
    occurredAt: parseDate(json.occurredAt),
    createdAt: parseDate(json.createdAt),
    confidence: typeof json.confidence === 'number' ? json.confidence : 1.0,
    pinned: json.pinned === true,
    accessCount: typeof json.accessCount === 'number' ? Math.trunc(json.accessCount) : 0,
    source: nullableStr(json.source) ?? '',
  };
}

export function memoryFactToJson(f: MemoryFact): Record<string, unknown> {
  return {
    id: f.id,
    fact: f.fact,
    category: f.category,
    ...(f.subject != null ? { subject: f.subject } : {}),
    ...(f.relation != null ? { relation: f.relation } : {}),
    ...(f.object != null ? { object: f.object } : {}),
    ...(f.occurredAt != null ? { occurredAt: f.occurredAt.toISOString() } : {}),
    ...(f.createdAt != null ? { createdAt: f.createdAt.toISOString() } : {}),
    confidence: f.confidence,
    pinned: f.pinned,
    accessCount: f.accessCount,
    ...(f.source !== '' ? { source: f.source } : {}),
  };
}

export function isOnThisDay(f: MemoryFact, now: Date): boolean {
  const d = f.occurredAt;
  return d != null && d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
}

export function subjectLabel(f: MemoryFact): string {
  if (f.subject != null) return f.subject;
  const lower = f.fact.toLowerCase();
  if (lower.startsWith('khent and clair')) return 'Khent and Clair';
  if (lower.startsWith('clair and khent')) return 'Clair and Khent';
  if (lower.startsWith('khent')) return 'Khent';
  if (lower.startsWith('clair')) return 'Clair';
  return 'Motchi';
}

const KNOWN_VERBS = new RegExp(
  '^(Khent and Clair|Clair and Khent|Khent|Clair)\\s+' +
    '(prefers?|loves?|likes?|dislikes?|hates?|wants?|enjoys?|' +
    'studies?|rides?|plays?|watched?|watches?|read|reads?|' +
    'went to|visited?|dreams? of|is|was|has|had|works at|' +
    'started|finished|learned|learnt)\\s+(.+)$',
  'i',
);

/** `FactStructureParser.parse`: subject, relation and object of a simple fact. */
export function parseFactStructure(fact: string): [string | null, string | null, string | null] {
  const trimmed = fact.trim();
  if (trimmed === '') return [null, null, null];
  const m = KNOWN_VERBS.exec(trimmed);
  if (!m) return [null, null, null];
  return [m[1], m[2], m[3]];
}

const tokens = (text: string) =>
  new Set(
    text
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((t) => t.length >= 3),
  );
const daysBetween = (a: Date, b: Date) => Math.trunc((a.getTime() - b.getTime()) / 86_400_000);

function score(fact: MemoryFact, toks: Set<string>, now: Date, query: string): number {
  let s = Math.min(1, Math.max(0.1, fact.confidence));
  if (fact.pinned) s += 2.0;
  if (fact.createdAt != null) {
    const age = daysBetween(now, fact.createdAt);
    if (age >= 0 && age <= 30) s += 1.0;
  }
  if (isOnThisDay(fact, now)) s += 3.0;
  if (toks.size === 0) return s;
  const text = `${fact.fact} ${fact.subject ?? ''} ${fact.relation ?? ''} ${fact.object ?? ''} ${fact.category}`.toLowerCase();
  for (const t of toks) if (text.includes(t)) s += 1.5;
  const subject = fact.subject?.toLowerCase() ?? '';
  const object = fact.object?.toLowerCase() ?? '';
  for (const t of toks) if (subject.includes(t) || object.includes(t)) s += 2.0;
  const phrase = query.toLowerCase();
  if (fact.fact.toLowerCase().includes(phrase) && phrase.length >= 4) s += 3.0;
  return s;
}

/** `MemoryRetriever.rank`. */
export function rankMemories(facts: MemoryFact[], { query = '', now = new Date(), max = 30 } = {}): MemoryFact[] {
  const toks = tokens(query);
  const sorted = [...facts].sort((a, b) => {
    const sa = score(a, toks, now, query);
    const sb = score(b, toks, now, query);
    if (sa !== sb) return sb - sa;
    return b.fact < a.fact ? -1 : b.fact > a.fact ? 1 : 0;
  });
  return max <= 0 ? sorted : sorted.slice(0, max);
}

export type MemoryTriviaQuestion = { question: string; choices: string[]; answerIndex: number; explanation: string };

function shuffle<T>(list: T[]): T[] {
  for (let n = list.length; n > 1;) {
    const pos = Math.floor(Math.random() * n);
    n -= 1;
    [list[n], list[pos]] = [list[pos], list[n]];
  }
  return list;
}

/** `MemoryTriviaGenerator.generate`. */
export function generateMemoryTrivia(facts: MemoryFact[], count = 5): MemoryTriviaQuestion[] {
  const candidates = facts.filter((f) => {
    const subject = f.subject ?? subjectLabel(f);
    return f.object != null && f.object.trim() !== '' && subject !== '';
  });
  shuffle(candidates);
  const selected = candidates.slice(0, count);
  const pool = new Set<string>([
    ...candidates.map((f) => f.object ?? '').filter((o) => o !== ''),
    ...candidates.map((f) => subjectLabel(f)).filter((s) => s !== ''),
  ]);
  return selected.map((fact) => {
    const subject = fact.subject ?? subjectLabel(fact);
    const object = fact.object!.trim();
    const question = `${subject.trim()} ${fact.relation ?? ''} _____`.replace(/\s+/g, ' ').trim();
    const choices = [object];
    const distractors = shuffle([...pool].filter((p) => p !== object));
    for (const c of distractors) {
      if (choices.length >= 4) break;
      if (!choices.includes(c)) choices.push(c);
    }
    shuffle(choices);
    return { question, choices, answerIndex: choices.indexOf(object), explanation: fact.fact };
  });
}

export type RelationshipInsight = { title: string; detail: string; category: string };

function top(counts: Map<string, number>): string {
  let best: [string, number] | null = null;
  for (const e of counts) if (best == null || !(best[1] >= e[1])) best = e;
  return best![0];
}

/** `RelationshipInsights.compute`. */
export function relationshipInsights(moods: string[], activities: string[]): RelationshipInsight[] {
  const insights: RelationshipInsight[] = [];
  if (moods.length > 0) {
    const counts = new Map<string, number>();
    for (const mood of moods) {
      const key = mood.trim().toLowerCase();
      if (key === '') continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
    if (counts.size > 0) {
      insights.push({
        title: 'Mood signal',
        detail: `"${top(counts)}" shows up most often in recent check-ins.`,
        category: 'mood',
      });
    }
  }
  if (activities.length > 0) {
    const categories = new Map<string, number>();
    const bump = (k: string) => categories.set(k, (categories.get(k) ?? 0) + 1);
    for (const activity of activities) {
      const lower = activity.toLowerCase();
      if (lower.includes('movie') || lower.includes('watch') || lower.includes('anime')) bump('movie night');
      else if (lower.includes('game') || lower.includes('valorant') || lower.includes('mobile legends')) bump('gaming');
      else if (lower.includes('food') || lower.includes('eat') || lower.includes('cook')) bump('food');
      else if (lower.includes('date')) bump('date');
    }
    if (categories.size > 0) {
      insights.push({ title: 'Shared rhythm', detail: `Recent activity leans toward ${top(categories)}.`, category: 'activity' });
    }
  }
  return insights;
}

export type Mood = { uid: string; mood: string };

/** `composeTodayRecap`. */
export function composeTodayRecap({
  dateLabel,
  moods = [],
  activities = [],
  watchlist = [],
  starlight = [],
  memories = [],
  now = new Date(),
}: {
  dateLabel: string;
  moods?: Mood[];
  activities?: string[];
  watchlist?: string[];
  starlight?: string[];
  memories?: MemoryFact[];
  now?: Date;
}): string {
  const parts = [`Today is ${dateLabel}.`];
  parts.push(moods.length === 0 ? 'No mood logged yet today.' : moods.map((m) => `${m.uid} feels ${m.mood}.`).join(' '));
  if (activities.length > 0) parts.push(`Recently: ${activities.slice(0, 3).join(', ')}.`);
  if (starlight.length > 0) parts.push(`A star in the jar: "${starlight[0]}".`);
  if (watchlist.length > 0) parts.push(`On the watchlist: ${watchlist.slice(0, 2).join(', ')}.`);
  const onThisDay = memories.filter((m) => isOnThisDay(m, now));
  if (onThisDay.length > 0) parts.push(`On this day: ${onThisDay[0].fact}.`);
  parts.push('Have a beautiful day together!');
  return parts.join(' ');
}
