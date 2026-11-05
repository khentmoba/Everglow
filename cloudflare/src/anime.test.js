import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';

import {
  assertPlayableHead,
  cdnStamp,
  cinemaHeaders,
  cinemaProxyUrl,
  scopeMessage,
  urlScope,
  decryptMegaPlayPayload,
  failHtml,
  firstM3u8,
  hlsPlayerHtml,
  isAnimeCdnHost,
  isMegaPlayHost,
  isMegavidHost,
  makeMegaPlayToken,
  MIN_MEGAVID_SECONDS,
  NO_SOURCE_MARKER,
  playlistDuration,
  playlistUris,
  resolveCinema,
  resolvePlaylistUrl,
  rewriteCinemaPlaylist,
  rewritePlaylistWithHosts,
  selectCinemaSubtitleTracks,
  validCdnStamp,
  validateAnimeParams,
  verifyCinemaStream,
  verifyStream,
  CINEMA_PROVIDERS,
  FMOV_ORIGIN,
  MEGAPLAY_ORIGIN,
  MEGAPLAY_HOSTS,
  MEGAVID_ORIGIN,
  VIDBOLT_ORIGIN,
} from './anime.js';
import { handleProxyHls } from './worker.js';

const KEY = 'demo-cdn-key';
const HOST = 'https://everglow-stream.example.workers.dev';

/** The upstream URL a proxy URL points at, in either shape: `u` (one-off) or
 *  `d` + `r` (scoped, relative to the signed directory). */
function upstreamOf(proxyUrl) {
  const u = proxyUrl instanceof URL ? proxyUrl : new URL(proxyUrl);
  const full = u.searchParams.get('u');
  if (full) return full;
  return (u.searchParams.get('d') || '') + (u.searchParams.get('r') || '');
}

test('validateAnimeParams accepts the sources the app actually offers', () => {
  for (const source of ['megavid', 'megaplay', 'everglow']) {
    const p = validateAnimeParams({ source, anilistId: 21, ep: 1, audio: 'sub' });
    assert.equal(p.error, undefined, source);
  }
  // AnimePahe is gone: it needed a self-hosted API base the app never uses.
  assert.ok(validateAnimeParams({ source: 'animepahe', malId: 21, ep: 1 }).error);
  assert.ok(validateAnimeParams({ source: 'megaplay', ep: 1 }).error);
  assert.ok(validateAnimeParams({ source: 'megaplay', anilistId: 21, ep: 0 }).error);
  assert.ok(validateAnimeParams({ source: 'megaplay', anilistId: 21, ep: 1, audio: 'x' }).error);
});

test('validateAnimeParams accepts cinema movie and tv and rejects bad params', () => {
  const movie = validateAnimeParams({ source: 'cinema', type: 'movie', tmdbId: 603 });
  assert.equal(movie.error, undefined);
  assert.equal(movie.mediaType, 'movie');
  assert.equal(movie.season, 1);
  assert.equal(movie.ep, 1);

  const tv = validateAnimeParams({ source: 'cinema', type: 'tv', tmdbId: 1396, s: 2, e: 3 });
  assert.equal(tv.error, undefined);
  assert.equal(tv.season, 2);
  assert.equal(tv.ep, 3);

  assert.ok(validateAnimeParams({ source: 'cinema', type: 'ova', tmdbId: 1 }).error);
  assert.ok(validateAnimeParams({ source: 'cinema', type: 'movie', tmdbId: 0 }).error);
  assert.ok(validateAnimeParams({ source: 'cinema', type: 'tv', tmdbId: 1, s: 0 }).error);
  assert.ok(validateAnimeParams({ source: 'cinema', type: 'tv', tmdbId: 1, e: 0 }).error);
});

test('host predicates match the Node originals', () => {
  assert.equal(isMegavidHost('megavid.buzz'), true);
  assert.equal(isMegavidHost('s-90.megavid.se'), true);
  assert.equal(isMegavidHost('cdnx.aniwatchtv.site'), true);
  assert.equal(isMegavidHost('evil.com'), false);

  for (const h of MEGAPLAY_HOSTS) assert.equal(isMegaPlayHost(h), true, h);
  assert.equal(isMegaPlayHost('fetch.nexabloom.top'), true);
  assert.equal(isMegaPlayHost('nexabloom.top.evil.com'), false);

  // Cinema hosts are deliberately NOT on the open allowlist.
  assert.equal(isAnimeCdnHost('fmov.my'), false);
  assert.equal(isAnimeCdnHost('proxy.vidbolt.xyz'), false);
  assert.deepEqual([...CINEMA_PROVIDERS].sort(), ['fmov', 'vidbolt']);
});

