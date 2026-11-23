'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { Writable } = require('node:stream');
const common = require('./common.js');
const manga = require('./media_proxy_manga.js');
const { resolveRasterImageStream, sniffRasterContentType } = require('./stream_media_body.js');

function makeRes() {
  const chunks = [];
  const res = new Writable({
    write(chunk, _encoding, done) {
      chunks.push(Buffer.from(chunk));
      done();
    },
  });
  res.code = 200;
  res.headers = {};
  res.set = (k, v) => { res.headers[k] = v; return res; };
  res.status = (n) => { res.code = n; return res; };
  res.json = (body) => { res.jsonBody = body; return res; };
  res.send = (body) => { res.textBody = body; return res; };
  res.chunks = chunks;
  return res;
}

function makeReq(url) {
  return {
    method: 'GET',
    headers: {},
    get: () => '',
    ip: '8.8.8.8',
    query: { url },
  };
}

test('proxyMangaKatana streams application/octet-stream JPEG pages with sniffed Content-Type', async (t) => {
  const chunk1 = Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x43]);
  const chunk2 = Buffer.from([0x01, 0x02, 0x03, 0x04, 0xff, 0xd9]);
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: true,
    status: 200,
    headers: new Headers({ 'content-type': 'application/octet-stream' }),
    body: new ReadableStream({
      start(controller) {
        controller.enqueue(chunk1);
        controller.enqueue(chunk2);
        controller.close();
      },
    }),
    arrayBuffer() { assert.fail('must not buffer whole image body'); },
  }));

  const res = makeRes();
  await manga.proxyMangaKatana(
    makeReq('https://i1.mangakatana.com/token/demo/0.jpg'),
    res,
  );
  assert.equal(res.code, 200);
  assert.equal(res.headers['Content-Type'], 'image/jpeg');
  assert.equal(res.headers['X-Content-Type-Options'], 'nosniff');
  assert.equal(res.headers['Content-Security-Policy'], "default-src 'none'; sandbox");
  assert.deepEqual(Buffer.concat(res.chunks), Buffer.concat([chunk1, chunk2]));
});

test('proxyMangaKatana rejects application/octet-stream containing HTML or SVG with 415', async (t) => {
  let cancelled = false;
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: true,
    status: 200,
    headers: new Headers({ 'content-type': 'application/octet-stream' }),
    body: new ReadableStream({
      pull(controller) {
        controller.enqueue(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'));
      },
      cancel() { cancelled = true; },
    }),
  }));

  const res = makeRes();
  await manga.proxyMangaKatana(
    makeReq('https://i7.mangakatana.com/token/demo/0.jpg'),
    res,
  );
  assert.equal(res.code, 415);
  assert.equal(cancelled, true);
});

test('proxyMangaKatana rejects image/svg+xml and text/html immediately with 415', async (t) => {
  for (const ct of ['image/svg+xml', 'text/html; charset=utf-8']) {
    let cancelled = false;
    t.mock.method(common, 'fetchPublicUrl', async () => ({
      ok: true,
      status: 200,
      headers: new Headers({ 'content-type': ct }),
      body: new ReadableStream({
        start(c) { c.enqueue(Buffer.from([0xff, 0xd8, 0xff, 0xe0])); c.close(); },
        cancel() { cancelled = true; },
      }),
    }));
    const res = makeRes();
    await manga.proxyMangaKatana(
      makeReq('https://i6.mangakatana.com/token/demo/0.jpg'),
      res,
    );
    assert.equal(res.code, 415, `expected 415 for ${ct}`);
    assert.equal(cancelled, true, `expected body cancel for ${ct}`);
  }
});

