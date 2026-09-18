'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const { isAllowedLastfmImageUrl } = require('./media_proxies.js');
const indexExports = require('./index.js');

const REAL_ART =
  'https://lastfm-img.freetls.fastly.net/i/u/300x300/312d04191a575f71f2c743fca3bb596f.png';
const LEGACY_ART = 'https://lastfm.freetls.fastly.net/i/u/174s/abc123.png';

test('proxyLastfmImage allow-list accepts both artwork CDN hosts', () => {
  assert.equal(isAllowedLastfmImageUrl(REAL_ART), true);
  assert.equal(isAllowedLastfmImageUrl(LEGACY_ART), true);
});

test('proxyLastfmImage allow-list rejects anything else', () => {
  assert.equal(isAllowedLastfmImageUrl(''), false);
  assert.equal(isAllowedLastfmImageUrl(null), false);
  assert.equal(isAllowedLastfmImageUrl('not a url'), false);
  assert.equal(
    isAllowedLastfmImageUrl('http://lastfm-img.freetls.fastly.net/i/u/x.png'),
    false,
  );
  assert.equal(isAllowedLastfmImageUrl('https://evil.com/x.png'), false);
  assert.equal(
    isAllowedLastfmImageUrl(
      'https://lastfm-img.freetls.fastly.net.evil.com/x.png',
    ),
    false,
  );
});

test('index re-exports proxyLastfmImage', () => {
  assert.equal(typeof indexExports.proxyLastfmImage, 'function');
});
