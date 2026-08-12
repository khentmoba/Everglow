'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  tokenize,
  parseFactStructure,
  rankMemories,
  selectContextBlocks,
  generateTrivia,
  computeInsights,
  composeTodayRecap,
} = require('../mochi_core.js');

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
