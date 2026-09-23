'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const study = require('../motchi_study.js');
const indexExports = require('../index.js');

const goodItem = {
  questionText: 'What planet is known as the Red Planet?',
  options: ['Venus', 'Mars', 'Jupiter', 'Mercury'],
  correctOptionIndex: 1,
  explanation: 'Mars looks red because of iron rust on its surface.',
};

test('index exposes generateStudySet', () => {
  assert.equal(typeof study.handleGenerateStudySet, 'function');
  assert.equal(typeof indexExports.generateStudySet, 'function');
});

test('cleanStudyItem keeps a valid question', () => {
  assert.deepEqual(study.cleanStudyItem(goodItem), goodItem);
});

test('cleanStudyItem rejects bad shapes', () => {
  assert.equal(study.cleanStudyItem(null), null);
  assert.equal(study.cleanStudyItem('nope'), null);
  assert.equal(study.cleanStudyItem({ ...goodItem, questionText: 'short' }), null);
  assert.equal(study.cleanStudyItem({ ...goodItem, options: ['A', 'B'] }), null);
  assert.equal(
    study.cleanStudyItem({ ...goodItem, options: ['A', 'a', 'B', 'C'] }),
    null,
  );
  assert.equal(study.cleanStudyItem({ ...goodItem, correctOptionIndex: 4 }), null);
  assert.equal(study.cleanStudyItem({ ...goodItem, correctOptionIndex: '1' }), null);
});

test('cleanStudyItem tolerates a missing explanation', () => {
  const { explanation: _explanation, ...rest } = goodItem;
  assert.equal(study.cleanStudyItem(rest).explanation, '');
});

test('parseStudySet parses a raw array and dedupes', () => {
  const other = { ...goodItem, questionText: 'What is the largest ocean on Earth?' };
  const parsed = study.parseStudySet(JSON.stringify([goodItem, goodItem, other]));
  // Only 2 unique keepers < MIN_KEEPERS(5) → too-few-valid.
  assert.equal(parsed.error, 'too-few-valid');
});

test('parseStudySet accepts fenced JSON with enough items', () => {
  const items = Array.from({ length: 6 }, (_, i) => ({
    ...goodItem,
    questionText: `Gentle sample question number ${i} about the world?`,
  }));
  const parsed = study.parseStudySet('```json\n' + JSON.stringify(items) + '\n```');
  assert.equal(parsed.error, undefined);
  assert.equal(parsed.questions.length, 6);
});

test('parseStudySet rejects garbage', () => {
  assert.equal(study.parseStudySet('hello love').error, 'unparseable');
  assert.equal(study.parseStudySet('{"foo": 1}').error, 'not-an-array');
  assert.equal(study.parseStudySet('[]').error, 'too-few-valid');
});

test('clampCount stays in range', () => {
  assert.equal(study.clampCount(10), 10);
  assert.equal(study.clampCount(99), 20);
  assert.equal(study.clampCount(1), 5);
  assert.equal(study.clampCount('nope'), 10);
});

test('buildStudyPrompt pins count, category, and topic', () => {
  const prompt = study.buildStudyPrompt({ category: 'film', count: 10, topic: 'Ghibli' });
  assert.match(prompt, /exactly 10/);
  assert.match(prompt, /film/);
  assert.match(prompt, /Ghibli/);
  assert.match(prompt, /ONLY a JSON array/);
});

test('429 retry waits out the Agnes RPM window (free tier: 5/min)', () => {
  const src = fs.readFileSync(path.join(__dirname, '../motchi_study.js'), 'utf8');
  assert.match(src, /e\.status === 429 \? 12000 : 1500/);
});
