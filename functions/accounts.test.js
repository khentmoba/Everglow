'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  hashPassword,
  verifyPassword,
  serializeAccount,
  registerAccount,
  loginAccount,
  manageAccounts,
} = require('./accounts.js');

function makeRes() {
  return {
    code: 200,
    headers: {},
    body: null,
    set(k, v) {
      this.headers[k] = v;
      return this;
    },
    status(c) {
      this.code = c;
      return this;
    },
    json(b) {
      this.body = b;
      return this;
    },
    send(b) {
      this.body = b;
      return this;
    },
  };
}

function makeFakeFirestore(initial = {}) {
  const store = new Map(Object.entries(initial));
  const docRef = (col, id) => {
    const key = `${col}/${id}`;
    return {
      id,
      _key: key,
      async get() {
        return {
          id,
          exists: store.has(key),
          data: () => store.get(key),
        };
      },
      async set(val, opts) {
        if (opts && opts.merge && store.has(key)) {
          store.set(key, { ...store.get(key), ...val });
        } else {
          store.set(key, { ...val });
        }
      },
      async update(val) {
        if (!store.has(key)) throw new Error('not-found');
        store.set(key, { ...store.get(key), ...val });
      },
      async delete() {
        store.delete(key);
      },
    };
  };

  return {
    store,
    collection(col) {
      return {
        doc: (id) => docRef(col, id),
        orderBy() {
          return {
            limit() {
              return {
                async get() {
                  const docs = [];
                  for (const [k, v] of store.entries()) {
                    if (k.startsWith(`${col}/`)) {
                      const id = k.slice(col.length + 1);
                      docs.push({ id, data: () => v });
                    }
                  }
                  return { docs };
                },
              };
            },
          };
        },
      };
    },
    async runTransaction(fn) {
      const tx = {
        get: (ref) => ref.get(),
        set: (ref, val, opts) => {
          if (opts && opts.merge && store.has(ref._key)) {
            store.set(ref._key, { ...store.get(ref._key), ...val });
          } else {
            store.set(ref._key, { ...val });
          }
        },
        delete: (ref) => {
          store.delete(ref._key);
        },
      };
      return await fn(tx);
    },
  };
}

test('hashPassword and verifyPassword round-trip securely', () => {
  const { salt, hash } = hashPassword('my-secret-pass');
  assert.equal(verifyPassword('my-secret-pass', salt, hash), true);
  assert.equal(verifyPassword('wrong-pass', salt, hash), false);
  assert.equal(verifyPassword('my-secret-pass', 'other-salt', hash), false);
});

test('serializeAccount never leaks passwordHash or passwordSalt', () => {
  const serialized = serializeAccount('sora', {
    username: 'Sora',
    status: 'pending',
    passwordHash: 'secret-hash',
    passwordSalt: 'secret-salt',
  });
  assert.equal(serialized.username, 'Sora');
  assert.equal(serialized.status, 'pending');
  assert.equal('passwordHash' in serialized, false);
  assert.equal('passwordSalt' in serialized, false);
});

test('registerAccount validates confirm password, reserved names, and creates pending account', async (t) => {
  const admin = require('./common').getAdmin();
  const db = makeFakeFirestore();
  t.mock.method(admin, 'firestore', () => db);

  // Mismatched confirm password -> 400
  const resMismatch = makeRes();
  await registerAccount(
    {
      method: 'POST',
      ip: '10.0.0.1',
      headers: {},
      get: () => '',
      body: { username: 'mika_chan', password: 'password123', confirmPassword: 'password999' },
    },
    resMismatch,
  );
  assert.equal(resMismatch.code, 400);
  assert.match(resMismatch.body.error, /do not match/i);

  // Reserved username -> 400
  const resReserved = makeRes();
  await registerAccount(
    {
      method: 'POST',
      ip: '10.0.0.2',
      headers: {},
      get: () => '',
      body: { username: 'khentsgdz', password: 'password123', confirmPassword: 'password123' },
    },
    resReserved,
  );
  assert.equal(resReserved.code, 400);

  // Valid creation -> 201 pending
  const resOk = makeRes();
  await registerAccount(
    {
      method: 'POST',
      ip: '10.0.0.3',
      headers: {},
      get: () => '',
      body: { username: 'mika_chan', password: 'password123', confirmPassword: 'password123' },
    },
    resOk,
  );
  assert.equal(resOk.code, 201);
  assert.deepEqual(resOk.body, { status: 'pending', username: 'mika_chan' });
  assert.equal(db.store.get('member_accounts/mika_chan').status, 'pending');

  // Duplicate username -> 409
  const resDup = makeRes();
  await registerAccount(
    {
      method: 'POST',
      ip: '10.0.0.4',
      headers: {},
      get: () => '',
      body: { username: 'Mika_Chan', password: 'password123', confirmPassword: 'password123' },
    },
    resDup,
  );
  assert.equal(resDup.code, 409);
});

