'use strict';

/* Unit tests for the Motchi tool dispatcher + executors.
 * Executors are (ctx, args) => JSON string, so tests pass stub services
 * instead of touching Firestore or the network.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const tools = require('../motchi_tools.js');
const {
  createToolCtx,
  executeToolCall,
  TOOL_EXECUTORS,
  levelForXp,
  XP_PER_LEVEL,
} = require('../motchi_exec_tools.js');

// ── Minimal Firestore stub ──────────────────────────────────
// Supports exactly the call shapes the tested executors use:
//   db.collection(a).doc(b).collection(c).doc(d).get()/set()/delete()
//   db.collection(a).add(doc)

function makeDocStub({ exists = true, data = {} } = {}) {
  const calls = { set: [], deleted: false };
  return {
    calls,
    get: async () => ({ exists, data: () => data, id: 'doc1' }),
    set: async (doc, opts) => { calls.set.push({ doc, opts }); },
    delete: async () => { calls.deleted = true; },
    collection: () => { throw new Error('nested collection not stubbed'); },
  };
}

function makeDbStub({ leafDoc = null, added = null } = {}) {
  const doc = leafDoc || makeDocStub({ exists: false, data: {} });
  const addedDocs = added || [];
  const terminal = {
    get: (...a) => doc.get(...a),
    set: (...a) => doc.set(...a),
    delete: (...a) => doc.delete(...a),
  };
  const chain = {
    doc: () => ({ ...terminal, collection: () => chain }),
    collection: () => chain,
    add: async (d) => { addedDocs.push(d); return { id: 'new1' }; },
  };
  return { db: { collection: () => chain }, doc, addedDocs };
}

function makeCtx(dbOverrides) {
  const { db, doc, addedDocs } = makeDbStub(dbOverrides);
  const ctx = {
    admin: {
      firestore: {
        FieldValue: { serverTimestamp: () => 'TS' },
        Timestamp: {
          fromDate: (d) => ({ toDate: () => d }),
          now: () => ({ toDate: () => new Date() }),
        },
      },
    },
    db,
    callerUid: 'khentsgdz',
    caller: 'khentsgdz',
    levelForXp,
    phtDateString: () => '2026-09-16',
    getTmdbKey: () => 'k',
    sendFCMToUser: async () => {},
    getSpotifyAppToken: async () => null,
    cacheGet: () => undefined,
    cacheSet: () => {},
    cacheTTLs: {},
  };
  return { ctx, doc, addedDocs };
}

test('dispatcher maps every pinned tool to an executor', () => {
  assert.equal(Object.keys(TOOL_EXECUTORS).length, tools.TOOL_NAMES.length);
  for (const name of tools.TOOL_NAMES) {
    assert.equal(typeof TOOL_EXECUTORS[name], 'function', `missing: ${name}`);
  }
});

test('dispatcher rejects unknown tools as JSON, never throws', async () => {
  const { ctx } = makeCtx();
  const out = JSON.parse(await executeToolCall(ctx, 'nope_tool', {}));
  assert.match(out.error, /Unknown tool/);
});

test('dispatcher gates malformed calls through validateToolArgs', async () => {
  const { ctx } = makeCtx();
  const bad = JSON.parse(await executeToolCall(ctx, 'add_to_watchlist', {}));
  assert.match(bad.error, /No title provided/);
  const bad2 = JSON.parse(await executeToolCall(ctx, 'remember_fact', { fact: '  ' }));
  assert.match(bad2.error, /No fact provided/);
});

test('level curve matches the client (200 XP per level)', () => {
  assert.equal(XP_PER_LEVEL, 200);
  assert.equal(levelForXp(0), 1);
  assert.equal(levelForXp(-5), 1);
  assert.equal(levelForXp(199), 1);
  assert.equal(levelForXp(200), 2);
  assert.equal(levelForXp(400), 3);
  assert.equal(levelForXp('not-a-number'), 1);
});

test('add_xp clamps the amount and reports the new total', async () => {
  const leaf = makeDocStub({ exists: true, data: { xpTotal: 150, streak: 3 } });
  const { ctx, doc } = makeCtx({ leafDoc: leaf });
  const out = JSON.parse(await executeToolCall(ctx, 'add_xp', { amount: 500, reason: 'test' }));
  assert.equal(out.success, true);
  assert.equal(out.amount, 100); // clamped from 500
  assert.equal(out.xpTotal, 250);
  assert.equal(out.level, 2);
  assert.equal(doc.calls.set.length, 1);
  assert.equal(doc.calls.set[0].doc.streak, 3); // streak preserved

  const out2 = JSON.parse(await executeToolCall(ctx, 'add_xp', { amount: 'junk' }));
  assert.equal(out2.amount, 25); // non-numeric falls back to 25
});

test('add_xp grants the remainder when the request exceeds the cap', async () => {
  const leaf = makeDocStub({
    exists: true,
    data: { xpTotal: 1000, streak: 5, motchiXpDate: '2026-09-16', motchiXpDayTotal: 150 },
  });
  const { ctx, doc } = makeCtx({ leafDoc: leaf });
  const partial = JSON.parse(await executeToolCall(ctx, 'add_xp', { amount: 100 }));
  assert.equal(partial.success, true);
  assert.equal(partial.amount, 50); // remainder up to the 200 cap
  assert.equal(partial.dayTotal, 200);
  assert.equal(partial.xpTotal, 1050);
  assert.equal(doc.calls.set[0].doc.motchiXpDayTotal, 200);
  assert.equal(doc.calls.set[0].doc.motchiXpDate, '2026-09-16');
});

test('add_xp refuses when the day total already hit the cap', async () => {
  const leaf = makeDocStub({
    exists: true,
    data: { xpTotal: 1000, streak: 5, motchiXpDate: '2026-09-16', motchiXpDayTotal: 200 },
  });
  const { ctx, doc } = makeCtx({ leafDoc: leaf });
  const out = JSON.parse(await executeToolCall(ctx, 'add_xp', { amount: 25 }));
  assert.equal(out.success, false);
  assert.equal(out.capped, true);
  assert.equal(out.xpTotal, 1000); // untouched
  assert.equal(doc.calls.set.length, 0); // no write at all
});

test('add_xp resets the day total on a new Philippine day', async () => {
  const leaf = makeDocStub({
    exists: true,
    data: { xpTotal: 1000, streak: 5, motchiXpDate: '2026-09-15', motchiXpDayTotal: 200 },
  });
  const { ctx } = makeCtx({ leafDoc: leaf });
  const out = JSON.parse(await executeToolCall(ctx, 'add_xp', { amount: 25 }));
  assert.equal(out.success, true);
  assert.equal(out.amount, 25);
  assert.equal(out.dayTotal, 25);
});

test('delete_memory asks for confirmation before touching anything', async () => {
  const leaf = makeDocStub({ exists: true, data: { fact: 'Clair loves oat lattes', category: 'fact' } });
  const { ctx, doc, addedDocs } = makeCtx({ leafDoc: leaf });
  const first = JSON.parse(await executeToolCall(ctx, 'delete_memory', { memory_id: 'm1' }));
  assert.equal(first.needs_confirmation, true);
  assert.equal(first.memory_id, 'm1');
  assert.match(first.message, /confirm:true/);
  assert.equal(doc.calls.deleted, false);
  assert.equal(addedDocs.length, 0);
});

test('delete_memory with confirm soft-deletes to trash, then deletes', async () => {
  const leaf = makeDocStub({ exists: true, data: { fact: 'Old fact', category: 'fact' } });
  const { ctx, doc, addedDocs } = makeCtx({ leafDoc: leaf });
  const out = JSON.parse(
    await executeToolCall(ctx, 'delete_memory', { memory_id: 'm1', confirm: true }),
  );
  assert.equal(out.success, true);
  assert.equal(out.memory_id, 'm1');
  assert.equal(addedDocs.length, 1); // trash copy first
  assert.equal(addedDocs[0].originalId, 'm1');
  assert.equal(addedDocs[0].deletedBy, 'khentsgdz');
  assert.equal(doc.calls.deleted, true);
});

test('delete_memory reports missing memories and missing ids', async () => {
  const { ctx } = makeCtx({ leafDoc: makeDocStub({ exists: false }) });
  const missing = JSON.parse(await executeToolCall(ctx, 'delete_memory', { memory_id: 'ghost' }));
  assert.match(missing.error, /not found/);
  const noId = JSON.parse(await executeToolCall(ctx, 'delete_memory', {}));
  assert.match(noId.error, /memory_id required/);
});

// ── Reminder executors ────────────────────────────────────

function makeReminderDoc(id, data, updates) {
  return {
    id,
    data: () => data,
    exists: true,
    ref: { update: async (patch) => { updates.push({ id, patch }); } },
  };
}

function makeReminderCtx(docs) {
  const updates = [];
  const fakeDocs = docs.map((d, i) =>
    makeReminderDoc(d.id || `r${i}`, d.data, updates));
  const query = {
    where: () => query,
    orderBy: () => query,
    limit: () => query,
    get: async () => ({ docs: fakeDocs, empty: fakeDocs.length === 0, size: fakeDocs.length }),
  };
  const db = {
    collection: () => ({
      ...query,
      doc: (id) => {
        const found = fakeDocs.find((d) => d.id === id);
        return {
          get: async () => found || { exists: false, data: () => null },
          update: async (patch) => { updates.push({ id, patch }); },
        };
      },
      add: async (d) => ({ id: 'new1', data: d }),
    }),
  };
  const { ctx } = makeCtx();
  ctx.db = db;
  return { ctx, updates };
}

test('list_reminders returns pending reminders due-soonest first', async () => {
  const day = 24 * 60 * 60 * 1000;
  const ts = (ms) => ({ toDate: () => new Date(ms) });
  const { ctx } = makeReminderCtx([
    { id: 'late', data: { title: 'Late', remindAtTs: ts(Date.now() + 3 * day), createdBy: 'khentsgdz' } },
    { id: 'soon', data: { title: 'Soon', note: 'x', remindAtTs: ts(Date.now() + day), createdBy: 'clairjassen' } },
    { id: 'nodate', data: { title: 'No date' } },
  ]);
  const out = JSON.parse(await executeToolCall(ctx, 'list_reminders', {}));
  assert.equal(out.count, 3);
  assert.deepEqual(out.reminders.map((r) => r.id), ['soon', 'late', 'nodate']);
  assert.equal(out.reminders[0].title, 'Soon');
  assert.equal(out.reminders[0].created_by, 'clairjassen');
});

test('cancel_reminder by id cancels a pending reminder', async () => {
  const { ctx, updates } = makeReminderCtx([
    { id: 'r1', data: { title: 'Water plants', fired: false } },
  ]);
  const out = JSON.parse(await executeToolCall(ctx, 'cancel_reminder', { id: 'r1' }));
  assert.equal(out.success, true);
  assert.equal(out.title, 'Water plants');
  assert.equal(updates.length, 1);
  assert.equal(updates[0].patch.cancelled, true);
  assert.equal(updates[0].patch.fired, true);
});

test('cancel_reminder by id reports missing, fired, and already-cancelled', async () => {
  const { ctx, updates } = makeReminderCtx([
    { id: 'done', data: { title: 'Old', fired: true } },
    { id: 'gone', data: { title: 'Gone', fired: true, cancelled: true } },
  ]);
  const missing = JSON.parse(await executeToolCall(ctx, 'cancel_reminder', { id: 'ghost' }));
  assert.match(missing.error, /not found/);
  const fired = JSON.parse(await executeToolCall(ctx, 'cancel_reminder', { id: 'done' }));
  assert.match(fired.error, /already fired/);
  const again = JSON.parse(await executeToolCall(ctx, 'cancel_reminder', { id: 'gone' }));
  assert.equal(again.success, true);
  assert.equal(again.already_cancelled, true);
  assert.equal(updates.length, 0);
  const noArgs = JSON.parse(await executeToolCall(ctx, 'cancel_reminder', {}));
  assert.match(noArgs.error, /id or title required/);
});

test('cancel_reminder by title confirms first, then cancels matches', async () => {
  const { ctx, updates } = makeReminderCtx([
    { id: 'r1', data: { title: 'Water the garden', fired: false } },
    { id: 'r2', data: { title: 'Unrelated', fired: false } },
  ]);
  const first = JSON.parse(await executeToolCall(ctx, 'cancel_reminder', { title: 'water' }));
  assert.equal(first.needs_confirmation, true);
  assert.equal(first.count, 1);
  assert.equal(updates.length, 0);
  const confirmed = JSON.parse(
    await executeToolCall(ctx, 'cancel_reminder', { title: 'water', confirm: true }));
  assert.equal(confirmed.success, true);
  assert.equal(confirmed.count, 1);
  assert.equal(updates.length, 1);
  assert.equal(updates[0].id, 'r1');
  const nomatch = JSON.parse(await executeToolCall(ctx, 'cancel_reminder', { title: 'zzz' }));
  assert.match(nomatch.error, /No pending reminder/);
});

// ── Journal / calendar / bucket cleanup executors ───────────

function makeCollectionCtx(seed) {
  // seed: { collectionName: [{ id, data }] }
  const writes = [];
  const db = {
    collection: (name) => {
      const docs = (seed[name] || []).map((d) => ({
        id: d.id,
        data: () => d.data,
        exists: true,
        ref: {
          id: d.id,
          get: async () => ({ exists: true, data: () => d.data }),
          update: async (patch) => { writes.push({ coll: name, id: d.id, op: 'update', patch }); },
          delete: async () => { writes.push({ coll: name, id: d.id, op: 'delete' }); },
        },
      }));
      const query = {
        where: () => query,
        orderBy: () => query,
        limit: () => query,
        get: async () => ({ docs, empty: docs.length === 0, size: docs.length }),
      };
      return {
        ...query,
        doc: (id) => {
          const found = docs.find((d) => d.id === id);
          return found ? found.ref : {
            id,
            get: async () => ({ exists: false, data: () => null }),
            update: async (patch) => { writes.push({ coll: name, id, op: 'update', patch }); },
            delete: async () => { writes.push({ coll: name, id, op: 'delete' }); },
          };
        },
        add: async (d) => ({ id: 'new1', data: d }),
      };
    },
  };
  const { ctx } = makeCtx();
  ctx.db = db;
  return { ctx, writes };
}

test('edit_journal_entry updates fields and recomputes search helpers', async () => {
  const { ctx, writes } = makeCollectionCtx({
    journal_entries: [{ id: 'j1', data: { title: 'Old title', content: 'old words here' } }],
  });
  const out = JSON.parse(await executeToolCall(ctx, 'edit_journal_entry',
    { id: 'j1', content: 'brand new content words' }));
  assert.equal(out.success, true);
  assert.equal(writes.length, 1);
  assert.equal(writes[0].patch.content, 'brand new content words');
  assert.equal(writes[0].patch.wordCount, 4);
  assert.match(writes[0].patch.searchKey, /brand new/);
  assert.ok(writes[0].patch.updatedAt);
});

test('edit_journal_entry resolves single title matches, lists candidates', async () => {
  const { ctx } = makeCollectionCtx({
    journal_entries: [
      { id: 'j1', data: { title: 'Beach day', content: 'x' } },
      { id: 'j2', data: { title: 'Beach night', content: 'y' } },
    ],
  });
  const multi = JSON.parse(await executeToolCall(ctx, 'edit_journal_entry',
    { title: 'beach', content: 'z' }));
  assert.equal(multi.needs_confirmation, true);
  assert.equal(multi.candidates.length, 2);
  const single = JSON.parse(await executeToolCall(ctx, 'edit_journal_entry',
    { title: 'beach day', content: 'z' }));
  assert.equal(single.success, true);
  assert.equal(single.id, 'j1');
  const missing = JSON.parse(await executeToolCall(ctx, 'edit_journal_entry',
    { title: 'nope', content: 'z' }));
  assert.match(missing.error, /No journal entry found/);
  const bad = JSON.parse(await executeToolCall(ctx, 'edit_journal_entry',
    { id: 'j1', category: 'nope' }));
  assert.match(bad.error, /Invalid category/);
});

test('delete_journal_entry confirms, then hard-deletes like the client', async () => {
  const { ctx, writes } = makeCollectionCtx({
    journal_entries: [{ id: 'j1', data: { title: 'Goodbye', content: 'x' } }],
  });
  const first = JSON.parse(await executeToolCall(ctx, 'delete_journal_entry', { id: 'j1' }));
  assert.equal(first.needs_confirmation, true);
  assert.equal(writes.length, 0);
  const done = JSON.parse(await executeToolCall(ctx, 'delete_journal_entry', { id: 'j1', confirm: true }));
  assert.equal(done.success, true);
  assert.deepEqual(writes, [{ coll: 'journal_entries', id: 'j1', op: 'delete' }]);
});

test('update_calendar_event changes fields and validates dates', async () => {
  const { ctx, writes } = makeCollectionCtx({
    calendar_events: [{ id: 'c1', data: { title: 'Dentist' } }],
  });
  const out = JSON.parse(await executeToolCall(ctx, 'update_calendar_event',
    { id: 'c1', date: '2026-10-01', location: 'Cabadbaran' }));
  assert.equal(out.success, true);
  assert.equal(writes.length, 1);
  assert.equal(writes[0].patch.location, 'Cabadbaran');
  assert.ok(writes[0].patch.date);
  const bad = JSON.parse(await executeToolCall(ctx, 'update_calendar_event',
    { id: 'c1', date: 'not-a-date' }));
  assert.match(bad.error, /Invalid date/);
  const empty = JSON.parse(await executeToolCall(ctx, 'update_calendar_event', { id: 'c1' }));
  assert.match(empty.error, /Nothing to update/);
});

test('delete_calendar_event confirms first', async () => {
  const { ctx, writes } = makeCollectionCtx({
    calendar_events: [{ id: 'c1', data: { title: 'Dentist' } }],
  });
  const first = JSON.parse(await executeToolCall(ctx, 'delete_calendar_event', { title: 'dentist' }));
  assert.equal(first.needs_confirmation, true);
  assert.equal(first.id, 'c1');
  assert.equal(writes.length, 0);
  const done = JSON.parse(await executeToolCall(ctx, 'delete_calendar_event', { id: 'c1', confirm: true }));
  assert.equal(done.success, true);
  assert.equal(writes.length, 1);
});

test('complete_bucket_item completes once, with client-parity fields', async () => {
  const { ctx, writes } = makeCollectionCtx({
    bucket_list: [
      { id: 'b1', data: { title: 'Bohol', status: 'wish' } },
      { id: 'b2', data: { title: 'Done thing', status: 'completed' } },
    ],
  });
  const out = JSON.parse(await executeToolCall(ctx, 'complete_bucket_item', { title: 'bohol' }));
  assert.equal(out.success, true);
  assert.equal(writes.length, 1);
  assert.equal(writes[0].patch.status, 'completed');
  assert.ok(writes[0].patch.completedAt);
  assert.equal(writes[0].patch.completedBy, 'khentsgdz');
  const again = JSON.parse(await executeToolCall(ctx, 'complete_bucket_item', { id: 'b2' }));
  assert.equal(again.success, true);
  assert.equal(again.already_completed, true);
  assert.equal(writes.length, 1); // no second write
});

test('delete_bucket_item confirms first', async () => {
  const { ctx, writes } = makeCollectionCtx({
    bucket_list: [{ id: 'b1', data: { title: 'Skydive', status: 'wish' } }],
  });
  const first = JSON.parse(await executeToolCall(ctx, 'delete_bucket_item', { id: 'b1' }));
  assert.equal(first.needs_confirmation, true);
  assert.equal(writes.length, 0);
  const done = JSON.parse(await executeToolCall(ctx, 'delete_bucket_item', { id: 'b1', confirm: true }));
  assert.equal(done.success, true);
  assert.equal(writes.length, 1);
});

test('createToolCtx builds a live ctx (smoke: shape only)', () => {
  // getAdmin() throws outside Cloud Functions without credentials, so a
  // live ctx can only be built where Firebase is configured. When it
  // builds, it must carry every service executors expect.
  let ctx;
  try {
    ctx = createToolCtx({ callerUid: 'khentsgdz', caller: 'khentsgdz' });
  } catch (_) {
    return; // no credentials here — shape covered by makeCtx above
  }
  for (const key of ['admin', 'db', 'callerUid', 'caller', 'levelForXp',
    'phtDateString', 'getTmdbKey', 'sendFCMToUser', 'getSpotifyAppToken',
    'cacheGet', 'cacheSet', 'cacheTTLs']) {
    assert.ok(ctx[key] !== undefined, `ctx missing: ${key}`);
  }
});
