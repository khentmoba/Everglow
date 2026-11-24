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
  exec_complete_habit,
  exec_cancel_reminder,
  exec_update_calendar_event,
  exec_delete_calendar_event,
  exec_complete_bucket_item,
  exec_delete_bucket_item,
  exec_add_trip_pin,
  exec_edit_trip,
} = require('./motchi_exec_planning.js');
const {
  exec_pin_memory,
  exec_delete_memory,
  exec_edit_memory,
  exec_read_journal_entry,
  exec_edit_journal_entry,
  exec_delete_journal_entry,
} = require('./motchi_exec_memory.js');
const { loginAccount, communityWatchPartyAccess } = require('./accounts.js');
const { recordMotchiTurn } = require('./motchi_sessions.js');
const { proxyLastfmImage } = require('./media_proxy_music.js');
const common = require('./common.js');
const { proxyFetchHtml } = require('./media_proxy_html.js');
const { proxyComick, proxyMangaDex, resolveMangaApiUrl } = require('./media_proxy_manga.js');
const { resolveCatalogUpstream } = require('./media_proxy_catalog.js');
const { parseStudySet } = require('./motchi_study.js');
const { proxyAnime } = require('./anime.js');
const { handleProxyAI } = require('./motchi_chat.js');
const { exec_web_search } = require('./motchi_exec_insights.js');
const { motchiStats } = require('./motchi_stats.js');
const { handleGenerateStudySet } = require('./motchi_study.js');
const { proxyBookText, proxyBookFile } = require('./media_proxy_books.js');
const { notifyDiscordWatch } = require('./discord_functions.js');
const { proxyWatchStream } = require('./media_proxy_video.js');
const { proxyTmdb } = require('./catalog.js');
const { proxyCatalog } = require('./media_proxy_catalog.js');
const { isAllowedTmdbPath } = require('./media_proxy_core.js');
const { proxyMegavidHls } = require('./anime.js');

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
    ['proxyTmdb', proxyTmdb],
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

test('isAllowedTmdbPath rejects query smuggling, fragments, backslashes, and encoded traversal', () => {
  assert.equal(isAllowedTmdbPath('/movie/550'), true);
  assert.equal(isAllowedTmdbPath('tv/1396/season/1'), true);
  assert.equal(isAllowedTmdbPath('movie/550?api_key=evil'), false);
  assert.equal(isAllowedTmdbPath('movie/550#frag'), false);
  assert.equal(isAllowedTmdbPath('movie\\550'), false);
  assert.equal(isAllowedTmdbPath('%2e%2e/4/account'), false);
  assert.equal(isAllowedTmdbPath('movie/%2e%2e/account'), false);
  assert.equal(isAllowedTmdbPath('movie/%E0%A4%A'), false);
});

test('proxyCatalog and proxyMangaDex do not cache non-200 upstream responses', async (t) => {
  t.mock.method(common.getAdmin(), 'auth', () => ({
    verifyIdToken: async () => ({
      uid: 'u-cache-err',
      username: 'clairjassen',
      firebase: { sign_in_provider: 'custom' },
    }),
  }));
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: false,
    status: 503,
    headers: new Headers({ 'content-type': 'application/json' }),
    body: new ReadableStream({
      start(c) { c.enqueue(Buffer.from('{"error":"busy"}')); c.close(); },
    }),
  }));

  const makeRes = () => ({
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  });

  const catRes = makeRes();
  await proxyCatalog(
    { method: 'GET', headers: {}, get: () => '', ip: '203.0.113.21', query: { base: 'openlibrary', path: 'search.json?q=test' } },
    catRes,
  );
  assert.equal(catRes.code, 503);
  assert.equal(catRes.headers['Cache-Control'], 'private, no-store');

  const mdRes = makeRes();
  await proxyMangaDex(
    {
      method: 'GET',
      headers: { authorization: 'Bearer test-token' },
      get: (h) => (String(h).toLowerCase() === 'authorization' ? 'Bearer test-token' : ''),
      ip: '203.0.113.22',
      query: { path: '/manga' },
    },
    mdRes,
  );
  assert.equal(mdRes.code, 503);
  assert.equal(mdRes.headers['Cache-Control'], 'private, no-store');
});

