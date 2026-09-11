'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const vm = require('node:vm');
const {
  normTitle,
  pickBestMatch,
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

test('hlsPlayerHtml recovers instead of spinning forever', () => {
  const html = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Ep 1',
    tracks: [],
  });
  // Starts playback once the manifest is ready (phones block silent autoplay).
  assert.ok(html.includes('MANIFEST_PARSED'));
  // Transient failures retry; repeated fatal ones surface a card + retry.
  assert.ok(html.includes('recoverMediaError'));
  assert.ok(html.includes('startLoad'));
  assert.ok(html.includes('location.reload'));
  // Unrecoverable stalls tell the app to advance to the next server.
  assert.ok(html.includes('animex-content-error'));
  // The in-player card must never trip the dead-server probe.
  assert.ok(!html.includes(NO_SOURCE_MARKER));
});

test('hlsPlayerHtml inline script parses', () => {
  const html = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Ep 1',
    tracks: [],
  });
  const blocks = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(
    (m) => m[1],
  );
  assert.ok(blocks.length >= 1);
  for (const code of blocks) new vm.Script(code);
});

test('firstM3u8 digs nested urls out of API payloads', () => {
  const found = firstM3u8({ a: [{ url: 'https://cdn/x/master.m3u8?k=1' }] });
  assert.deepEqual(found, ['https://cdn/x/master.m3u8?k=1']);
  assert.deepEqual(firstM3u8({ a: 1 }), []);
});
