'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  tokenize,
  parseFactStructure,
  rankMemories,
  needsEmbeddingBackfill,
  selectContextBlocks,
  selectBlockKeys,
  DEFAULT_CONTEXT_KEYS,
  generateTrivia,
  computeInsights,
  composeTodayRecap,
  shouldExtractMemory,
  phtDateString,
  phtDayBounds,
  parseReminderDate,
} = require('../motchi_core.js');

const {
  buildContextForFeature,
  invalidateContextBlock,
} = require('../motchi_context.js');

const facts = [
  {
    id: 'a',
    fact: 'Khent prefers black coffee',
    category: 'preference',
    subject: 'Khent',
    relation: 'prefers',
    object: 'black coffee',
    createdAt: new Date('2026-08-01T00:00:00Z'),
  },
  {
    id: 'b',
    fact: 'Clair loves Ethel Cain music',
    category: 'preference',
    subject: 'Clair',
    relation: 'loves',
    object: 'Ethel Cain music',
    createdAt: new Date('2026-08-10T00:00:00Z'),
    pinned: true,
  },
  {
    id: 'c',
    fact: 'Khent rides a Honda Winner X',
    category: 'fact',
    subject: 'Khent',
    relation: 'rides',
    object: 'a Honda Winner X',
    createdAt: new Date('2026-01-01T00:00:00Z'),
  },
  {
    id: 'd',
    fact: 'Khent and Clair started dating on Valentine\'s Day',
    category: 'date',
    subject: 'Khent and Clair',
    relation: 'started dating on',
    object: 'Valentine\'s Day',
    occurredAt: new Date('2026-02-14T00:00:00Z'),
    createdAt: new Date('2026-02-14T00:00:00Z'),
  },
];

test('tokenize strips short and non-word tokens', () => {
  assert.deepEqual(tokenize('What movie should we watch?'), [
    'what',
    'movie',
    'should',
    'watch',
  ]);
});

test('parseFactStructure infers known patterns', () => {
  assert.deepEqual(parseFactStructure('Khent prefers black coffee'), {
    subject: 'Khent',
    relation: 'prefers',
    object: 'black coffee',
  });
  assert.deepEqual(parseFactStructure('They met in February'), {
    subject: null,
    relation: null,
    object: null,
  });
});

test('rankMemories puts the matching fact first', () => {
  const ranked = rankMemories(facts, 'coffee');
  assert.equal(ranked[0].id, 'a');
});

test('rankMemories boosts on-this-day memories', () => {
  const ranked = rankMemories(facts, '', 30, new Date('2027-02-14T12:00:00Z'));
  assert.equal(ranked[0].id, 'd');
});

test('selectContextBlocks keeps proactive plus relevant blocks', () => {
  const blocks = [
    { key: 'proactive', value: 'Birthday in 5 days' },
    { key: 'movies', value: 'Watchlist: Interstellar, Dune' },
    { key: 'music', value: 'Recently played: Ethel Cain' },
    { key: 'books', value: 'Our Books: The Midnight Library' },
    { key: 'chat', value: 'Recent sanctuary messages' },
    { key: 'garden', value: 'Garden has four flowers' },
    { key: 'mood', value: 'Clair logged happy today' },
  ];
  const selected = selectContextBlocks(blocks, 'what should we watch tonight');
  assert.equal(selected[0].key, 'proactive');
  assert.ok(selected.some((b) => b.key === 'movies'));
  assert.ok(!selected.some((b) => b.key === 'music'));
});

test('generateTrivia answers come from real facts', () => {
  const questions = generateTrivia(facts, 3, () => 0.5);
  assert.equal(questions.length, 3);
  for (const question of questions) {
    assert.ok(question.explanation.includes(question.choices[question.answerIndex]));
    assert.ok(question.choices.length >= 2);
  }
});

test('computeInsights finds mood and activity patterns', () => {
  const insights = computeInsights({
    moods: ['happy', 'happy', 'stressed'],
    activities: ['Watched a movie', 'Movie night', 'Cooked dinner'],
  });
  assert.equal(insights.length, 2);
  assert.ok(insights[0].detail.includes('happy'));
  assert.ok(insights[1].detail.includes('movie night'));
});

test('composeTodayRecap grounds the recap in real data', () => {
  const recap = composeTodayRecap({
    dateLabel: '2026-08-13',
    moods: [{ uid: 'khentsgdz', mood: 'happy' }],
    activities: ['Watched a movie'],
    starlight: ['I love our mornings'],
    watchlist: ['Interstellar'],
    memories: facts,
    now: '2026-02-14T12:00:00Z',
  });
  assert.ok(recap.includes('2026-08-13'));
  assert.ok(recap.includes('khentsgdz feels happy'));
  assert.ok(recap.includes('"I love our mornings"'));
  assert.ok(recap.includes('On this day'));
});

