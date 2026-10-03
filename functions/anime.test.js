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
    'hianime was removed',
  );
  assert.ok(
    validateAnimeParams({ source: 'megavid', malId: 21, ep: 0 }).error,
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

test('validateAnimeParams rejects unknown sources', () => {
  const bad = validateAnimeParams({
    source: 'anivexa',
    anilistId: 20,
    malId: 20,
    ep: 1,
    audio: 'dub',
  });
  assert.ok(bad.error);
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

test('hlsPlayerHtml hidden overlays stay hidden', () => {
  const html = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Ep 1',
    tracks: [],
  });
  // Regression: author-origin `.ov{display:flex}` beats the UA
  // stylesheet's `[hidden]{display:none}`, so without an explicit rule
  // the tap-to-play button AND the "stalled" card paint over the video
  // from the first frame on every episode.
  assert.ok(html.includes('.ov[hidden]{display:none'));
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

/** Minimal DOM + Hls stubs so the player script can run inside a vm.
 *  Elements need style/hidden/addEventListener; the video also needs
 *  src/play for the native-HLS fallback branch. */
function playerScriptContext(calls, { search = '', native = false, hls = true } = {}) {
  const element = () => ({
    style: {},
    hidden: true,
    src: '',
    currentTime: 0,
    duration: NaN,
    listeners: {},
    addEventListener(event, handler) {
      (this.listeners[event] ||= []).push(handler);
    },
    dispatch(event, data) {
      for (const handler of this.listeners[event] || []) handler(data);
    },
    play() {},
  });
  const els = {
    v: element(),
    boot: element(),
    tapw: element(),
    tap: element(),
    dead: element(),
  };
  function Hls() {}
  Hls.isSupported = () => true;
  Hls.Events = { ERROR: 'error', MANIFEST_PARSED: 'manifestParsed' };
  Hls.ErrorTypes = { NETWORK_ERROR: 'networkError', MEDIA_ERROR: 'mediaError' };
  Hls.prototype.on = function (event, handler) {
    calls.handlers[event] = handler;
  };
  Hls.prototype.loadSource = (url) => calls.loadSource.push(url);
  Hls.prototype.attachMedia = (media) => calls.attachMedia.push(media);
  Hls.prototype.destroy = () => {};
  Hls.prototype.startLoad = () => {};
  Hls.prototype.recoverMediaError = () => {};
  calls.postMessages = [];
  calls.nativeMessages = [];
  calls.now = 0;
  const window = element();
  window.Hls = hls ? Hls : null;
  window.location = {
    search,
    origin: 'https://us-central1-everglow-1c6db.cloudfunctions.net',
    pathname: '/proxyAnime',
  };
  window.parent = native ? window : {};
  window.parent.postMessage = (data) => calls.postMessages.push(data);
  if (native) window.EverglowPlayer = {
    postMessage: (data) => calls.nativeMessages.push(data),
  };
  const context = {
    window,
    Hls,
    URLSearchParams,
    Date: { now: () => calls.now },
    document: { getElementById: (id) => els[id] || null },
  };
  context.elements = els;
  return context;
}

test('hlsPlayerHtml inline script actually runs and starts the stream', () => {
  const html = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Ep 1',
    tracks: [],
  });
  const code = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];
  const calls = { loadSource: [], attachMedia: [], handlers: {} };
  const context = playerScriptContext(calls);
  vm.createContext(context);
  // Regression: 94c57427 shipped `(function(){...});` — a script that
  // parses cleanly but is never invoked, so the player spun forever.
  // Executing the script must actually start the stream.
  new vm.Script(code, { filename: 'player.js' }).runInContext(context);
  assert.deepEqual(calls.loadSource, ['https://x/y.m3u8']);
  assert.equal(calls.attachMedia.length, 1);
  assert.ok(calls.handlers.manifestParsed, 'manifest handler registered');
});

function runPlayer(options = {}) {
  const calls = { loadSource: [], attachMedia: [], handlers: {} };
  const context = playerScriptContext(calls, options);
  const html = hlsPlayerHtml({ src: 'https://x/y.m3u8', ep: 3 });
  const code = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];
  new vm.Script(code).runInNewContext(context);
  return { calls, window: context.window, video: context.elements.v };
}

