'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { loadCompanion, updateCompanion, companionPrompt, normalizePreferences,
  allowsPush, pushReservation, memoryEvidence, actionKey, requestBudget, journeyMetrics } = require('./motchi_agent.js');
const { executeToolCall, clearIdempotencyCache, TOOL_EXECUTORS } = require('./motchi_exec_tools.js');

// Transactional demo storage: no network or real data. Count documents, not query calls.
function demoStorage() {
  const records = new Map();
  const counts = { reads: 0, writes: 0 };
  function merge(a, b) {
    const out = { ...a };
    for (const [k, v] of Object.entries(b)) out[k] = v && typeof v === 'object' && !Array.isArray(v) &&
      !(v instanceof Date) ? merge(a?.[k] || {}, v) : v;
    return out;
  }
  const db = { collection: (collection) => ({ doc: (id) => {
    const key = `${collection}/${id}`;
    return {
      get: async () => {
        counts.reads++;
        const data = records.get(key);
        return { exists: !!data, data: () => data };
      },
      set: async (data, options) => {
        counts.writes++;
        records.set(key, options?.merge ? merge(records.get(key) || {}, data) : data);
      },
    };
  } }) };
  let queue = Promise.resolve();
  db.runTransaction = (fn) => {
    const run = queue.then(() => fn({ get: (ref) => ref.get(), set: (ref, data, options) => ref.set(data, options) }));
    queue = run.catch(() => {});
    return run;
  };
  return { db, records, counts };
}

test('companion reads coalesce, feedback stays bounded, saves preserve push tokens and preferences', async () => {
  const { db, records, counts } = demoStorage();
  records.set('fcm_tokens/clairjassen', { token: 'fake-token' });
  await Promise.all([loadCompanion(db, 'clairjassen'), loadCompanion(db, 'clairjassen')]);
  assert.equal(counts.reads, 1);
  await updateCompanion(db, 'clairjassen', 'preferences', { nudges: 'weekly', quietStart: 20 });
  assert.equal(counts.reads, 1, 'saving settings needs no pre-read');
  for (let i = 0; i < 23; i++) {
    await updateCompanion(db, 'clairjassen', 'feedback', { title: `Demo movie ${i}`, reason: 'seen' });
  }
  const data = records.get('fcm_tokens/clairjassen');
  assert.equal(data.token, 'fake-token');
  assert.equal(data.motchi.preferences.nudges, 'weekly');
  assert.equal(data.motchi.feedback.length, 20);
  assert.equal(counts.reads, 24);
  assert.equal(counts.writes, 24);
  await assert.rejects(updateCompanion(db, 'clairjassen', 'feedback', { title: 'Demo', reason: 'invalid' }));
  assert.equal(counts.reads, 24, 'bad feedback never touches storage');
});

test('recommendation feedback keeps owners separate and expires tonight-only reactions', () => {
  const now = Date.now();
  const prompt = companionPrompt({ Clair: { feedback: [
    { title: 'Demo A', reason: 'not_tonight', at: now - 86400001 },
    { title: 'Demo B', reason: 'seen', at: now - 86400001 },
  ] }, Khent: { feedback: [{ title: 'Demo C', reason: 'more_like_this', at: now }] } }, now);
  assert.ok(!prompt.includes('Demo A'));
  assert.ok(prompt.includes('Clair: "Demo B"'));
  assert.ok(prompt.includes('Khent: "Demo C"'));
});

test('quiet hours cross midnight, nudges have a persistent interval, requested reminders bypass them', () => {
  const now = Date.parse('2026-10-10T15:00:00Z'); // 11 PM Philippine time
  assert.equal(allowsPush({}, 'habit_streak', now), false);
  assert.equal(allowsPush({ preferences: { nudges: 'off', digests: false } }, 'reminder', now), true);
  assert.equal(allowsPush({}, 'reminder_shared', now), true);
  const noon = Date.parse('2026-10-11T04:00:00Z');
  assert.equal(allowsPush({}, 'habit_streak', noon), true);
  assert.equal(allowsPush({ lastNudgeAt: noon - 3600000 }, 'journal_nudge', noon), false);
  assert.equal(allowsPush({ preferences: { nudges: 'weekly' }, lastNudgeAt: noon - 2 * 86400000 }, 'nudge', noon), false);
  assert.equal(allowsPush({ preferences: { quietStart: 12, quietEnd: 13 } }, 'nudge', noon), false);
  assert.equal(allowsPush({ preferences: { quietStart: 12, quietEnd: 12 } }, 'nudge', noon), true);
  assert.equal(allowsPush({ preferences: { digests: false } }, 'daily_digest', noon), false);
  assert.deepEqual(normalizePreferences(null), normalizePreferences());
  const sent = pushReservation('daily_digest', noon);
  assert.equal(allowsPush(sent, 'daily_digest', noon), false);
  assert.equal(allowsPush(sent, 'night_recap', noon), true);
  assert.equal(allowsPush(pushReservation('journal_nudge', noon - 2 * 86400000), 'journal_nudge', noon), false);
});

