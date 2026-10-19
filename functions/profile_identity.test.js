'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { getVerifiedUsername } = require('./common');

test('client names and old password accounts never grant a verified profile', async () => {
  for (const username of ['khentsgdz', 'clairjassen', 'breyan', 'octagram']) {
    const token = { uid: 'synthetic-user', username, email: 'approved@example.test',
      firebase: { sign_in_provider: 'password' } };
    assert.equal(await getVerifiedUsername(token), null);
    assert.equal(await getVerifiedUsername({ ...token,
      firebase: { sign_in_provider: 'custom' } }), username);
  }
});
