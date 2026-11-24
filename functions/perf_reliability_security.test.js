'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  exec_add_to_watchlist,
  exec_search_movies,
  exec_get_watchlist,
  exec_search_books,
} = require('./motchi_exec_media.js');
const {
  exec_plan_date_night,
  exec_get_weather,
} = require('./motchi_exec_planning.js');
const common = require('./common.js');
const { proxyFetchHtml } = require('./media_proxy_html.js');
const { proxyComick, proxyMangaDex } = require('./media_proxy_manga.js');
const { handleProxyAI } = require('./motchi_chat.js');
const { exec_web_search } = require('./motchi_exec_insights.js');
const { motchiStats } = require('./motchi_stats.js');
const { handleGenerateStudySet } = require('./motchi_study.js');
const { proxyBookText, proxyBookFile } = require('./media_proxy_books.js');
const { notifyDiscordWatch } = require('./discord_functions.js');
const { proxyWatchStream } = require('./media_proxy_video.js');

function makeCtx(overrides = {}) {
  const cache = new Map();
  return {
    callerUid: 'khentsgdz',
    getTmdbKey: () => 'test-key',
    cacheTTLs: { tmdb: 60_000, books: 60_000, weather: 60_000 },
    cacheGet: (k) => cache.get(k) || null,
    cacheSet: (k, v) => cache.set(k, v),
    _cache: cache,
    admin: { firestore: { FieldValue: { serverTimestamp: () => 'TS' } } },
    db: {
      collection: () => ({
        add: async () => ({ id: 'doc1' }),
        limit: () => ({ get: async () => ({ docs: [] }) }),
      }),
    },
    ...overrides,
  };
}

test('exec_search_movies sanitizes media_type and never caches non-OK TMDB responses', async (t) => {
  const seen = [];
  t.mock.method(globalThis, 'fetch', async (url, opts) => {
    seen.push({ url: String(url), hasSignal: Boolean(opts && opts.signal) });
    return { ok: false, status: 503, json: async () => ({ error: 'down' }) };
  });
  const ctx = makeCtx();
  const out = JSON.parse(await exec_search_movies(ctx, { query: 'Dune', media_type: '../account' }));
  assert.match(out.error, /503/);
  assert.equal(seen.length, 1);
  assert.match(seen[0].url, /\/3\/search\/multi\?/);
  assert.equal(seen[0].hasSignal, true);
  assert.equal(ctx._cache.size, 0);
});

test('exec_add_to_watchlist rejects non-integer tmdb_id before calling TMDB', async (t) => {
  const fetchMock = t.mock.method(globalThis, 'fetch', async () => {
    assert.fail('must not fetch for invalid tmdb_id');
  });
  const ctx = makeCtx();
  const out = JSON.parse(await exec_add_to_watchlist(ctx, { tmdb_id: -5, media_type: 'movie' }));
  assert.match(out.error, /Invalid TMDB ID/);
  assert.equal(fetchMock.mock.callCount(), 0);
});

test('exec_search_books checks response.ok with timeout and skips caching failures', async (t) => {
  let hasSignal = false;
  t.mock.method(globalThis, 'fetch', async (_url, opts) => {
    hasSignal = Boolean(opts && opts.signal);
    return { ok: false, status: 502, json: async () => ({}) };
  });
  const ctx = makeCtx();
  const out = JSON.parse(await exec_search_books(ctx, { query: 'Dune' }));
  assert.match(out.error, /502/);
  assert.equal(hasSignal, true);
  assert.equal(ctx._cache.size, 0);
});

test('exec_get_watchlist queries both profiles concurrently', async () => {
  let inFlight = 0;
  let maxInFlight = 0;
  const ctx = makeCtx({
    db: {
      collection: () => ({
        where: (_field, _op, user) => ({
          orderBy: () => ({
            limit: () => ({
              get: async () => {
                inFlight += 1;
                maxInFlight = Math.max(maxInFlight, inFlight);
                await new Promise((r) => setTimeout(r, 15));
                inFlight -= 1;
                return {
                  docs: [{ data: () => ({ title: `Pick for ${user}`, mediaType: 'movie', status: 'plan_to_watch' }) }],
                };
              },
            }),
          }),
        }),
      }),
    },
  });
  const out = JSON.parse(await exec_get_watchlist(ctx, { limit: 10 }));
  assert.equal(maxInFlight, 2);
  assert.match(out.watchlist, /Pick for khentsgdz/);
  assert.match(out.watchlist, /Pick for clairjassen/);
});