test('headers follow the stamped provider, never the URL host', () => {
  assert.equal(cinemaHeaders('fmov').Origin, FMOV_ORIGIN);
  assert.equal(cinemaHeaders('vidbolt').Origin, VIDBOLT_ORIGIN);
  assert.equal(cinemaHeaders('fmov').Referer, `${FMOV_ORIGIN}/`);
});

test('Cinema stamps bind provider + scope, and never pass as another provider', async () => {
  const url = 'https://fmov.my/api/proxy?url=https%3A%2F%2Fcdn.example%2Fm.m3u8';
  const proxied = new URL(await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, url, 'fmov', KEY));
  assert.equal(upstreamOf(proxied), url);
  assert.equal(proxied.searchParams.get('p'), 'fmov');
  const scope = proxied.searchParams.get('d');
  const s = proxied.searchParams.get('s');
  assert.equal(scope, 'https://fmov.my/api/');
  assert.ok(await validCdnStamp(KEY, scopeMessage('fmov', scope), s));
  assert.equal(await validCdnStamp(KEY, scopeMessage('vidbolt', scope), s), false);
  assert.equal(await validCdnStamp(KEY, scopeMessage('megaplay', scope), s), false);
  assert.equal(await validCdnStamp('other-key', scopeMessage('fmov', scope), s), false);
  // A different scope under the same provider must not validate.
  assert.equal(await validCdnStamp(KEY, scopeMessage('fmov', 'https://fmov.my/other/'), s), false);
});

test('urlScope returns the containing directory', () => {
  assert.equal(urlScope('https://a.example/x/y/index.m3u8'), 'https://a.example/x/y/');
  assert.equal(urlScope('https://a.example/x/y/tiles/0.png'), 'https://a.example/x/y/tiles/');
  assert.equal(urlScope('https://a.example/index.m3u8'), 'https://a.example/');
});

test('rewriteCinemaPlaylist stamps a whole playlist with ONE signature', async () => {
  const base = 'https://img.rousav.tech/media/a/index.m3u8?api_key=k1';
  const segs = Array.from({ length: 400 }, (_, i) => `seg${i}.ts`).join('\n');
  const out = await rewriteCinemaPlaylist(
    `#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,URI="track_en.m3u8"\n${segs}\n`,
    base,
    `${HOST}/proxyMegavidHls`,
    'vidbolt',
    KEY,
  );
  const urls = [...out.matchAll(/https:\/\/[^?"\s]+\/proxyMegavidHls\?[^"\s]+/g)].map((m) => new URL(m[0]));
  assert.equal(urls.length, 401);
  const stamps = new Set(urls.map((u) => u.searchParams.get('s')));
  assert.equal(stamps.size, 1, 'one signature covers the whole directory');
  const scopes = new Set(urls.map((u) => u.searchParams.get('d')));
  assert.deepEqual([...scopes], ['https://img.rousav.tech/media/a/']);
  for (const u of urls) {
    assert.equal(u.searchParams.get('p'), 'vidbolt');
    assert.ok(upstreamOf(u).includes('api_key=k1'), 'api_key survives');
    assert.ok(u.searchParams.get('r'), 'scoped URLs send a relative path');
    assert.ok(!u.searchParams.get('u'), 'no full URL when a relative path will do');
  }
  assert.ok(await validCdnStamp(KEY, scopeMessage('vidbolt', 'https://img.rousav.tech/media/a/'), [...stamps][0]));
});

test('a URI outside the playlist directory gets its own scope', async () => {
  const base = 'https://img.rousav.tech/media/a/index.m3u8';
  const out = await rewriteCinemaPlaylist(
    '#EXTM3U\nhttps://other.example/deep/x.ts\n',
    base,
    `${HOST}/proxyMegavidHls`,
    'vidbolt',
    KEY,
  );
  const u = new URL(out.split('\n').find((l) => l.startsWith('https://')));
  assert.equal(u.searchParams.get('d'), 'https://other.example/deep/');
});

