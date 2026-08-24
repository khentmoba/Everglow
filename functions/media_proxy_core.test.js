'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  buildLastfmUpstream,
  buildTmdbUpstream,
} = require('./media_proxy_core');

test('TMDB proxy strips client credentials and appends server key', () => {
  const url = buildTmdbUpstream(
    '/trending/all/week',
    { api_key: 'browser-leak', page: '1', __auth: 'jwt' },
    'server-key',
  );
  assert.equal(url.pathname, '/3/trending/all/week');
  assert.equal(url.searchParams.get('page'), '1');
  assert.equal(url.searchParams.get('__auth'), null);
  assert.equal(url.searchParams.get('api_key'), 'server-key');
});

test('TMDB proxy rejects traversal paths', () => {
  assert.throws(() => buildTmdbUpstream('/../secret', {}, 'server-key'));
});

test('Last.fm proxy allows only read-only lookup methods', () => {
  const url = buildLastfmUpstream(
    { method: 'user.getrecenttracks', api_key: 'browser-leak' },
    'server-key',
  );
  assert.equal(url.searchParams.get('method'), 'user.getrecenttracks');
  assert.equal(url.searchParams.get('api_key'), 'server-key');
  assert.throws(() => buildLastfmUpstream({ method: 'artist.addtags' }, 'server-key'));
});