test('journey diagnostics count partial outcomes and latency without treating old turns as measured', () => {
  const metrics = journeyMetrics([
    { requestTrace: { completedWrites: 2, unfinishedWrites: 0, modelCalls: 3, firstTokenMs: 100 }, durationMs: 800 },
    { requestTrace: { completedWrites: 1, unfinishedWrites: 1, unknownWrites: 1, interrupted: 1, firstTokenMs: 500 },
      durationMs: 900 },
    { requestTrace: { completedWrites: 0, unfinishedWrites: 0, firstTokenMs: null }, durationMs: 100 },
    { requestTrace: null },
  ]);
  assert.equal(metrics.measuredTurns, 3);
  assert.equal(metrics.actionTurns, 2);
  assert.equal(metrics.completedActionTurns, 1);
  assert.equal(metrics.unknownWrites, 1);
  assert.equal(metrics.firstTokenP95Ms, 500);
  assert.equal(metrics.modelCalls, 3);
});

test('automatic memories require user evidence, reject temporary moods and preserve who reported them', () => {
  const candidate = { fact: 'Clair prefers short movies', category: 'preference', quote: 'Clair prefers short movies' };
  const report = memoryEvidence(candidate, candidate.quote, 'khentsgdz');
  assert.equal(report.provenance, 'partner_report');
  assert.equal(report.confidence, 0.8);
  assert.equal(memoryEvidence(candidate, candidate.quote, 'clairjassen').provenance, 'self_report');
  assert.equal(memoryEvidence(candidate, 'What should we watch?', 'khentsgdz'), null);
  assert.equal(memoryEvidence({ ...candidate, fact: 'Clair loves harp music' }, candidate.quote, 'khentsgdz'), null);
  assert.equal(memoryEvidence({ ...candidate, quote: 'I want short movies tonight' }, 'I want short movies tonight', 'clairjassen'), null);
  assert.equal(memoryEvidence({ ...candidate, fact: 'Khent and Clair prefer short movies' }, candidate.quote, 'khentsgdz'), null);
});

test('request budgets reserve long waits for artifacts and cap ordinary chat work', () => {
  assert.deepEqual(requestBudget({ lightChat: true }), { durationMs: 45000, calls: 2 });
  assert.deepEqual(requestBudget({}), { durationMs: 90000, calls: 8 });
  assert.equal(requestBudget({ thinking: true }).durationMs, 180000);
  assert.equal(requestBudget({ artifact: true }).durationMs, 280000);
});

test('durable actions survive cache resets; independent tasks are not accidentally collapsed', async () => {
  const { db, counts } = demoStorage();
  const original = TOOL_EXECUTORS.add_calendar_event;
  let saves = 0;
  TOOL_EXECUTORS.add_calendar_event = async () => JSON.stringify({ success: true, id: `demo-${++saves}` });
  try {
    const ctx = { db, caller: 'clairjassen', sessionId: 'demo-session', actionScopeId: 'demo-task-one' };
    const args = { title: 'Demo date', date: '2026-10-14' };
    const first = await executeToolCall(ctx, 'add_calendar_event', args);
    clearIdempotencyCache();
    const replay = await executeToolCall({ ...ctx }, 'add_calendar_event', args);
    assert.equal(JSON.parse(first).id, JSON.parse(replay).id);
    assert.equal(saves, 1);
    assert.equal(counts.reads, 2);
    assert.equal(counts.writes, 2, 'one reservation and one completion, no replay writes');
    await executeToolCall({ ...ctx, actionScopeId: 'demo-task-two' }, 'add_calendar_event', args);
    assert.equal(saves, 2, 'an intentional repeat in a new task is allowed');
    assert.equal(actionKey('clairjassen', 'a', 'delete_memory', { memory_id: 'm', confirm: false }),
      actionKey('clairjassen', 'a', 'delete_memory', { confirm: true, memory_id: 'm' }));
  } finally { TOOL_EXECUTORS.add_calendar_event = original; }
});

test('concurrent duplicates and uncertain writes cannot execute twice; stopping starts no new work', async () => {
  const { db, counts } = demoStorage();
  const original = TOOL_EXECUTORS.add_calendar_event;
  let saves = 0;
  let release;
  const gate = new Promise((resolve) => { release = resolve; });
  TOOL_EXECUTORS.add_calendar_event = async () => {
    saves++; await gate;
    throw new Error('connection lost after saving');
  };
  const ctx = { db, caller: 'khentsgdz', actionScopeId: 'demo-concurrent-task' };
  const args = { title: 'Demo date', date: '2026-10-14' };
  try {
    const first = executeToolCall(ctx, 'add_calendar_event', args);
    await new Promise((resolve) => setImmediate(resolve));
    const duplicate = JSON.parse(await executeToolCall({ ...ctx }, 'add_calendar_event', args));
    assert.equal(duplicate.outcome_unknown, true);
    release();
    assert.equal(JSON.parse(await first).outcome_unknown, true);
    clearIdempotencyCache();
    assert.equal(JSON.parse(await executeToolCall({ ...ctx }, 'add_calendar_event', args)).outcome_unknown, true);
    assert.equal(saves, 1);
    const before = { ...counts };
    await executeToolCall({ ...ctx, signal: AbortSignal.abort() }, 'add_calendar_event', args);
    assert.deepEqual(counts, before, 'Stop adds zero reads and writes');
  } finally { release(); TOOL_EXECUTORS.add_calendar_event = original; }
});
