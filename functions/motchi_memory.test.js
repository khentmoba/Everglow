'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const mem = require('./motchi_memory');

test('motchi memory group exposes its helpers (no remote embeddings)', () => {
  assert.equal(typeof mem.serverExtractAndSaveMemory, 'function');
  assert.equal(typeof mem.checkHallucinations, 'function');
  assert.equal(typeof mem.selectRelevantMemories, 'function');
  assert.equal(typeof mem.selectCoreProfileNotes, 'function');
  assert.equal(typeof mem.loadMemoryFacts, 'function');
  assert.equal(typeof mem.invalidateMemoryCache, 'function');
  assert.equal(mem.getEmbedding, undefined);
  assert.equal(mem.getRemoteEmbedding, undefined);
  assert.equal(mem.isCasualMemoryQuery, undefined);
});

test('invalidateMemoryCache is safe to call any time', () => {
  mem.invalidateMemoryCache();
  mem.invalidateMemoryCache();
});

function memoryDb(facts) {
  const calls = { reads: 0, limits: [], writes: 0 };
  const chain = (pinned = false) => ({
    collection: () => chain(),
    doc: () => ({ collection: () => chain(), update: async () => { calls.writes++; } }),
    orderBy: () => chain(),
    where: () => chain(true),
    limit: (n) => { calls.limits.push(n); return chain(pinned); },
    get: async () => {
      calls.reads++;
      const docs = facts.filter((f) => !pinned || f.pinned)
        .map((f, i) => ({ id: f.id || String(i), data: () => f }));
      return { docs };
    },
  });
  return { db: { collection: () => chain() }, calls };
}

test('server retrieval preserves metadata and caches candidates, not stale selections', async () => {
  const facts = [
    { id: 'cake', fact: 'Clair loves strawberry cake' },
    { id: 'coffee', fact: 'Khent prefers black coffee' },
    { id: 'pin', fact: 'Clair loves lilies', pinned: true },
  ];
  const { db, calls } = memoryDb(facts);
  const ranked = await mem.selectRelevantMemories('What cake does Clair love?', 10, db);
  assert.ok(ranked.includes(facts[0].fact));
  assert.ok(ranked.includes(facts[2].fact));
  assert.ok(!ranked.includes(facts[1].fact));
  assert.equal(calls.reads, 2);
  assert.deepEqual(calls.limits, [150, 20]);
  await mem.selectRelevantMemories('What cake does Clair love?', 10, db);
  assert.equal(calls.reads, 2);
  assert.equal(calls.writes, 2, 'access writes are deduped within the cache window');
  assert.deepEqual(await mem.selectRelevantMemories('Explain binary search', 10, db), []);
  facts.push({ id: 'fresh', fact: 'Clair loves mango cake' });
  mem.invalidateMemoryCache();
  assert.ok((await mem.selectRelevantMemories('Clair cake', 10, db)).includes('Clair loves mango cake'));
  assert.equal(calls.reads, 4);
});

test('prompt retrieval uses no remote embedding request', async () => {
  const realFetch = global.fetch;
  const { db } = memoryDb([{ fact: 'Clair loves coffee', embedding: new Array(1536).fill(0) }]);
  global.fetch = async () => { throw new Error('network must not be touched'); };
  try {
    assert.deepEqual(await mem.selectRelevantMemories('What coffee does Clair love?', 1, db), ['Clair loves coffee']);
  } finally {
    global.fetch = realFetch;
  }
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

test('selectCoreProfileNotes returns pinned profile facts only, oldest first, capped', async () => {
  const facts = [
    { id: 'new', fact: 'we love horror marathons', category: 'profile', pinned: true, createdAt: { toDate: () => new Date('2026-03-01') } },
    { id: 'old', fact: 'we are night owls', category: 'profile', pinned: true, createdAt: { toDate: () => new Date('2026-01-01') } },
    { id: 'unpinned', fact: 'we like ramen', category: 'profile', pinned: false },
    { id: 'plain', fact: 'Khent prefers black coffee', category: 'fact', pinned: true },
  ];
  const { db } = memoryDb(facts);
  const notes = await mem.selectCoreProfileNotes(db);
  assert.deepEqual(notes, ['we are night owls', 'we love horror marathons']);
  const many = Array.from({ length: 12 }, (_, i) => ({ id: `p${i}`, fact: `profile note ${i}`, category: 'profile', pinned: true }));
  const capped = await mem.selectCoreProfileNotes(memoryDb(many).db);
  assert.equal(capped.length, 8);
});
