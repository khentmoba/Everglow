'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  exec_add_to_watchlist,
  exec_search_movies,
  exec_get_watchlist,
  exec_mark_watchlist_item_watched,
  exec_remove_from_watchlist,
  exec_search_books,
  exec_update_book_progress,
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
const { loginAccount, manageAccounts, communityWatchPartyAccess } = require('./accounts.js');
const { sendFCMToUser } = require('./triggers.js');
const { recordMotchiTurn } = require('./motchi_sessions.js');
const { proxyLastfmImage } = require('./media_proxy_music.js');
const common = require('./common.js');
const { proxyScanlation, proxyFetchHtml } = require('./media_proxy_html.js');
const { spotifyExchange } = require('./spotify.js');
const { proxyComick, proxyMangaDex, resolveMangaApiUrl } = require('./media_proxy_manga.js');
const { resolveCatalogUpstream } = require('./media_proxy_catalog.js');
const { parseStudySet } = require('./motchi_study.js');
const { proxyAnime } = require('./anime.js');
const { proxyAnimeImage } = require('./media_proxy_anime.js');
const { proxyMangaImage } = require('./media_proxy_manga.js');
const { handleProxyAI } = require('./motchi_chat.js');
const { exec_web_search, exec_read_web_page, exec_browse_web } = require('./motchi_exec_insights.js');
const { deleteGalleryDocs } = require('./media_proxy_gallery.js');
const { loadMemoryFacts, serverExtractAndSaveMemory, invalidateMemoryCache } = require('./motchi_memory.js');
const { motchiStats } = require('./motchi_stats.js');
const { handleGenerateStudySet } = require('./motchi_study.js');
const { proxyBookText, proxyBookFile } = require('./media_proxy_books.js');
const { notifyDiscordWatch } = require('./discord_functions.js');
const { proxyWatchStream } = require('./media_proxy_video.js');
const { proxyTmdb } = require('./catalog.js');
const { proxyCatalog } = require('./media_proxy_catalog.js');
const { isAllowedTmdbPath } = require('./media_proxy_core.js');
const { proxyMegavidHls } = require('./anime.js');
const { exec_get_gallery } = require('./motchi_exec_social.js');
const { getMoodContext, getWatchContext, getRecentChatContext } = require('./motchi_context.js');
const { onNewChatMessage } = require('./triggers.js');
const crypto = require('node:crypto');

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
  const docRef = (id) => {
    docIds.push(id);
    return {
      get: async () => ({ exists: false }),
      set: async () => {},
    };
  };
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
      doc: (id) => docRef(id),
    }),
    runTransaction: (fn) =>
      fn({
        get: (ref) => ref.get(),
        set: (ref, data) => ref.set(data),
        update: (ref, data) => ref.update(data),
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

test('proxyScanlation allows ComicK cover hosts and sanitizes upstream fetch errors', async (t) => {
  let fetchedUrl = '';
  t.mock.method(common, 'fetchPublicUrl', async (url) => {
    fetchedUrl = url;
    throw new Error('ECONNREFUSED 10.0.0.5:443 internal-detail');
  });
  const res = {
    code: 200,
    headers: {},
    headersSent: false,
    destroyed: false,
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  };
  await proxyScanlation(
    {
      method: 'GET',
      headers: {},
      get: () => '',
      ip: '203.0.113.55',
      query: { url: 'https://meo.comick.pictures/cover-123.jpg' },
    },
    res,
  );
  assert.equal(fetchedUrl, 'https://meo.comick.pictures/cover-123.jpg');
  assert.equal(res.code, 502);
  assert.equal(res.body.error, 'Upstream fetch failed');
  assert.ok(!String(res.body.error).includes('10.0.0.5'));
});

test('spotifyExchange sanitizes upstream error bodies and rejects missing access_token', async (t) => {
  const prevClientId = process.env.SPOTIFY_CLIENT_ID;
  process.env.SPOTIFY_CLIENT_ID = 'test-client-id';
  const origFetch = globalThis.fetch;
  const authInstance = common.getAdmin().auth();
  t.mock.method(authInstance, 'verifyIdToken', async () => ({
    uid: 'khent-uid',
    username: 'khentsgdz',
    firebase: { sign_in_provider: 'custom' },
  }));
  const makeRes = () => ({
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  });
  try {
    globalThis.fetch = async () => ({
      ok: false,
      status: 400,
      text: async () => '{"error":"invalid_grant","error_description":"sensitive-upstream-detail"}',
    });
    const res1 = makeRes();
    await spotifyExchange(
      {
        method: 'POST',
        headers: { authorization: 'Bearer tok' },
        get: () => 'Bearer tok',
        ip: '203.0.113.56',
        body: {
          code: 'abc',
          redirectUri: 'https://everglow-1c6db.web.app/spotify/callback',
          codeVerifier: 'verifier-123',
        },
      },
      res1,
    );
    assert.equal(res1.code, 400);
    assert.equal(res1.body.error, 'Spotify token exchange failed');
    assert.ok(!String(res1.body.error).includes('sensitive-upstream-detail'));

    globalThis.fetch = async () => ({
      ok: true,
      status: 200,
      text: async () => '{"expires_in":3600}',
    });
    const res2 = makeRes();
    await spotifyExchange(
      {
        method: 'POST',
        headers: { authorization: 'Bearer tok' },
        get: () => 'Bearer tok',
        ip: '203.0.113.57',
        body: {
          code: 'abc',
          redirectUri: 'https://everglow-1c6db.web.app/spotify/callback',
          codeVerifier: 'verifier-123',
        },
      },
      res2,
    );
    assert.equal(res2.code, 502);
    assert.equal(res2.body.error, 'Invalid Spotify token response');
  } finally {
    globalThis.fetch = origFetch;
    if (prevClientId === undefined) delete process.env.SPOTIFY_CLIENT_ID;
    else process.env.SPOTIFY_CLIENT_ID = prevClientId;
  }
});

test('exec_add_trip_pin ignores null, empty, and out-of-range coordinates instead of writing 0', async () => {
  let savedPlaces = null;
  const ctx = makeCtx({
    db: {
      collection: () => ({
        doc: () => ({ id: 'trip-1' }),
      }),
      runTransaction: async (fn) =>
        fn({
          get: async () => ({ exists: true, data: () => ({ places: [] }) }),
          update: (_ref, data) => { savedPlaces = data.places; },
        }),
    },
  });
  const out = JSON.parse(await exec_add_trip_pin(ctx, { trip_id: 'trip-1', title: 'Cafe', lat: null, lng: '' }));
  assert.equal(out.success, true);
  assert.equal(savedPlaces.length, 1);
  assert.equal('lat' in savedPlaces[0], false);
  assert.equal('lng' in savedPlaces[0], false);

  const out2 = JSON.parse(await exec_add_trip_pin(ctx, { trip_id: 'trip-1', title: 'Far', lat: 95, lng: -200 }));
  assert.equal(out2.success, true);
  assert.equal('lat' in savedPlaces[0], false);
  assert.equal('lng' in savedPlaces[0], false);
});

test('watchlist mutation tools bound our_cinema scans with .limit()', async () => {
  const limits = [];
  const makeDb = () => ({
    collection: () => ({
      limit(n) {
        limits.push(n);
        return { get: async () => ({ docs: [] }) };
      },
      get: async () => {
        throw new Error('unbounded collection scan');
      },
    }),
  });
  await exec_mark_watchlist_item_watched(makeCtx({ db: makeDb() }), { title: 'Spirited Away' });
  await exec_remove_from_watchlist(makeCtx({ db: makeDb() }), { title: 'Spirited Away' });
  assert.deepEqual(limits, [200, 200]);
});

test('proxyMegavidHls resolves relative playlist entries against redirected upstream.url', async (t) => {
  const authInstance = common.getAdmin().auth();
  t.mock.method(authInstance, 'verifyIdToken', async () => ({
    uid: 'khent-uid',
    username: 'khentsgdz',
    firebase: { sign_in_provider: 'custom' },
  }));
  t.mock.method(common, 'isPublicDnsHost', async () => true);
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: true,
    status: 200,
    url: 'https://cdn.megavid.buzz/edge-2/nested/master.m3u8',
    headers: new Headers({ 'content-type': 'application/vnd.apple.mpegurl' }),
    body: new ReadableStream({
      start(c) {
        c.enqueue(new TextEncoder().encode('#EXTM3U\n#EXTINF:6,\nseg01.ts\n'));
        c.close();
      },
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
  await proxyMegavidHls(
    {
      method: 'GET',
      protocol: 'https',
      headers: { authorization: 'Bearer tok', host: 'us-central1-everglow-1c6db.cloudfunctions.net' },
      get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer tok' : h.toLowerCase() === 'host' ? 'us-central1-everglow-1c6db.cloudfunctions.net' : ''),
      ip: '203.0.113.59',
      query: { u: 'https://megavid.buzz/start.m3u8' },
    },
    res,
  );
  assert.equal(res.code, 200);
  assert.ok(String(res.body).includes(encodeURIComponent('https://cdn.megavid.buzz/edge-2/nested/seg01.ts')));
});

test('motchiStats returns generic 500 error without leaking internal error details', async (t) => {
  const admin = common.getAdmin();
  t.mock.method(admin.auth(), 'verifyIdToken', async () => ({
    uid: 'khent-uid',
    username: 'khentsgdz',
    firebase: { sign_in_provider: 'custom' },
  }));
  t.mock.method(admin, 'firestore', () => {
    throw new Error('secret-internal-firestore-details');
  });
  const res = {
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  };
  await motchiStats(
    {
      method: 'GET',
      headers: { authorization: 'Bearer tok' },
      get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer tok' : ''),
      ip: '203.0.113.60',
      query: {},
    },
    res,
  );
  assert.equal(res.code, 500);
  assert.equal(res.body.error, 'Could not load stats');
  assert.ok(!String(res.body.error).includes('secret-internal-firestore-details'));
});

test('Motchi title-lookup tools never match untitled documents and bound our_books reads', async () => {
  const untitledDoc = {
    id: 'untitled-1',
    data: () => ({ title: '' }),
    ref: {
      update: async () => { throw new Error('must not update untitled doc'); },
      delete: async () => { throw new Error('must not delete untitled doc'); },
    },
  };
  let ourBooksLimit = null;
  const ctx = makeCtx({
    db: {
      batch: () => ({
        update: () => { throw new Error('must not batch-update untitled doc'); },
        delete: () => { throw new Error('must not batch-delete untitled doc'); },
        commit: async () => {},
      }),
      collection: (name) => ({
        where: () => ({
          limit: () => ({ get: async () => ({ docs: [untitledDoc] }) }),
        }),
        limit: (n) => {
          if (name === 'our_books') ourBooksLimit = n;
          return { get: async () => ({ docs: [untitledDoc] }) };
        },
        get: async () => {
          if (name === 'our_books') throw new Error('our_books query must be bounded with limit()');
          return { docs: [untitledDoc] };
        },
      }),
    },
  });

  const bookRes = JSON.parse(await exec_update_book_progress(ctx, { title: 'Dune', progress: 50 }));
  assert.match(bookRes.error, /No book found/);
  assert.equal(ourBooksLimit, 200);

  const watchRes = JSON.parse(await exec_mark_watchlist_item_watched(ctx, { title: 'Dune' }));
  assert.match(watchRes.error, /No watchlist item found/);

  const removeRes = JSON.parse(await exec_remove_from_watchlist(ctx, { title: 'Dune', confirm: true }));
  assert.match(removeRes.error, /No watchlist item found/);

  const editJournalRes = JSON.parse(await exec_edit_journal_entry(ctx, { title: 'Dune', content: 'hi' }));
  assert.match(editJournalRes.error, /No journal entry found/);

  const delJournalRes = JSON.parse(await exec_delete_journal_entry(ctx, { title: 'Dune', confirm: true }));
  assert.match(delJournalRes.error, /No journal entry found/);

  const remRes = JSON.parse(await exec_cancel_reminder(ctx, { title: 'Dune', confirm: true }));
  assert.match(remRes.error, /No pending reminder found/);

  const updCalRes = JSON.parse(await exec_update_calendar_event(ctx, { title: 'Dune', description: 'x' }));
  assert.match(updCalRes.error, /No calendar event found/);

  const delCalRes = JSON.parse(await exec_delete_calendar_event(ctx, { title: 'Dune', confirm: true }));
  assert.match(delCalRes.error, /No calendar event found/);

  const compBucketRes = JSON.parse(await exec_complete_bucket_item(ctx, { title: 'Dune' }));
  assert.match(compBucketRes.error, /No bucket item found/);

  const delBucketRes = JSON.parse(await exec_delete_bucket_item(ctx, { title: 'Dune', confirm: true }));
  assert.match(delBucketRes.error, /No bucket item found/);
});

test('exec_search_movies, exec_search_books, and exec_get_weather reject empty input without calling fetch', async (t) => {
  let fetchCalls = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    fetchCalls += 1;
    throw new Error('fetch should not be called');
  });
  const ctx = makeCtx();

  const movieRes = JSON.parse(await exec_search_movies(ctx, { query: '   ' }));
  assert.deepEqual(movieRes, { results: [] });

  const bookRes = JSON.parse(await exec_search_books(ctx, {}));
  assert.deepEqual(bookRes, { results: [] });

  const weatherRes = JSON.parse(await exec_get_weather(ctx, { location: '' }));
  assert.match(weatherRes.error, /No location provided/);

  assert.equal(fetchCalls, 0);
});

test('sendFCMToUser bounds device collection reads with limit(50)', async (t) => {
  let devicesLimit = null;
  const admin = common.getAdmin();
  t.mock.method(admin, 'firestore', () => ({
    collection: () => ({
      doc: () => ({
        collection: (sub) => ({
          limit: (n) => {
            if (sub === 'devices') devicesLimit = n;
            return { get: async () => ({ docs: [] }) };
          },
          get: async () => {
            throw new Error('devices query must use limit()');
          },
        }),
      }),
    }),
  }));
  const ok = await sendFCMToUser('clairjassen', { title: 'Hi', body: 'Test' });
  assert.equal(ok, true);
  assert.equal(devicesLimit, 50);
});

test('communityWatchPartyAccess unlockRoom rejects ended rooms with 410', async (t) => {
  const admin = common.getAdmin();
  t.mock.method(admin.auth(), 'verifyIdToken', async () => ({
    uid: 'guest-uid',
    username: 'breyan',
    firebase: { sign_in_provider: 'custom' },
  }));
  t.mock.method(admin, 'firestore', () => ({
    collection: () => ({
      doc: () => ({
        get: async () => ({ exists: true, data: () => ({ active: false, hasPassword: true, hostUid: 'other' }) }),
      }),
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
  await communityWatchPartyAccess(
    {
      method: 'POST',
      headers: { authorization: 'Bearer tok' },
      get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer tok' : ''),
      ip: '203.0.113.61',
      body: { action: 'unlockRoom', roomId: 'room123', password: 'secret' },
    },
    res,
  );
  assert.equal(res.code, 410);
  assert.match(res.body.error, /ended/i);
});

test('proxyBookFile sets nosniff and sandbox CSP on binary EPUB responses', async (t) => {
  const admin = common.getAdmin();
  t.mock.method(admin.auth(), 'verifyIdToken', async () => ({
    uid: 'clair-uid',
    username: 'clairjassen',
    firebase: { sign_in_provider: 'custom' },
  }));
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: true,
    status: 200,
    headers: new Headers({ 'content-type': 'application/epub+zip', 'content-length': '4' }),
    body: new ReadableStream({
      start(c) {
        c.enqueue(new Uint8Array([0x50, 0x4b, 0x03, 0x04]));
        c.close();
      },
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
  await proxyBookFile(
    {
      method: 'POST',
      headers: { authorization: 'Bearer tok', accept: 'application/epub+zip' },
      get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer tok' : h.toLowerCase() === 'accept' ? 'application/epub+zip' : ''),
      ip: '203.0.113.62',
      body: { urls: ['https://www.gutenberg.org/ebooks/84.epub.images'] },
    },
    res,
  );
  assert.equal(res.code, 200);
  assert.equal(res.headers['X-Content-Type-Options'], 'nosniff');
  assert.equal(res.headers['Content-Security-Policy'], "default-src 'none'; sandbox");
});

test('manageAccounts enforces per-uid rate limiting', async (t) => {
  const admin = common.getAdmin();
  t.mock.method(admin.auth(), 'verifyIdToken', async () => ({
    uid: 'khent-rate-uid',
    username: 'khentsgdz',
    firebase: { sign_in_provider: 'custom' },
  }));
  t.mock.method(admin, 'firestore', () => ({
    collection: () => ({
      orderBy: () => ({
        limit: () => ({
          get: async () => ({ docs: [] }),
        }),
      }),
    }),
  }));
  let lastCode = 200;
  for (let i = 0; i < 61; i++) {
    const res = {
      code: 200,
      headers: {},
      set(k, v) { this.headers[k] = v; return this; },
      status(n) { this.code = n; return this; },
      send(b) { this.body = b; return this; },
      json(b) { this.body = b; return this; },
    };
    await manageAccounts(
      {
        method: 'GET',
        headers: { authorization: 'Bearer tok' },
        get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer tok' : ''),
        ip: '203.0.113.63',
      },
      res,
    );
    lastCode = res.code;
  }
  assert.equal(lastCode, 429);
});

test('recordMotchiTurn records turns inside a Firestore transaction', async () => {
  let txUsed = false;
  let stored = null;
  const fakeDocRef = { id: 'sess_tx_test' };
  const fakeDb = {
    collection: () => ({ doc: () => fakeDocRef }),
    runTransaction: async (fn) => {
      txUsed = true;
      await fn({
        get: async () => ({
          exists: true,
          data: () => ({
            id: 'sess_tx_test',
            caller: 'khentsgdz',
            turnCount: 2,
            turns: [{ userMessage: 'hi', assistantReply: 'hello' }],
            toolsUsedTotal: 1,
          }),
        }),
        set: () => { throw new Error('unexpected set'); },
        update: (_ref, data) => { stored = data; },
      });
    },
  };
  const origGetDb = common.getDb;
  const origGetAdmin = common.getAdmin;
  common.getDb = () => fakeDb;
  common.getAdmin = () => ({ firestore: { FieldValue: { serverTimestamp: () => 'TS' } } });
  try {
    const id = await recordMotchiTurn({
      sessionId: 'sess_tx_test',
      caller: 'khentsgdz',
      userMessage: 'follow up',
      assistantReply: 'got it',
      tools: [{ name: 't1' }],
    });
    assert.equal(id, 'sess_tx_test');
    assert.equal(txUsed, true);
    assert.equal(stored.turnCount, 3);
    assert.equal(stored.turns.length, 2);
    assert.equal(stored.toolsUsedTotal, 2);
  } finally {
    common.getDb = origGetDb;
    common.getAdmin = origGetAdmin;
  }
});

test('deleteGalleryDocs removes both full image and thumbnail from Storage', async () => {
  const deletedFiles = [];
  let docsDeleted = 0;
  const docs = [
    {
      data: () => ({
        imageUrl: 'https://firebasestorage.googleapis.com/v0/b/everglow-1c6db.firebasestorage.app/o/gallery%2Fu1%2Fphoto_full.jpg?alt=media&token=abc',
        thumbUrl: 'https://firebasestorage.googleapis.com/v0/b/everglow-1c6db.firebasestorage.app/o/gallery%2Fu1%2Fphoto_thumb.jpg?alt=media&token=def',
      }),
      ref: { delete: async () => { docsDeleted++; } },
    },
  ];
  const res = await deleteGalleryDocs(docs, async (path) => { deletedFiles.push(path); }, 2);
  assert.deepEqual(res, { deleted: 1, failed: 0 });
  assert.equal(docsDeleted, 1);
  assert.deepEqual(deletedFiles.sort(), [
    'gallery/u1/photo_full.jpg',
    'gallery/u1/photo_thumb.jpg',
  ]);
});

test('read_web_page truncates an oversized page instead of failing it', async (t) => {
  const origKey = process.env.TINYFISH_API_KEY;
  process.env.TINYFISH_API_KEY = 'test-key';
  const bigText = 'Title: Big page\nMarkdown Content:\n' + 'a'.repeat(1_500_000);
  t.mock.method(globalThis, 'fetch', async () => {
    let sent = false;
    const body = new ReadableStream({
      pull(controller) {
        if (sent) {
          controller.close();
          return;
        }
        sent = true;
        controller.enqueue(new TextEncoder().encode(bigText));
      },
    });
    return { ok: true, status: 200, body };
  });
  try {
    const out = JSON.parse(await exec_read_web_page(makeCtx(), { urls: ['https://example.com/long'] }));
    assert.equal(out.pages.length, 1, JSON.stringify(out.errors));
    assert.equal(out.pages[0].title, 'Big page');
    assert.equal(out.pages[0].content.length, 4000);
    assert.deepEqual(out.errors, []);
  } finally {
    if (origKey === undefined) delete process.env.TINYFISH_API_KEY;
    else process.env.TINYFISH_API_KEY = origKey;
  }
});

test('exec_read_web_page and exec_browse_web reject private/localhost/credentialed URLs', async (t) => {
  const origKey = process.env.TINYFISH_API_KEY;
  process.env.TINYFISH_API_KEY = 'test-key';
  const fetchMock = t.mock.method(globalThis, 'fetch', async () => {
    assert.fail('must not fetch blocked internal URLs');
  });
  const ctx = makeCtx();
  try {
    const readOut = JSON.parse(await exec_read_web_page(ctx, {
      urls: [
        'http://127.0.0.1/admin',
        'http://169.254.169.254/latest/meta-data/',
        'https://user:pass@example.com/secret',
        'http://localhost:8080/internal',
      ],
    }));
    assert.match(readOut.error, /No valid public/);

    const browseOut = JSON.parse(await exec_browse_web(ctx, {
      url: 'http://169.254.169.254/latest/meta-data/',
      goal: 'read metadata',
    }));
    assert.match(browseOut.error, /No valid public/);
    assert.equal(fetchMock.mock.callCount(), 0);
  } finally {
    if (origKey === undefined) delete process.env.TINYFISH_API_KEY;
    else process.env.TINYFISH_API_KEY = origKey;
  }
});

test('exec_browse_web stops polling immediately when ctx.signal aborts and drains error bodies', async (t) => {
  const origKey = process.env.TINYFISH_API_KEY;
  process.env.TINYFISH_API_KEY = 'test-key';
  let cancelled = false;
  const ctrl = new AbortController();
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    calls++;
    if (calls === 1) {
      return { ok: false, status: 500, body: { cancel: async () => { cancelled = true; } } };
    }
    assert.fail('should not poll after abort');
  });
  try {
    const errOut = JSON.parse(await exec_browse_web(makeCtx(), {
      url: 'https://example.com',
      goal: 'check title',
    }));
    assert.match(errOut.error, /HTTP 500/);
    assert.equal(cancelled, true);

    ctrl.abort();
    const abortedOut = JSON.parse(await exec_browse_web(makeCtx({ signal: ctrl.signal }), {
      run_id: 'run_123',
      url: 'https://example.com',
      goal: 'check title',
    }));
    assert.equal(abortedOut.status, 'RUNNING');
    assert.equal(calls, 1);
  } finally {
    if (origKey === undefined) delete process.env.TINYFISH_API_KEY;
    else process.env.TINYFISH_API_KEY = origKey;
  }
});

test('serverExtractAndSaveMemory does not mutate shared facts cache when Firestore write fails', async (t) => {
  const origKey = process.env.AGNES_API_KEY;
  process.env.AGNES_API_KEY = 'test-key';
  invalidateMemoryCache();
  const fakeDb = {
    collection: () => ({
      doc: () => ({
        collection: () => ({
          orderBy: () => ({
            limit: () => ({
              get: async () => ({
                docs: [{ id: 'f1', data: () => ({ fact: 'Khent loves coffee' }) }],
              }),
            }),
          }),
          where: () => ({
            limit: () => ({
              get: async () => ({ docs: [] }),
            }),
          }),
          add: async () => { throw new Error('firestore unavailable'); },
          doc: () => ({ update: async () => { throw new Error('firestore unavailable'); } }),
        }),
      }),
    }),
  };
  const admin = common.getAdmin();
  t.mock.method(admin, 'firestore', () => fakeDb);
  t.mock.method(globalThis, 'fetch', async () => ({
    ok: true,
    json: async () => ({
      choices: [{
        message: {
          content: JSON.stringify([{
            fact: 'Khent loves matcha lattes on rainy days',
            category: 'preference',
            quote: 'I really love matcha lattes on rainy days',
          }]),
        },
      }],
    }),
  }));
  try {
    const before = await loadMemoryFacts(fakeDb);
    assert.equal(before.length, 1);
    await serverExtractAndSaveMemory(
      'I really love matcha lattes on rainy days so much!',
      'Noted, Dada!',
      'khentsgdz_cache_test',
    );
    const after = await loadMemoryFacts(fakeDb);
    assert.equal(after.length, 1);
    assert.equal(after[0].fact, 'Khent loves coffee');
  } finally {
    invalidateMemoryCache();
    if (origKey === undefined) delete process.env.AGNES_API_KEY;
    else process.env.AGNES_API_KEY = origKey;
  }
});

test('exec_get_gallery orders by uploadedAt desc and uses uploadedAt for createdAt', async () => {
  const orderCalls = [];
  const uploadedDate = new Date('2026-06-01T12:00:00Z');
  const ctx = makeCtx({
    db: {
      collection: (name) => {
        assert.equal(name, 'gallery');
        return {
          orderBy: (field, dir) => {
            orderCalls.push([field, dir]);
            return {
              limit: () => ({
                get: async () => ({
                  empty: false,
                  docs: [
                    {
                      data: () => ({
                        caption: 'Beach sunset',
                        uploadedBy: 'clairjassen',
                        imageUrl: 'https://example.com/photo.jpg',
                        uploadedAt: { toDate: () => uploadedDate },
                      }),
                    },
                  ],
                }),
              }),
            };
          },
        };
      },
    },
  });
  const out = JSON.parse(await exec_get_gallery(ctx, { limit: 5 }));
  assert.deepEqual(orderCalls, [['uploadedAt', 'desc']]);
  assert.equal(out.count, 1);
  assert.equal(out.photos[0].createdAt, uploadedDate.toISOString());
});

test('getMoodContext queries moods by timestamp desc in parallel and getRecentChatContext reads sender', async (t) => {
  const moodOrderFields = [];
  const admin = common.getAdmin();
  t.mock.method(admin, 'firestore', () => ({
    collection: (name) => {
      if (name === 'moods') {
        return {
          where: (_field, _op, user) => ({
            orderBy: (field, dir) => {
              moodOrderFields.push([user, field, dir]);
              return {
                limit: () => ({
                  get: async () => ({
                    empty: false,
                    docs: [{ data: () => ({ moodEmoji: '😊', mood: 'happy' }) }],
                  }),
                }),
              };
            },
          }),
        };
      }
      if (name === 'sanctuary_messages') {
        return {
          orderBy: () => ({
            limit: () => ({
              get: async () => ({
                empty: false,
                docs: [
                  { data: () => ({ sender: 'clairjassen', text: 'Good morning!' }) },
                  { data: () => ({ sender: 'khentsgdz', text: 'Morning love' }) },
                ],
              }),
            }),
          }),
        };
      }
      if (name === 'our_cinema') {
        return {
          where: (field, _op, user) => {
            assert.equal(field, 'addedBy');
            return {
              orderBy: (orderField, dir) => {
                assert.equal(orderField, 'addedAt');
                assert.equal(dir, 'desc');
                return {
                  limit: () => ({
                    get: async () => ({
                      empty: false,
                      docs: [{ data: () => ({ title: `Pick for ${user}`, mediaType: 'movie', status: 'plan_to_watch' }) }],
                    }),
                  }),
                };
              },
            };
          },
        };
      }
      throw new Error(`unexpected collection ${name}`);
    },
  }));

  const moodsText = await getMoodContext();
  assert.deepEqual(moodOrderFields, [
    ['khentsgdz', 'timestamp', 'desc'],
    ['clairjassen', 'timestamp', 'desc'],
  ]);
  assert.match(moodsText, /khentsgdz: 😊 happy/);
  assert.match(moodsText, /clairjassen: 😊 happy/);

  const chatText = await getRecentChatContext();
  assert.match(chatText, /clairjassen: Good morning!/);
  assert.match(chatText, /khentsgdz: Morning love/);

  const watchText = await getWatchContext();
  assert.match(watchText, /Pick for khentsgdz/);
  assert.match(watchText, /Pick for clairjassen/);
});

test('exec_get_watchlist queries our_cinema by addedBy/addedAt backed by firestore.indexes.json', async () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const indexes = JSON.parse(
    fs.readFileSync(path.join(__dirname, '..', 'firestore.indexes.json'), 'utf8'),
  ).indexes;
  assert.ok(
    indexes.some(
      (idx) =>
        idx.collectionGroup === 'our_cinema' &&
        idx.fields?.length === 2 &&
        idx.fields[0].fieldPath === 'addedBy' &&
        idx.fields[0].order === 'ASCENDING' &&
        idx.fields[1].fieldPath === 'addedAt' &&
        idx.fields[1].order === 'DESCENDING',
    ),
    'firestore.indexes.json must declare our_cinema (addedBy ASC, addedAt DESC)',
  );

  const queries = [];
  const ctx = makeCtx({
    db: {
      collection: (name) => {
        assert.equal(name, 'our_cinema');
        return {
          where: (field, op, value) => ({
            orderBy: (orderField, dir) => {
              queries.push([field, op, value, orderField, dir]);
              return {
                limit: () => ({
                  get: async () => ({
                    docs: [{ data: () => ({ title: `Saved by ${value}`, mediaType: 'movie', status: 'plan_to_watch' }) }],
                  }),
                }),
              };
            },
          }),
        };
      },
    },
  });
  const out = JSON.parse(await exec_get_watchlist(ctx, { limit: 10 }));
  assert.deepEqual(queries, [
    ['addedBy', '==', 'khentsgdz', 'addedAt', 'desc'],
    ['addedBy', '==', 'clairjassen', 'addedAt', 'desc'],
  ]);
  assert.match(out.watchlist, /Saved by khentsgdz/);
  assert.match(out.watchlist, /Saved by clairjassen/);
});

test('loginAccount runs dummy scrypt verification when account does not exist', async (t) => {
  let timingEqualCalls = 0;
  const origTimingSafeEqual = crypto.timingSafeEqual;
  t.mock.method(crypto, 'timingSafeEqual', (...args) => {
    timingEqualCalls += 1;
    return origTimingSafeEqual(...args);
  });
  const admin = common.getAdmin();
  t.mock.method(admin, 'firestore', () => ({
    collection: () => ({
      doc: () => ({
        get: async () => ({ exists: false }),
      }),
    }),
    runTransaction: async (fn) => fn({
      get: async () => ({ exists: false }),
      set: () => {},
      delete: () => {},
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
  await loginAccount(
    {
      method: 'POST',
      headers: {},
      get: () => '',
      ip: '203.0.113.71',
      body: { username: 'nonexistentuser99', password: 'wrongpassword' },
    },
    res,
  );
  assert.equal(res.code, 401);
  assert.equal(timingEqualCalls, 1);
});

test('onNewChatMessage skips duplicate push notification when via is motchi', async (t) => {
  let firestoreCalled = false;
  const admin = common.getAdmin();
  t.mock.method(admin, 'firestore', () => {
    firestoreCalled = true;
    throw new Error('should not query fcm_tokens for motchi-sent messages');
  });
  await onNewChatMessage.run({
    data: () => ({ sender: 'khentsgdz', text: 'hello from motchi', via: 'motchi' }),
  });
  assert.equal(firestoreCalled, false);
});

test('proxyAnimeImage rate-limits before verifyIdToken and rejects non-standard ports', async (t) => {
  const mkRes = () => ({
    code: 200,
    headers: {},
    body: null,
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  });
  const portRes = mkRes();
  await proxyAnimeImage(
    {
      method: 'GET',
      headers: {},
      get: () => '',
      ip: '198.51.100.41',
      query: { url: 'https://static.crunchyroll.com:8443/poster.jpg' },
    },
    portRes,
  );
  assert.equal(portRes.code, 400);

  let verifyCalls = 0;
  const admin = common.getAdmin();
  t.mock.method(admin, 'auth', () => ({
    verifyIdToken: async () => {
      verifyCalls += 1;
      throw new Error('bad token');
    },
  }));
  let hit429 = false;
  for (let i = 0; i < 245; i++) {
    const res = mkRes();
    await proxyAnimeImage(
      {
        method: 'GET',
        headers: { authorization: 'Bearer bogus-token' },
        get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer bogus-token' : ''),
        ip: '198.51.100.42',
        query: { url: 'https://static.crunchyroll.com/poster.jpg' },
      },
      res,
    );
    if (res.code === 429) {
      hit429 = true;
      break;
    }
  }
  assert.equal(hit429, true);
  assert.equal(verifyCalls, 240);
});

test('image and HTML proxies reject non-standard ports on allowed hosts', async () => {
  const mkRes = () => ({
    code: 200,
    headers: {},
    body: null,
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  });
  const res1 = mkRes();
  await proxyMangaImage(
    {
      method: 'GET',
      headers: {},
      get: () => '',
      ip: '198.51.100.43',
      query: { url: 'https://uploads.mangadex.org:8443/covers/a.jpg' },
    },
    res1,
  );
  assert.equal(res1.code, 400);

  const res2 = mkRes();
  await proxyScanlation(
    {
      method: 'GET',
      headers: {},
      get: () => '',
      ip: '198.51.100.44',
      query: { url: 'https://img.bato.to:8443/page.jpg' },
    },
    res2,
  );
  assert.equal(res2.code, 400);
});

test('communityWatchPartyAccess rate-limits per uid with Retry-After without tripping loginAccount IP bucket', async (t) => {
  const admin = common.getAdmin();
  t.mock.method(admin, 'auth', () => ({
    verifyIdToken: async () => ({
      uid: 'uid-room-rl-test',
      username: 'khentsgdz',
      firebase: { sign_in_provider: 'custom' },
    }),
  }));
  t.mock.method(admin, 'firestore', () => ({
    collection: () => ({
      doc: () => ({
        id: 'room1',
        get: async () => ({ exists: false }),
        collection: () => ({ doc: () => ({}) }),
      }),
    }),
    batch: () => ({ set: () => {}, commit: async () => {} }),
  }));
  const mkRes = () => ({
    code: 200,
    headers: {},
    body: null,
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    send(b) { this.body = b; return this; },
    json(b) { this.body = b; return this; },
  });
  let limitedRes = null;
  for (let i = 0; i < 17; i++) {
    const res = mkRes();
    await communityWatchPartyAccess(
      {
        method: 'POST',
        headers: { authorization: 'Bearer ok' },
        get: (h) => (h.toLowerCase() === 'authorization' ? 'Bearer ok' : ''),
        ip: '198.51.100.55',
        body: { action: 'unlockRoom', roomId: 'room1', password: '' },
      },
      res,
    );
    if (res.code === 429) {
      limitedRes = res;
      break;
    }
  }
  assert.ok(limitedRes, 'expected 429 after exceeding per-uid unlockRoom limit');
  assert.ok(Number(limitedRes.headers['Retry-After']) >= 1);
});
