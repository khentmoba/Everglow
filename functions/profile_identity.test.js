'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const adminCompat = require('./admin_compat');
const { getVerifiedUsername } = require('./common');

test('a self-created cinema profile cannot unlock paid helpers for an unrelated account', async (t) => {
  const previous = process.env.BREYAN_EMAIL;
  process.env.BREYAN_EMAIL = 'approved@example.test';
  t.after(() => {
    if (previous === undefined) delete process.env.BREYAN_EMAIL;
    else process.env.BREYAN_EMAIL = previous;
  });
  t.mock.method(adminCompat, 'getAdminCompat', () => ({
    firestore: () => ({ collection: () => ({ doc: () => ({
      get: async () => ({ exists: true, data: () => ({ username: 'breyan' }) }),
    }) }) }),
  }));
  const login = (email) => ({ uid: 'synthetic-user', email,
    firebase: { sign_in_provider: 'password' } });
  assert.equal(await getVerifiedUsername(login('stranger@example.test')), null);
  assert.equal(await getVerifiedUsername(login('approved@example.test')), 'breyan');
  delete process.env.BREYAN_EMAIL;
  assert.equal(await getVerifiedUsername(login('approved@example.test')), null);
  assert.equal(await getVerifiedUsername(login('breyan@scrapbook.local')), null);
  assert.equal(await getVerifiedUsername({ uid: 'couple', username: 'clairjassen',
    firebase: { sign_in_provider: 'custom' } }), 'clairjassen');
});