test('start seeks on metadata, clamps to duration and never reapplies', () => {
  for (const hls of [true, false]) {
    for (const [start, expected] of [['95', 95], ['0', 0], ['9999', 100], ['12.5', 12.5]]) {
      const { video } = runPlayer({ search: `?start=${start}`, hls });
      assert.equal(video.currentTime, 0, 'waits for metadata');
      video.duration = 100;
      video.dispatch('durationchange');
      assert.equal(video.currentTime, 0, 'start waits for loadedmetadata');
      video.dispatch('loadedmetadata');
      assert.equal(video.currentTime, expected);
      video.currentTime = 17;
      video.dispatch('loadedmetadata');
      video.dispatch('durationchange');
      assert.equal(video.currentTime, 17, 'does not rewind on a later metadata event');
    }
  }
  for (const start of ['', '-5', 'NaN', 'Infinity', '1e309', '0x10', '12oops', ' ', '9'.repeat(400)]) {
    const { video } = runPlayer({ search: `?start=${encodeURIComponent(start)}` });
    video.currentTime = 8;
    video.duration = 100;
    video.dispatch('loadedmetadata');
    assert.equal(video.currentTime, 8, `invalid start ${start}`);
  }
});

test('seek requires trusted parent source AND exact app origin, queues until metadata', () => {
  const { calls, window, video } = runPlayer({ search: '?start=5' });
  const seek = (seconds, source = window.parent, origin = 'https://everglow-1c6db.web.app') =>
    window.dispatch('message', { source, origin, data: { type: 'animex-seek', seconds } });
  seek(40);
  assert.equal(video.currentTime, 0);
  video.duration = 100;
  video.dispatch('loadedmetadata');
  assert.equal(video.currentTime, 40, 'pending seek overrides start');
  for (const origin of ['https://evil.example', 'null', 'https://everglow-1c6db.web.app.evil.com',
    'https://everglow-1c6db.web.app:443', 'https://another-project--pr-1.web.app',
    'https://everglow-1c6db--pr-1.web.app.evil.com', 'http://192.168.1.1:5000']) {
    seek(70, window.parent, origin);
    assert.equal(video.currentTime, 40, origin);
  }
  seek(70, {}, 'https://everglow-1c6db.web.app');
  assert.equal(video.currentTime, 40, 'same-origin foreign frame is ignored');
  for (const seconds of [NaN, Infinity, -1, '20', null, {}, true]) {
    seek(seconds);
    assert.equal(video.currentTime, 40, `invalid seek ${seconds}`);
  }
  for (const origin of ['https://everglow-1c6db.firebaseapp.com',
    'https://everglow-1c6db--pr-123-abc.web.app', 'http://localhost:5000',
    'http://127.0.0.1:8080', 'http://[::1]:8080']) {
    seek(150, window.parent, origin);
    assert.equal(video.currentTime, 100, origin);
    seek(40);
  }
  seek(0);
  assert.equal(video.currentTime, 0);
  assert.equal(calls.loadSource.length, 1, 'seek does not reload the stream');
});

test('progress has strict finite seconds, throttled timeupdates and forced pause/end', () => {
  const { calls, video } = runPlayer();
  video.duration = 100;
  video.currentTime = 12.5;
  video.dispatch('timeupdate');
  assert.deepEqual(JSON.parse(JSON.stringify(calls.postMessages[0])), {
    type: 'animex-progress', position: 12.5, duration: 100, episode: 3,
  });
  calls.now = 500;
  video.currentTime = 13;
  video.dispatch('timeupdate');
  assert.equal(calls.postMessages.length, 1);
  calls.now = 1000;
  video.dispatch('timeupdate');
  video.dispatch('pause');
  video.currentTime = 100;
  video.dispatch('ended');
  assert.equal(calls.postMessages.length, 4);
  assert.equal(calls.postMessages[3].position, 100);
  for (const [position, duration] of [[NaN, 100], [Infinity, 100], [-1, 100], [101, 100],
    ['10', 100], [1, '100'], [1, Infinity], [1, NaN], [0, 0]]) {
    video.currentTime = position;
    video.duration = duration;
    video.dispatch('pause');
  }
  assert.equal(calls.postMessages.length, 4);
});

test('native owned top-level EverglowPlayer bridges progress, seek and playback errors', () => {
  const { calls, window, video } = runPlayer({ native: true });
  video.duration = 100;
  video.dispatch('loadedmetadata');
  window.dispatch('message', {
    source: window, origin: window.location.origin, data: { type: 'animex-seek', seconds: 60 },
  });
  assert.equal(video.currentTime, 60);
  window.dispatch('message', {
    source: {}, origin: window.location.origin, data: { type: 'animex-seek', seconds: 80 },
  });
  assert.equal(video.currentTime, 60);
  video.dispatch('pause');
  assert.deepEqual(JSON.parse(calls.nativeMessages[0]), {
    type: 'animex-progress', position: 60, duration: 100, episode: 3,
  });
  for (let i = 0; i < 4; i++) calls.handlers.error(null, { fatal: true, type: 'networkError' });
  assert.equal(calls.nativeMessages.at(-1), 'animex-content-error');
  window.location.pathname = '/unrelated';
  window.dispatch('message', {
    source: window, origin: window.location.origin, data: { type: 'animex-seek', seconds: 80 },
  });
  assert.equal(video.currentTime, 60, 'native self exception is confined to proxyAnime');
});

