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
  // Exact per-artist playcount and all-time charts barely move between listens.
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
  // The jukebox live feed holds only 30s so song changes surface fast;
  // other live reads keep the short default.
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