test('rewritePlaylistWithHosts keeps Megavid allowlisted and stamps MegaPlay', async () => {
  const base = 'https://megavid.buzz/v.m3u8';
  const out = await rewritePlaylistWithHosts(
    '#EXTM3U\n#EXTINF:8,\nhttps://s-90.megavid.se/a.ts\nhttps://evil.example/b.ts\n',
    base,
    `${HOST}/proxyMegavidHls`,
    isMegavidHost,
    null,
  );
  assert.ok(out.includes('s-90.megavid.se'));
  assert.ok(out.includes('evil.example'), 'unlisted host left untouched without a stamp');

  const stamped = await rewritePlaylistWithHosts(
    '#EXTM3U\n#EXTINF:8,\nhttps://wintergrove.space/a.jpg\n',
    'https://fetch.nexabloom.top/v.m3u8',
    `${HOST}/proxyMegavidHls`,
    isMegaPlayHost,
    KEY,
  );
  assert.ok(stamped.includes('&s='), 'rotating MegaPlay CDN gets stamped');
});

test('resolvePlaylistUrl keeps same-origin api_key and never leaks it cross-origin', () => {
  const base = 'https://img.rousav.tech/media/abc/index.m3u8?api_key=secret123';
  assert.equal(
    resolvePlaylistUrl('tiles.m3u8', base),
    'https://img.rousav.tech/media/abc/tiles.m3u8?api_key=secret123',
  );
  assert.equal(
    resolvePlaylistUrl('https://other.example/tiles.m3u8', base),
    'https://other.example/tiles.m3u8',
  );
  assert.equal(resolvePlaylistUrl('#EXTM3U', base), null);
});

test('playlistUris and playlistDuration behave as before', () => {
  const text = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nv1.m3u8\n#EXTINF:8.5,\nseg1.ts\n#EXTINF:1.5,\nseg2.ts\n';
  assert.deepEqual(playlistUris(text, 'https://x.example/a/m.m3u8', { variantsOnly: true }), [
    'https://x.example/a/v1.m3u8',
  ]);
  assert.equal(playlistUris(text, 'https://x.example/a/m.m3u8').length, 3);
  assert.equal(playlistDuration(text), 10);
  assert.equal(MIN_MEGAVID_SECONDS, 120);
});

test('firstM3u8 digs nested urls out of API payloads', () => {
  const found = firstM3u8({ a: [{ b: 'https://x.example/v.m3u8?t=1' }], c: 'https://y.example/w.m3u8' });
  assert.deepEqual(found, ['https://x.example/v.m3u8?t=1', 'https://y.example/w.m3u8']);
});

test('assertPlayableHead rejects images and HTML posing as segments', () => {
  assert.doesNotThrow(() => assertPlayableHead(new Uint8Array([0x47]), 'https://x.example/a.ts', 'segment'));
  assert.throws(() => assertPlayableHead(new Uint8Array([0x3c]), 'https://x.example/a.ts', 'segment'));
  assert.doesNotThrow(() => assertPlayableHead(new Uint8Array([0x47]), 'https://x.example/tiles/0.png', 'segment'));
  assert.throws(() => assertPlayableHead(new Uint8Array([0x89, 0x50]), 'https://x.example/tiles/0.png', 'segment'));
  assert.throws(() => assertPlayableHead(new Uint8Array([0xff]), 'https://x.example/seg.jpg', 'segment'));
});

test('selectCinemaSubtitleTracks ranks English first, dedupes mirrors, skips srt', () => {
  const tracks = selectCinemaSubtitleTracks([
    { label: 'Arabic', file: 'https://cache.vdrk.site/v1/ar.vtt', type: 'vtt' },
    { label: 'Brazilian2', file: 'https://cache.vdrk.site/v1/br2.vtt', type: 'vtt' },
    { label: 'Brazilian3', file: 'https://cache.vdrk.site/v1/br3.vtt', type: 'vtt' },
    { label: 'English Hi3', file: 'https://cache.vdrk.site/v1/en_hi.vtt', type: 'vtt' },
    { label: 'English', file: 'https://cache.vdrk.site/v1/en.vtt', type: 'vtt' },
    { label: 'French', file: 'https://cache.vdrk.site/v1/fr.srt', type: 'srt' },
  ]);
  assert.deepEqual(tracks.map((t) => t.label), ['English', 'English Hi3', 'Arabic', 'Brazilian2']);
});

