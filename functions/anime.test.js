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
  resolvePlaylistUrl,
  playlistUris,
  verifyMegavidStream,
  assertPlayableHead,
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

test('playlistUris resolves variants and skips comments', () => {
  const master =
    '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nhttps://cdn/x/480p/video.m3u8\n' +
    '#EXT-X-STREAM-INF:BANDWIDTH=2\n/vid/720p/video.m3u8\n';
  assert.deepEqual(
    playlistUris(master, 'https://cdn/x/playlist.m3u8', { variantsOnly: true }),
    ['https://cdn/x/480p/video.m3u8', 'https://cdn/vid/720p/video.m3u8'],
  );
  const media =
    '#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nseg0.ts\n' +
    '#EXTINF:4,\nhttps://cdn/y/seg1.ts\n';
  assert.deepEqual(playlistUris(media, 'https://cdn/x/v/video.m3u8'), [
    'https://cdn/x/v/seg0.ts',
    'https://cdn/y/seg1.ts',
  ]);
  assert.equal(resolvePlaylistUrl('s.ts', 'https://h/a/b.m3u8'), 'https://h/a/s.ts');
  assert.equal(resolvePlaylistUrl('javascript:alert(1)', 'https://h/a.m3u8'), null);
});

test('verifyMegavidStream accepts a healthy stream end to end', async () => {
  const master =
    '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nhttps://cdn/v.m3u8\n';
  const variant =
    '#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nhttps://cdn/s0.ts\n';
  const seen = [];
  const origins = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, opts) => {
    seen.push(String(url));
    origins.push(opts && opts.headers ? opts.headers.Origin : null);
    if (String(url).endsWith('.m3u8')) {
      const text = String(url).includes('/v.m3u8') ? variant : master;
      return {
        ok: true,
        status: 200,
        headers: { get: (k) => (k === 'access-control-allow-origin' ? '*' : null) },
        text: async () => text,
      };
    }
    return {
      ok: true,
      status: 206,
      headers: { get: (k) => (k === 'access-control-allow-origin' ? '*' : null) },
      body: {
        getReader: () => ({
          read: async () => ({ done: false, value: new Uint8Array([0x47, 2]) }),
          cancel: async () => {},
        }),
      },
    };
  };
  try {
    const out = await verifyMegavidStream('https://cdn/master.m3u8');
    assert.equal(out.variantUrl, 'https://cdn/v.m3u8');
    assert.equal(out.segmentUrl, 'https://cdn/s0.ts');
    assert.ok(seen.includes('https://cdn/master.m3u8'));
    assert.ok(seen.includes('https://cdn/v.m3u8'));
    assert.ok(seen.includes('https://cdn/s0.ts'));
    assert.ok(origins.length > 0 && origins.every((o) => typeof o === 'string' && o.length > 0));
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('verifyMegavidStream rejects dead playlists, segments, and key failures', async () => {
  const realFetch = globalThis.fetch;
  const playlist = (text) => ({
    ok: true,
    status: 200,
    headers: { get: (k) => (k === 'access-control-allow-origin' ? '*' : null) },
    text: async () => text,
  });
  const segOk = {
    ok: true,
    status: 206,
    headers: { get: (k) => (k === 'access-control-allow-origin' ? '*' : null) },
    body: {
      getReader: () => ({
        read: async () => ({ done: false, value: new Uint8Array([0x47]) }),
        cancel: async () => {},
      }),
    },
  };
  const cases = [
    {
      name: 'master 404',
      fetch: async () => ({ ok: false, status: 404 }),
    },
    {
      name: 'master without CORS header',
      fetch: async () => ({
        ok: true,
        status: 200,
        headers: { get: () => null },
        text: async () => '#EXTM3U\n',
      }),
    },
    {
      name: 'variant 404',
      fetch: async (url) =>
        String(url).includes('master')
          ? playlist('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nhttps://cdn/v.m3u8\n')
          : { ok: false, status: 404 },
    },
    {
      name: 'first segment 403',
      fetch: async (url) =>
        String(url).endsWith('.m3u8')
          ? playlist('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nhttps://cdn/s0.ts\n')
          : { ok: false, status: 403 },
    },
    {
      name: 'no segments listed',
      fetch: async (url) =>
        String(url).endsWith('.m3u8')
          ? playlist('#EXTM3U\n#EXT-X-TARGETDURATION:4\n')
          : segOk,
    },
    {
      name: 'segment without CORS header',
      fetch: async (url) =>
        String(url).endsWith('.m3u8')
          ? playlist('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nhttps://cdn/s0.ts\n')
          : {
              ok: true,
              status: 206,
              headers: { get: () => null },
              body: {
                getReader: () => ({
                  read: async () => ({ done: false, value: new Uint8Array([0x47]) }),
                  cancel: async () => {},
                }),
              },
            },
    },
    {
      name: 'segment is an HTML error page',
      fetch: async (url) =>
        String(url).endsWith('.m3u8')
          ? playlist('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nhttps://cdn/s0.ts\n')
          : {
              ok: true,
              status: 200,
              headers: { get: () => '*' },
              body: {
                getReader: () => ({
                  read: async () => ({
                    done: false,
                    value: new Uint8Array([0x3c, 0x68, 0x74, 0x6d, 0x6c]),
                  }),
                  cancel: async () => {},
                }),
              },
            },
    },
    {
      name: 'second variant dead',
      fetch: async (url) => {
        const u = String(url);
        if (u.endsWith('master.m3u8')) {
          return playlist(
            '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nhttps://cdn/a.m3u8\n' +
              '#EXT-X-STREAM-INF:BANDWIDTH=2\nhttps://cdn/b.m3u8\n',
          );
        }
        if (u.endsWith('.m3u8')) {
          const seg = u.includes('/b.m3u8') ? 'https://cdn/b0.ts' : 'https://cdn/a0.ts';
          return playlist(`#EXTM3U\n#EXTINF:4,\n${seg}\n`);
        }
        if (String(url).endsWith('b0.ts')) return { ok: false, status: 404 };
        return segOk;
      },
    },
    {
      name: 'encryption key 404',
      fetch: async (url) => {
        if (String(url).endsWith('.m3u8')) {
          return playlist(
            '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="https://cdn/k.key"\n' +
              '#EXTINF:4,\nhttps://cdn/s0.ts\n',
          );
        }
        if (String(url).endsWith('.key')) return { ok: false, status: 404 };
        return segOk;
      },
    },
  ];
  for (const c of cases) {
    globalThis.fetch = c.fetch;
    await assert.rejects(
      verifyMegavidStream('https://cdn/master.m3u8'),
      /megavid/,
      c.name,
    );
  }
  globalThis.fetch = realFetch;
});

test('assertPlayableHead only accepts real TS bytes for .ts files', () => {
  assert.doesNotThrow(() =>
    assertPlayableHead(new Uint8Array([0x47, 0, 0]), 'https://cdn/s0.ts', 'segment'),
  );
  assert.throws(
    () => assertPlayableHead(new Uint8Array([0x3c, 0x21]), 'https://cdn/s0.ts', 'segment'),
    /not video data/,
  );
  assert.doesNotThrow(() =>
    assertPlayableHead(new Uint8Array([0x00, 0x00]), 'https://cdn/s0.m4s', 'segment'),
  );
});

test('firstM3u8 digs nested urls out of API payloads', () => {
  const found = firstM3u8({ a: [{ url: 'https://cdn/x/master.m3u8?k=1' }] });
  assert.deepEqual(found, ['https://cdn/x/master.m3u8?k=1']);
  assert.deepEqual(firstM3u8({ a: 1 }), []);
});