test('exec_get_weather passes timeout and does not cache non-OK responses', async (t) => {
  let hasSignal = false;
  t.mock.method(globalThis, 'fetch', async (_url, opts) => {
    hasSignal = Boolean(opts && opts.signal);
    return { ok: false, status: 503, text: async () => '<html>503</html>' };
  });
  const ctx = makeCtx();
  const out = JSON.parse(await exec_get_weather(ctx, { location: 'Manila' }));
  assert.equal(hasSignal, true);
  assert.equal(out.weather, 'Weather unavailable');
  assert.match(out.error, /503/);
  assert.equal(ctx._cache.size, 0);
});

test('exec_plan_date_night falls back gracefully when weather fetch rejects', async (t) => {
  t.mock.method(globalThis, 'fetch', async () => {
    throw new Error('network timeout');
  });
  const ctx = makeCtx({
    db: {
      collection: (name) => ({
        limit: () => ({
          get: async () => ({
            docs: name === 'date_ideas'
              ? [{ data: () => ({ title: 'Stargazing' }) }]
              : [{ data: () => ({ title: 'Past Lives' }) }],
          }),
        }),
      }),
    },
  });
  const out = JSON.parse(await exec_plan_date_night(ctx, { location: 'Manila' }));
  assert.equal(out.weather, 'Weather unavailable');
  assert.deepEqual(out.ideas, ['Stargazing']);
  assert.deepEqual(out.watchlist, ['Past Lives']);
});

test('proxyFetchHtml sets hardened CSP and private Cache-Control', async (t) => {
  t.mock.method(common, 'requireAuth', async () => ({ uid: 'u-html' }));
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: true,
    status: 200,
    headers: new Headers({ 'content-type': 'text/html' }),
    body: new ReadableStream({
      start(c) { c.enqueue(Buffer.from('<html>ok</html>')); c.close(); },
    }),
  }));
  const res = {
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  };
  await proxyFetchHtml(
    {
      method: 'GET',
      headers: {},
      get: () => '',
      ip: '8.8.8.8',
      query: { url: 'https://mangakatana.com/manga/demo' },
    },
    res,
  );
  assert.equal(res.code, 200);
  assert.equal(res.headers['Content-Security-Policy'], "default-src 'none'; sandbox");
  assert.equal(res.headers['Cache-Control'], 'private, max-age=60');
});

test('exec_plan_date_night falls back to Weather unavailable if body stream aborts', async (t) => {
  const ctx = makeCtx();
  t.mock.method(global, 'fetch', async () => ({
    ok: true,
    status: 200,
    text: async () => {
      const err = new Error('The operation was aborted due to timeout');
      err.name = 'TimeoutError';
      throw err;
    },
  }));
  const out = JSON.parse(await exec_plan_date_night(ctx, { location: 'Manila', count: 2 }));
  assert.equal(out.weather, 'Weather unavailable');
  assert.equal(ctx._cache.size, 0);
});

test('exec_web_search returns graceful error when TinyFish json body stream times out', async (t) => {
  const prevKey = process.env.TINYFISH_API_KEY;
  process.env.TINYFISH_API_KEY = 'test-key';
  t.after(() => {
    if (prevKey === undefined) delete process.env.TINYFISH_API_KEY;
    else process.env.TINYFISH_API_KEY = prevKey;
  });
  t.mock.method(globalThis, 'fetch', async () => ({
    ok: true,
    status: 200,
    json: async () => {
      const err = new Error('The operation was aborted due to timeout');
      err.name = 'TimeoutError';
      throw err;
    },
  }));
  const ctx = makeCtx({ cacheTTLs: { web_search: 60_000, web_search_long: 60_000 } });
  const out = JSON.parse(await exec_web_search(ctx, { query: 'manila weather', domain_type: 'news' }));
  assert.match(out.error, /timed out/i);
});

test('auth-gated private endpoints set Cache-Control: private, no-store and Vary: Origin, Authorization', async () => {
  const handlers = [
    ['motchiStats', motchiStats],
    ['handleGenerateStudySet', handleGenerateStudySet],
    ['handleProxyAI', handleProxyAI],
    ['proxyBookText', proxyBookText],
    ['proxyBookFile', proxyBookFile],
    ['proxyFetchHtml', proxyFetchHtml],
    ['proxyComick', proxyComick],
    ['proxyMangaDex', proxyMangaDex],
    ['notifyDiscordWatch', notifyDiscordWatch],
    ['proxyWatchStream', proxyWatchStream],
  ];
  for (const [name, fn] of handlers) {
    const res = {
      code: 200,
      headers: {},
      set(k, v) { this.headers[k] = v; return this; },
      status(n) { this.code = n; return this; },
      send(b) { this.body = b; return this; },
      json(b) { this.body = b; return this; },
    };
    await fn({ method: 'OPTIONS', headers: {}, query: {}, get: () => '', ip: '203.0.113.20' }, res);
    assert.equal(res.headers['Cache-Control'], 'private, no-store', `${name} Cache-Control`);
    assert.equal(res.headers['Vary'], 'Origin, Authorization', `${name} Vary`);
  }
});
