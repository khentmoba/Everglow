'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const { resolveCatalogUpstream } = require('./media_proxies.js');
const indexExports = require('./index.js');

test('proxyCatalog allow-list rejects unknown base', () => {
  assert.throws(
    () => resolveCatalogUpstream('evil', 'search.json?q=x'),
    /base must be openlibrary, jikan, itunes, or aniskip/,
  );
});

test('proxyCatalog rejects missing path', () => {
  assert.throws(
    () => resolveCatalogUpstream('openlibrary', ''),
    /Missing \?path/,
  );
});

test('proxyCatalog rejects traversal path', () => {
  assert.throws(
    () => resolveCatalogUpstream('jikan', '../../etc/passwd'),
    /Invalid path/,
  );
});

test('proxyCatalog rejects overlong path', () => {
  assert.throws(
    () => resolveCatalogUpstream('openlibrary', `search.json?${'q=x&'.repeat(100)}`),
    /Invalid path/,
  );
});

test('proxyCatalog builds openlibrary search URL server-side', () => {
  const url = resolveCatalogUpstream(
    'openlibrary',
    'search.json?q=dune&limit=1',
  );
  assert.equal(url.origin + url.pathname, 'https://openlibrary.org/search.json');
  assert.equal(url.searchParams.get('q'), 'dune');
  assert.equal(url.searchParams.get('limit'), '1');
});

test('proxyCatalog builds jikan anime lookup URL server-side', () => {
  const url = resolveCatalogUpstream('jikan', 'anime?q=naruto&limit=1');
  assert.equal(url.origin + url.pathname, 'https://api.jikan.moe/v4/anime');
  assert.equal(url.searchParams.get('q'), 'naruto');
});

test('proxyCatalog builds itunes search URL server-side', () => {
  const url = resolveCatalogUpstream(
    'itunes',
    'search?term=dune&entity=song&media=music&limit=1',
  );
  assert.equal(url.origin + url.pathname, 'https://itunes.apple.com/search');
  assert.equal(url.searchParams.get('term'), 'dune');
  assert.equal(url.searchParams.get('entity'), 'song');
});

test('proxyCatalog builds aniskip skip-times URL server-side', () => {
  const url = resolveCatalogUpstream(
    'aniskip',
    'v1/skip-times/5114/1?types[]=op&types[]=ed',
  );
  assert.equal(
    url.origin + url.pathname,
    'https://api.aniskip.com/v1/skip-times/5114/1',
  );
  assert.deepEqual(url.searchParams.getAll('types[]'), ['op', 'ed']);
});

test('proxyCatalog strips path traversal but keeps legit query', () => {
  const url = resolveCatalogUpstream('jikan', '/anime?q=one+piece');
  assert.equal(url.origin + url.pathname, 'https://api.jikan.moe/v4/anime');
  assert.equal(url.searchParams.get('q'), 'one piece');
});

test('index re-exports proxyCatalog', () => {
  assert.equal(typeof indexExports.proxyCatalog, 'function');
});
