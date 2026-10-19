'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { getAdmin } = require('./common');
const { getSpotifyAppToken } = require('./spotify');
const { createToolCtx } = require('./motchi_exec_tools');

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
