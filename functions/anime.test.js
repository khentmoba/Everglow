'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const vm = require('node:vm');
const {
  ANIVEXA_PROVIDERS,
  ANIVEXA_CORE_PROVIDERS,
  ANIVEXA_SPARE_PROVIDERS,
  pickAnivexaEpisode,
  pickAnivexaStream,
  isAnivexaMediaHost,
  rewriteAnivexaPlaylist,
  httpsOrigin,
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
  playlistDuration,
  MIN_MEGAVID_SECONDS,
  NO_SOURCE_MARKER,
  isMegavidHost,
  megavidProxyUrl,
  rewriteMegavidPlaylist,
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

test('validateAnimeParams accepts anivexa', () => {
  const ok = validateAnimeParams({
    source: 'anivexa',
    anilistId: 20,
    malId: 20,
    ep: 1,
    audio: 'dub',
  });
  assert.equal(ok.error, undefined);
  assert.equal(ok.source, 'anivexa');
});

test('pickAnivexaEpisode finds episodes with audio fallback', () => {
  const data = {
    anizone: {
      episodes: {
        sub: [
          { id: 'watch/anizone/20/sub/anizone-1', number: 1 },
          { id: 'watch/anizone/20/sub/anizone-2', number: 2 },
        ],
        dub: [],
      },
    },
  };
  assert.equal(
    pickAnivexaEpisode(data, 'anizone', 2, 'sub'),
    'watch/anizone/20/sub/anizone-2',
  );
  // Empty dub list falls back to sub.
  assert.equal(
    pickAnivexaEpisode(data, 'anizone', 1, 'dub'),
    'watch/anizone/20/sub/anizone-1',
  );
  assert.equal(pickAnivexaEpisode(data, 'anizone', 99, 'sub'), null);
  assert.equal(pickAnivexaEpisode(data, 'missing', 1, 'sub'), null);
  assert.equal(pickAnivexaEpisode(null, 'anizone', 1, 'sub'), null);
});

test('pickAnivexaStream prefers HLS and drops embeds', () => {
  const watch = {
    streams: [
      { server: 'X-embed', type: 'embed', url: 'https://x/e/1' },
      { server: 'X-mp4', type: 'mp4', url: 'https://x/v.mp4' },
      { server: 'X-hls', type: 'hls', url: 'https://x/master.m3u8' },
    ],
    subtitles: [{ url: 'https://x/en.vtt', language: 'English' }],
  };
  const pick = pickAnivexaStream(watch);
  assert.equal(pick.src, 'https://x/master.m3u8');
  assert.deepEqual(pick.tracks, [
    { file: 'https://x/en.vtt', label: 'English' },
  ]);
  assert.equal(pick.referer, null);
  assert.equal(
    pickAnivexaStream({ streams: [{ type: 'embed', url: 'https://x/e' }] }),
    null,
  );
  assert.equal(pickAnivexaStream({}), null);
});

test('pickAnivexaStream reads the referer off the winning stream', () => {
  const byStream = {
    streams: [
      {
        server: 'Vidstream-2',
        type: 'hls',
        url: 'https://megap.akirax.buzz/x/master.m3u8',
        referer: 'https://megaplay.buzz/',
      },
    ],
  };
  assert.equal(pickAnivexaStream(byStream).referer, 'https://megaplay.buzz/');

  const byEmbedUrl = {
    streams: [
      {
        server: 'S',
        type: 'hls',
        url: 'https://h/x.m3u8',
        embedUrl: 'https://megaplay.buzz/stream/s-2/94012/sub',
      },
    ],
  };
  assert.equal(pickAnivexaStream(byEmbedUrl).referer, 'https://megaplay.buzz/');

  const byHeaders = {
    streams: [{ server: 'S', type: 'hls', url: 'https://h/x.m3u8' }],
    headers: { Referer: 'https://cdn.h/page' },
  };
  assert.equal(pickAnivexaStream(byHeaders).referer, 'https://cdn.h/');

  // No hints anywhere — stays null so direct-only behavior is kept.
  assert.equal(pickAnivexaStream({ streams: [{ type: 'hls', url: 'https://h/x.m3u8' }] }).referer, null);
});

test('pickAnivexaStream reports the embed origin as referer', () => {
  const withEmbeds = {
    streams: [
      { server: 'Vidplay', type: 'hls', url: 'https://cdn.h/x.m3u8' },
    ],
    embeds: [
      { name: 'Vidplay', url: 'https://play.h/e/abc' },
      { name: 'Other', url: 'https://other.h/e/1' },
    ],
  };
  assert.equal(
    pickAnivexaStream(withEmbeds).referer,
    'https://play.h/',
  );
  // No name match — first embed wins.
  const fallback = {
    streams: [{ server: 'X', type: 'mp4', url: 'https://cdn.h/v.mp4' }],
    embeds: [{ name: 'Y', url: 'https://first.h/e/1' }],
  };
  assert.equal(pickAnivexaStream(fallback).referer, 'https://first.h/');
  // Non-https embeds are ignored.
  const bad = {
    streams: [{ server: 'X', type: 'mp4', url: 'https://cdn.h/v.mp4' }],
    embeds: [{ name: 'X', url: 'http://plain.h/e/1' }],
  };
  assert.equal(pickAnivexaStream(bad).referer, null);
});

test('isAnivexaMediaHost covers rotating pool subdomains', () => {
  assert.equal(isAnivexaMediaHost('cdn.savedly.net'), true);
  assert.equal(isAnivexaMediaHost('fetch8.flixcloud.cc'), true);
  assert.equal(isAnivexaMediaHost('FLIXCLOUD.CC'), true);
  assert.equal(isAnivexaMediaHost('megavid.buzz'), false);
  assert.equal(isAnivexaMediaHost('evil.com'), false);
  assert.equal(isAnivexaMediaHost('flixcloud.cc.evil.com'), false);
});

test('rewriteAnivexaPlaylist proxies pool hosts with ref, skips others', () => {
  const base = 'https://host/proxyMegavidHls';
  const text =
    '#EXTM3U\nhttps://cdn.savedly.net/a/1.ts\n' +
    '#EXT-X-KEY:METHOD=AES,URI="https://cdn.savedly.net/a/k"\n' +
    'https://evil.com/x.ts\n';
  const out = rewriteAnivexaPlaylist(
    text,
    'https://cdn.savedly.net/a/p.m3u8',
    base,
    'tok',
    'https://embed.h/',
  );
  assert.ok(out.includes(`${base}?u=${encodeURIComponent('https://cdn.savedly.net/a/1.ts')}`));
  assert.ok(out.includes('URI="' + base));
  assert.ok(out.includes(`ref=${encodeURIComponent('https://embed.h/')}`));
  assert.ok(out.includes('https://evil.com/x.ts'));
});

test('httpsOrigin only passes https origins', () => {
  assert.equal(httpsOrigin('https://a.b/c?d=1'), 'https://a.b/');
  assert.equal(httpsOrigin('http://a.b/c'), null);
  assert.equal(httpsOrigin('nope'), null);
  assert.equal(httpsOrigin(null), null);
});

test('ANIVEXA_PROVIDERS leads with open HLS, hangy hosts demoted', () => {
  // Open/direct hosts first; animegg hangs 20s+ at times and must sit
  // behind the reliable ones; spares always trail.
  assert.equal(ANIVEXA_PROVIDERS[0], 'anineko');
  assert.equal(ANIVEXA_PROVIDERS[1], 'anikoto');
  assert.ok(
    ANIVEXA_PROVIDERS.indexOf('anikoto') <
      ANIVEXA_PROVIDERS.indexOf('animegg'),
  );
  assert.ok(
    ANIVEXA_PROVIDERS.indexOf('animegg') <
      ANIVEXA_PROVIDERS.indexOf('mkissa'),
  );
  assert.ok(ANIVEXA_PROVIDERS.includes('reanime'));
  // The burst waves are core-first; spares only fire when core is empty.
  assert.equal(ANIVEXA_CORE_PROVIDERS[0], 'anineko');
  assert.ok(ANIVEXA_CORE_PROVIDERS.includes('animegg'));
  assert.ok(ANIVEXA_SPARE_PROVIDERS.includes('2dhive'));
  assert.equal(
    ANIVEXA_PROVIDERS.length,
    ANIVEXA_CORE_PROVIDERS.length + ANIVEXA_SPARE_PROVIDERS.length,
  );
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
    '#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:200,\nhttps://cdn/s0.ts\n';
  const seen = [];
  const referers = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, opts) => {
    seen.push(String(url));
    referers.push(opts && opts.headers ? opts.headers.Referer : null);
    if (String(url).endsWith('.m3u8')) {
      const text = String(url).includes('/v.m3u8') ? variant : master;
      return {
        ok: true,
        status: 200,
        headers: { get: () => null },
        text: async () => text,
      };
    }
    return {
      ok: true,
      status: 206,
      headers: { get: () => null },
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
    // Server-side verification sends the Referer the CDN expects; it never
    // needs CORS headers because the browser streams via proxyMegavidHls.
    assert.ok(
      referers.length > 0 &&
        referers.every((r) => r === 'https://megavid.buzz/'),
    );
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('verifyMegavidStream rejects dead playlists, segments, and key failures', async () => {
  const realFetch = globalThis.fetch;
  const playlist = (text) => ({
    ok: true,
    status: 200,
    headers: { get: () => null },
    text: async () => text,
  });
  const segOk = {
    ok: true,
    status: 206,
    headers: { get: () => null },
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
      name: 'master is not a playlist',
      fetch: async () => ({
        ok: true,
        status: 200,
        headers: { get: () => null },
        text: async () => 'not a playlist',
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
          ? playlist('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:200,\nhttps://cdn/s0.ts\n')
          : { ok: false, status: 403 },
    },
    {
      name: 'no segments listed',
      fetch: async (url) =>
        String(url).endsWith('.m3u8')
          ? playlist('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:200,\n')
          : segOk,
    },
    {
      name: 'segment is an HTML error page',
      fetch: async (url) =>
        String(url).endsWith('.m3u8')
          ? playlist('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:200,\nhttps://cdn/s0.ts\n')
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
          return playlist(`#EXTM3U\n#EXTINF:200,\n${seg}\n`);
        }
        if (String(url).endsWith('b0.ts')) return { ok: false, status: 404 };
        return segOk;
      },
    },
    {
      name: 'truncated 72s playlist',
      fetch: async (url) => {
        if (String(url).endsWith('.m3u8')) {
          const segs = Array.from(
            { length: 18 },
            (_, i) => `#EXTINF:4.004,\nhttps://cdn/s${i}.ts\n`,
          ).join('');
          return playlist(`#EXTM3U\n#EXT-X-TARGETDURATION:4\n${segs}`);
        }
        return segOk;
      },
    },
    {
      name: 'encryption key 404',
      fetch: async (url) => {
        if (String(url).endsWith('.m3u8')) {
          return playlist(
            '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="https://cdn/k.key"\n' +
              '#EXTINF:200,\nhttps://cdn/s0.ts\n',
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

test('playlistDuration sums EXTINF durations', () => {
  assert.equal(
    playlistDuration('#EXTM3U\n#EXTINF:4,\na.ts\n#EXTINF:3.5,\nb.ts\n'),
    7.5,
  );
  assert.equal(playlistDuration('#EXTM3U\n#EXT-X-TARGETDURATION:4\n'), 0);
  assert.ok(MIN_MEGAVID_SECONDS >= 60);
});

test('firstM3u8 digs nested urls out of API payloads', () => {
  const found = firstM3u8({ a: [{ url: 'https://cdn/x/master.m3u8?k=1' }] });
  assert.deepEqual(found, ['https://cdn/x/master.m3u8?k=1']);
  assert.deepEqual(firstM3u8({ a: 1 }), []);
});

test('isMegavidHost only allows Megavid hosts', () => {
  assert.equal(isMegavidHost('megavid.buzz'), true);
  assert.equal(isMegavidHost('a.megavid.buzz'), true);
  assert.equal(isMegavidHost('MEGAVID.buzz'), true);
  assert.equal(isMegavidHost('evil.com'), false);
  assert.equal(isMegavidHost('megavid.buzz.evil.com'), false);
});

test('rewriteMegavidPlaylist proxies nested URIs and keys', () => {
  const base = 'https://host/proxyMegavidHls';
  const master =
    '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\n' +
    'https://megavid.buzz/vid/a/v.m3u8\n' +
    '#EXT-X-MEDIA:TYPE=AUDIO,URI="https://megavid.buzz/vid/a/audio.m3u8"\n';
  const out = rewriteMegavidPlaylist(
    master,
    'https://megavid.buzz/vid/a/master.m3u8',
    base,
    'tok',
  );
  assert.ok(out.includes(`${base}?u=${encodeURIComponent('https://megavid.buzz/vid/a/v.m3u8')}`));
  assert.ok(out.includes('URI="' + base));
  assert.ok(out.includes(encodeURIComponent('tok')));
  // External hosts are never rewritten into the proxy.
  const mixed = '#EXTM3U\nhttps://evil.com/x.ts\n';
  assert.equal(
    rewriteMegavidPlaylist(mixed, 'https://megavid.buzz/a.m3u8', base, ''),
    mixed,
  );
});

test('megavidProxyUrl carries the upstream URL and token', () => {
  const u = megavidProxyUrl('https://h/proxyMegavidHls', 't 1', 'https://megavid.buzz/v.m3u8');
  assert.ok(u.startsWith('https://h/proxyMegavidHls?u='));
  assert.ok(u.includes(encodeURIComponent('https://megavid.buzz/v.m3u8')));
  assert.ok(u.includes(encodeURIComponent('t 1')));
});
