'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const mem = require('./mochi_memory');

test('mochi memory group exposes four helpers', () => {
  assert.equal(typeof mem.serverExtractAndSaveMemory, 'function');
  assert.equal(typeof mem.checkHallucinations, 'function');
  assert.equal(typeof mem.getEmbedding, 'function');
  assert.equal(typeof mem.selectRelevantMemories, 'function');
});

test('selectRelevantMemories ranks client facts without Firestore', async () => {
  const facts = [
    'Clair loves strawberry cake',
    'Khent prefers black coffee',
    'The sky is blue today',
  ];
  const ranked = await mem.selectRelevantMemories(facts, 'What cake does Clair love?');
  assert.ok(Array.isArray(ranked));
  assert.equal(ranked.length, 3);
  assert.match(ranked[0].toLowerCase(), /clair|cake/);
});

test('selectRelevantMemories respects maxResults', async () => {
  const facts = ['fact one', 'fact two', 'fact three'];
  const ranked = await mem.selectRelevantMemories(facts, 'fact', 2);
  assert.equal(ranked.length, 2);
});

test('getEmbedding returns null for empty input', async () => {
  assert.equal(await mem.getEmbedding(''), null);
  assert.equal(await mem.getEmbedding('   '), null);
});

test('checkHallucinations ignores short replies', async () => {
  await mem.checkHallucinations('hi');
  await mem.checkHallucinations('');
});

test('serverExtractAndSaveMemory ignores empty input', async () => {
  await mem.serverExtractAndSaveMemory('', 'reply', 'mochi');
  await mem.serverExtractAndSaveMemory('hello', '', 'mochi');
});

test('index still loads with the memory group extracted', () => {
  const indexExports = require('./index');
  assert.ok(indexExports.proxyAI);
  assert.ok(indexExports.proxyAIv2);
});
