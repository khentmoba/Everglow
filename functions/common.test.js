'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { EventEmitter } = require('node:events');
const { Readable } = require('node:stream');
const dns = require('node:dns').promises;
const https = require('node:https');
const adminCompat = require('./admin_compat.js');
const { isPrivateIp, fetchPublicUrl, requireAuth, allowedCorsOrigin } = require('./common.js');

function response(statusCode, headers = {}, body = 'ok') {
  const stream = Readable.from([Buffer.from(body)]);
  stream.statusCode = statusCode;
  stream.headers = headers;
  return stream;
}

function mockGet(module, implementation) {
  return test.mock.method(module, 'get', (url, options, callback) => {
    const request = new EventEmitter();
    implementation(url, options, callback);
    return request;
  });
}

function resMock() {
  return {
    statusCode: null,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(value) { this.body = value; return this; },
  };
}

test('public URL guard rejects local, reserved, and credential-bearing destinations', async () => {
  for (const ip of ['127.0.0.1', '10.2.3.4', '169.254.169.254', '::1', 'fc00::1', '::ffff:127.0.0.1']) {
    assert.equal(isPrivateIp(ip), true, `${ip} must be blocked`);
  }
  assert.equal(isPrivateIp('8.8.8.8'), false);
  assert.equal(isPrivateIp('2606:4700:4700::1111'), false);
  await assert.rejects(fetchPublicUrl('file:///etc/passwd', {}), /credential-free http\(s\)/);
  await assert.rejects(fetchPublicUrl('http://user:pass@example.com/', {}), /credential-free http\(s\)/);
});

test('fetchPublicUrl rejects a private initial DNS target before requesting it', async (t) => {
  t.mock.method(dns, 'lookup', async () => [{ address: '127.0.0.1', family: 4 }]);
  const get = mockGet(https, () => assert.fail('must not request private address'));
  await assert.rejects(fetchPublicUrl('https://example.test/', {}), /Host not allowed/);
  assert.equal(get.mock.callCount(), 0);
});

test('fetchPublicUrl validates redirect destination before requesting it', async (t) => {
  t.mock.method(dns, 'lookup', async (host) => [{ address: host === 'public.test' ? '8.8.8.8' : '10.0.0.1', family: 4 }]);
  let requests = 0;
  mockGet(https, (_url, _options, callback) => {
    requests++;
    callback(response(302, { location: 'https://private.test/secret' }, ''));
  });
  await assert.rejects(fetchPublicUrl('https://public.test/', {}), /Host not allowed/);
  assert.equal(requests, 1);
});

test('fetchPublicUrl enforces httpsOnly and isAllowedUrl on redirect hops', async (t) => {
  t.mock.method(dns, 'lookup', async () => [{ address: '8.8.8.8', family: 4 }]);
  mockGet(https, (_url, _options, callback) => {
    callback(response(302, { location: 'http://allowed.test/downgrade' }, ''));
  });
  await assert.rejects(
    fetchPublicUrl('https://allowed.test/start', { httpsOnly: true }),
    /Only credential-free https urls/,
  );

  mockGet(https, (_url, _options, callback) => {
    callback(response(302, { location: 'https://evil.test/steal' }, ''));
  });
  await assert.rejects(
    fetchPublicUrl('https://allowed.test/start', {
      httpsOnly: true,
      isAllowedUrl: (u) => u.hostname === 'allowed.test',
    }),
    /Host not allowed/,
  );
});

test('fetchPublicUrl pins a public DNS result and streams successful responses', async (t) => {
  let lookups = 0;
  t.mock.method(dns, 'lookup', async () => {
    lookups++;
    return [{ address: '8.8.8.8', family: 4 }, { address: '1.1.1.1', family: 4 }];
  });
  let pinned;
  mockGet(https, (_url, options, callback) => {
    options.lookup('public.test', { all: true }, (_error, records) => { pinned = records; });
    callback(response(200, { 'content-type': 'video/mp4' }, 'video'));
  });
  const result = await fetchPublicUrl('https://public.test/watch', {});
  assert.equal(lookups, 1);
  assert.deepEqual(pinned, [{ address: '8.8.8.8', family: 4 }]);
  assert.equal(result.ok, true);
  assert.equal(result.headers.get('content-type'), 'video/mp4');
  assert.equal(await new Response(result.body).text(), 'video');
});

test('requireAuth rejects anonymous and unapproved accounts, accepting signed profiles only', async (t) => {
  t.mock.method(adminCompat, 'getAdminCompat', () => ({
    auth: () => ({ verifyIdToken: async (token) => ({ uid: 'u1', username: 'breyan',
      firebase: { sign_in_provider: token } }) }),
  }));
  const req = (token) => ({ get: () => `Bearer ${token}`, headers: {} });
  const anonymousRes = resMock();
  assert.equal(await requireAuth(req('anonymous'), anonymousRes), null);
  assert.equal(anonymousRes.statusCode, 401);
  assert.match(anonymousRes.body.error, /signed-in profile/);
  const strangerRes = resMock();
  assert.equal(await requireAuth(req('password'), strangerRes), null);
  assert.equal(strangerRes.statusCode, 403);
  assert.deepEqual(await requireAuth(req('custom'), resMock()), {
    uid: 'u1', username: 'breyan', firebase: { sign_in_provider: 'custom' },
  });
});

test('allowedCorsOrigin permits Everglow and localhost origins and rejects strangers', () => {
  const mk = (origin) => ({ get: (h) => (h.toLowerCase() === 'origin' ? origin : ''), headers: {} });
  assert.equal(allowedCorsOrigin(mk('https://everglow-1c6db.web.app')), 'https://everglow-1c6db.web.app');
  assert.equal(allowedCorsOrigin(mk('https://everglow-1c6db.firebaseapp.com')), 'https://everglow-1c6db.firebaseapp.com');
  assert.equal(allowedCorsOrigin(mk('http://localhost:5173')), 'http://localhost:5173');
  assert.equal(allowedCorsOrigin(mk('http://127.0.0.1:4173')), 'http://127.0.0.1:4173');
  assert.equal(allowedCorsOrigin(mk('https://evil.example')), 'https://everglow-1c6db.web.app');
  assert.equal(allowedCorsOrigin(mk('')), 'https://everglow-1c6db.web.app');
});

test('requireAuth checks token revocation and applyCors caches preflight for 24h', async (t) => {
  const { applyCors, getAdmin } = require('./common');
  let seenCheckRevoked = null;
  t.mock.method(getAdmin(), 'auth', () => ({
    verifyIdToken: async (_token, checkRevoked) => {
      seenCheckRevoked = checkRevoked;
      return { uid: 'u1', username: 'clairjassen', firebase: { sign_in_provider: 'custom' } };
    },
  }));
  const req = { get: () => 'Bearer tok', headers: {} };
  const decoded = await requireAuth(req, resMock());
  assert.equal(decoded.uid, 'u1');
  assert.equal(seenCheckRevoked, true);

  const res = { headers: {}, set(k, v) { this.headers[k] = v; return this; } };
  applyCors({ get: () => 'https://everglow-1c6db.web.app', headers: {} }, res, 'GET, OPTIONS');
  assert.equal(res.headers['Access-Control-Max-Age'], '86400');
});
