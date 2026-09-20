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
  visionMessageForResults,
  VISION_IMAGES_PER_ROUND,
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
    // Query-chain no-ops returning empty results, so the split-injury guard
    // below can run read executors (orderBy/limit/get) without a real DB.
    where: () => chain,
    orderBy: () => chain,
    limit: () => chain,
    get: async () => ({ docs: [], empty: true, size: 0 }),
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

// ── Gallery vision ────────────────────────────────────────

test('get_gallery stays text-only unless include_images is set', async () => {
  const { ctx } = makeCollectionCtx({
    gallery: [{ id: 'g1', data: { caption: 'Beach', imageUrl: 'https://full/1', thumbUrl: 'https://thumb/1' } }],
  });
  const out = JSON.parse(await executeToolCall(ctx, 'get_gallery', {}));
  assert.equal(out.count, 1);
  assert.equal(out.photos[0].imageUrl, '[image]');
  assert.ok(!('vision_images' in out));
});

test('get_gallery attaches up to 3 thumbnails when asked', async () => {
  const docs = [1, 2, 3, 4, 5].map((i) => ({
    id: `g${i}`,
    data: { caption: `Photo ${i}`, imageUrl: `https://full/${i}`, thumbUrl: `https://thumb/${i}` },
  }));
  // One photo with full-size URL only (no thumbnail backfilled yet).
  docs.push({ id: 'g6', data: { caption: 'Old one', imageUrl: 'https://full/6' } });
  const { ctx } = makeCollectionCtx({ gallery: docs });
  const out = JSON.parse(await executeToolCall(ctx, 'get_gallery', { include_images: true }));
  assert.equal(out.vision_images.length, 3);
  assert.equal(out.vision_images[0].url, 'https://thumb/1'); // thumbnails first
  assert.equal(out.vision_images[0].caption, 'Photo 1');
});

test('get_gallery falls back to full URLs without thumbnails', async () => {
  const { ctx } = makeCollectionCtx({
    gallery: [{ id: 'g1', data: { caption: 'Old', imageUrl: 'https://full/1' } }],
  });
  const out = JSON.parse(await executeToolCall(ctx, 'get_gallery', { include_images: true }));
  assert.equal(out.vision_images.length, 1);
  assert.equal(out.vision_images[0].url, 'https://full/1');
});

