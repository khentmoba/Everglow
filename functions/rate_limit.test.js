'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  rateLimitHit,
  enforceRateLimit,
  clientIp,
  _todayDayKey,
} = require('./common');

function fakeRes() {
  return {
    statusCode: 0,
    body: null,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
}

function fakeReq({ ip = '9.9.9.9', fwd = '' } = {}) {
  return {
    ip,
    headers: { 'x-forwarded-for': fwd },
    get(name) {
      if (name === 'X-Forwarded-For') return fwd;
      return '';
    },
  };
}

test('rateLimitHit allows up to the limit, then trips', () => {
  const key = `test:trip:${Date.now()}`;
  assert.equal(rateLimitHit(key, 3, 60000), false);
  assert.equal(rateLimitHit(key, 3, 60000), false);
  assert.equal(rateLimitHit(key, 3, 60000), false);
  assert.equal(rateLimitHit(key, 3, 60000), true);
});

test('rateLimitHit resets after the window slides past', () => {
  const key = `test:window:${Date.now()}`;
  const now = Date.now();
  assert.equal(rateLimitHit(key, 1, 1000, now), false);
  assert.equal(rateLimitHit(key, 1, 1000, now + 500), true);
  assert.equal(rateLimitHit(key, 1, 1000, now + 1001), false);
});

test('rateLimitHit isolates keys from each other', () => {
  const stamp = Date.now();
  assert.equal(rateLimitHit(`test:iso-a:${stamp}`, 1, 60000), false);
  assert.equal(rateLimitHit(`test:iso-a:${stamp}`, 1, 60000), true);
  assert.equal(rateLimitHit(`test:iso-b:${stamp}`, 1, 60000), false);
});

test('enforceRateLimit 429s with Retry-After when over the limit', () => {
  const req = fakeReq({ ip: `10.7.0.${Date.now() % 250 + 1}` });
  const endpoint = `testEnforce${Date.now()}`;
  const opts = { endpoint, limit: 2, windowMs: 60000 };
  assert.equal(enforceRateLimit(req, fakeRes(), opts), false);
  assert.equal(enforceRateLimit(req, fakeRes(), opts), false);
  const res = fakeRes();
  assert.equal(enforceRateLimit(req, res, opts), true);
  assert.equal(res.statusCode, 429);
  assert.ok(res.headers['Retry-After']);
});

test('enforceRateLimit keys authed callers by uid, not IP', () => {
  const endpoint = `testUid${Date.now()}`;
  const mkRes = () => fakeRes();
  const a = { endpoint, limit: 1, windowMs: 60000, uid: `u-a-${Date.now()}` };
  const b = { endpoint, limit: 1, windowMs: 60000, uid: `u-b-${Date.now()}` };
  assert.equal(enforceRateLimit(fakeReq(), mkRes(), a), false);
  assert.equal(enforceRateLimit(fakeReq(), mkRes(), a), true);
  // A different user on the same IP still gets their own budget.
  assert.equal(enforceRateLimit(fakeReq(), mkRes(), b), false);
});

test('clientIp prefers X-Forwarded-For first hop, falls back safely', () => {
  assert.equal(
    clientIp(fakeReq({ ip: '1.2.3.4', fwd: '5.6.7.8, 9.9.9.9' })),
    '5.6.7.8',
  );
  assert.equal(clientIp(fakeReq({ ip: '1.2.3.4', fwd: '' })), '1.2.3.4');
  assert.equal(clientIp(fakeReq({ ip: '', fwd: '' })), 'unknown');
});

test('_todayDayKey returns a YYYY-MM-DD day bucket', () => {
  assert.match(_todayDayKey(new Date('2026-09-14T10:00:00.000Z')), /^\d{4}-\d{2}-\d{2}$/);
  assert.equal(_todayDayKey(new Date('2026-09-14T10:00:00.000Z')), '2026-09-14');
});