test('proxyTmdb sets private, no-store on non-200 upstream responses and private, max-age=300 on 200', async (t) => {
  const prevKey = process.env.TMDB_API_KEY;
  process.env.TMDB_API_KEY = 'tmdb-test-key';
  t.after(() => {
    if (prevKey === undefined) delete process.env.TMDB_API_KEY;
    else process.env.TMDB_API_KEY = prevKey;
  });
  t.mock.method(common.getAdmin(), 'auth', () => ({
    verifyIdToken: async () => ({
      uid: 'u-tmdb-cache',
      username: 'clairjassen',
      firebase: { sign_in_provider: 'custom' },
    }),
  }));
  let nextStatus = 503;
  t.mock.method(globalThis, 'fetch', async () => ({
    ok: nextStatus === 200,
    status: nextStatus,
    headers: new Headers({ 'content-type': 'application/json' }),
    body: new ReadableStream({
      start(c) { c.enqueue(Buffer.from('{"ok":true}')); c.close(); },
    }),
  }));
  const makeRes = () => ({
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  });
  const authReq = {
    method: 'GET',
    path: '/movie/999001',
    query: {},
    headers: { authorization: 'Bearer test-token' },
    get: (h) => (String(h).toLowerCase() === 'authorization' ? 'Bearer test-token' : ''),
    ip: '203.0.113.23',
  };

  const errRes = makeRes();
  await proxyTmdb(authReq, errRes);
  assert.equal(errRes.code, 503);
  assert.equal(errRes.headers['Cache-Control'], 'private, no-store');

  nextStatus = 200;
  const okRes = makeRes();
  await proxyTmdb(authReq, okRes);
  assert.equal(okRes.code, 200);
  assert.equal(okRes.headers['Cache-Control'], 'private, max-age=300');
});

test('proxyMegavidHls marks 206 partial responses private, no-store with Vary: Origin, Range', async (t) => {
  const dns = require('node:dns').promises;
  t.mock.method(dns, 'lookup', async () => [{ address: '93.184.216.34', family: 4 }]);
  t.mock.method(common.getAdmin(), 'auth', () => ({
    verifyIdToken: async () => ({
      uid: 'u-hls-206',
      username: 'clairjassen',
      firebase: { sign_in_provider: 'custom' },
    }),
  }));
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: true,
    status: 206,
    headers: new Headers({
      'content-type': 'video/mp2t',
      'content-range': 'bytes 0-10/100',
      'accept-ranges': 'bytes',
    }),
    arrayBuffer: async () => Buffer.from('01234567890'),
  }));
  const res = {
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  };
  await proxyMegavidHls(
    {
      method: 'GET',
      headers: { authorization: 'Bearer test-token', range: 'bytes=0-10' },
      get: (h) => {
        const k = String(h).toLowerCase();
        if (k === 'authorization') return 'Bearer test-token';
        if (k === 'range') return 'bytes=0-10';
        return '';
      },
      ip: '203.0.113.24',
      query: { u: 'https://megavid.buzz/seg1.ts' },
    },
    res,
  );
  assert.equal(res.code, 206);
  assert.equal(res.headers['Cache-Control'], 'private, no-store');
  assert.equal(res.headers['Vary'], 'Origin, Range');
});

test('isSafeDocId accepts normal Firestore IDs and rejects traversal, reserved, and control chars', () => {
  assert.equal(common.isSafeDocId('abc123_-XYZ'), true);
  assert.equal(common.isSafeDocId('sess_1700000000_khent_ab12'), true);
  for (const bad of ['', '.', '..', 'a/b', '../users/khentsgdz', '__reserved__', 'bad\nid', 'a\x00b', 'x'.repeat(129), null, 42]) {
    assert.equal(common.isSafeDocId(bad), false, `expected ${JSON.stringify(bad)} to be rejected`);
  }
});

