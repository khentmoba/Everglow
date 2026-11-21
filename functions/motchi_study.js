'use strict';

const {
  applyCors,
  requireAuth,
  enforceRateLimit,
  checkDailyCap,
  getVerifiedUsername,
} = require('./common.js');

const AGNES_URL = 'https://apihub.agnes-ai.com/v1/chat/completions';
const MODEL = 'agnes-3.0-flash';

const STUDY_CATEGORIES = [
  'engineering',
  'tourism',
  'music',
  'general',
  'cartoons',
  'celebrities',
  'film',
  'books',
];

const MIN_COUNT = 5;
const MAX_COUNT = 20;
const DEFAULT_COUNT = 10;
const MIN_KEEPERS = 5;
const STUDY_PROFILES = ['khentsgdz', 'clairjassen', 'breyan', 'octagram'];

function isStudyProfile(username) {
  return STUDY_PROFILES.includes(username);
}

function studyDailyLimit(username) {
  return ['breyan', 'octagram'].includes(username) ? 50 : 300;
}

function clampCount(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return DEFAULT_COUNT;
  return Math.min(MAX_COUNT, Math.max(MIN_COUNT, Math.floor(n)));
}

function cleanTopic(value) {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\s+/g, ' ').slice(0, 120);
}

function buildStudyPrompt({ category, count, topic }) {
  const focus = topic
    ? `Theme every question around "${topic}" (still within ${category}).`
    : `Cover ${category} broadly with a fun mix.`;
  return (
    `You write calm multiple-choice study sets for a couple's quiz app. ` +
    `Write exactly ${count} gentle ${category} questions. ${focus}\n` +
    `Rules:\n` +
    `- Clear questionText (one short sentence).\n` +
    `- Exactly 4 options: short, plausible, distinct. Vary which position is correct.\n` +
    `- correctOptionIndex 0-3 pointing at the right option.\n` +
    `- explanation: one short kind sentence saying why the answer is right.\n` +
    `- Keep difficulty cozy, never trick questions. Plain text only, no markdown.\n` +
    `Reply with ONLY a JSON array of objects ` +
    `[{"questionText","options":[4],"correctOptionIndex","explanation"}] — ` +
    `no fences, no commentary.`
  );
}

