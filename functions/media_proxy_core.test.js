'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  buildLastfmUpstream,
  buildTmdbUpstream,
  resolveGalleryDeletePath,
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

test('Gallery delete resolves the bucket path from a download URL', () => {
  const path = resolveGalleryDeletePath(
'https://firebasestorage.googleapis.com/v0/b/everglow-1c6db.firebasestorage.app/o/gallery%2Fabc%2F1700000000_photo.jpg?alt=media&token=abc123',
  );
  assert.equal(path, 'gallery/abc/1700000000_photo.jpg');
});

test('Gallery delete rejects non-bucket hosts', () => {
  assert.throws(() =>
    resolveGalleryDeletePath('https://evil.example.com/o/gallery%2Fx.jpg'),
    /project Storage bucket/,
  );
});

test('Gallery delete rejects other-bucket project URLs and non-gallery paths', () => {
  assert.throws(() =>
    resolveGalleryDeletePath('https://firebasestorage.googleapis.com/v0/b/other-proj.appspot.com/o/gallery%2Fx.jpg?alt=media'),
    /project Storage bucket/,
  );
  assert.throws(() =>
    resolveGalleryDeletePath('https://firebasestorage.googleapis.com/v0/b/everglow-1c6db.firebasestorage.app/o/vault%2Fsecret.jpg?alt=media'),
    /Only gallery files/,
  );
});

test('Gallery delete rejects garbage input', () => {
  assert.throws(() => resolveGalleryDeletePath(''));
  assert.throws(() => resolveGalleryDeletePath(null));
  assert.throws(() => resolveGalleryDeletePath('not a url'));
});
