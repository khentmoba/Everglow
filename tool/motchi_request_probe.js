#!/usr/bin/env node
'use strict';

// Runs the REAL Motchi handler and tool loop with demo Firestore/auth.
// --live uses TokenHarbor (paid calls); nothing can touch production data.
// Compare an archived functions directory with --functions PATH --legacy-client.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

function demoDb() {
  const facts = new Map();
  const seedDate = new Date(Date.now() - 1000);
  const stamp = { toDate: () => seedDate };
  facts.set('coffee', { fact: 'Khent prefers demo oat coffee.', createdAt: stamp });
  for (let i = 0; i < 150; i++) facts.set(`demo-${i}`, {
    fact: `Clair visited demo island number ${i}.`, createdAt: stamp,
  });
  facts.set('old-pin', {
    fact: 'Clair plays a demo harp.', pinned: true,
    createdAt: { toDate: () => new Date('2000-01-01') },
  });
  const stats = { queries: 0, factDocs: 0, writes: 0 };
  let counter = 0;
  function ref(parts, filters = [], limit = Infinity, order = null) {
    const name = parts.join('/');
    const obj = {
      collection: (key) => ref([...parts, key]),
      doc: (key) => ref([...parts, key]),
      orderBy: (key, direction = 'asc') => ref(parts, filters, limit, { key, direction }),
      where: (...args) => ref(parts, [...filters, args], limit, order),
      limit: (n) => ref(parts, filters, n, order),
      get: async () => {
        stats.queries++;
        if (name === 'ai_memories/shared/facts') {
          let entries = [...facts];
          for (const [key, op, value] of filters) {
            entries = entries.filter(([, d]) => op === '==' ? d[key] === value : true);
          }
          if (order) entries.sort((a, b) => {
            const value = (d) => d[order.key]?.toDate?.()?.getTime() || 0;
            return (value(a[1]) - value(b[1])) * (order.direction === 'desc' ? -1 : 1);
          });
          const docs = entries.slice(0, limit).map(([id, data]) => ({ id, data: () => data }));
          stats.factDocs += docs.length;
          return { docs, size: docs.length, empty: !docs.length, forEach: (fn) => docs.forEach(fn) };
        }
        if (parts.length === 4 && parts[2] === 'facts') {
          const data = facts.get(parts[3]);
          return { exists: !!data, data: () => data };
        }
        return { exists: false, docs: [], size: 0, empty: true, forEach: () => {} };
      },
      add: async (data) => {
        assert.equal(name, 'ai_memories/shared/facts', `unexpected demo write: ${name}`);
        stats.writes++;
        const id = `saved-${++counter}`;
        facts.set(id, data);
        return { id };
      },
      update: async (data) => {
        stats.writes++;
        const id = parts[3];
        assert.ok(facts.has(id), `unknown demo fact: ${id}`);
        Object.assign(facts.get(id), data);
      },
      set: async () => { throw new Error(`Unexpected demo set: ${name}`); },
      delete: async () => { throw new Error('Deletes are disabled in the request probe'); },
    };
    return obj;
  }
  const db = { collection: (key) => ref([key]) };
  const firestore = () => db;
  firestore.FieldValue = { serverTimestamp: () => { const now = new Date(); return { toDate: () => now }; }, increment: (n) => n };
  firestore.Timestamp = { fromDate: (d) => ({ toDate: () => d }) };
  return { db, admin: { firestore }, stats, facts, caller: 'khentsgdz' };
}

