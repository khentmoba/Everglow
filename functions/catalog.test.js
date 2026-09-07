'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const catalog = require('./catalog');
const indexExports = require('./index');

test('catalog group exposes TMDB + Last.fm proxies', () => {
  assert.equal(typeof catalog.proxyTmdb, 'function');
  assert.equal(typeof catalog.proxyLastfm, 'function');
});

test('index re-exports the catalog group without renaming', () => {
  assert.equal(indexExports.proxyTmdb, catalog.proxyTmdb);
  assert.equal(indexExports.proxyLastfm, catalog.proxyLastfm);
});