test('failHtml notifies only when asked, and stays marker-clean for Anime', () => {
  const plain = failHtml('Episode unavailable', 'No stream found');
  assert.ok(!plain.includes('<script'));
  assert.ok(plain.includes(NO_SOURCE_MARKER));

  const cinema = failHtml('Episode unavailable', 'No stream found', { notify: true });
  assert.ok(cinema.includes('animex-content-error'));
  for (const code of [...cinema.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1])) {
    new vm.Script(code);
  }
});

test('hlsPlayerHtml escapes, keeps the failover marker out, and its script runs', () => {
  const html = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: '<b>Hi</b>',
    tracks: [{ file: 'https://x/en.vtt', label: 'English' }],
    ep: 3,
  });
  assert.ok(!html.includes('<b>Hi</b>'));
  assert.ok(html.includes('en.vtt'));
  assert.ok(!html.includes(NO_SOURCE_MARKER), 'a healthy player must not trip the probe');
  assert.ok(html.includes('animex-content-error'));
  assert.ok(html.includes('.ov[hidden]{display:none'));

  const code = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];
  new vm.Script(code);

  // It must actually start the stream, not just parse.
  const calls = { loadSource: [], attachMedia: [], handlers: {} };
  const element = () => ({
    style: {}, hidden: true, src: '', currentTime: 0, duration: NaN, listeners: {},
    addEventListener(e, h) { (this.listeners[e] ||= []).push(h); },
    play() {},
  });
  const els = { v: element(), boot: element(), tapw: element(), tap: element(), dead: element() };
  function Hls() {}
  Hls.isSupported = () => true;
  Hls.Events = { ERROR: 'error', MANIFEST_PARSED: 'manifestParsed' };
  Hls.ErrorTypes = { NETWORK_ERROR: 'networkError', MEDIA_ERROR: 'mediaError' };
  Hls.prototype.on = function (e, h) { calls.handlers[e] = h; };
  Hls.prototype.loadSource = (u) => calls.loadSource.push(u);
  Hls.prototype.attachMedia = (m) => calls.attachMedia.push(m);
  Hls.prototype.destroy = () => {};
  Hls.prototype.startLoad = () => {};
  Hls.prototype.recoverMediaError = () => {};
  const win = element();
  win.Hls = Hls;
  win.location = { search: '', origin: 'https://everglow-stream.example.workers.dev', pathname: '/proxyAnime' };
  win.parent = {};
  win.parent.postMessage = () => {};
  const ctx = {
    window: win, Hls, URLSearchParams, Date,
    document: { getElementById: (id) => els[id] || null },
  };
  vm.createContext(ctx);
  new vm.Script(code).runInContext(ctx);
  assert.deepEqual(calls.loadSource, ['https://x/y.m3u8']);
  assert.equal(calls.attachMedia.length, 1);
});

test('decryptMegaPlayPayload matches the Node implementation byte for byte', async () => {
  // Same ciphertext the Firebase test pins: proves the WebCrypto port is
  // decrypting identically, not merely without throwing.
  const enc =
    'wdeBruh3qqn_i5wUNnyaPcXqidp1UWP84FfPHzGyKXA2hDZBfMCmZ4FLvs7_pQuH549Eptax8UOjAJyRIZfrRhUGUKy9OBeGh2yB_-m_JLAlLnWTLzYZC3_C5I4ltveYoiaU66Do9RgI9bCetmk_o87-sd66brXnWV1MbjhLnjw';
  const data = await decryptMegaPlayPayload(enc);
  assert.equal(
    data.file,
    'https://fetch.nexabloom.top/anime/f899139df5e1059396431415e770c6dd/61b87186ab260d05003427e16ccf5657/master.m3u8',
  );
});

test('makeMegaPlayToken signs exp|path with HMAC-SHA256', async () => {
  const path = 'f899139df5e1059396431415e770c6dd/61b87186ab260d05003427e16ccf5657';
  const token = await makeMegaPlayToken(path);
  const [payload, sig] = token.split('.');
  assert.ok(payload && sig);
  const raw = Buffer.from(payload, 'base64url').toString('utf8');
  assert.ok(raw.endsWith(`|${path}`));
  assert.ok(Number(raw.split('|')[0]) > Date.now() / 1000);
});

