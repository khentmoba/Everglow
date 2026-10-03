'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const common = require('./common');
let verifiedUsername = null;
common.requireAuth = async () => ({ uid: 'demo-cinema' });
common.getVerifiedUsername = async () => verifiedUsername;
common.enforceRateLimit = () => false;
const { handleProxyAI } = require('./motchi_chat');

test('Motchi never falls back to a caller-supplied couple name', async () => {
  for (const identity of [null, 'breyan', 'octagram']) {
    verifiedUsername = identity;
    const res = { code: 0, set() { return this; }, status(code) { this.code = code; return this; },
      json(value) { this.body = value; } };
    await handleProxyAI({ method: 'POST', query: {},
      body: { caller: 'khentsgdz', messages: [{ role: 'user', content: 'demo' }] } }, res);
    assert.equal(res.code, 403);
    assert.equal(res.body.error, 'Couple only');
  }
});
