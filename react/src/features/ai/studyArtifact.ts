// Port of lib/features/ai/data/services/study_artifact.dart.

export function motchiWantsArtifact(text: string): boolean {
  return /quiz|flashcards?|flash cards?|trivia|\bgame\b|chess|checkers|tic-?tac|html|artifact|\bapp\b|website/i.test(text);
}

export type QuizQuestion = { question: string; options: string[]; answerIndex: number; explanation: string };
export type Flashcard = { front: string; back: string };
export type HtmlArtifact = { title: string; html: string };
export type AppLink = { route: string; label: string };
export type ClarificationChoice = { prompt: string; choices: string[] };

export type StudyArtifacts = {
  quiz: QuizQuestion[];
  flashcards: Flashcard[];
  html: HtmlArtifact[];
  links: AppLink[];
  choices: ClarificationChoice[];
};

export const emptyArtifacts = (): StudyArtifacts => ({ quiz: [], flashcards: [], html: [], links: [], choices: [] });
export const artifactsEmpty = (a: StudyArtifacts) =>
  a.quiz.length === 0 && a.flashcards.length === 0 && a.html.length === 0 && a.links.length === 0 && a.choices.length === 0;
export const quizHasAnswer = (q: QuizQuestion) => q.answerIndex >= 0 && q.answerIndex < q.options.length;

export const kMaxQuizQuestions = 12;
export const kMaxFlashcards = 20;
export const kMaxHtmlChars = 30000;
export const kMaxHtmlArtifacts = 3;
export const kMaxAppLinks = 3;

export const kAppLinkLabels: Record<string, string> = {
  '/play-zone': 'Open the Play Zone 🕹️',
  '/play-zone/chess': 'Play Couple Chess ♟️',
  '/play-zone/scribble': 'Play Scribble Together ✏️',
  '/play-zone/tt': 'Play Table Tennis 🏓',
  '/play-zone/tt/lobby': 'Open the Table Tennis Lobby 🏓',
};

const fencePattern = () => /```[ \t]*([\w-]+)[ \t]*\n?([\s\S]*?)```/g;

export function parseStudyArtifacts(text: string): StudyArtifacts {
  const hasQuizJson = fencedBodies(text, 'quiz-json').length > 0;
  const hasCardsJson = fencedBodies(text, 'flashcards-json').length > 0;
  const quiz = [...parseQuizJsonBlocks(text), ...(hasQuizJson ? [] : parseQuizMarkdownFallback(withoutFencedBlocks(text)))];
  const cards = [
    ...parseFlashcardsJsonBlocks(text),
    ...(hasCardsJson ? [] : parseFlashcardsMarkdownFallback(withoutFencedBlocks(text))),
  ];
  return {
    quiz: quiz.slice(0, kMaxQuizQuestions),
    flashcards: cards.slice(0, kMaxFlashcards),
    html: parseHtmlArtifactBlocks(text).slice(0, kMaxHtmlArtifacts),
    links: parseAppLinkBlocks(text).slice(0, kMaxAppLinks),
    choices: parseChoicesJsonBlocks(text).slice(0, 3),
  };
}

export function stripArtifactBlocks(text: string, collapseVisibleLists = true): string {
  const withoutBlocks = withoutTrailingOpenFence(withoutFencedBlocks(text));
  if (!collapseVisibleLists) return withoutBlocks.trim();
  let out = withoutBlocks;
  if (parseQuizJsonBlocks(text).length > 0) out = collapseVisibleQuiz(out);
  if (parseFlashcardsJsonBlocks(text).length > 0) out = collapseVisibleCards(out);
  return out.trim();
}

const VISIBLE_SIGNALS = [
  'ask them all',
  'all now',
  'all here',
  'in chat',
  'right here',
  'here in',
  'type them',
  'type it out',
  'type out',
  'write them',
  'write it out',
  'write out',
  'list them',
  'list it',
  'show them',
  'show me',
  'show all',
  'display them',
  'post them',
  'send them',
  'spell them out',
];