test('verifyStream accepts a healthy stream and rejects dead playlists', async () => {
  const realFetch = globalThis.fetch;
  const segOk = { ok: true, status: 200, arrayBuffer: async () => new Uint8Array([0x47, 0, 0, 0]).buffer };
  try {
    globalThis.fetch = async (url) => {
      const u = String(url);
      if (u.includes('master.m3u8')) {
        return { ok: true, status: 200, text: async () => '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nhttps://fetch.nexabloom.top/v.m3u8\n' };
      }
      if (u.includes('v.m3u8')) {
        return { ok: true, status: 200, text: async () => '#EXTM3U\n#EXTINF:200,\nhttps://7v8gl.eclipseharbor.space/seg.jpg\n' };
      }
      return segOk;
    };
    await assert.doesNotReject(verifyStream('https://fetch.nexabloom.top/master.m3u8'));

    globalThis.fetch = async () => ({ ok: false, status: 404 });
    await assert.rejects(verifyStream('https://fetch.nexabloom.top/master.m3u8'), /megaplay/);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('resolveCinema resolves a movie and stamps the player + subtitles', async () => {
  const realFetch = globalThis.fetch;
  const segOk = { ok: true, status: 200, arrayBuffer: async () => new Uint8Array([0x47, 0, 0, 0]).buffer };
  try {
    globalThis.fetch = async (url) => {
      const u = String(url);
      if (u.startsWith('https://fmov.my/api/stream/movie/603')) {
        return {
          ok: true, status: 200,
          json: async () => ({
            success: true,
            sources: [{ url: '/api/proxy?url=master.m3u8', type: 'hls' }],
            subtitles: [{ label: 'English', file: 'https://cache.vdrk.site/en.vtt', type: 'vtt' }],
          }),
        };
      }
      if (u.includes('master.m3u8')) {
        return { ok: true, status: 200, text: async () => '#EXTM3U\n#EXTINF:200,\n/api/proxy?url=seg1.ts\n' };
      }
      if (u.startsWith('https://vidbolt.xyz/')) return { ok: false, status: 502 };
      return segOk;
    };
    const out = await resolveCinema('movie', 603, 1, 1, `${HOST}/proxyMegavidHls`, KEY);
    const src = new URL(out.src);
    assert.equal(src.pathname, '/proxyMegavidHls');
    assert.equal(src.searchParams.get('p'), 'fmov');
    const scope = src.searchParams.get('d');
    const stamp = src.searchParams.get('s');
    assert.equal(scope, 'https://fmov.my/api/');
    assert.ok(await validCdnStamp(KEY, scopeMessage('fmov', scope), stamp));
    assert.ok(upstreamOf(src).startsWith(scope));
    assert.equal(out.title, 'Movie');
    assert.equal(out.tracks.length, 1);
    assert.ok(out.tracks[0].file.includes('p=fmov'));
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('resolveCinema gives up inside its budget so the app can fall back to CineSrc', async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = () => new Promise(() => {});
  try {
    const started = Date.now();
    await assert.rejects(
      resolveCinema('movie', 603, 1, 1, `${HOST}/proxyMegavidHls`, KEY, { budgetMs: 50 }),
      /no playable stream/,
    );
    assert.ok(Date.now() - started < 1000);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('resolveCinema fails closed without a stamp key', async () => {
  await assert.rejects(
    resolveCinema('movie', 603, 1, 1, `${HOST}/proxyMegavidHls`, null),
    /stamp key unavailable/,
  );
});

// ─── Worker request handling ─────────────────────────────

function hlsRequest(query) {
  const u = new URL(`${HOST}/proxyMegavidHls`);
  for (const [k, v] of Object.entries(query)) u.searchParams.set(k, v);
  return new Request(u.toString());
}

test('the Worker refuses to relay URLs it did not stamp (no open proxy)', async () => {
  const realFetch = globalThis.fetch;
  const fetched = [];
  globalThis.fetch = async (url) => {
    fetched.push(String(url));
    return new Response('<html>example</html>', { status: 200, headers: { 'content-type': 'text/html' } });
  };
  try {
    const relay = `https://fmov.my/api/proxy?url=${encodeURIComponent('https://example.com/')}`;
    const cases = [
      { u: relay },
      { u: relay, p: 'fmov' },
      { u: relay, p: 'fmov', s: 'f'.repeat(64) },
      // A Cinema stamp cannot be reused as a bare MegaPlay stamp, so
      // stripping `p` never upgrades a Cinema URL to the MegaPlay path.
      // A Cinema stamp lifted onto another provider, or reused with a scope
      // it was not minted for, must not open the relay.
      { u: relay, p: 'vidbolt', d: 'https://fmov.my/api/', s: await cdnStamp(KEY, scopeMessage('fmov', 'https://fmov.my/api/')) },
      { u: relay, p: 'fmov', d: 'https://evil.example/', s: await cdnStamp(KEY, scopeMessage('fmov', 'https://evil.example/')) },
      { u: 'https://img.rousav.tech/media/a/index.m3u8' },
      { u: 'http://fmov.my/api/proxy' },
    ];
    for (const q of cases) {
      const res = await handleProxyHls(hlsRequest(q), { CDN_STAMP_KEY: KEY });
      assert.equal(res.status, 400, JSON.stringify(q));
    }
    assert.deepEqual(fetched, [], 'nothing reached an upstream');

    // A genuine MegaPlay stamp still works: that path is how its rotating
    // CDNs are reached, and only this Worker can mint one.
    const rotating = 'https://wintergrove.space/seg.jpg';
    const megaplayScope = 'https://wintergrove.space/';
    const ok = await handleProxyHls(
      hlsRequest({
        u: rotating,
        p: 'megaplay',
        d: megaplayScope,
        s: await cdnStamp(KEY, scopeMessage('megaplay', megaplayScope)),
      }),
      { CDN_STAMP_KEY: KEY },
    );
    assert.equal(ok.status, 200);
    assert.deepEqual(fetched, [rotating]);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('the Worker serves a stamped Cinema playlist with that provider headers', async () => {
  const realFetch = globalThis.fetch;
  let seen;
  globalThis.fetch = async (url, init) => {
    seen = { url: String(url), headers: init.headers };
    return new Response('#EXTM3U\n#EXTINF:8,\n/api/proxy?url=seg1.ts\n', {
      status: 200,
      headers: { 'content-type': 'application/vnd.apple.mpegurl' },
    });
  };
  try {
    const master = 'https://fmov.my/api/proxy?url=https%3A%2F%2Fcdn.example%2Fmaster.m3u8';
    const signed = new URL(await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, master, 'fmov', KEY));
    const res = await handleProxyHls(
      hlsRequest(Object.fromEntries(signed.searchParams)),
      { CDN_STAMP_KEY: KEY },
    );
    assert.equal(res.status, 200);
    assert.equal(seen.url, master);
    assert.equal(seen.headers.Origin, FMOV_ORIGIN);
    const body = await res.text();
    const child = new URL(body.split('\n').find((l) => l.startsWith('https://')));
    assert.equal(child.searchParams.get('p'), 'fmov');
    assert.equal(upstreamOf(child), 'https://fmov.my/api/proxy?url=seg1.ts');
    assert.ok(
      await validCdnStamp(
        KEY,
        scopeMessage('fmov', child.searchParams.get('d')),
        child.searchParams.get('s'),
      ),
    );
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('the Worker streams segments through with the upstream status and range', async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(new Uint8Array([0x47, 1, 2, 3]), {
      status: 206,
      headers: { 'content-type': 'video/mp2t', 'content-range': 'bytes 0-3/100', 'accept-ranges': 'bytes' },
    });
  try {
    const seg = 'https://fmov.my/api/proxy?url=seg1.ts';
    const signed = new URL(await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, seg, 'fmov', KEY));
    const req = new Request(`${signed.toString()}`, { headers: { Range: 'bytes=0-3' } });
    const res = await handleProxyHls(req, { CDN_STAMP_KEY: KEY });
    assert.equal(res.status, 206);
    assert.equal(res.headers.get('content-range'), 'bytes 0-3/100');
    assert.equal(res.headers.get('content-type'), 'video/mp2t');
    assert.equal((await res.arrayBuffer()).byteLength, 4);
  } finally {
    globalThis.fetch = realFetch;
  }
});
