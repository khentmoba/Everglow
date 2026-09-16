'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const schedules = require('./motchi_schedules');
const indexExports = require('./index');

const NAMES = [
  'motchiDailyDigest',
  'motchiNightRecap',
  'motchiMoodCheckIn',
  'motchiSmartNudge',
  'motchiWeeklyRecap',
  'motchiSpecialDayNudge',
  'motchiReminderChecker',
  'motchiMemorySweep',
];

test('motchi schedules group exposes eight timers', () => {
  for (const name of NAMES) {
    assert.equal(typeof schedules[name], 'function', `missing: ${name}`);
  }
});

test('index re-exports the schedules group without renaming', () => {
  for (const name of NAMES) {
    assert.equal(indexExports[name], schedules[name], `mismatch: ${name}`);
  }
});

// Minimal Firestore fake: collections answer with canned docs, and every
// query combinator returns the query itself for chaining.
function fakeDb(canned) {
  const makeQuery = (docs) => {
    const q = {
      docs: docs.map((data) => ({ data: () => data })),
      get empty() { return this.docs.length === 0; },
    };
    q.where = () => q;
    q.orderBy = () => q;
    q.limit = () => q;
    q.get = async () => ({ docs: q.docs, empty: q.docs.length === 0 });
    return q;
  };
  return {
    collection: (name) => makeQuery(canned[name] || []),
  };
}

test('collectRecapData maps snapshots with generous fallbacks', async () => {
  const db = fakeDb({
    moods: [{ uid: 'khentsgdz', mood: 'happy' }, { username: 'clairjassen', moodLabel: 'calm' }, { username: 'khentsgdz', moodScore: 4, moodEmoji: '😊' }, {}],
    recent_activity: [{ activity: 'Movie night' }, { description: 'Cooked dinner' }, {}],
    starlight_jar: [{ content: 'I love our mornings' }, {}],
    our_cinema: [{ title: 'Interstellar' }, {}],
    ai_memories: [], // nested facts path is stubbed below
  });
  // facts live at ai_memories/shared/facts — point doc() back at canned docs
  const factsQuery = (() => {
    const docs = [{ fact: 'Khent prefers black coffee' }, {}].map((data) => ({ data: () => data }));
    return { orderBy: () => ({ limit: () => ({ get: async () => ({ docs, empty: false }) }) }) };
  })();
  const origCollection = db.collection;
  db.collection = (name) => (name === 'ai_memories'
    ? { doc: () => ({ collection: () => factsQuery }) }
    : origCollection(name));

  const { recapData, snaps } = await schedules.collectRecapData(db, {
    dateLabel: '2026-09-16',
    moodsQuery: db.collection('moods').where('date', '==', '2026-09-16'),
  });
  assert.equal(recapData.dateLabel, '2026-09-16');
  assert.deepEqual(recapData.moods[0], { uid: 'khentsgdz', mood: 'happy' });
  assert.deepEqual(recapData.moods[1], { uid: 'clairjassen', mood: 'calm' });
  assert.deepEqual(recapData.moods[2], { uid: 'khentsgdz', mood: '😊' });
  assert.deepEqual(recapData.moods[3], { uid: 'someone', mood: 'okay' });
  assert.deepEqual(recapData.activities, ['Movie night', 'Cooked dinner']);
  assert.deepEqual(recapData.starlight, ['I love our mornings']);
  assert.deepEqual(recapData.watchlist, ['Interstellar']);
  assert.equal(recapData.memories[0].fact, 'Khent prefers black coffee');
  assert.ok(snaps.moodsSnap && snaps.activitySnap && snaps.starSnap);
});

test('collectRecapData skips the watchlist when asked', async () => {
  const db = fakeDb({});
  db.collection = (name) => {
    if (name === 'ai_memories') {
      return { doc: () => ({ collection: () => ({ orderBy: () => ({ limit: () => ({ get: async () => ({ docs: [], empty: true }) }) }) }) }) };
    }
    const q = { docs: [], empty: true };
    q.where = () => q;
    q.orderBy = () => q;
    q.limit = () => q;
    q.get = async () => ({ docs: [], empty: true });
    return q;
  };
  const { recapData, snaps } = await schedules.collectRecapData(db, {
    dateLabel: 'tonight',
    moodsQuery: db.collection('moods'),
    includeWatchlist: false,
  });
  assert.deepEqual(recapData.watchlist, []);
  assert.equal(snaps.watchSnap, null);
  assert.deepEqual(recapData.moods, []);
});
