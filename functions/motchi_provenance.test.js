'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const common = require('./common.js');
let db;
common.getDb = () => db;
common.getAdmin = () => ({ firestore: { FieldValue: { serverTimestamp: () => 'demo-time' } } });
const memory = require('./motchi_memory.js');

test('extraction uses only user words, reuses cached facts, and cannot overwrite explicit corrections', async () => {
  let reads = 0;
  const writes = [];
  const stored = [{ id: 'demo-coffee', fact: 'Clair prefers black coffee', provenance: 'explicit' }];
  const ref = {
    collection: () => ref, doc: () => ref, where: () => ref, orderBy: () => ref, limit: () => ref,
    get: async () => { reads++; return { docs: stored.map((f) => ({ id: f.id, data: () => f })) }; },
    update: async (data) => writes.push(data),
    add: async (data) => { writes.push(data); return { id: 'demo-fresh' }; },
  };
  db = { collection: () => ref };
  memory.invalidateMemoryCache();
  await memory.loadMemoryFacts(db);
  assert.equal(reads, 2);
  process.env.AGNES_API_KEY = 'demo-key-only';
  const realFetch = global.fetch;
  let payload;
  global.fetch = async (_url, request) => {
    payload = JSON.parse(request.body);
    return { ok: true, json: async () => ({ choices: [{ message: { content: JSON.stringify([
      { fact: 'Clair prefers green tea', category: 'preference', quote: 'I prefer green tea' },
      { fact: 'Clair likes stargazing', category: 'preference', quote: 'I like stargazing' },
      { fact: 'Clair prefers short movies', category: 'preference', quote: 'Clair prefers short movies' },
    ]) } }] }) };
  };
  try {
    await memory.serverExtractAndSaveMemory('I prefer green tea and I like stargazing.',
      'Maybe Clair prefers short movies. This is just an assistant suggestion.', 'clairjassen');
    assert.equal(payload.messages[1].content, 'I prefer green tea and I like stargazing.');
    assert.ok(!JSON.stringify(payload).includes('assistant suggestion'));
    assert.equal(reads, 2, 'a warm extraction must not re-query facts');
    assert.ok(stored[0].fact.includes('black coffee'));
    assert.equal(writes.length, 1, 'explicit preference stays intact; assistant-only fact is rejected');
    assert.equal(writes[0].fact, 'Clair likes stargazing');
    assert.equal(writes[0].sourceText, 'I like stargazing');
    assert.equal(writes[0].provenance, 'self_report');
  } finally { global.fetch = realFetch; }
});
