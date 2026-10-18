'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { _pcLockoutAttempt } = require('./passcode.js');

function makeDb(initial = {}) {
  const data = new Map(Object.entries(initial));
  let tail = Promise.resolve();
  return {
    ref: (id) => id,
    get data() { return data; },
    runTransaction(callback) {
      const run = tail.then(async () => callback({
        get: async (ref) => ({ exists: data.has(ref), data: () => data.get(ref) }),
        set: (ref, value) => { data.set(ref, { ...data.get(ref), ...value }); },
        delete: (ref) => { data.delete(ref); },
      }));
      tail = run.catch(() => {});
      return run;
    },
  };
}

const attempt = (db, ip, accepted = false) =>
  _pcLockoutAttempt(db, db.ref(ip), db.ref('global'), accepted);

test('concurrent invalid passcodes atomically exhaust the shared global budget across IPs', async () => {
  const db = makeDb();
  const attempts = await Promise.all(
    Array.from({ length: 100 }, (_, i) => attempt(db, `ip-${i}`, false)),
  );

  assert.equal(attempts.filter((result) => result.locked).length, 0);
  assert.equal(db.data.get('global').fails, 100);
  assert.ok(db.data.get('global').lockedUntil > Date.now());
  assert.deepEqual(await attempt(db, 'new-rotated-ip', true), { locked: true });
});

test('valid passcode still works and clears IP failures when no lockout is active', async () => {
  const db = makeDb({ ip: { fails: 3, firstFailAt: Date.now(), lockedUntil: 0 } });
  assert.deepEqual(await attempt(db, 'ip', true), { locked: false });
  assert.equal(db.data.has('ip'), false);
});

test('correct passcode is rejected during an IP lockout', async () => {
  const db = makeDb({
    ip: { fails: 20, firstFailAt: Date.now(), lockedUntil: Date.now() + 60_000 },
  });
  assert.deepEqual(await attempt(db, 'ip', true), { locked: true });
});

test('correct passcode is rejected during global lockout regardless of IP', async () => {
  const db = makeDb({
    global: { fails: 100, firstFailAt: Date.now() - 1_000, lockedUntil: Date.now() + 60_000 },
  });
  assert.deepEqual(await attempt(db, 'different-ip', true), { locked: true });
});

test('invalid passcode attempts fail closed if durable lockout storage is down', async () => {
  const db = makeDb();
  db.runTransaction = async () => { throw new Error('Firestore unavailable'); };
  await assert.rejects(attempt(db, 'ip', true), /Firestore unavailable/);
  await assert.rejects(attempt(db, 'ip', false), /Firestore unavailable/);
});
