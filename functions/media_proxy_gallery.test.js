'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const common = require('./common');
const { parseProjectStorageUrl, resolveGalleryDeletePath } = require('./media_proxy_core');
const { proxyGalleryImage, cleanupGallery, deleteGalleryPhoto, deleteGalleryDocs, safeUrlPath } = require('./media_proxy_gallery');
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
  return {
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    json(data) { this.body = data; },
    send(data) { this.body = data; },
  };
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
  assert.match(res.headers['Cache-Control'], /^private,/);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].opts.redirect, 'error');
});

test('gallery proxy logs only the object path, never the signed token', async (t) => {
  const warnings = [];
  t.mock.method(console, 'warn', (...args) => warnings.push(args.map(String).join(' ')));
  t.mock.method(global, 'fetch', async () => { throw new Error('upstream down'); });
  const req = { method: 'GET', query: { url: good }, headers: {}, get: () => '', ip: '203.0.113.4' };
  const res = response();
  await proxyGalleryImage(req, res);
  assert.equal(res.code, 502);
  const logged = warnings.join(' ');
  assert.ok(logged.includes('/o/gallery%2Fdemo.jpg'), `expected object path in log, got: ${logged}`);
  assert.ok(!logged.includes('token=demo'), `must not log the capability token: ${logged}`);
  assert.equal(safeUrlPath('not a url'), '<invalid-url>');
});

test('deleteGalleryDocs keeps going after one failed Firestore delete', async () => {
  const removed = [];
  const docs = [
    { data: () => ({}), ref: { delete: async () => { removed.push('a'); } } },
    { data: () => ({}), ref: { delete: async () => { throw new Error('deadline exceeded'); } } },
    { data: () => ({}), ref: { delete: async () => { removed.push('c'); } } },
  ];
  const result = await deleteGalleryDocs(docs, async () => {}, 2);
  assert.deepEqual(removed.sort(), ['a', 'c']);
  assert.deepEqual(result, { deleted: 2, failed: 1 });
});

test('deleteGalleryDocs removes the doc even when its Storage file is missing', async () => {
  let docDeleted = false;
  const docs = [{
    data: () => ({ imageUrl: good }),
    ref: { delete: async () => { docDeleted = true; } },
  }];
  const result = await deleteGalleryDocs(docs, async () => { throw new Error('404 not found'); });
  assert.equal(docDeleted, true);
  assert.deepEqual(result, { deleted: 1, failed: 0 });
});

test('cleanupGallery deletes Storage objects and sets private no-store headers', async (t) => {
  const deletedFiles = [];
  const deletedDocs = [];
  const admin = common.getAdmin();
  t.mock.method(admin, 'auth', () => ({
    verifyIdToken: async () => ({
      uid: 'everglow_khentsgdz',
      username: 'khentsgdz',
      firebase: { sign_in_provider: 'custom' },
    }),
  }));
  t.mock.method(admin, 'firestore', () => ({
    collection: (name) => {
      if (name === 'users') {
        return {
          doc: () => ({ get: async () => ({ exists: true, data: () => ({ username: 'khentsgdz' }) }) }),
        };
      }
      return {
        limit: () => ({
          get: async () => ({
            docs: [{
              data: () => ({ imageUrl: good }),
              ref: { delete: async () => { deletedDocs.push('doc1'); } },
            }],
          }),
        }),
      };
    },
  }));
  t.mock.method(admin, 'storage', () => ({
    bucket: () => ({
      file: (objectPath) => ({
        delete: async (opts) => { deletedFiles.push({ objectPath, opts }); },
      }),
    }),
  }));

  const req = {
    method: 'POST',
    headers: { authorization: 'Bearer tok' },
    get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer tok' : ''),
    ip: '203.0.113.8',
    body: { confirm: true },
  };
  const res = response();
  await cleanupGallery(req, res);

  assert.equal(res.code, 200);
  assert.equal(res.headers['Cache-Control'], 'private, no-store');
  assert.equal(res.headers['Vary'], 'Origin, Authorization');
  assert.deepEqual(deletedFiles, [{ objectPath: 'gallery/demo.jpg', opts: { ignoreNotFound: true } }]);
  assert.deepEqual(deletedDocs, ['doc1']);
  assert.deepEqual(res.body, { deleted: 1, failed: 0 });
});

test('deleteGalleryPhoto sets private no-store headers', async () => {
  const req = { method: 'OPTIONS', headers: {}, get: () => '', ip: '203.0.113.9' };
  const res = response();
  await deleteGalleryPhoto(req, res);
  assert.equal(res.code, 204);
  assert.equal(res.headers['Cache-Control'], 'private, no-store');
  assert.equal(res.headers['Vary'], 'Origin, Authorization');
});
