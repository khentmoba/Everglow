'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { _pcLockoutAttempt, profileForPasscode } = require('./passcode.js');

test('all four codes resolve server-side; missing, wrong and duplicate codes fail closed', () => {
  const env = { CLAIR_PASSCODE: '1001', KHENT_PASSCODE: '1002',
    BREYAN_PASSCODE: '1003', OCTAGRAM_PASSCODE: '1004' };
  for (const [code, username] of [['1001', 'clairjassen'], ['1002', 'khentsgdz'],
    ['1003', 'breyan'], ['1004', 'octagram']]) {
    assert.equal(profileForPasscode(code, env), username);
  }
  assert.equal(profileForPasscode('9999', env), null);
  assert.equal(profileForPasscode('1003', {}), null);
  assert.equal(profileForPasscode('1003', { ...env, CLAIR_PASSCODE: '1003' }), null);
});

test('the login handler issues signed tokens for existing guest accounts, without passwords', async (t) => {
  const env = { BREYAN_PASSCODE: '3001', OCTAGRAM_PASSCODE: '3002',
    BREYAN_EMAIL: 'breyan@example.test', OCTAGRAM_EMAIL: 'octagram@example.test' };
  const previous = Object.fromEntries(Object.keys(env).map((key) => [key, process.env[key]]));
  Object.assign(process.env, env);
  t.after(() => {
    for (const key of Object.keys(env)) {
      if (previous[key] === undefined) delete process.env[key];
      else process.env[key] = previous[key];
    }
  });
  const admin = require('./common').getAdmin();
  const db = makeDb();
  db.collection = () => ({ doc: (id) => id });
  t.mock.method(admin, 'firestore', () => db);
  const issued = [];
  t.mock.method(admin.auth(), 'getUserByEmail', async (email) => ({ uid: email }));
  t.mock.method(admin.auth(), 'createCustomToken', async (uid, claims) => {
    issued.push({ uid, claims });
    return 'fake-custom-token';
  });
  const { verifyPasscode } = require('./passcode');
  for (const [passcode, username] of [['3001', 'breyan'], ['3002', 'octagram']]) {
    const res = { code: 200, set() { return this; }, status(code) { this.code = code; return this; },
      json(body) { this.body = body; } };
    await verifyPasscode({ method: 'POST', ip: '127.0.0.1', headers: {},
      get: () => '', body: { passcode } }, res);
    assert.equal(res.code, 200);
    assert.deepEqual(res.body, { token: 'fake-custom-token', username });
    assert.deepEqual(issued.at(-1).claims, { username });
  }
});

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
