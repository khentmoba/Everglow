'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const catalog = require('./catalog');
const indexExports = require('./index');

test('catalog group exposes TMDB + Last.fm proxies', () => {
  assert.equal(typeof catalog.proxyTmdb, 'function');
  assert.equal(typeof catalog.proxyLastfm, 'function');
  assert.equal(typeof catalog.lastfmCacheTtlMs, 'function');
});

test('catalog endpoints reject unapproved accounts before calling an upstream API', async (t) => {
  const admin = require('./common').getAdmin();
  t.mock.method(admin.auth(), 'verifyIdToken', async () => ({
    uid: 'stranger', username: 'breyan', firebase: { sign_in_provider: 'password' },
  }));
  const fetchMock = t.mock.method(globalThis, 'fetch', async () => assert.fail('must not call upstream'));
  for (const endpoint of [catalog.proxyTmdb, catalog.proxyLastfm]) {
    const res = { set() { return this; }, status(code) { this.code = code; return this; },
      json(body) { this.body = body; } };
    await endpoint({ method: 'GET', headers: {}, get: () => 'Bearer fake' }, res);
    assert.equal(res.code, 403);
  }
  assert.equal(fetchMock.mock.callCount(), 0);
});

test('cache key omits the server API key and sorts params', () => {
  const upstream = new URL(
    'https://ws.audioscrobbler.com/2.0/?api_key=server-key&method=artist.getInfo&username=clair',
  );
  const key = catalog.externalCacheKey('lastfm:proxy:', upstream);
  assert.equal(key, 'lastfm:proxy:/2.0/?method=artist.getInfo&username=clair');
  assert.equal(key.includes('server-key'), false);
});

test('Last.fm cache holds all-time reads longer than live ones', () => {
  const fiveMinutes = 5 * 60 * 1000;
  const thirtyMinutes = 30 * 60 * 1000;
  assert.equal(catalog.lastfmCacheTtlMs('artist.getInfo'), thirtyMinutes);
  assert.equal(catalog.lastfmCacheTtlMs('artist.getTopTracks'), thirtyMinutes);
  assert.equal(
    catalog.lastfmCacheTtlMs('user.gettoptracks', 'overall'),
    thirtyMinutes,
  );
  assert.equal(
    catalog.lastfmCacheTtlMs('user.gettopalbums', 'overall'),
    thirtyMinutes,
  );
  assert.equal(catalog.lastfmCacheTtlMs('user.getrecenttracks'), 30 * 1000);
  assert.equal(
    catalog.lastfmCacheTtlMs('user.gettoptracks', '7day'),
    fiveMinutes,
  );
  assert.equal(catalog.lastfmCacheTtlMs('user.getinfo'), fiveMinutes);
});

test('index re-exports the catalog group without renaming', () => {
  assert.equal(indexExports.proxyTmdb, catalog.proxyTmdb);
  assert.equal(indexExports.proxyLastfm, catalog.proxyLastfm);
});

test('proxyTmdb deduplicates concurrent cache misses and sets security headers', async (t) => {
  const previousKey = process.env.TMDB_API_KEY;
  process.env.TMDB_API_KEY = 'fake-tmdb-key';
  t.after(() => {
    if (previousKey === undefined) delete process.env.TMDB_API_KEY;
    else process.env.TMDB_API_KEY = previousKey;
  });
  const admin = require('./common').getAdmin();
  t.mock.method(admin.auth(), 'verifyIdToken', async () => ({
    uid: 'clair-uid', username: 'clairjassen', firebase: { sign_in_provider: 'custom' },
  }));
  let release;
  const fetchMock = t.mock.method(globalThis, 'fetch', () => new Promise((resolve) => {
    release = () => resolve(new Response(JSON.stringify({ results: [{ id: 1 }] }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    }));
  }));

  const makeRes = () => {
    const headers = {};
    return {
      headers,
      set(k, v) { headers[k.toLowerCase()] = v; return this; },
      status(code) { this.code = code; return this; },
      send(body) { this.body = body; return this; },
      json(body) { this.body = body; return this; },
    };
  };
  const req = {
    method: 'GET',
    path: '/movie/singleflight-test',
    query: {},
    headers: {},
    get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer fake-token' : ''),
  };
  const res1 = makeRes();
  const res2 = makeRes();
  const p1 = catalog.proxyTmdb(req, res1);
  const p2 = catalog.proxyTmdb(req, res2);
  await new Promise((r) => setImmediate(r));
  assert.equal(fetchMock.mock.callCount(), 1);
  release();
  await Promise.all([p1, p2]);
  assert.equal(res1.code, 200);
  assert.equal(res2.code, 200);
  assert.equal(res1.headers['x-content-type-options'], 'nosniff');
  assert.equal(res1.headers['content-security-policy'], "default-src 'none'; sandbox");
  assert.equal(res2.headers['x-content-type-options'], 'nosniff');
});
