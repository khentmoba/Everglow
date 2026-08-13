'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  STALE_PRESENCE_MS,
  timestampToMillis,
  isStalePresence,
} = require('../system_core.js');

test('timestampToMillis accepts Firestore-like timestamps and Dates', () => {
  const millis = Date.parse('2026-08-14T00:00:00.000Z');
  assert.equal(timestampToMillis({ toMillis: () => millis }), millis);
  assert.equal(timestampToMillis(new Date(millis)), millis);
  assert.equal(timestampToMillis('2026-08-14T00:00:00.000Z'), millis);
  assert.equal(timestampToMillis(null), null);
  assert.equal(timestampToMillis('not-a-date'), null);
});

test('isStalePresence treats old lastSeen as stale', () => {
  const now = Date.parse('2026-08-14T12:00:00.000Z');
  const staleAt = new Date(now - STALE_PRESENCE_MS - 1);
  const freshAt = new Date(now - STALE_PRESENCE_MS + 1);

  assert.equal(
    isStalePresence({ isOnline: true, lastSeen: staleAt }, now),
    true,
  );
  assert.equal(
    isStalePresence({ isOnline: true, lastSeen: freshAt }, now),
    false,
  );
});

test('isStalePresence ignores offline docs and missing timestamps', () => {
  const now = Date.now();
  assert.equal(isStalePresence({ isOnline: false, lastSeen: new Date(0) }, now), false);
  assert.equal(isStalePresence({ isOnline: true }, now), true);
  assert.equal(isStalePresence(null, now), false);
});
