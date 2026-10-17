'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { _pcLockoutAttempt } = require('./passcode.js');

function makeDb(initial = null, fail = false) {
  let data = initial;
  let tail = Promise.resolve();
  return {
    ref: {},
    get data() { return data; },
    runTransaction(callback) {
      const run = tail.then(async () => {
        if (fail) throw new Error('Firestore unavailable');
        return callback({
          get: async () => ({ exists: data !== null, data: () => data }),
          set: (_ref, value) => { data = { ...data, ...value }; },
          delete: () => { data = null; },
        });
      });
      tail = run.catch(() => {});
      return run;
    },
  };
}

test('concurrent invalid passcodes atomically reach the durable lockout threshold', async () => {
  const db = makeDb();
  const attempts = await Promise.all(
    Array.from({ length: 25 }, () => _pcLockoutAttempt(db, db.ref, false)),
  );

  assert.equal(db.data.fails, 20);
  assert.equal(attempts.filter((result) => result.locked).length, 5);
  assert.ok(db.data.lockedUntil > Date.now());
});

test('a valid passcode clears failures and remains usable if lockout storage is down', async () => {
  const db = makeDb({ fails: 19, firstFailAt: Date.now(), lockedUntil: 0 });
  assert.deepEqual(await _pcLockoutAttempt(db, db.ref, true), { locked: false });
  assert.equal(db.data, null);

  const unavailable = makeDb(null, true);
  assert.equal((await _pcLockoutAttempt(unavailable, unavailable.ref, true)).locked, false);
  await assert.rejects(_pcLockoutAttempt(unavailable, unavailable.ref, false), /Firestore unavailable/);
});
