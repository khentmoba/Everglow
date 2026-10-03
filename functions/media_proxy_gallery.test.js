'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const { parseProjectStorageUrl, resolveGalleryDeletePath } = require('./media_proxy_core');
const { proxyGalleryImage } = require('./media_proxy_gallery');
const good = 'https://firebasestorage.googleapis.com/v0/b/everglow-1c6db.firebasestorage.app/o/gallery%2Fdemo.jpg?alt=media&token=demo';
const bad = [
  'https://attacker.invalid/?firebasestorage.googleapis.com=everglow-1c6db',
  'http://127.0.0.1/?firebasestorage.googleapis.com=everglow-1c6db',
  good.replace('https:', 'http:'),
  good.replace('firebasestorage.googleapis.com', 'firebasestorage.googleapis.com.attacker.invalid'),
  good.replace('everglow-1c6db.firebasestorage.app', 'other-project.appspot.com'),
  good.replace('everglow-1c6db.firebasestorage.app', 'everglow-1c6db-attacker.appspot.com'),
  good.replace('https://', 'https://user:password@'),
  good.replace('googleapis.com/', 'googleapis.com:444/'),
];
function response() {
  return { code: 200, set() { return this; }, status(n) { this.code = n; return this; },
    json(data) { this.body = data; }, send(data) { this.body = data; } };
}
test('gallery URL parser accepts only exact HTTPS project buckets', () => {
  assert.equal(parseProjectStorageUrl(good).hostname, 'firebasestorage.googleapis.com');
  assert.equal(parseProjectStorageUrl(good.replace('firebasestorage.app', 'appspot.com')).protocol, 'https:');
  for (const url of bad) {
    assert.throws(() => parseProjectStorageUrl(url));
    assert.throws(() => resolveGalleryDeletePath(url));
  }
});
test('gallery proxy rejects malicious URLs before fetch and forbids redirects', async (t) => {
  const requests = [];
  t.mock.method(global, 'fetch', async (url, opts) => {
    requests.push({ url, opts });
    return { ok: true, headers: new Headers({ 'Content-Type': 'image/jpeg' }),
      body: null, arrayBuffer: async () => Buffer.from('demo image') };
  });
  const req = (url) => ({ method: 'GET', query: { url }, headers: {}, get: () => '', ip: '203.0.113.4' });
  for (const url of bad) {
    const res = response();
    await proxyGalleryImage(req(url), res);
    assert.equal(res.code, 403);
  }
  assert.equal(requests.length, 0);
  const res = response();
  await proxyGalleryImage(req(good), res);
  assert.equal(res.code, 200);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].opts.redirect, 'error');
});
