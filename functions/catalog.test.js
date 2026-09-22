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
  assert.equal(
    catalog.lastfmCacheTtlMs('user.gettoptracks', 'overall'),
    thirtyMinutes,
  );
  assert.equal(
    catalog.lastfmCacheTtlMs('user.gettopalbums', 'overall'),
    thirtyMinutes,
  );
  // Live reads keep the short default so the jukebox stays current.
  assert.equal(catalog.lastfmCacheTtlMs('user.getrecenttracks'), fiveMinutes);
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
