'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { getVerifiedUsername, isCoupleIdentity } = require('./common.js');

test('identity helpers accept only server-issued known role claims', () => {
  assert.equal(
    getVerifiedUsername({ role: 'couple', username: 'khentsgdz' }),
    'khentsgdz',
  );
  assert.equal(
    getVerifiedUsername({ role: 'cinema', username: 'breyan' }),
    'breyan',
  );
  assert.equal(
    getVerifiedUsername({ role: 'cinema', username: 'khentsgdz' }),
    null,
  );
  assert.equal(
    getVerifiedUsername({ username: 'khentsgdz' }),
    null,
  );
  assert.equal(isCoupleIdentity({ role: 'couple', username: 'clairjassen' }), true);
  assert.equal(isCoupleIdentity({ role: 'cinema', username: 'breyan' }), false);
});