test('loginAccount blocks pending accounts and issues custom token after approval', async (t) => {
  const admin = require('./common').getAdmin();
  const { salt, hash } = hashPassword('secret123');
  const db = makeFakeFirestore({
    'member_accounts/sora99': {
      username: 'sora99',
      usernameLower: 'sora99',
      passwordSalt: salt,
      passwordHash: hash,
      status: 'pending',
    },
  });
  t.mock.method(admin, 'firestore', () => db);
  const issued = [];
  t.mock.method(admin.auth(), 'getUserByEmail', async (email) => ({ uid: `uid_${email}` }));
  t.mock.method(admin.auth(), 'createCustomToken', async (uid, claims) => {
    issued.push({ uid, claims });
    return 'member-token';
  });

  // Pending -> 403
  const resPending = makeRes();
  await loginAccount(
    {
      method: 'POST',
      ip: '10.0.1.1',
      headers: {},
      get: () => '',
      body: { username: 'sora99', password: 'secret123' },
    },
    resPending,
  );
  assert.equal(resPending.code, 403);
  assert.equal(resPending.body.status, 'pending');

  // Wrong password -> 401
  const resWrong = makeRes();
  await loginAccount(
    {
      method: 'POST',
      ip: '10.0.1.2',
      headers: {},
      get: () => '',
      body: { username: 'sora99', password: 'wrongpassword' },
    },
    resWrong,
  );
  assert.equal(resWrong.code, 401);

  // Approve and sign in -> 200
  db.store.get('member_accounts/sora99').status = 'approved';
  const resApproved = makeRes();
  await loginAccount(
    {
      method: 'POST',
      ip: '10.0.1.3',
      headers: {},
      get: () => '',
      body: { username: 'sora99', password: 'secret123' },
    },
    resApproved,
  );
  assert.equal(resApproved.code, 200);
  assert.equal(resApproved.body.token, 'member-token');
  assert.equal(resApproved.body.username, 'sora99');
  assert.deepEqual(issued.at(-1).claims, { username: 'sora99', accountType: 'member' });
  const userDoc = db.store.get(`users/${issued.at(-1).uid}`);
  assert.equal(userDoc.username, 'sora99');
  assert.equal(userDoc.partnerUsername, null);
  assert.deepEqual(Object.keys(userDoc).sort(), ['partnerUsername', 'updatedAt', 'username']);
});

test('registerAccount rejects dots in usernames and blocks takeover of rejected activated accounts', async (t) => {
  const admin = require('./common').getAdmin();
  const db = makeFakeFirestore({
    'member_accounts/olduser': {
      username: 'olduser',
      status: 'rejected',
      uid: 'uid_previous_owner',
    },
  });
  t.mock.method(admin, 'firestore', () => db);

  const resDot = makeRes();
  await registerAccount(
    {
      method: 'POST',
      ip: '10.0.2.1',
      headers: {},
      get: () => '',
      body: { username: 'khentsg.z', password: 'password123', confirmPassword: 'password123' },
    },
    resDot,
  );
  assert.equal(resDot.code, 400);

  const resTakeover = makeRes();
  await registerAccount(
    {
      method: 'POST',
      ip: '10.0.2.2',
      headers: {},
      get: () => '',
      body: { username: 'olduser', password: 'password123', confirmPassword: 'password123' },
    },
    resTakeover,
  );
  assert.equal(resTakeover.code, 409);
});