export function userAskedForVisibleQuiz(userText: string): boolean {
  const t = userText.toLowerCase();
  const mentionsQuiz = ['quiz', 'question', 'trivia', 'test me', 'flashcard', 'study card'].some((w) => t.includes(w));
  if (!mentionsQuiz) return false;
  return VISIBLE_SIGNALS.some((s) => t.includes(s));
}

function collapseVisibleQuiz(text: string): string {
  const lines = text.split('\n');
  const start = visibleQuizStart(lines);
  if (start === -1) return text;
  const intro = lines.slice(0, start).join('\n').trimEnd();
  if (intro === '') return 'Your quiz is ready — tap below to start ✍️';
  return intro;
}

function collapseVisibleCards(text: string): string {
  const lines = text.split('\n');
  const pattern = /^(?:Q\s*[:-]|Front\s*[:-]|Card\s+\d+\s*[:-])/i;
  for (let i = 0; i < lines.length; i++) {
    if (pattern.test(lines[i].trim())) {
      const intro = lines.slice(0, i).join('\n').trimEnd();
      if (intro === '') return 'Your flashcards are ready — tap below to flip 🃏';
      return intro;
    }
  }
  return text;
}

function visibleQuizStart(lines: string[]): number {
  for (let i = 0; i < lines.length; i++) {
    if (!looksLikeQuestion(lines[i])) continue;
    for (let j = i + 1; j < lines.length && j <= i + 6; j++) {
      if (looksLikeQuestion(lines[j])) break;
      if (looksLikeOption(lines[j])) return i;
    }
  }
  return -1;
}

function looksLikeQuestion(line: string): boolean {
  const t = line.trim().replaceAll('*', '').trim();
  if (/^\d+[.)]\s+\S/.test(t)) return true;
  return /^(?:question\s*\d*|q\s*\d+)\s*[:.)-]\s*\S/i.test(t);
}

function looksLikeOption(line: string): boolean {
  const t = line
    .trim()
    .replace(/^[•\-*]\s+/, '')
    .replaceAll('*', '')
    .trim();
  return /^[A-E][.)]\s+\S/.test(t);
}

export function stripStreamingArtifacts(draft: string): string {
  return withoutTrailingOpenFence(withoutFencedBlocks(draft));
}

const OPEN_FENCE =
  /```\s*(quiz[\s_-]*json|quiz|flashcards?[\s_-]*json|flashcards?|html[\s_-]*artifacts?|html|choices?[\s_-]*json|choices?|everglow-link)[\s\S]*$/i;
const standaloneHtmlStart = () => /(?:^|\n)[ \t]*(?:```[ \t]*\r?\n[ \t]*)?(?:<!doctype\s+html\b|<html\b)/gi;
const standaloneHtmlPage = () =>
  /(?:^|\n)[ \t]*(?:```[ \t]*\r?\n[ \t]*)?((?:<!doctype\s+html\b[^>]*>\s*)?<html\b[\s\S]*?<\/html\s*>|<!doctype\s+html\b[^>]*>[\s\S]*?<body\b[^>]*>[\s\S]*?<\/body\s*>(?:\s*<\/html\s*>)?)[ \t]*(?:\r?\n[ \t]*```[ \t]*(?=\r?\n|$))?/gi;

function withoutTrailingOpenFence(text: string): string {
  const open = OPEN_FENCE.exec(text);
  if (open) return text.slice(0, open.index).trimEnd();
  for (const page of text.matchAll(standaloneHtmlStart())) {
    if (!insideLabeledFence(text, page.index!)) return text.slice(0, page.index).trimEnd();
  }
  return text;
}

function normTag(tag: string): string {
  const t = tag.toLowerCase().replaceAll('_', '-');
  if (t === 'quiz-json' || t === 'quizjson' || t === 'quiz') return 'quiz-json';
  if (['flashcards-json', 'flashcardsjson', 'flashcards', 'flash-cards-json', 'flashcard-json', 'flashcard'].includes(t)) {
    return 'flashcards-json';
  }
  if (['html-artifact', 'htmlartifact', 'html-artifacts', 'html'].includes(t)) return 'html-artifact';
  if (['everglow-link', 'everglowlink', 'app-link', 'applink'].includes(t)) return 'everglow-link';
  if (['choices-json', 'choicesjson', 'choices', 'choice-json', 'choice'].includes(t)) return 'choices-json';
  return t;
}

