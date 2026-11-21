'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const common = require('./common.js');
const { proxyCatalog, resolveCatalogUpstream } = require('./media_proxy_catalog.js');
const indexExports = require('./index.js');

test('proxyCatalog allow-list rejects unknown base', () => {
  assert.throws(
    () => resolveCatalogUpstream('evil', 'search.json?q=x'),
    /base must be openlibrary, jikan, itunes, aniskip, opentdb, gutendex, archive, anizip, or torrentio/,
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

test('proxyCatalog builds opentdb quiz URL server-side', () => {
  const url = resolveCatalogUpstream(
    'opentdb',
    'api.php?amount=50&category=9&type=multiple&token=abc',
  );
  assert.equal(url.origin + url.pathname, 'https://opentdb.com/api.php');
  assert.equal(url.searchParams.get('amount'), '50');
  assert.equal(url.searchParams.get('token'), 'abc');
});

test('proxyCatalog builds gutendex/archive/anizip URLs server-side', () => {
  const g = resolveCatalogUpstream('gutendex', 'books?search=dune');
  assert.equal(g.origin + g.pathname, 'https://gutendex.com/books');
  const a = resolveCatalogUpstream('archive', 'metadata/dune');
  assert.equal(a.origin + a.pathname, 'https://archive.org/metadata/dune');
  const z = resolveCatalogUpstream('anizip', 'mappings?mal_id=16498');
  assert.equal(z.origin + z.pathname, 'https://api.ani.zip/mappings');
});

test('proxyCatalog builds torrentio download-copy URL server-side', () => {
  const movie = resolveCatalogUpstream('torrentio', 'stream/movie/tt0137523.json');
  assert.equal(
    movie.origin + movie.pathname,
    'https://torrentio.strem.fun/stream/movie/tt0137523.json',
  );
  const episode = resolveCatalogUpstream(
    'torrentio',
    'stream/series/tt0944947:1:1.json',
  );
  assert.equal(
    episode.origin + episode.pathname,
    'https://torrentio.strem.fun/stream/series/tt0944947:1:1.json',
  );
});

test('index re-exports proxyCatalog', () => {
  assert.equal(typeof indexExports.proxyCatalog, 'function');
});

test('proxyCatalog rejects absolute and scheme-relative SSRF paths', () => {
  assert.throws(
    () => resolveCatalogUpstream('openlibrary', 'http://169.254.169.254/computeMetadata/v1/'),
    /Invalid path/,
  );
  assert.throws(
    () => resolveCatalogUpstream('openlibrary', 'https://evil.example/secret'),
    /Invalid path/,
  );
  assert.throws(
    () => resolveCatalogUpstream('jikan', '//evil.example/anime'),
    /Invalid path/,
  );
  assert.throws(
    () => resolveCatalogUpstream('jikan', '\\\\evil.example\\anime'),
    /Invalid path/,
  );
});

test('proxyCatalog caches 200 responses in memory and skips opentdb', async (t) => {
  let hits = 0;
  t.mock.method(common, 'fetchPublicUrl', async () => {
    hits++;
    return {
      ok: true,
      status: 200,
      headers: new Headers({ 'content-type': 'application/json' }),
      body: new Response(JSON.stringify({ ok: hits })).body,
    };
  });
  const call = async (base, path) => {
    const res = {
      code: 200,
      headers: {},
      set(k, v) { this.headers[k] = v; return this; },
      status(n) { this.code = n; return this; },
      send(b) { this.body = b; },
      json(b) { this.body = b; },
    };
    await proxyCatalog({ method: 'GET', query: { base, path }, headers: {}, get: () => '', ip: '203.0.113.9' }, res);
    return res;
  };
  const first = await call('jikan', 'anime?q=frieren-cache-test');
  const second = await call('jikan', 'anime?q=frieren-cache-test');
  assert.equal(first.headers['X-Cache'], 'MISS');
  assert.equal(second.headers['X-Cache'], 'HIT');
  assert.equal(hits, 1);

  await call('opentdb', 'api.php?amount=5');
  await call('opentdb', 'api.php?amount=5');
  assert.equal(hits, 3);
});
