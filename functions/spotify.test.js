'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { getAdmin } = require('./common');
const { getSpotifyAppToken, proxySpotifySearch, spotifyExchange, spotifyRefresh, spotifyCurrentlyPlaying, _mapSpotifyRecentItems } = require('./spotify');
const { createToolCtx } = require('./motchi_exec_tools');

test('concurrent getSpotifyAppToken calls coalesce into one token request', async (t) => {
  const previous = [process.env.SPOTIFY_CLIENT_ID, process.env.SPOTIFY_CLIENT_SECRET];
  process.env.SPOTIFY_CLIENT_ID = 'fake-public-id';
  process.env.SPOTIFY_CLIENT_SECRET = 'fake-server-secret';
  t.after(() => {
    for (const [i, key] of ['SPOTIFY_CLIENT_ID', 'SPOTIFY_CLIENT_SECRET'].entries()) {
      if (previous[i] === undefined) delete process.env[key];
      else process.env[key] = previous[i];
    }
  });
  let resolveFetch;
  const fetchMock = t.mock.method(globalThis, 'fetch', () => new Promise((resolve) => {
    resolveFetch = () => resolve(new Response(JSON.stringify({ access_token: 'coalesced-token', expires_in: 1 })));
  }));
  const p1 = getSpotifyAppToken();
  const p2 = getSpotifyAppToken();
  const p3 = getSpotifyAppToken();
  assert.equal(fetchMock.mock.callCount(), 1);
  resolveFetch();
  assert.deepEqual(await Promise.all([p1, p2, p3]), ['coalesced-token', 'coalesced-token', 'coalesced-token']);
});

test('Spotify private endpoints set Cache-Control: private, no-store', async () => {
  for (const [endpoint, method] of [
    [proxySpotifySearch, 'OPTIONS'],
    [spotifyExchange, 'OPTIONS'],
    [spotifyRefresh, 'OPTIONS'],
    [spotifyCurrentlyPlaying, 'OPTIONS'],
  ]) {
    const headers = {};
    const res = {
      set(k, v) { headers[k.toLowerCase()] = v; return this; },
      status(code) { this.code = code; return this; },
      send() {},
      json() {},
    };
    await endpoint({ method, headers: {}, get: () => '' }, res);
    assert.equal(res.code, 204);
    assert.equal(headers['cache-control'], 'private, no-store');
    assert.equal(headers.vary, 'Origin, Authorization');
  }
});

test('Motchi and Spotify share one token helper and cache', async (t) => {
  const previous = [process.env.SPOTIFY_CLIENT_ID, process.env.SPOTIFY_CLIENT_SECRET];
  process.env.SPOTIFY_CLIENT_ID = 'fake-public-id';
  process.env.SPOTIFY_CLIENT_SECRET = 'fake-server-secret';
  t.after(() => {
    for (const [i, key] of ['SPOTIFY_CLIENT_ID', 'SPOTIFY_CLIENT_SECRET'].entries()) {
      if (previous[i] === undefined) delete process.env[key];
      else process.env[key] = previous[i];
    }
  });
  t.mock.method(getAdmin(), 'firestore', () => ({}));
  const fetchMock = t.mock.method(globalThis, 'fetch', async (url) => {
    assert.equal(url, 'https://accounts.spotify.com/api/token');
    return new Response(JSON.stringify({ access_token: 'fake-token', expires_in: 3600 }));
  });
  const ctx = createToolCtx({ caller: 'clairjassen' });
  assert.equal(ctx.getSpotifyAppToken, getSpotifyAppToken);
  assert.equal(await getSpotifyAppToken(), 'fake-token');
  assert.equal(await ctx.getSpotifyAppToken(), 'fake-token');
  assert.equal(fetchMock.mock.callCount(), 1);
  delete process.env.SPOTIFY_CLIENT_SECRET;
  assert.equal(await getSpotifyAppToken(), null);
});