function insideLabeledFence(text: string, offset: number): boolean {
  for (const fence of text.matchAll(fencePattern())) {
    const start = fence.index!;
    if (offset > start && offset < start + fence[0].length) return true;
  }
  return false;
}

const ARTIFACT_TAGS = new Set(['quiz-json', 'flashcards-json', 'html-artifact', 'choices-json', 'everglow-link']);

function withoutFencedBlocks(text: string): string {
  const withoutArtifacts = text.replace(fencePattern(), (whole, tag: string) => (ARTIFACT_TAGS.has(normTag(tag)) ? '' : whole));
  return withoutArtifacts.replace(standaloneHtmlPage(), (...args) => {
    const whole = args[0] as string;
    const offset = args[args.length - 2] as number;
    return insideLabeledFence(withoutArtifacts, offset) ? whole : '';
  });
}

function parseChoicesJsonBlocks(text: string): ClarificationChoice[] {
  const out: ClarificationChoice[] = [];
  for (const body of fencedBodies(text, 'choices-json')) {
    try {
      const decoded = JSON.parse(body);
      if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) {
        const prompt = (typeof decoded.prompt === 'string' ? decoded.prompt : '').trim();
        const raw = decoded.choices ?? decoded.options;
        if (Array.isArray(raw)) {
          const choices = raw
            .map((c) => (typeof c === 'string' ? c : '').trim())
            .filter((c) => c !== '')
            .slice(0, 6);
          if (choices.length >= 2) out.push({ prompt, choices });
        }
      }
    } catch {
      // Lenient parse: bad choice block skipped.
    }
  }
  return out;
}

function fencedBodies(text: string, tag: string): string[] {
  const out: string[] = [];
  for (const m of text.matchAll(fencePattern())) {
    if (normTag(m[1]) !== tag) continue;
    const body = m[2].trim();
    if (body !== '') out.push(body);
  }
  return out;
}

function decodeJsonList(body: string): unknown[] {
  try {
    const decoded = JSON.parse(body);
    if (Array.isArray(decoded)) return decoded;
    if (decoded && typeof decoded === 'object') {
      for (const key of ['questions', 'cards', 'items', 'data']) if (Array.isArray(decoded[key])) return decoded[key];
    }
  } catch {
    // Fall through to lenient extraction.
  }
  const arraySpan = outerSpan(body, '[', ']');
  if (arraySpan != null) {
    try {
      const decoded = JSON.parse(stripTrailingCommas(arraySpan));
      if (Array.isArray(decoded)) return decoded;
    } catch {
      // Fall through to per-object scan.
    }
    const items: unknown[] = [];
    for (const span of objectSpans(arraySpan)) {
      try {
        items.push(JSON.parse(stripTrailingCommas(span)));
      } catch {
        // Skip the bad entry, keep the rest.
      }
    }
    if (items.length > 0) return items;
  }
  const lines: unknown[] = [];
  for (const line of body.split('\n')) {
    const t = line.trim();
    if (!t.startsWith('{') || !t.endsWith('}')) continue;
    try {
      lines.push(JSON.parse(stripTrailingCommas(t)));
    } catch {
      // Skip bad lines.
    }
  }
  return lines;
}

function outerSpan(s: string, open: string, close: string): string | null {
  const start = s.indexOf(open);
  if (start === -1) return null;
  let depth = 0;
  let inStr = false;
  let escape = false;
  for (let i = start; i < s.length; i++) {
    const c = s[i];
    if (inStr) {
      if (escape) escape = false;
      else if (c === '\\') escape = true;
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') inStr = true;
    else if (c === open) depth++;
    else if (c === close) {
      depth--;
      if (depth === 0) return s.slice(start, i + 1);
    }
  }
  return null;
}

function objectSpans(arraySpan: string): string[] {
  const out: string[] = [];
  let depth = 0;
  let start = -1;
  let inStr = false;
  let escape = false;
  for (let i = 0; i < arraySpan.length; i++) {
    const c = arraySpan[i];
    if (inStr) {
      if (escape) escape = false;
      else if (c === '\\') escape = true;
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') inStr = true;
    else if (c === '{') {
      if (depth === 0) start = i;
      depth++;
    } else if (c === '}') {
      depth--;
      if (depth === 0 && start !== -1) {
        out.push(arraySpan.slice(start, i + 1));
        start = -1;
      }
    }
  }
  return out;
}

const stripTrailingCommas = (s: string) => s.replace(/,(\s*[}\]])/g, '$1');
const str = (v: unknown) => (v == null ? '' : String(v));

