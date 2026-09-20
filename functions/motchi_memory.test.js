'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const mem = require('./motchi_memory');

test('motchi memory group exposes four helpers', () => {
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
  await mem.serverExtractAndSaveMemory('', 'reply', 'motchi');
  await mem.serverExtractAndSaveMemory('hello', '', 'motchi');
});

test('claimMemoryExtractSlot throttles to one extraction per window', () => {
  const now = 1_700_000_000_000;
  assert.equal(mem.claimMemoryExtractSlot('khentsgdz', now), true);
  assert.equal(mem.claimMemoryExtractSlot('khentsgdz', now + 1000), false);
  assert.equal(mem.claimMemoryExtractSlot('KHENTSGdz', now + 2000), false);
  assert.equal(mem.claimMemoryExtractSlot('clairjassen', now + 3000), true);
  assert.equal(
    mem.claimMemoryExtractSlot('khentsgdz', now + mem.EXTRACT_THROTTLE_MS),
    true,
  );
});

test('index still loads with the memory group extracted', () => {
  const indexExports = require('./index');
  assert.ok(indexExports.proxyAI);
  assert.ok(indexExports.proxyAIv2);
});

test('getRemoteEmbedding returns null without an API key', async () => {
  const saved = process.env.AGNES_API_KEY;
  delete process.env.AGNES_API_KEY;
  try {
    assert.equal(await mem.getRemoteEmbedding('hello'), null);
    assert.equal(await mem.getRemoteEmbedding(''), null);
  } finally {
    if (saved !== undefined) process.env.AGNES_API_KEY = saved;
  }
});

test('getEmbedding falls back to a local 64-dim vector', async () => {
  const saved = process.env.AGNES_API_KEY;
  delete process.env.AGNES_API_KEY;
  try {
    const emb = await mem.getEmbedding('Clair loves lilies');
    assert.ok(Array.isArray(emb));
    assert.equal(emb.length, 64);
  } finally {
    if (saved !== undefined) process.env.AGNES_API_KEY = saved;
  }
});

test('checkHallucinations samples telemetry and caps title checks', async () => {
  const realFetch = global.fetch;
  let calls = 0;
  global.fetch = async () => { calls++; throw new Error('network touched'); };
  try {
    // Skipped sample never touches the network, even for media replies.
    await mem.checkHallucinations('Watch "Galactic Hamsters 9" tonight, it is great!', () => 0.99);
    assert.equal(calls, 0);
  } finally {
    global.fetch = realFetch;
  }
});
