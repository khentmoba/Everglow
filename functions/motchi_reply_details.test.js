'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { citedMemories, stripMemoryCitations, toolReceipt } = require('./motchi_reply_details');
const { executeToolCall, TOOL_EXECUTORS } = require('./motchi_exec_tools');
const { exec_edit_memory } = require('./motchi_exec_memory');
const { selectToolsForRequest } = require('./motchi_tool_schemas');

test('only cited, supplied facts become memory references; owners are preserved', () => {
  const facts = [
    { id: 'clair-cake', fact: 'Clair likes mango cake', subject: 'Clair' },
    { id: 'khent-coffee', fact: 'Khent likes coffee', subject: 'Khent' },
  ];
  const reply = 'Pick cake [[memory:clair-cake]] [[memory:invented]] [[memory:clair-cake]]';
  assert.deepEqual(citedMemories(reply, facts), [facts[0]]);
  assert.equal(stripMemoryCitations(reply).trim(), 'Pick cake');
  assert.deepEqual(citedMemories('No personalization needed', facts), []);
});

test('a memory correction keeps its owner, including old unstructured facts', async () => {
  for (const previous of [{ subject: 'Clair' }, { fact: 'Clair likes short movies' }]) {
    let update;
    const ref = { get: async () => ({ exists: true, data: () => previous }), update: async (v) => { update = v; } };
    const ctx = {
      db: { collection: () => ({ doc: () => ({ collection: () => ({ doc: () => ref }) }) }) },
      admin: { firestore: { FieldValue: { serverTimestamp: () => 'demo-time' } } },
    };
    const result = JSON.parse(await exec_edit_memory(ctx, { memory_id: 'demo-clair', fact: 'Short comedies are my favorite' }));
    assert.equal(result.success, true);
    assert.equal(update.subject, 'Clair');
  }
  const schemas = selectToolsForRequest('assistant', 'Correct the saved memory with memory_id "demo-clair": "Clair likes comedies". Use edit_memory to update this exact id, not remember_fact.');
  assert.ok(schemas.some((s) => s.function.name === 'edit_memory'));
});

test('a multi-step result separates saved, pending, failed, unscheduled, and unknown work', () => {
  const receipts = [
    toolReceipt('search_movies', { query: 'cozy' }, { movies: [] }),
    toolReceipt('add_calendar_event', { title: 'Date night' }, { success: true }),
    toolReceipt('create_reminder', { title: 'Get snacks' }, { error: 'bad date' }),
    toolReceipt('delete_memory', {}, { needs_confirmation: true }),
    toolReceipt('create_reminder', {}, { success: true, scheduled: false }),
    toolReceipt('add_calendar_event', {}, { error: 'timeout', outcome_unknown: true }),
    toolReceipt('add_trip', {}, {}),
  ];
  assert.deepEqual(receipts.map((s) => s.status), ['done', 'done', 'failed', 'waiting', 'unscheduled', 'unknown', 'unknown']);
  assert.equal(receipts[1].title, 'Date night');
  assert.equal(receipts[0].write, false);
  assert.equal(receipts[1].write, true);
});

test('thrown writes are not retried and report an unknown outcome', async (t) => {
  const original = TOOL_EXECUTORS.add_calendar_event;
  t.after(() => { TOOL_EXECUTORS.add_calendar_event = original; });
  let calls = 0;
  TOOL_EXECUTORS.add_calendar_event = async () => { calls++; throw new Error('503 after save'); };
  const ctx = {};
  const result = JSON.parse(await executeToolCall(ctx, 'add_calendar_event', { title: 'Date', date: '2026-10-09' }));
  const repeated = JSON.parse(await executeToolCall(ctx, 'add_calendar_event', { title: 'Another date', date: '2026-10-10' }));
  assert.equal(repeated.outcome_unknown, true);
  assert.equal(calls, 1);
  assert.equal(result.outcome_unknown, true);
});