function stripFences(text) {
  let out = String(text || '').trim();
  if (out.startsWith('```')) {
    out = out.replace(/^```[a-zA-Z-]*\n?/, '');
    const fence = out.lastIndexOf('```');
    if (fence >= 0) out = out.slice(0, fence);
  }
  return out.trim();
}

function isValidOption(opt) {
  return typeof opt === 'string' && opt.trim().length > 0 && opt.length <= 200;
}

function cleanStudyItem(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const questionText = typeof raw.questionText === 'string' ? raw.questionText.trim() : '';
  if (questionText.length < 10 || questionText.length > 500) return null;
  const options = Array.isArray(raw.options)
    ? raw.options.map((o) => (typeof o === 'string' ? o.trim() : '')).filter(isValidOption)
    : [];
  if (options.length !== 4) return null;
  const lowered = options.map((o) => o.toLowerCase());
  if (new Set(lowered).size !== 4) return null;
  const correct = raw.correctOptionIndex;
  if (!Number.isInteger(correct) || correct < 0 || correct > 3) return null;
  const explanation = typeof raw.explanation === 'string' ? raw.explanation.trim().slice(0, 500) : '';
  return { questionText, options, correctOptionIndex: correct, explanation };
}

function parseStudySet(text) {
  let raw;
  try {
    raw = JSON.parse(stripFences(text));
  } catch {
    return { error: 'unparseable' };
  }
  const list = Array.isArray(raw) ? raw : raw.questions;
  if (!Array.isArray(list)) return { error: 'not-an-array' };
  const seen = new Set();
  const questions = [];
  for (const item of list) {
    const cleaned = cleanStudyItem(item);
    if (!cleaned) continue;
    const key = cleaned.questionText.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    questions.push(cleaned);
  }
  if (questions.length < MIN_KEEPERS) return { error: 'too-few-valid' };
  return { questions };
}

async function callLlm({ apiKey, messages, maxTokens, timeoutMs }) {
  const resp = await fetch(AGNES_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      messages,
      max_tokens: maxTokens,
      temperature: 0.7,
      top_p: 0.95,
      stream: false,
      chat_template_kwargs: { enable_thinking: false },
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!resp.ok) {
    const err = new Error(`Agnes HTTP ${resp.status}`);
    err.status = resp.status;
    throw err;
  }
  const body = await resp.json();
  return (body.choices?.[0]?.message?.content || '').trim();
}

async function handleGenerateStudySet(req, res) {
  applyCors(req, res, 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.query.warmup === 'true' || (req.body && req.body.warmup === true)) {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'generateStudySet', limit: 10, windowMs: 60000, uid: decoded.uid })) return;

  const category = typeof req.body?.category === 'string' ? req.body.category.trim().toLowerCase() : '';
  if (!STUDY_CATEGORIES.includes(category)) {
    res.status(400).json({ error: 'Unknown category' });
    return;
  }
  const count = clampCount(req.body?.count);
  const topic = cleanTopic(req.body?.topic);

  const caller = await getVerifiedUsername(decoded).catch(() => null);
  if (!isStudyProfile(caller)) {
    res.status(403).json({ error: 'A verified app profile is required' });
    return;
  }
  const dailyLimit = studyDailyLimit(caller);
  const usage = await checkDailyCap(decoded.uid, 'proxyAI', dailyLimit);
  if (!usage.allowed) {
    res.status(429).json({ error: 'Daily AI limit reached — Motchi will be back tomorrow.' });
    return;
  }

  const apiKey = process.env.AGNES_API_KEY;
  if (!apiKey) {
    res.status(503).json({ error: 'Study generator is resting — try the cached questions.' });
    return;
  }

  const isCouple = caller === 'khentsgdz' || caller === 'clairjassen';
  const messages = [
    {
      role: 'system',
      content:
        (isCouple
          ? 'You are Motchi 🍡, a warm white cat writing cozy quiz questions for Khent and Clair. '
          : 'You are a helpful study assistant writing clear, accurate quiz questions. ') +
        'Be kind, simple, and encouraging. Never include markdown, prefix letters, or numbering inside fields.',
    },
    { role: 'user', content: buildStudyPrompt({ category, count, topic }) },
  ];

  let reply;
  try {
    reply = await callLlm({ apiKey, messages, maxTokens: 4000, timeoutMs: 60000 });
  } catch (e) {
    if (e.status === 429 || e.status === 502 || e.status === 503) {
      try {
        await new Promise((r) => setTimeout(r, e.status === 429 ? 12000 : 1500));
        reply = await callLlm({ apiKey, messages, maxTokens: 4000, timeoutMs: 60000 });
      } catch {
        res.status(502).json({ error: 'Motchi got distracted — try the cached questions.' });
        return;
      }
    } else {
      console.warn('[generateStudySet] Agnes failed:', e.message);
      res.status(502).json({ error: 'Motchi got distracted — try the cached questions.' });
      return;
    }
  }

  let parsed = parseStudySet(reply);
  if (parsed.error) {
    try {
      const repair = await callLlm({
        apiKey,
        messages: [
          ...messages,
          { role: 'assistant', content: reply.slice(0, 4000) },
          {
            role: 'user',
            content:
              'That reply was not a clean JSON array. Reply again with ONLY the JSON array of ' +
              `${count} questions — no fences, no commentary, just the array.`,
          },
        ],
        maxTokens: 4000,
        timeoutMs: 60000,
      });
      parsed = parseStudySet(repair);
    } catch (e) {
      console.warn('[generateStudySet] repair failed:', e.message);
    }
  }

  if (parsed.error) {
    res.status(502).json({ error: 'Motchi wrote a messy set — try the cached questions.' });
    return;
  }
  res.json({ questions: parsed.questions.slice(0, count), category, topic });
}

module.exports = {
  handleGenerateStudySet,
  buildStudyPrompt,
  cleanStudyItem,
  parseStudySet,
  clampCount,
  STUDY_CATEGORIES,
  isStudyProfile,
  studyDailyLimit,
};
