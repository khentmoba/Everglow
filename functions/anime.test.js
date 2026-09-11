'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  normTitle,
  pickBestMatch,
  hianimeSlug,
  hianimeSlugVariants,
  normalizeHianimeEpisodeId,
  pickHianimeServer,
  validateAnimeParams,
  failHtml,
  hlsPlayerHtml,
  firstM3u8,
  NO_SOURCE_MARKER,
} = require('./anime');

test('normTitle strips punctuation for fuzzy matching', () => {
  assert.equal(normTitle('Attack on Titan!'), normTitle('attack-on-titan'));
  assert.equal(normTitle('  Solo   Leveling 2 '), 'sololeveling2');
});

test('pickBestMatch prefers exact titles, bonuses matching year', () => {
  const cands = [
    { key: 'a', title: 'Naruto Shippuden' },
    { key: 'b', title: 'Naruto', year: 2002 },
  ];
  const exact = pickBestMatch(cands, ['Naruto'], 2002);
  assert.equal(exact.key, 'b');
  const none = pickBestMatch(cands, ['One Piece'], null);
  assert.equal(none, null);
});

test('validateAnimeParams rejects bad source, ids, episodes', () => {
  assert.ok(validateAnimeParams({ source: 'nope', ep: 1 }).error);
  assert.ok(
    validateAnimeParams({ source: 'hianime', ep: 1 }).error,
    'needs an id',
  );
  assert.ok(
    validateAnimeParams({ source: 'hianime', malId: 21, ep: 0 }).error,
  );
  const okMegavid = validateAnimeParams({
    source: 'megavid',
    anilistId: 21,
    malId: 0,
    ep: 1,
    audio: 'sub',
  });
  assert.equal(okMegavid.error, undefined);
  assert.equal(okMegavid.source, 'megavid');
});

test('failHtml always carries the app failover marker', () => {
  const html = failHtml('Episode unavailable', 'No stream found');
  assert.ok(html.includes(NO_SOURCE_MARKER));
});

test('hlsPlayerHtml escapes titles and includes subs', () => {
  const html = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: '<b>Hi</b>',
    tracks: [{ file: 'https://x/en.vtt', label: 'English' }],
  });
  assert.ok(!html.includes('<b>Hi</b>'));
  assert.ok(html.includes('https://x/y.m3u8'));
  assert.ok(html.includes('en.vtt'));
});

test('hianimeSlugVariants tries the exact slug before the stripped base', () => {
  assert.deepEqual(hianimeSlugVariants('black-clover-season-2'), [
    'black-clover-season-2',
    'black-clover',
  ]);
  assert.deepEqual(hianimeSlugVariants('solo-leveling-s2'), [
    'solo-leveling-s2',
    'solo-leveling',
  ]);
  assert.deepEqual(hianimeSlugVariants('attack-on-titan-final-season'), [
    'attack-on-titan-final-season',
    'attack-on-titan',
  ]);
  // Plain slugs gain no duplicate candidate.
  assert.deepEqual(hianimeSlugVariants('black-clover'), ['black-clover']);
  assert.deepEqual(hianimeSlugVariants(hianimeSlug('Black Clover!')), [
    'black-clover',
  ]);
});

test('normalizeHianimeEpisodeId accepts every upstream id shape', () => {
  assert.equal(
    normalizeHianimeEpisodeId('black-clover/ep-2'),
    'black-clover::ep=2',
  );
  assert.equal(
    normalizeHianimeEpisodeId('steins-gate-3?ep=213'),
    'steins-gate-3::ep=213',
  );
  assert.equal(
    normalizeHianimeEpisodeId('black-clover::ep=2'),
    'black-clover::ep=2',
  );
});

test('pickHianimeServer accepts name and serverName item shapes', () => {
  assert.deepEqual(pickHianimeServer([{ name: 'HD-2' }]), {
    server: 'hd-2',
    embedUrl: null,
  });
  assert.deepEqual(
    pickHianimeServer([
      { serverName: 'HD-1', embedUrl: 'https://x/e/1' },
    ]),
    { server: 'hd-1', embedUrl: 'https://x/e/1' },
  );
  assert.equal(pickHianimeServer([]), null);
  assert.equal(pickHianimeServer(null), null);
});

test('firstM3u8 digs nested urls out of API payloads', () => {
  const found = firstM3u8({ a: [{ url: 'https://cdn/x/master.m3u8?k=1' }] });
  assert.deepEqual(found, ['https://cdn/x/master.m3u8?k=1']);
  assert.deepEqual(firstM3u8({ a: 1 }), []);
});