test('selectBlockKeys pre-selects the blocks a query needs', () => {
  assert.ok(selectBlockKeys('what should we watch tonight').includes('watchlist'));
  assert.ok(selectBlockKeys('how is our garden doing').includes('garden'));
  assert.ok(selectBlockKeys('what do you remember about our first dates').includes('sessions'));
  assert.ok(selectBlockKeys('what did we talk about at the start').includes('sessions'));
  assert.ok(selectBlockKeys('add our anniversary dinner to the calendar').includes('calendar'));
  assert.ok(selectBlockKeys('play some Ethel Cain songs').includes('music'));
  assert.ok(selectBlockKeys('log a gym workout streak').includes('wellness'));
  assert.ok(selectBlockKeys('how much did we spend this month').includes('budget'));
});

test('needsEmbeddingBackfill spots unusable stored vectors', () => {
  assert.equal(needsEmbeddingBackfill(null), true);
  assert.equal(needsEmbeddingBackfill(undefined), true);
  assert.equal(needsEmbeddingBackfill('nope'), true);
  assert.equal(needsEmbeddingBackfill([0.1, 0.2]), true);
  assert.equal(needsEmbeddingBackfill(new Array(1536).fill(0)), true);
  assert.equal(needsEmbeddingBackfill(new Array(64).fill(0)), false);
});

test('phtDateString keys late-night entries to the PHT day', () => {
  // 23:59 PHT Sept 16
  assert.equal(phtDateString(Date.parse('2026-09-16T15:59:59Z')), '2026-09-16');
  // 00:00 PHT Sept 17 (still Sept 16 in UTC)
  assert.equal(phtDateString(Date.parse('2026-09-16T16:00:00Z')), '2026-09-17');
  // noon PHT
  assert.equal(phtDateString(Date.parse('2026-09-16T04:00:00Z')), '2026-09-16');
});

test('phtDayBounds spans the PHT calendar day', () => {
  const { start, end } = phtDayBounds(Date.parse('2026-09-16T12:00:00Z'));
  assert.equal(start.toISOString(), '2026-09-15T16:00:00.000Z');
  assert.equal(end.toISOString(), '2026-09-16T15:59:59.999Z');
});

test('selectBlockKeys falls back to the awareness set', () => {
  assert.deepEqual(selectBlockKeys(''), DEFAULT_CONTEXT_KEYS);
  assert.deepEqual(selectBlockKeys('zzzq blorp fnord'), DEFAULT_CONTEXT_KEYS);
  assert.equal(selectBlockKeys('hi motchi').length, 7);
});

test('buildContextForFeature resolves safely without crashing', async () => {
  const ctx = await buildContextForFeature('assistant', 'khentsgdz', 'tell me about our movies');
  assert.equal(typeof ctx, 'string');
  assert.doesNotThrow(() => invalidateContextBlock('watchlist'));
  assert.doesNotThrow(() => invalidateContextBlock());
});

test('shouldExtractMemory gates casual chatter and passes durable personal facts', () => {
  assert.equal(shouldExtractMemory('hi motchi', 'Mew! Hello there!'), false);
  assert.equal(shouldExtractMemory('good morning', 'Good morning Dada! Hope you have a lovely day.'), false);
  assert.equal(shouldExtractMemory('ok thanks', 'Anytime! Mew!'), false);
  assert.equal(shouldExtractMemory('what is the weather in cabadbaran', 'It is 29 degrees and sunny in Cabadbaran.'), false);
  assert.equal(shouldExtractMemory('search movies for Dune', 'Found Dune on TMDB.'), false);

  assert.equal(shouldExtractMemory('remember that Khent prefers black coffee', 'Got it! Saved to memory.'), true);
  assert.equal(shouldExtractMemory('I love Ethel Cain music so much', 'Her voice is truly ethereal!'), true);
  assert.equal(shouldExtractMemory('Clair dislikes spicy food', 'Noted! Mama prefers mild food.'), true);
  assert.equal(shouldExtractMemory('My birthday is October 26', 'Dada\'s birthday is marked!'), true);
  assert.equal(shouldExtractMemory('I bought a new helmet for my Winner X bike today', 'Stay safe on the road!'), true);
});

test('parseReminderDate reads ISO, relatives, and PHT wall times', () => {
  // Thu Sep 17 2026, 08:00 PHT (midnight UTC).
  const now = Date.UTC(2026, 8, 17, 0, 0, 0);
  assert.equal(parseReminderDate('2026-09-20T15:00:00+08:00', now).toISOString(), '2026-09-20T07:00:00.000Z');
  // "tomorrow at 3pm" = 3pm in Cabadbaran, not 3pm UTC.
  assert.equal(parseReminderDate('tomorrow at 3pm', now).toISOString(), '2026-09-18T07:00:00.000Z');
  assert.equal(parseReminderDate('tonight at 8', now).toISOString(), '2026-09-17T12:00:00.000Z');
  assert.equal(parseReminderDate('in 2 hours', now).toISOString(), '2026-09-17T02:00:00.000Z');
  assert.equal(parseReminderDate('in 30 minutes', now).toISOString(), '2026-09-17T00:30:00.000Z');
  assert.equal(parseReminderDate('next week', now).toISOString(), '2026-09-24T00:00:00.000Z');
  // 7am already passed today (8am now) — rolls to tomorrow.
  assert.equal(parseReminderDate('today at 7am', now).toISOString(), '2026-09-17T23:00:00.000Z');
  assert.equal(parseReminderDate('someday maybe', now), null);
  assert.equal(parseReminderDate('', now), null);
});
