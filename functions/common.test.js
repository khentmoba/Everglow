'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { EventEmitter } = require('node:events');
const { Readable } = require('node:stream');
const dns = require('node:dns').promises;
const https = require('node:https');
const adminCompat = require('./admin_compat.js');
const { isPrivateIp, fetchPublicUrl, requireAuth } = require('./common.js');

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

test('requireAuth rejects anonymous tokens and accepts a verified login', async (t) => {
  t.mock.method(adminCompat, 'getAdminCompat', () => ({
    auth: () => ({ verifyIdToken: async (token) => ({ uid: 'u1', firebase: { sign_in_provider: token } }) }),
  }));
  const req = (token) => ({ get: () => `Bearer ${token}`, headers: {} });
  const anonymousRes = resMock();
  assert.equal(await requireAuth(req('anonymous'), anonymousRes), null);
  assert.equal(anonymousRes.statusCode, 401);
  assert.match(anonymousRes.body.error, /signed-in profile/);
  assert.deepEqual(await requireAuth(req('password'), resMock()), { uid: 'u1', firebase: { sign_in_provider: 'password' } });
});