test('sniffRasterContentType recognizes common raster headers and rejects non-raster bytes', () => {
  assert.equal(sniffRasterContentType(Buffer.from([0xff, 0xd8, 0xff, 0xe0])), 'image/jpeg');
  assert.equal(sniffRasterContentType(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])), 'image/png');
  assert.equal(sniffRasterContentType(Buffer.from('GIF89a......')), 'image/gif');
  assert.equal(sniffRasterContentType(Buffer.from('RIFF1234WEBP')), 'image/webp');
  assert.equal(sniffRasterContentType(Buffer.from('\x00\x00\x00\x1cftypavif')), 'image/avif');
  assert.equal(sniffRasterContentType(Buffer.from('BM\x00\x00')), 'image/bmp');
  assert.equal(sniffRasterContentType(Buffer.from('<html><body>hi</body></html>')), null);
  assert.equal(sniffRasterContentType(Buffer.from('<svg></svg>')), null);
});

test('resolveRasterImageStream handles magic bytes split across chunks and forwards cancel', async () => {
  const chunks = [Buffer.from('RIFF'), Buffer.from('1234'), Buffer.from('WEBP'), Buffer.from('payload')];
  let idx = 0;
  let cancelled = false;
  const resolved = await resolveRasterImageStream({
    headers: new Headers({ 'content-type': 'application/octet-stream' }),
    body: new ReadableStream({
      pull(controller) {
        if (idx < chunks.length) controller.enqueue(chunks[idx++]);
        else controller.close();
      },
      cancel() { cancelled = true; },
    }),
  });
  assert.ok(resolved);
  assert.equal(resolved.contentType, 'image/webp');
  const reader = resolved.body.getReader();
  const first = await reader.read();
  assert.deepEqual(Buffer.from(first.value), Buffer.from('RIFF'));
  await reader.cancel('stop');
  assert.equal(cancelled, true);
});

test('resolveMangaApiUrl rejects traversal, scheme, and backslash paths', () => {
  assert.equal(
    manga.resolveMangaApiUrl('https://api.mangadex.org', '/manga?title=frieren'),
    'https://api.mangadex.org/manga?title=frieren',
  );
  assert.throws(() => manga.resolveMangaApiUrl('https://api.mangadex.org', '../secret'), /Invalid path/);
  assert.throws(() => manga.resolveMangaApiUrl('https://api.mangadex.org', 'https://evil.test/x'), /Invalid path/);
  assert.throws(() => manga.resolveMangaApiUrl('https://api.mangadex.org', 'foo\\bar'), /Invalid path/);
  assert.throws(() => manga.resolveMangaApiUrl('https://api.mangadex.org', '//evil.test/x'), /Invalid path/);
});

test('proxyMangaDex caches 200 responses in memory with private Cache-Control', async (t) => {
  t.mock.method(common.getAdmin(), 'auth', () => ({
    verifyIdToken: async () => ({
      uid: 'u-manga',
      username: 'clairjassen',
      firebase: { sign_in_provider: 'custom' },
    }),
  }));
  let fetches = 0;
  t.mock.method(common, 'fetchPublicUrl', async () => {
    fetches += 1;
    return {
      ok: true,
      status: 200,
      headers: new Headers({ 'content-type': 'application/json' }),
      body: new ReadableStream({
        start(c) { c.enqueue(Buffer.from('{"data":[]}')); c.close(); },
      }),
    };
  });
  const req = {
    method: 'GET',
    headers: { authorization: 'Bearer test-token' },
    get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer test-token' : ''),
    ip: '8.8.8.8',
    query: { path: `manga?title=cache-test-${Date.now()}` },
  };
  const res1 = makeRes();
  await manga.proxyMangaDex(req, res1);
  assert.equal(res1.code, 200);
  assert.equal(res1.headers['Cache-Control'], 'private, max-age=60');
  assert.equal(res1.headers['X-Cache'], 'MISS');
  assert.equal(fetches, 1);

  const res2 = makeRes();
  await manga.proxyMangaDex(req, res2);
  assert.equal(res2.code, 200);
  assert.equal(res2.headers['Cache-Control'], 'private, max-age=60');
  assert.equal(res2.headers['X-Cache'], 'HIT');
  assert.equal(fetches, 1);
});