test('loginAccount rejects path-traversal usernames before touching Firestore', async (t) => {
  let touchedDb = false;
  t.mock.method(common.getAdmin(), 'firestore', () => {
    touchedDb = true;
    throw new Error('Firestore should not be called');
  });
  const res = {
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  };
  await loginAccount(
    {
      method: 'POST',
      headers: {},
      get: () => '',
      ip: '203.0.113.41',
      body: { username: '../users/khentsgdz', password: 'password123' },
    },
    res,
  );
  assert.equal(res.code, 400);
  assert.equal(touchedDb, false);
});

test('communityWatchPartyAccess unlockRoom rejects reserved dot and double-underscore roomIds', async (t) => {
  t.mock.method(common.getAdmin(), 'auth', () => ({
    verifyIdToken: async () => ({
      uid: 'u-room-id',
      username: 'clairjassen',
      firebase: { sign_in_provider: 'custom' },
    }),
  }));
  let touchedDoc = false;
  t.mock.method(common.getAdmin(), 'firestore', () => ({
    collection: () => ({
      doc: () => {
        touchedDoc = true;
        throw new Error('doc() should not be called');
      },
    }),
  }));
  for (const badId of ['.', '..', '__internal__', 'a/b']) {
    const res = {
      code: 200,
      headers: {},
      set(k, v) { this.headers[k] = v; return this; },
      status(n) { this.code = n; return this; },
      send(b) { this.body = b; return this; },
      json(b) { this.body = b; return this; },
    };
    await communityWatchPartyAccess(
      {
        method: 'POST',
        headers: { authorization: 'Bearer tok' },
        get: (h) => (String(h).toLowerCase() === 'authorization' ? 'Bearer tok' : ''),
        ip: '203.0.113.42',
        body: { action: 'unlockRoom', roomId: badId, password: 'pw' },
      },
      res,
    );
    assert.equal(res.code, 400, `expected 400 for roomId ${badId}`);
  }
  assert.equal(touchedDoc, false);
});

test('recordMotchiTurn ignores unsafe sessionId traversal and generates a safe session id', async (t) => {
  const docIds = [];
  t.mock.method(common, 'getDb', () => ({
    collection: () => ({
      where: () => ({
        where: () => ({
          where: () => ({
            orderBy: () => ({
              limit: () => ({ get: async () => ({ empty: true, docs: [] }) }),
            }),
          }),
        }),
      }),
      doc: (id) => {
        docIds.push(id);
        return {
          get: async () => ({ exists: false }),
          set: async () => {},
        };
      },
    }),
  }));
  const returned = await recordMotchiTurn({
    sessionId: '../users/khentsgdz',
    caller: 'khentsgdz',
    userMessage: 'hello',
    assistantReply: 'hi',
  });
  assert.equal(docIds.length, 1);
  assert.match(docIds[0], /^sess_\d+_khentsgdz_/);
  assert.equal(returned, docIds[0]);
});

test('motchi memory and planning executors reject unsafe Firestore doc IDs without calling .doc()', async () => {
  let docCalled = false;
  const ctx = makeCtx({
    db: {
      collection: () => ({
        doc: () => {
          docCalled = true;
          throw new Error('.doc() must not be called for invalid id');
        },
      }),
    },
  });
  const calls = [
    exec_pin_memory(ctx, { memory_id: 'a/b/c', pinned: true }),
    exec_delete_memory(ctx, { memory_id: '..', confirm: true }),
    exec_edit_memory(ctx, { memory_id: '__reserved__', fact: 'hi' }),
    exec_read_journal_entry(ctx, { id: 'a/b/c' }),
    exec_edit_journal_entry(ctx, { id: '../secret', new_title: 'x' }),
    exec_delete_journal_entry(ctx, { id: '__bad__', confirm: true }),
    exec_complete_habit(ctx, { habit_id: 'a/b/c' }),
    exec_cancel_reminder(ctx, { id: '..' }),
    exec_update_calendar_event(ctx, { id: 'a/b', new_title: 'x' }),
    exec_delete_calendar_event(ctx, { id: '__x__', confirm: true }),
    exec_complete_bucket_item(ctx, { id: 'a/b/c' }),
    exec_delete_bucket_item(ctx, { id: '..', confirm: true }),
    exec_add_trip_pin(ctx, { title: 'Cafe', trip_id: 'a/b/c' }),
    exec_edit_trip(ctx, { id: 'a/b/c', new_title: 'x' }),
  ];
  const results = await Promise.all(calls);
  for (const raw of results) {
    const parsed = JSON.parse(raw);
    assert.ok(parsed.error, `expected error for unsafe doc id, got ${raw}`);
  }
  assert.equal(docCalled, false);
});