test('visionMessageForResults builds image input, capped per round', () => {
  assert.equal(VISION_IMAGES_PER_ROUND, 3);
  assert.equal(visionMessageForResults([]), null);
  assert.equal(visionMessageForResults(['{"photos":[]}']), null);
  assert.equal(visionMessageForResults(['not json']), null);
  const msg = visionMessageForResults([
    JSON.stringify({ vision_images: [{ url: 'a' }, { url: 'b' }] }),
    JSON.stringify({ vision_images: [{ url: 'c' }, { url: 'd' }] }),
  ]);
  assert.equal(msg.role, 'user');
  const images = msg.content.filter((p) => p.type === 'image_url');
  assert.equal(images.length, 3); // merged total capped
  assert.deepEqual(images.map((p) => p.image_url.url), ['a', 'b', 'c']);
  assert.equal(msg.content[0].type, 'text');
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

test('every tool runs without ReferenceError (split-injury guard)', async () => {
  // The motchi_chat.js -> motchi_exec_*.js split moved executors without
  // their helpers (parseFactStructure, rankMemories, getEmbedding,
  // PARTNER_UID), so remember_fact and friends threw on every call while
  // Motchi told Khent the memory book had a hiccup. This guard runs all
  // 58 tools with validation-passing args against both a missing and an
  // existing doc; any 'X is not defined' fails loudly. Other errors are
  // fine — stubs have no network or real data.
  const realFetch = global.fetch;
  global.fetch = async () => ({
    ok: false, status: 500, json: async () => ({}), text: async () => '',
  });
  try {
    const argsByTool = {
      add_to_watchlist: { title: 'x' },
      save_to_starlight_jar: { note: 'x' },
      set_mood: { mood: 'happy' },
      search_movies: { query: 'x' },
      get_weather: {},
      create_reminder: { title: 'x' },
      list_reminders: {},
      cancel_reminder: { id: 'x' },
      log_activity: { activity: 'x' },
      search_books: { query: 'x' },
      get_date_ideas: {},
      read_chat_messages: {},
      send_sanctuary_message: { text: 'hi' },
      get_xp_stats: {},
      search_anime: { query: 'x' },
      add_book_to_our_books: { query: 'x' },
      read_starlight_jar: {},
      get_watchlist: {},
      remember_fact: { fact: 'Clair loves lilies' },
      read_memories: {},
      pin_memory: { memory_id: 'x' },
      delete_memory: { memory_id: 'x' },
      edit_memory: { memory_id: 'x', fact: 'y' },
      web_search: { query: 'x' },
      read_web_page: { urls: ['https://example.com'] },
      browse_web: { url: 'https://example.com', goal: 'Get the price' },
      mark_watchlist_item_watched: { title: 'x' },
      update_book_progress: { title: 'x', progress: 10 },
      add_xp: { amount: 10 },
      send_note_to_partner: { note: 'hi' },
      get_relationship_insights: {},
      get_memory_trivia: {},
      get_today_recap: {},
      get_gallery: {},
      get_garden: {},
      get_canvas: {},
      search_spotify: { query: 'x' },
      remove_from_watchlist: { title: 'x' },
      search_everglow: { query: 'x' },
      plan_date_night: {},
      add_calendar_event: { title: 'x', date: '2026-10-01' },
      create_journal_entry: { title: 't', content: 'c' },
      add_bucket_item: { title: 'x' },
      add_trip: { title: 'x', start_date: '2026-10-01', end_date: '2026-10-05' },
      add_trip_pin: { title: 'x' },
      log_habit: { title: 'x' },
      complete_habit: {},
      get_calendar_events: {},
      get_bucket_list: {},
      get_journal_entries: {},
      search_journal_entries: { query: 'x' },
      read_journal_entry: { id: 'x' },
      get_trips: {},
      edit_journal_entry: { id: 'x', content: 'y' },
      delete_journal_entry: { id: 'x' },
      update_calendar_event: { id: 'x', location: 'y' },
      delete_calendar_event: { id: 'x' },
      complete_bucket_item: { id: 'x' },
      delete_bucket_item: { id: 'x' },
      edit_bucket_item: { id: 'x', new_title: 'y' },
      edit_habit: { id: 'x', new_title: 'y' },
      edit_reminder: { id: 'x', note: 'y' },
      edit_trip: { id: 'x', new_title: 'y' },
    };
    for (const name of tools.TOOL_NAMES) {
      for (const exists of [false, true]) {
        const { ctx } = makeCtx({
          leafDoc: makeDocStub({
            exists,
            data: { fact: 'seed fact', title: 'seed title', category: 'fact' },
          }),
        });
        const out = await executeToolCall(ctx, name, argsByTool[name] || {});
        assert.ok(
          !/is not defined/.test(out),
          `${name} (exists=${exists}): ${String(out).slice(0, 200)}`,
        );
      }
    }
  } finally {
    global.fetch = realFetch;
  }
});

test('browse_web needs its API key before touching the network', async () => {
  const { ctx } = makeCtx();
  const realKey = process.env.TINYFISH_API_KEY;
  delete process.env.TINYFISH_API_KEY;
  try {
    const out = JSON.parse(await executeToolCall(
      ctx, 'browse_web', { url: 'https://example.com', goal: 'Get the price' },
    ));
    assert.match(out.error, /not configured/);
  } finally {
    if (realKey === undefined) delete process.env.TINYFISH_API_KEY;
    else process.env.TINYFISH_API_KEY = realKey;
  }
});

test('browse_web queues a run and returns the completed result', async () => {
  const { ctx } = makeCtx();
  const realKey = process.env.TINYFISH_API_KEY;
  const realFetch = global.fetch;
  process.env.TINYFISH_API_KEY = 'test-key';
  const seen = [];
  global.fetch = async (url, opts) => {
    seen.push(String(url));
    if (String(url).includes('/run-async')) {
      assert.equal(JSON.parse(opts.body).browser_profile, 'lite');
      return { ok: true, status: 200, json: async () => ({ run_id: 'run-1', error: null }) };
    }
    return {
      ok: true, status: 200,
      json: async () => ({
        run_id: 'run-1', status: 'COMPLETED',
        result: { title: 'Beans', price: '$9' }, error: null,
      }),
    };
  };
  try {
    const out = JSON.parse(await executeToolCall(
      ctx, 'browse_web', { url: 'https://example.com/beans', goal: 'Get the price as JSON' },
    ));
    assert.equal(out.status, 'COMPLETED');
    assert.equal(out.run_id, 'run-1');
    assert.equal(out.url, 'https://example.com/beans');
    assert.equal(out.title, 'Beans');
    assert.match(out.text, /\$9/);
    assert.ok(seen.some((u) => u.includes('/run-async')), 'queues first');
    assert.ok(seen.some((u) => u.includes('/v1/runs/run-1')), 'then polls');
  } finally {
    global.fetch = realFetch;
    if (realKey === undefined) delete process.env.TINYFISH_API_KEY;
    else process.env.TINYFISH_API_KEY = realKey;
  }
});

test('browse_web sends stealth when asked and stays resumable mid-run', async () => {
  const { ctx } = makeCtx();
  const realKey = process.env.TINYFISH_API_KEY;
  const realFetch = global.fetch;
  process.env.TINYFISH_API_KEY = 'test-key';
  global.fetch = async (url, opts) => {
    if (String(url).includes('/run-async')) {
      assert.equal(JSON.parse(opts.body).browser_profile, 'stealth');
      return { ok: true, status: 200, json: async () => ({ run_id: 'run-2', error: null }) };
    }
    throw new Error('poll timed out');
  };
  try {
    const out = JSON.parse(await executeToolCall(
      ctx, 'browse_web',
      { url: 'https://example.com/gated', goal: 'Read it', stealth: true },
    ));
    assert.equal(out.status, 'RUNNING');
    assert.equal(out.run_id, 'run-2');
    assert.match(out.hint, /attempt 2/);
  } finally {
    global.fetch = realFetch;
    if (realKey === undefined) delete process.env.TINYFISH_API_KEY;
    else process.env.TINYFISH_API_KEY = realKey;
  }
});

test('browse_web resumes by run_id without re-queueing, failures as JSON', async () => {
  const { ctx } = makeCtx();
  const realKey = process.env.TINYFISH_API_KEY;
  const realFetch = global.fetch;
  process.env.TINYFISH_API_KEY = 'test-key';
  global.fetch = async (url) => {
    assert.ok(!String(url).includes('/run-async'), 'resume must not queue');
    return {
      ok: true, status: 200,
      json: async () => ({
        run_id: 'run-9', status: 'FAILED',
        result: null, error: { message: 'page blocked', category: 'AGENT_FAILURE' },
      }),
    };
  };
  try {
    const out = JSON.parse(await executeToolCall(
      ctx, 'browse_web',
      { url: 'https://example.com/gated', goal: 'Read it', run_id: 'run-9', attempt: 3 },
    ));
    assert.equal(out.status, 'FAILED');
    assert.match(out.error, /page blocked/);
  } finally {
    global.fetch = realFetch;
    if (realKey === undefined) delete process.env.TINYFISH_API_KEY;
    else process.env.TINYFISH_API_KEY = realKey;
  }
});

test('remember_fact updates a contradicted fact instead of adding a twin', async () => {
  const { exec_remember_fact } = require('../motchi_exec_memory.js');
  const updates = [];
  const added = [];
  const staleDoc = {
    id: 'fact1',
    data: () => ({ fact: 'Khent prefers black coffee', category: 'preference' }),
  };
  const factsCol = {
    where: () => ({ limit: () => ({ get: async () => ({ docs: [staleDoc] }) }) }),
    doc: (id) => ({
      update: async (patch) => { updates.push({ id, patch }); },
    }),
    add: async (d) => { added.push(d); return { id: 'new1' }; },
  };
  const ctx = {
    admin: { firestore: { FieldValue: { serverTimestamp: () => 'TS' } } },
    db: { collection: () => ({ doc: () => ({ collection: () => factsCol }) }) },
    callerUid: 'khentsgdz',
  };
  const res = JSON.parse(await exec_remember_fact(ctx, { fact: 'Khent prefers oat lattes' }));
  assert.equal(res.success, true);
  assert.equal(res.updated, true);
  assert.equal(res.id, 'fact1');
  assert.equal(res.previous, 'Khent prefers black coffee');
  assert.equal(updates.length, 1);
  assert.equal(updates[0].patch.fact, 'Khent prefers oat lattes');
  assert.equal(added.length, 0);
});

test('remember_fact adds fresh facts with no contradiction', async () => {
  const { exec_remember_fact } = require('../motchi_exec_memory.js');
  const added = [];
  const factsCol = {
    where: () => ({ limit: () => ({ get: async () => ({ docs: [] }) }) }),
    doc: () => ({ update: async () => { throw new Error('should not update'); } }),
    add: async (d) => { added.push(d); return { id: 'new1' }; },
  };
  const ctx = {
    admin: { firestore: { FieldValue: { serverTimestamp: () => 'TS' } } },
    db: { collection: () => ({ doc: () => ({ collection: () => factsCol }) }) },
    callerUid: 'khentsgdz',
  };
  const res = JSON.parse(await exec_remember_fact(ctx, { fact: 'Clair loves dachshunds' }));
  assert.equal(res.success, true);
  assert.equal(res.updated, undefined);
  assert.equal(added.length, 1);
  assert.equal(added[0].fact, 'Clair loves dachshunds');
});

test('edit executors patch by title and reject bad fields', async () => {
  const planning = require('../motchi_exec_planning.js');
  const updates = [];
  const mkCtx = (docs) => {
    const col = {
      limit: () => ({
        get: async () => ({
          docs: docs.map((d) => ({
            id: d.id,
            data: () => d.data,
            ref: { id: d.id, get: async () => ({ exists: true, data: () => d.data }), update: async (u) => { updates.push({ id: d.id, patch: u }); } },
          })),
        }),
      }),
      doc: () => ({
        get: async () => ({ exists: false }),
      }),
    };
    return {
      admin: { firestore: { Timestamp: { fromDate: (d) => ({ _d: d }) } } },
      db: { collection: () => col },
      callerUid: 'khentsgdz',
    };
  };
  // Bucket: title lookup + patch + enum guard.
  let out = JSON.parse(await planning.exec_edit_bucket_item(
    mkCtx([{ id: 'b1', data: { title: 'Siargao surfing' } }]),
    { title: 'Siargao', priority: 'high' },
  ));
  assert.equal(out.success, true);
  assert.equal(updates[0].patch.priority, 'high');
  out = JSON.parse(await planning.exec_edit_bucket_item(mkCtx([]), { title: 'nowhere' }));
  assert.ok(out.error);
  out = JSON.parse(await planning.exec_edit_bucket_item(
    mkCtx([{ id: 'b1', data: { title: 'Siargao surfing' } }]),
    { title: 'Siargao', priority: 'extreme' },
  ));
  assert.ok(/Invalid priority/.test(out.error));
  out = JSON.parse(await planning.exec_edit_bucket_item(
    mkCtx([{ id: 'b1', data: { title: 'Siargao surfing' } }]),
    { title: 'Siargao' },
  ));
  assert.ok(/Nothing to update/.test(out.error));
  // Habit: ambiguity asks for confirmation.
  out = JSON.parse(await planning.exec_edit_habit(
    mkCtx([{ id: 'h1', data: { title: 'morning run' } }, { id: 'h2', data: { title: 'morning pages' } }]),
    { title: 'morning', frequency: 'weekly' },
  ));
  assert.equal(out.needs_confirmation, true);
  assert.equal(out.candidates.length, 2);
  // Reminder: rescheduling parses PHT time and re-arms.
  updates.length = 0;
  out = JSON.parse(await planning.exec_edit_reminder(
    mkCtx([{ id: 'r1', data: { title: 'water plants' } }]),
    { title: 'plants', remind_at: 'tomorrow at 3pm' },
  ));
  assert.equal(out.success, true);
  assert.equal(updates[0].patch.fired, false);
  assert.ok(updates[0].patch.remindAtTs);
  out = JSON.parse(await planning.exec_edit_reminder(
    mkCtx([{ id: 'r1', data: { title: 'water plants' } }]),
    { title: 'plants', remind_at: 'someday maybe' },
  ));
  assert.ok(/Could not understand/.test(out.error));
  // Trip: dates + searchKey refresh on rename.
  updates.length = 0;
  out = JSON.parse(await planning.exec_edit_trip(
    mkCtx([{ id: 't1', data: { title: 'Cebu trip', description: 'beaches' } }]),
    { title: 'Cebu', new_title: 'Bohol trip', start_date: '2026-03-01', end_date: '2026-03-05' },
  ));
  assert.equal(out.success, true);
  assert.equal(updates[0].patch.title, 'Bohol trip');
  assert.ok(updates[0].patch.startDate);
  assert.ok(updates[0].patch.searchKey.includes('bohol trip'));
});

test('deletes return restorable data for undo', async () => {
  const planning = require('../motchi_exec_planning.js');
  const memory = require('../motchi_exec_memory.js');
  const mkCtx = (data) => {
    const ref = {
      id: 'd1',
      get: async () => ({ exists: true, data: () => data }),
      delete: async () => {},
    };
    return {
      admin: { firestore: {} },
      db: { collection: () => ({ doc: () => ref }) },
      callerUid: 'khentsgdz',
    };
  };
  const ts = (iso) => ({ toDate: () => new Date(iso) });
  let out = JSON.parse(await planning.exec_delete_calendar_event(
    mkCtx({ title: 'Anniversary dinner', description: 'fancy', date: ts('2026-02-14T19:00:00.000Z'), type: 'dateNight', location: 'Cabadbaran', isAllDay: false }),
    { id: 'd1', confirm: true },
  ));
  assert.equal(out.success, true);
  assert.equal(out.deleted.title, 'Anniversary dinner');
  assert.equal(out.deleted.date, '2026-02-14T19:00:00.000Z');
  assert.equal(out.deleted.type, 'dateNight');
  out = JSON.parse(await memory.exec_delete_journal_entry(
    mkCtx({ title: 'Beach day', content: 'Sunset was perfect.', category: 'memory', mood: 'happy', tags: ['beach'] }),
    { id: 'd1', confirm: true },
  ));
  assert.equal(out.success, true);
  assert.equal(out.deleted.content, 'Sunset was perfect.');
  assert.deepEqual(out.deleted.tags, ['beach']);
  out = JSON.parse(await planning.exec_delete_bucket_item(
    mkCtx({ title: 'Siargao surfing', category: 'adventure', priority: 'high', status: 'planned' }),
    { id: 'd1', confirm: true },
  ));
  assert.equal(out.success, true);
  assert.equal(out.deleted.priority, 'high');
  assert.equal(out.deleted.status, 'planned');
});
