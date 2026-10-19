'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const common = require('./common');

function fakeDb(seed = {}) {
  const records = new Map(Object.entries(seed));
  let next = 0;
  let tail = Promise.resolve();
  function ref(path) {
    return { id: path.split('/').at(-1), path,
      async get() { return { id: this.id, exists: records.has(path), data: () => records.get(path), ref: this }; },
      async set(data) { records.set(path, data); },
      async update(data) { records.set(path, { ...records.get(path), ...data }); },
    };
  }
  function query(name, filters = [], ordered) {
    return {
      doc: (id) => ref(`${name}/${id}`),
      async add(data) { const r = ref(`${name}/new${++next}`); await r.set(data); return r; },
      where: (field, op, value) => query(name, [...filters, [field, op, value]], ordered),
      orderBy: (field) => query(name, filters, field),
      limit() { return this; },
      async get() {
        const paths = [...records.keys()].filter((p) => p.startsWith(name + '/') && p.split('/').length === 2);
        const docs = [];
        for (const p of paths) {
          const data = records.get(p);
          if (ordered && !(ordered in data)) continue;
          if (!filters.every(([f, op, v]) => data[f] != null &&
              (op === '==' ? data[f] === v : op === '>=' ? data[f] >= v : data[f] < v))) continue;
          docs.push(await ref(p).get());
        }
        return { docs, empty: !docs.length, size: docs.length };
      },
    };
  }
  return { records, collection: (name) => query(name),
    runTransaction(fn) {
      const result = tail.then(() => fn({ get: (r) => r.get(), set: (r, d) => r.set(d), update: (r, d) => r.update(d) }));
      tail = result.catch(() => {});
      return result;
    },
  };
}
const admin = { firestore: { Timestamp: { fromDate: (date) => date, now: () => new Date() } } };
let db;
common.getDb = () => db;
common.getAdmin = () => admin;
const { buildContextForFeature, invalidateContextBlock } = require('./motchi_context');
const planning = require('./motchi_exec_planning');
const memory = require('./motchi_exec_memory');
const { exec_add_book_to_our_books } = require('./motchi_exec_media');

function ctx() {
  return { db, admin, callerUid: 'khentsgdz', cacheGet: () => ({ docs: [
    { key: '/works/OL123W', title: 'Demo book', author_name: ['Demo author'] },
  ] }), cacheTTLs: { books: 1 } };
}

test('Motchi trip writes use the same fields as Trip Kit and preserve concurrent places', async () => {
  db = fakeDb();
  const trip = JSON.parse(await planning.exec_add_trip(ctx(), { title: 'Demo trip', description: 'Demo notes',
    budget: 5000, start_date: '2026-11-01', end_date: '2026-11-02' }));
  const saved = db.records.get(`travel_trips/${trip.id}`);
  assert.equal(saved.notes, 'Demo notes');
  assert.equal(saved.budgetTotal, 5000);
  await planning.exec_edit_trip(ctx(), { id: trip.id, description: 'Updated notes', budget: 6000 });
  assert.equal(db.records.get(`travel_trips/${trip.id}`).notes, 'Updated notes');
  assert.equal(db.records.get(`travel_trips/${trip.id}`).budgetTotal, 6000);
  await Promise.all(['Demo cafe', 'Demo park'].map((title) =>
    planning.exec_add_trip_pin(ctx(), { trip_id: trip.id, title, lat: 10, lng: 12 })));
  const places = db.records.get(`travel_trips/${trip.id}`).places;
  assert.deepEqual(places.map((p) => p.name), ['Demo cafe', 'Demo park']);
  assert.equal(new Set(places.map((p) => p.id)).size, 2);
  assert.equal(places[0].lat, 10);
  assert.equal([...db.records.keys()].some((key) => key.startsWith('travel_pins/')), false);
});

test('Money context reads normal MoneyEntry fields at Philippine month boundaries', async (t) => {
  t.mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-31T17:00:00Z') });
  db = fakeDb({ 'budget_transactions/demo': { createdAt: new Date('2026-10-31T16:15:00Z'),
    amount: 250, category: 'Food', type: 'expense', author: 'clairjassen', note: 'Demo meal' } });
  invalidateContextBlock();
  const result = await buildContextForFeature('assistant', 'khentsgdz', 'budget spending money');
  assert.match(result, /Food ₱250 by clairjassen — Demo meal/);
});

test('subscription context agrees with the tool after Philippine midnight', async (t) => {
  t.mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-19T17:00:00Z') });
  db = fakeDb({ 'subscriptions/demo': { createdAt: new Date(), name: 'Demo subscription', price: 100,
    renewalDate: { toDate: () => new Date('2026-10-19T16:00:00Z') }, cycle: 'monthly' } });
  invalidateContextBlock();
  const result = await buildContextForFeature('assistant', 'khentsgdz', 'subscriptions renewal');
  assert.match(result, /Demo subscription.*renews today/);
});

test('sealed journal body and tags stay out of context, lists and search until confirmed', async () => {
  db = fakeDb({ 'journal_entries/sealed': { title: 'Demo sealed title', content: 'SECRET_BODY', tags: ['SECRET_TAG'],
    isLocked: true, createdAt: new Date() } });
  invalidateContextBlock();
  const context = await buildContextForFeature('assistant', 'khentsgdz', 'journal entries');
  assert.ok(!context.includes('SECRET_BODY'));
  const listed = await memory.exec_get_journal_entries(ctx(), {});
  assert.ok(!listed.includes('SECRET_BODY'));
  const searched = await memory.exec_search_journal_entries(ctx(), { query: 'Demo' });
  assert.ok(!searched.includes('SECRET_BODY') && !searched.includes('SECRET_TAG'));
  assert.equal(JSON.parse(await memory.exec_search_journal_entries(ctx(), { query: 'SECRET_BODY' })).count, 0);
  assert.equal(JSON.parse(await memory.exec_search_journal_entries(ctx(), { tag: 'SECRET_TAG' })).count, 0);
  const first = JSON.parse(await memory.exec_read_journal_entry(ctx(), { id: 'sealed' }));
  assert.equal(first.needs_confirmation, true);
  assert.equal(first.content, undefined);
  const opened = JSON.parse(await memory.exec_read_journal_entry(ctx(), { id: 'sealed', confirm: true }));
  assert.equal(opened.content, 'SECRET_BODY');
});

test('book creation shares the client SHA-256 id and preserves reading flags', async () => {
  db = fakeDb();
  await Promise.all([exec_add_book_to_our_books(ctx(), { query: 'Demo book' }),
    exec_add_book_to_our_books(ctx(), { query: 'Demo book' })]);
  const id = createHash('sha256').update('/works/OL123W').digest('hex');
  assert.equal(id, '48da23763e038af20b0d295f141fce2b65c71e2d21180caf005f0e5c3216da72');
  assert.equal(db.records.size, 1);
  const saved = db.records.get(`our_books/${id}`);
  saved.clairReadAt = new Date('2026-10-01');
  await exec_add_book_to_our_books(ctx(), { query: 'Demo book' });
  assert.equal(db.records.size, 1);
  assert.equal(saved.clairReadAt.toISOString(), '2026-10-01T00:00:00.000Z');
});
