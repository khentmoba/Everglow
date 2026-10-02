'use strict';

// Exercise the real HTTP handler and both agent loops without credentials,
// network, or couple data. Only the model/auth/storage boundaries are fake.
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const { createRequire } = require('node:module');
const path = require('node:path');
const chatPath = path.join(__dirname, '../motchi_chat.js');
const realRequire = createRequire(chatPath);

async function journey(stream, { interrupt = false, recall = false } = {}) {
  const facts = [{ id: 'demo-clair', fact: 'Clair prefers short movies', subject: 'Clair' }];
  const calls = [];
  const saved = [];
  const realTools = realRequire('./motchi_exec_tools');
  const ctx = {
    callerUid: 'clairjassen',
    admin: { firestore: { Timestamp: { fromDate: (date) => date }, FieldValue: { serverTimestamp: () => 'demo-time' } } },
    db: { collection: (collection) => ({ add: async (data) => {
      if (collection === 'reminders') throw new Error('storage disconnected');
      saved.push({ collection, data }); return { id: 'demo-saved-event' };
    } }) },
  };
  const events = [];
  const prompts = [];
  let response;
  const modules = {
    './common.js': {
      requireAuth: async () => ({ uid: 'demo-user' }),
      getVerifiedUsername: async () => 'clairjassen',
      enforceRateLimit: () => false,
      checkDailyCap: async () => ({ allowed: true }),
      getAdmin: () => { throw new Error('no persona in this fixture'); },
    },
    './motchi_memory.js': {
      selectRelevantMemoryFacts: async () => recall ? [] : facts,
      selectCoreProfileNotes: async () => [],
      serverExtractAndSaveMemory: async () => {}, checkHallucinations: async () => {},
    },
    './motchi_context.js': { buildContextForFeature: async () => '', invalidateContextBlock: () => {} },
    './triggers.js': { logToolCall: async () => {} },
    './motchi_sessions.js': { recordMotchiTurn: async () => {} },
    './motchi_exec_tools.js': {
      createToolCtx: () => ctx, visionMessageForResults: () => null,
      executeToolCall: async (_, name, args) => {
        calls.push(name);
        return name === 'read_memories' ? JSON.stringify({ memories: facts })
          : realTools.executeToolCall(ctx, name, args);
      },
    },
  };
  const toolCalls = (recall ? ['read_memories'] : ['add_calendar_event', 'create_reminder']).map((name, i) => ({
    id: `call_${i}`, type: 'function', function: { name, arguments: JSON.stringify(
      name === 'add_calendar_event' ? { title: 'Demo date', date: '2026-10-09T20:00:00+08:00' }
        : name === 'create_reminder' ? { title: 'Demo snacks', remind_at: '2026-10-09T19:00:00+08:00' } : {}
    ) },
  }));
  let rounds = 0;
  const mockFetch = async (_, request) => {
    const body = JSON.parse(request.body);
    prompts.push(body.messages);
    const first = rounds++ === 0;
    if (!first && interrupt) throw new Error('model disconnected');
    const message = first ? { content: 'Let me help.', tool_calls: toolCalls }
      : { content: 'A short movie fits Clair’s preference. [[memory:demo-clair]] [[memory:fake-id]] The date was saved, but I could not confirm the reminder.' };
    if (!body.stream) return { ok: true, json: async () => ({ choices: [{ message }] }) };
    let consumed = false;
    const data = `data: ${JSON.stringify({ choices: [{ delta: message, finish_reason: first ? 'tool_calls' : 'stop' }] })}\n\n`;
    // Streaming calls need indices for delta assembly.
    if (message.tool_calls) message.tool_calls.forEach((t, i) => { t.index = i; });
    const bytes = new TextEncoder().encode(first ? `data: ${JSON.stringify({ choices: [{ delta: message, finish_reason: 'tool_calls' }] })}\n\n` : data);
    return { ok: true, body: { getReader: () => ({ read: async () => {
      if (consumed) return { done: true };
      consumed = true; return { done: false, value: bytes };
    } }) } };
  };
  const sandbox = {
    require: (name) => modules[name] || realRequire(name),
    module: { exports: {} }, console: { log() {}, warn() {}, error() {} },
    process: { env: { TOKENHARBOR_API_KEY: 'fake-test-only' } },
    fetch: mockFetch, TextDecoder, AbortSignal,
    setTimeout: (fn) => setTimeout(fn, 0), clearTimeout,
    setInterval, clearInterval,
  };
  vm.runInNewContext(fs.readFileSync(chatPath, 'utf8'), sandbox, { filename: chatPath });
  const res = {
    set() {}, flushHeaders() {}, end() {},
    status() { return this; }, json(value) { response = value; },
    write(line) { if (line.startsWith('data: ')) events.push(JSON.parse(line.slice(6))); },
  };
  await sandbox.module.exports.handleProxyAI({
    method: 'POST', query: {}, body: {
      feature: 'assistant', stream, canvas: false,
      messages: [{ role: 'user', content: 'Plan our date night and add a calendar event and a reminder' }],
    },
  }, res);
  const details = stream ? events.filter((e) => e?.tool_result?.tool === 'reply_details').at(-1)?.tool_result : response?.details;
  return { details: JSON.parse(JSON.stringify(details)), calls, prompts, response, saved };
}

for (const stream of [false, true]) {
  test(`${stream ? 'streaming' : 'JSON'} journey keeps saved and unconfirmed steps plus verified memory`, async () => {
    const result = await journey(stream);
    assert.deepEqual(result.calls, ['add_calendar_event', 'create_reminder']);
    assert.equal(result.saved.length, 1);
    assert.equal(result.saved[0].collection, 'calendar_events');
    assert.equal(result.saved[0].data.title, 'Demo date');
    assert.equal(result.saved[0].data.createdBy, 'clairjassen');
    assert.deepEqual(result.details.steps.map((s) => s.status), ['done', 'unknown']);
    assert.deepEqual(result.details.memories, [{ id: 'demo-clair', fact: 'Clair prefers short movies', subject: 'Clair' }]);
    assert.equal(result.details.interrupted, false);
    assert.ok(result.prompts[0][0].content.includes('Trust and follow-through'));
    if (!stream) assert.ok(!result.response.reply.includes('[[memory:'));
  });
  test(`${stream ? 'streaming' : 'JSON'} interruption retains the saved action`, async () => {
    const result = await journey(stream, { interrupt: true });
    assert.equal(result.details.interrupted, true);
    assert.equal(result.details.steps[0].status, 'done');
    assert.equal(result.calls.filter((c) => c === 'add_calendar_event').length, 1);
    assert.equal(result.saved.length, 1);
  });
}

test('facts read by a tool can be cited without automatic memory injection', async () => {
  const result = await journey(false, { recall: true });
  assert.equal(result.details.memories[0].id, 'demo-clair');
});