test('_mapSpotifyRecentItems maps played_at and track metadata', () => {
  const mapped = _mapSpotifyRecentItems([
    {
      played_at: '2026-11-18T07:00:00.000Z',
      track: {
        id: 'sp123',
        name: 'Preacher',
        artists: [{ name: 'Ethel Cain' }],
        album: { name: 'Preacher Daughter', images: [{ url: 'https://i.scdn.co/image/abc' }] },
        external_urls: { spotify: 'https://open.spotify.com/track/sp123' },
        duration_ms: 240000,
      },
    },
    { played_at: 'bad', track: null },
  ]);
  assert.equal(mapped.length, 1);
  assert.equal(mapped[0].trackId, 'sp123');
  assert.equal(mapped[0].trackName, 'Preacher');
  assert.equal(mapped[0].artistName, 'Ethel Cain');
  assert.equal(mapped[0].imageUrl, 'https://i.scdn.co/image/abc');
  assert.equal(mapped[0].isPlaying, false);
  assert.equal(mapped[0].timestamp, Date.parse('2026-11-18T07:00:00.000Z'));
});

test('_mapSpotifyRecentItems deduplicates repeated plays keeping newest timestamp and caps at maxUnique', () => {
  const mk = (id, name, artist, playedAt) => ({
    played_at: playedAt,
    track: {
      id,
      name,
      artists: [{ name: artist }],
      album: { name: 'Album', images: [{ url: `https://i.scdn.co/image/${id}` }] },
      external_urls: { spotify: `https://open.spotify.com/track/${id}` },
    },
  });
  const mapped = _mapSpotifyRecentItems([
    mk('1', 'Chasing Cars', 'Snow Patrol', '2026-11-24T14:20:00.000Z'),
    mk('2', 'Totoong tayo', 'Jin DC', '2026-11-24T14:15:00.000Z'),
    mk('1b', 'Chasing Cars', 'Snow Patrol', '2026-11-24T14:10:00.000Z'),
    mk('3', 'My Love Mine All Mine', 'Mitski', '2026-11-24T14:05:00.000Z'),
    mk('3b', 'My Love Mine All Mine', 'Mitski', '2026-11-24T14:00:00.000Z'),
    mk('4', 'Sparks', 'Coldplay', '2026-11-24T13:55:00.000Z'),
    mk('5', 'Pink + White', 'Frank Ocean', '2026-11-24T13:50:00.000Z'),
  ], 5);
  assert.deepEqual(
    mapped.map((t) => t.trackName),
    ['Chasing Cars', 'Totoong tayo', 'My Love Mine All Mine', 'Sparks', 'Pink + White'],
  );
  assert.equal(mapped[0].timestamp, Date.parse('2026-11-24T14:20:00.000Z'));
});

test('spotifyCurrentlyPlaying requests limit=50 for recently-played when includeRecent=1', async (t) => {
  const admin = getAdmin();
  t.mock.method(admin, 'auth', () => ({
    verifyIdToken: async () => ({ uid: 'uid-khent', username: 'khentsgdz', firebase: { sign_in_provider: 'custom' } }),
  }));
  t.mock.method(admin, 'firestore', () => ({
    collection: (name) => ({
      doc: () => ({
        get: async () => {
          if (name === 'spotify_tokens') {
            return { exists: true, data: () => ({ access_token: 'tok', expires_at: Date.now() + 600_000 }) };
          }
          return { exists: true, data: () => ({ username: 'khentsgdz' }) };
        },
      }),
    }),
  }));
  const urls = [];
  t.mock.method(globalThis, 'fetch', async (url) => {
    urls.push(String(url));
    if (String(url).includes('recently-played')) {
      return new Response(JSON.stringify({
        items: [
          { played_at: '2026-11-24T14:20:00.000Z', track: { id: 'a', name: 'Song A', artists: [{ name: 'Art' }], album: { name: 'Alb', images: [] } } },
          { played_at: '2026-11-24T14:15:00.000Z', track: { id: 'a', name: 'Song A', artists: [{ name: 'Art' }], album: { name: 'Alb', images: [] } } },
          { played_at: '2026-11-24T14:10:00.000Z', track: { id: 'b', name: 'Song B', artists: [{ name: 'Art' }], album: { name: 'Alb', images: [] } } },
        ],
      }), { status: 200 });
    }
    return new Response(null, { status: 204 });
  });
  let body;
  const res = {
    set() { return this; },
    status() { return this; },
    send() {},
    json(payload) { body = payload; },
  };
  await spotifyCurrentlyPlaying(
    { method: 'GET', query: { includeRecent: '1' }, headers: { authorization: 'Bearer id-tok' }, get: () => '' },
    res,
  );
  assert.ok(urls.includes('https://api.spotify.com/v1/me/player/recently-played?limit=50'));
  assert.deepEqual(body.recentTracks.map((t) => t.trackName), ['Song A', 'Song B']);
});