function parseQuizJsonBlocks(text: string): QuizQuestion[] {
  const out: QuizQuestion[] = [];
  for (const body of fencedBodies(text, 'quiz-json')) {
    for (const item of decodeJsonList(body)) {
      const q = quizFromJson(item);
      if (q) out.push(q);
    }
  }
  return out;
}

function quizFromJson(item: unknown): QuizQuestion | null {
  if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
  const m = item as Record<string, unknown>;
  const question = str(m.q ?? m.question ?? '').trim();
  const raw = m.options ?? m.choices;
  if (question === '' || !Array.isArray(raw)) return null;
  const options = raw.map((o) => str(o).trim()).filter((o) => o !== '');
  if (options.length < 2 || options.length > 6) return null;
  const answer = answerToIndex(m.answer, options.length);
  if (answer == null) return null;
  const why = str(m.why ?? m.explanation ?? '').trim();
  return { question, options, answerIndex: answer, explanation: why };
}

function answerToIndex(answer: unknown, optionCount: number): number | null {
  if (typeof answer === 'number' && Number.isInteger(answer)) {
    if (answer >= 0 && answer < optionCount) return answer;
    if (answer >= 1 && answer <= optionCount) return answer - 1;
    return null;
  }
  if (typeof answer === 'string') {
    const t = answer.trim().toUpperCase();
    if (t.length === 1) {
      const idx = t.charCodeAt(0) - 65;
      if (idx >= 0 && idx < optionCount) return idx;
    }
    if (/^[+-]?\d+$/.test(t)) {
      const asNum = parseInt(t, 10);
      if (asNum >= 0 && asNum < optionCount) return asNum;
      if (asNum >= 1 && asNum <= optionCount) return asNum - 1;
    }
  }
  return null;
}

function parseFlashcardsJsonBlocks(text: string): Flashcard[] {
  const out: Flashcard[] = [];
  for (const body of fencedBodies(text, 'flashcards-json')) {
    for (const item of decodeJsonList(body)) {
      const card = cardFromJson(item);
      if (card) out.push(card);
    }
  }
  return out;
}

function cardFromJson(item: unknown): Flashcard | null {
  if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
  const m = item as Record<string, unknown>;
  const front = str(m.front ?? m.q ?? m.question ?? '').trim();
  const back = str(m.back ?? m.a ?? m.answer ?? '').trim();
  if (front === '' || back === '') return null;
  if (front.length > 500 || back.length > 800) return null;
  return { front, back };
}

function parseHtmlArtifactBlocks(text: string): HtmlArtifact[] {
  const out: HtmlArtifact[] = [];
  const bodies = [
    ...fencedBodies(text, 'html-artifact'),
    ...[...text.matchAll(standaloneHtmlPage())].filter((p) => !insideLabeledFence(text, p.index!)).map((p) => p[1]),
  ];
  for (const body of bodies) {
    const html = body.trim();
    if (html.length < 20 || html.length > kMaxHtmlChars) continue;
    const lower = html.toLowerCase();
    const isFullPage = lower.includes('<html') || lower.includes('<!doctype');
    const hasTag = /<[a-z][a-z0-9-]*(\s[^<>]*)?>/i.test(html);
    if (!isFullPage && !hasTag) continue;
    out.push({ title: htmlTitle(html), html: isFullPage ? html : wrapHtmlFragment(html) });
  }
  return out;
}

function wrapHtmlFragment(fragment: string): string {
  const title = htmlTitle(fragment);
  const safeTitle = title === 'Preview' ? 'Motchi Canvas' : title;
  return (
    '<!DOCTYPE html><html><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    `<title>${escapeHtml(safeTitle)}</title>` +
    '<style>body{margin:0;padding:16px;font-family:system-ui,-apple-system,' +
    'sans-serif;background:#fff;color:#111}*{box-sizing:border-box}</style>' +
    `</head><body>${fragment}</body></html>`
  );
}