test('browser top-level cannot masquerade as a native player', () => {
  const { window, video } = runPlayer();
  window.parent = window;
  video.duration = 100;
  window.dispatch('message', {
    source: window, origin: window.location.origin, data: { type: 'animex-seek', seconds: 80 },
  });
  assert.equal(video.currentTime, 0);
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

test('isMegavidHost only allows trusted Megavid hosts', () => {
  assert.equal(isMegavidHost('megavid.buzz'), true);
  assert.equal(isMegavidHost('a.megavid.buzz'), true);
  assert.equal(isMegavidHost('MEGAVID.buzz'), true);
  // Segments stream from Megavid's CDN, not its own domain — the proxy
  // and playlist rewriter must accept it or every episode stalls on CORS.
  assert.equal(isMegavidHost('cdn.api-webs.com'), true);
  assert.equal(isMegavidHost('cdnx.aniwatchtv.site'), true);
  assert.equal(isMegavidHost('aniwatchtv.site'), false);
  assert.equal(isMegavidHost('edge.cdnx.aniwatchtv.site'), false);
  assert.equal(isMegavidHost('unverified-cdn.aniwatchtv.site'), false);
  assert.equal(isMegavidHost('evil.com'), false);
  assert.equal(isMegavidHost('megavid.buzz.evil.com'), false);
  assert.equal(isMegavidHost('cdn.api-webs.com.evil.com'), false);
  assert.equal(isMegavidHost('aniwatchtv.site.evil.com'), false);
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
  );
  assert.ok(out.includes(`${base}?u=${encodeURIComponent('https://megavid.buzz/vid/a/v.m3u8')}`));
  assert.ok(out.includes('URI="' + base));
  // Nested media URLs must never carry a login token.
  assert.ok(!out.includes('token='));
  // External hosts are never rewritten into the proxy.
  const mixed = '#EXTM3U\nhttps://evil.com/x.ts\n';
  assert.equal(
    rewriteMegavidPlaylist(mixed, 'https://megavid.buzz/a.m3u8', base),
    mixed,
  );
});

test('rewriteMegavidPlaylist proxies CDN segment hosts', () => {
  const base = 'https://host/proxyMegavidHls';
  // Regression: Megavid moved every media segment to cdn.api-webs.com
  // while playlists stayed on megavid.buzz. Leaving the CDN host out
  // meant variant playlists kept bare CDN URLs, the browser fetched them
  // directly, and — with no CORS headers — every episode stalled.
  const variant =
    '#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4.004,\n' +
    'https://cdn.api-webs.com/abc/480p/video0.ts\n';
  const out = rewriteMegavidPlaylist(
    variant,
    'https://cp.megavid.buzz/hls/abc/480p/video.m3u8',
    base,
  );
  assert.ok(
    out.includes(
      `${base}?u=${encodeURIComponent('https://cdn.api-webs.com/abc/480p/video0.ts')}`,
    ),
  );
  assert.ok(!out.includes('https://cdn.api-webs.com/abc/480p/video0.ts\n'));
});

test('rewriteMegavidPlaylist proxies the active ani.watch CDN', () => {
  const base = 'https://host/proxyMegavidHls';
  const segment = 'https://cdnx.aniwatchtv.site/uwu/episode/segment.ts';
  const playlist = `#EXTM3U\n#EXTINF:4.0,\n${segment}\n`;

  const out = rewriteMegavidPlaylist(
    playlist,
    'https://cdnx.aniwatchtv.site/uwu/episode/master.m3u8',
    base,
  );

  assert.ok(out.includes(`${base}?u=${encodeURIComponent(segment)}`));
  assert.ok(!out.includes(segment));
});

test('megavidProxyUrl carries the upstream URL, never a token', () => {
  const u = megavidProxyUrl('https://h/proxyMegavidHls', 'https://megavid.buzz/v.m3u8');
  assert.ok(u.startsWith('https://h/proxyMegavidHls?u='));
  assert.ok(u.includes(encodeURIComponent('https://megavid.buzz/v.m3u8')));
  assert.ok(!u.includes('token='));
});

test('hlsPlayerHtml sends the token as a header, not in URLs', () => {
  const html = hlsPlayerHtml({
    src: 'https://h/proxyMegavidHls?u=https%3A%2F%2Fcdn%2Fv.m3u8',
    title: 'Ep 1',
    tracks: [],
    token: 'tok123',
  });
  assert.ok(html.includes('xhrSetup'));
  assert.ok(html.includes('Authorization'));
  assert.ok(!html.includes('token='));
  const code = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];
  new vm.Script(code);
});