test('manageAccounts restricts access to khentsgdz and supports list/approve/reject', async (t) => {
  const admin = require('./common').getAdmin();
  const { salt, hash } = hashPassword('secret123');
  const db = makeFakeFirestore({
    'member_accounts/kenji': {
      username: 'kenji',
      passwordSalt: salt,
      passwordHash: hash,
      status: 'pending',
    },
  });
  t.mock.method(admin, 'firestore', () => db);

  // Non-creator caller -> 403
  t.mock.method(admin.auth(), 'verifyIdToken', async () => ({
    uid: 'uid_breyan',
    username: 'breyan',
    firebase: { sign_in_provider: 'custom' },
  }));
  const resForbidden = makeRes();
  await manageAccounts(
    { method: 'GET', headers: { authorization: 'Bearer tok' }, get: (h) => (h === 'Authorization' ? 'Bearer tok' : '') },
    resForbidden,
  );
  assert.equal(resForbidden.code, 403);

  // Khent lists and approves
  t.mock.method(admin.auth(), 'verifyIdToken', async () => ({
    uid: 'uid_khent',
    username: 'khentsgdz',
    firebase: { sign_in_provider: 'custom' },
  }));
  const resList = makeRes();
  await manageAccounts(
    { method: 'GET', headers: { authorization: 'Bearer tok' }, get: (h) => (h === 'Authorization' ? 'Bearer tok' : '') },
    resList,
  );
  assert.equal(resList.code, 200);
  assert.equal(resList.body.accounts.length, 1);
  assert.equal(resList.body.accounts[0].username, 'kenji');
  assert.equal('passwordHash' in resList.body.accounts[0], false);

  const resApprove = makeRes();
  await manageAccounts(
    {
      method: 'POST',
      headers: { authorization: 'Bearer tok' },
      get: (h) => (h === 'Authorization' ? 'Bearer tok' : ''),
      body: { action: 'approve', username: 'kenji' },
    },
    resApprove,
  );
  assert.equal(resApprove.code, 200);
  assert.equal(db.store.get('member_accounts/kenji').status, 'approved');
});

test('manageAccounts deletes users/{uid} on revoke and delete to cut off Firestore access immediately', async (t) => {
  const admin = require('./common').getAdmin();
  const db = makeFakeFirestore({
    'member_accounts/ren': { username: 'ren', status: 'approved', uid: 'uid_ren' },
    'users/uid_ren': { username: 'ren', partnerUsername: null },
    'member_accounts/kai': { username: 'kai', status: 'approved', uid: 'uid_kai' },
    'users/uid_kai': { username: 'kai', partnerUsername: null },
  });
  t.mock.method(admin, 'firestore', () => db);
  t.mock.method(admin.auth(), 'verifyIdToken', async () => ({
    uid: 'uid_khent',
    username: 'khentsgdz',
    firebase: { sign_in_provider: 'custom' },
  }));
  let revokedUid = null;
  let deletedUid = null;
  t.mock.method(admin.auth(), 'revokeRefreshTokens', async (uid) => { revokedUid = uid; });
  t.mock.method(admin.auth(), 'deleteUser', async (uid) => { deletedUid = uid; });

  const resRevoke = makeRes();
  await manageAccounts(
    {
      method: 'POST',
      headers: { authorization: 'Bearer tok' },
      get: (h) => (h === 'Authorization' ? 'Bearer tok' : ''),
      body: { action: 'revoke', username: 'ren' },
    },
    resRevoke,
  );
  assert.equal(resRevoke.code, 200);
  assert.equal(revokedUid, 'uid_ren');
  assert.equal(db.store.has('users/uid_ren'), false);

  const resDelete = makeRes();
  await manageAccounts(
    {
      method: 'POST',
      headers: { authorization: 'Bearer tok' },
      get: (h) => (h === 'Authorization' ? 'Bearer tok' : ''),
      body: { action: 'delete', username: 'kai' },
    },
    resDelete,
  );
  assert.equal(resDelete.code, 200);
  assert.equal(deletedUid, 'uid_kai');
  assert.equal(db.store.has('users/uid_kai'), false);
  assert.equal(db.store.has('member_accounts/kai'), false);
});

test('account and watch-party endpoints set Cache-Control: private, no-store', async () => {
  const { communityWatchPartyAccess } = require('./accounts');
  for (const endpoint of [registerAccount, loginAccount, manageAccounts, communityWatchPartyAccess]) {
    const res = makeRes();
    await endpoint({ method: 'OPTIONS', headers: {}, get: () => '' }, res);
    assert.equal(res.code, 204);
    assert.equal(res.headers['Cache-Control'], 'private, no-store');
  }
});

test('verifyPassword and verifyPasswordAsync reject passwords over 128 chars before invoking scrypt', async (t) => {
  const crypto = require('node:crypto');
  const { hashPassword, verifyPassword, verifyPasswordAsync } = require('./accounts');
  const { salt, hash } = hashPassword('valid-pass');
  const scryptSyncSpy = t.mock.method(crypto, 'scryptSync');
  const scryptSpy = t.mock.method(crypto, 'scrypt');
  const huge = 'a'.repeat(129);
  assert.equal(verifyPassword(huge, salt, hash), false);
  assert.equal(await verifyPasswordAsync(huge, salt, hash), false);
  assert.equal(scryptSyncSpy.mock.callCount(), 0);
  assert.equal(scryptSpy.mock.callCount(), 0);
  assert.throws(() => hashPassword(huge), /maximum length/);
});