const escapeHtml = (s: string) =>
  s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

function parseAppLinkBlocks(text: string): AppLink[] {
  const out: AppLink[] = [];
  const seen = new Set<string>();
  for (const body of fencedBodies(text, 'everglow-link')) {
    const route = /\/play-zone(?:\/[a-z]+)*/.exec(body)?.[0] ?? '';
    if (route === '' || seen.has(route)) continue;
    const label = kAppLinkLabels[route];
    if (label == null) continue;
    seen.add(route);
    out.push({ route, label });
  }
  return out;
}

function htmlTitle(html: string): string {
  const titleTag = /<title\s*>([\s\S]*?)<\/title\s*>/i.exec(html)?.[1]?.trim();
  if (titleTag) return titleTag.length > 80 ? `${titleTag.slice(0, 80)}…` : titleTag;
  const comment = /<!--\s*title\s*:([\s\S]*?)-->/i.exec(html)?.[1]?.trim();
  if (comment) return comment.length > 80 ? `${comment.slice(0, 80)}…` : comment;
  return 'Preview';
}

function parseQuizMarkdownFallback(text: string): QuizQuestion[] {
  if (fencedBodies(text, 'quiz-json').length > 0) return [];
  const lines = text.split('\n');
  const out: QuizQuestion[] = [];
  let i = 0;
  while (i < lines.length) {
    const qMatch = /^\s*(?:\*{0,2}\s*)?(\d+)[.)]\s+(.{4,}?)\s*\*{0,2}\s*$/.exec(lines[i]);
    if (!qMatch) {
      i++;
      continue;
    }
    const question = cleanInline(qMatch[2]);
    const options: string[] = [];
    let j = i + 1;
    while (j < lines.length && options.length < 6) {
      const opt = /^\s*(?:[-*•]\s*)?([A-E])[.)]\s+(.+?)\s*$/.exec(lines[j]);
      if (!opt) break;
      options.push(cleanInline(opt[2]));
      j++;
    }
    let answer = -1;
    let why = '';
    if (options.length >= 2 && j < lines.length) {
      const ans = /^\s*(?:[-*•]\s*)?(?:\*{0,2}\s*)?(?:answer|correct)\s*[:-]\s*([A-Ea-e]|\d)\b\s*(.*)$/i.exec(lines[j]);
      if (ans) {
        answer = answerToIndex(ans[1], options.length) ?? -1;
        why = cleanInline(ans[2] ?? '');
        j++;
      }
    }
    if (question !== '' && options.length >= 2 && answer >= 0) {
      out.push({ question, options, answerIndex: answer, explanation: why });
      i = j;
    } else {
      i++;
    }
  }
  return out;
}

function parseFlashcardsMarkdownFallback(text: string): Flashcard[] {
  if (fencedBodies(text, 'flashcards-json').length > 0) return [];
  const lines = text.split('\n').map((l) => l.trim());
  const out: Flashcard[] = [];
  let i = 0;
  let explicitHits = 0;
  while (i < lines.length) {
    const front = /^(?:Q\s*[:-]|Front\s*[:-]|Card\s+\d+\s*[:-])\s*(.+)$/i.exec(lines[i]);
    if (!front) {
      i++;
      continue;
    }
    const back = i + 1 < lines.length ? /^(?:A\s*[:-]|Back\s*[:-])\s*(.+)$/i.exec(lines[i + 1])?.[1] : undefined;
    if (back != null && back.trim() !== '') {
      out.push({ front: cleanInline(front[1]), back: cleanInline(back) });
      explicitHits++;
      i += 2;
    } else {
      i++;
    }
  }
  return explicitHits < 2 ? [] : out;
}

function cleanInline(s: string): string {
  return s
    .replace(/\*\*(.+?)\*\*/g, '$1')
    .replace(/`(.+?)`/g, '$1')
    .replace(/\*(.+?)\*/g, '$1')
    .trim();
}