async function createProbe({ functionsDir = path.join(__dirname, '../functions'), modelFetch = global.fetch, legacyClient = false } = {}) {
  functionsDir = path.resolve(functionsDir);
  const fixture = demoDb();
  const common = require(path.join(functionsDir, 'common.js'));
  Object.assign(common, {
    getDb: () => fixture.db,
    getAdmin: () => fixture.admin,
    requireAuth: async () => ({ uid: 'demo-auth' }),
    getVerifiedUsername: async () => fixture.caller,
    enforceRateLimit: () => false,
    checkDailyCap: async () => ({ allowed: true }),
  });
  const triggers = require(path.join(functionsDir, 'triggers.js'));
  triggers.logToolCall = async () => {};
  triggers.sendFCMToUser = async () => { throw new Error('Notifications are disabled in the request probe'); };
  const memory = require(path.join(functionsDir, 'motchi_memory.js'));
  memory.serverExtractAndSaveMemory = async () => {};
  memory.checkHallucinations = async () => {};
  memory.invalidateMemoryCache();
  let recorded = null;
  require(path.join(functionsDir, 'motchi_sessions.js')).recordMotchiTurn = async (turn) => { recorded = turn; };
  const { handleProxyAI } = require(path.join(functionsDir, 'motchi_chat.js'));
  // Mimic the OLD app's once-loaded text cache. Deliberately not refreshed
  // after server tool writes, so the save/recall pair exercises freshness.
  const clientMemories = [...fixture.facts.values()].slice(0, 150).map((f) => f.fact);
  const request = async function request(label, message, extra = {}) {
    recorded = null;
    const before = { ...fixture.stats };
    const start = Date.now();
    let firstTokenMs = null;
    const calls = [];
    const events = [];
    const realFetch = global.fetch;
    global.fetch = async (url, opts) => {
      assert.equal(String(url), 'https://tokenharbor.ai/v1/chat/completions', 'probe forbids third-party calls');
      const payload = JSON.parse(opts.body);
      const system = payload.messages[0].content;
      calls.push({
        promptChars: system.length,
        memoryCount: (system.split('## Remembered Facts\n')[1] || '').split('\n').filter((l) => l.startsWith('- ')).length,
        attachedTools: (payload.tools || []).length,
      });
      return modelFetch(url, opts);
    };
    const body = {
      messages: [{ role: 'user', content: message }],
      feature: 'assistant', caller: 'khentsgdz', stream: true,
      enableThinking: false, canvas: false,
      ...(legacyClient ? { memories: clientMemories } : {}),
      ...extra,
    };
    const req = { method: 'POST', query: {}, body, headers: {}, get: () => 'Bearer demo' };
    let status = 200;
    const res = {
      set: () => {}, flushHeaders: () => {},
      status: (code) => { status = code; return res; },
      json: (value) => events.push(value), send: () => {}, end: () => {},
      write: (chunk) => {
        if (!chunk.startsWith('data: ')) return;
        const event = JSON.parse(chunk.slice(6));
        events.push(event);
        if (event.content && firstTokenMs === null) firstTokenMs = Date.now() - start;
      },
    };
    try {
      await handleProxyAI(req, res);
      await Promise.resolve();
    } finally {
      global.fetch = realFetch;
    }
    const result = {
      label, status, durationMs: Date.now() - start, firstTokenMs,
      modelCalls: calls.length, ...calls[0],
      requestBytes: Buffer.byteLength(JSON.stringify(body)),
      queries: fixture.stats.queries - before.queries,
      factDocs: fixture.stats.factDocs - before.factDocs,
      writes: fixture.stats.writes - before.writes,
      tools: (recorded?.tools || []).map((t) => t.name),
      errors: events.filter((e) => e.error).map((e) => e.error),
      reply: events.map((e) => e.content || '').join(''),
      trace: recorded?.requestTrace || null,
    };
    return result;
  };
  request.fixture = fixture;
  return request;
}

async function main() {
  const args = process.argv.slice(2);
  if (!args.includes('--live')) throw new Error('Pass --live to authorize paid demo requests to TokenHarbor.');
  if (!process.env.TOKENHARBOR_API_KEY) throw new Error('TOKENHARBOR_API_KEY is not configured.');
  const idx = args.indexOf('--functions');
  const request = await createProbe({
    functionsDir: idx >= 0 ? args[idx + 1] : undefined,
    legacyClient: args.includes('--legacy-client'),
  });
  const cases = [
    ['greeting', 'Hi Motchi!'],
    ['general', 'Explain binary search in two short sentences.'],
    ['personal', 'What coffee does Khent prefer? Answer in one sentence.'],
    ['bisaya', 'Unsa nga coffee ang paborito ni Khent?'],
    ['old-pin', 'What instrument does Clair play? Answer in one sentence.'],
    ['save', 'Use remember_fact to save exactly this demo fact: Clair prefers hibiscus tea. Then say saved.'],
    ['fresh-recall', 'What tea does Clair prefer? Answer in one sentence.'],
  ];
  const results = [];
  for (const [label, message] of cases) results.push(await request(label, message));
  const out = args.indexOf('--output');
  if (out >= 0) fs.writeFileSync(args[out + 1], JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
  assert.ok(results.every((r) => r.status === 200 && r.reply && !r.errors.length), 'a request failed');
  assert.ok(results.find((r) => r.label === 'save').tools.includes('remember_fact'), 'save was not executed');
  assert.match(results.find((r) => r.label === 'fresh-recall').reply, /hibiscus/i, 'fresh fact was not recalled');
}

module.exports = { createProbe, demoDb };
if (require.main === module) main().catch((e) => { console.error(e.message); process.exitCode = 1; });