test('proxyLastfmImage still returns 415 when upstream body cancel rejects', async (t) => {
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: true,
    status: 200,
    headers: new Headers({ 'content-type': 'text/html' }),
    body: {
      cancel: async () => {
        throw new Error('stream already closed');
      },
    },
  }));
  const res = {
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  };
  await proxyLastfmImage(
    {
      method: 'GET',
      headers: {},
      get: () => '',
      ip: '203.0.113.43',
      query: { url: 'https://lastfm.freetls.fastly.net/i/u/300x300/demo.jpg' },
    },
    res,
  );
  assert.equal(res.code, 415);
});

test('resolveCatalogUpstream and resolveMangaApiUrl reject encoded traversal, fragments, and bad encoding', () => {
  for (const bad of [
    'anime/%2e%2e/secret',
    'anime/%2E%2E/secret',
    'anime%2f..%2fsecret',
    'anime/1#fragment',
    'anime/%ZZ/bad',
    'anime//double',
    'anime/./same',
  ]) {
    assert.throws(() => resolveCatalogUpstream('jikan', bad), /Invalid path/);
    assert.throws(() => resolveMangaApiUrl('https://api.mangadex.org', bad), /Invalid path/);
  }
  assert.equal(
    resolveCatalogUpstream('jikan', 'anime/123/').toString(),
    'https://api.jikan.moe/v4/anime/123/',
  );
  assert.equal(
    resolveMangaApiUrl('https://api.mangadex.org', 'manga/abc/'),
    'https://api.mangadex.org/manga/abc/',
  );
});

test('parseStudySet returns structured error for null and primitive JSON payloads', () => {
  assert.deepEqual(parseStudySet('null'), { error: 'not-an-array' });
  assert.deepEqual(parseStudySet('42'), { error: 'not-an-array' });
  assert.deepEqual(parseStudySet('"hello"'), { error: 'not-an-array' });
});

test('proxyAnime sets private cache and vary headers on early error responses', async () => {
  const res = {
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  };
  await proxyAnime({ method: 'POST', headers: {}, get: () => '', query: {} }, res);
  assert.equal(res.code, 405);
  assert.equal(res.headers['Cache-Control'], 'private, no-store');
  assert.equal(res.headers.Vary, 'Origin, Authorization');
});

test('motchi_exec_tools bounds _idempotencyCache to IDEMPOTENCY_MAX_ENTRIES', async () => {
  const {
    executeToolCall,
    clearIdempotencyCache,
    _idempotencyCache,
    IDEMPOTENCY_MAX_ENTRIES,
  } = require('./motchi_exec_tools.js');
  clearIdempotencyCache();
  try {
    const now = Date.now();
    for (let i = 0; i < IDEMPOTENCY_MAX_ENTRIES + 25; i++) {
      _idempotencyCache.set(`seed::${i}`, { result: '{"success":true}', ts: now });
    }
    const ctx = makeCtx({
      sessionId: 'sess-bound',
      admin: { firestore: { Timestamp: { now: () => ({ toDate: () => new Date() }) } } },
      db: {
        collection: () => ({
          add: async () => ({ id: 'doc-1' }),
          where: () => ({ limit: () => ({ get: async () => ({ empty: true, docs: [] }) }) }),
        }),
      },
    });
    const out = JSON.parse(await executeToolCall(ctx, 'add_bucket_item', { title: 'Watch aurora' }));
    assert.equal(out.success, true);
    assert.ok(
      _idempotencyCache.size <= IDEMPOTENCY_MAX_ENTRIES,
      `expected cache size <= ${IDEMPOTENCY_MAX_ENTRIES}, got ${_idempotencyCache.size}`,
    );
  } finally {
    clearIdempotencyCache();
  }
});
