import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';

import {
  assertPlayableHead,
  cdnStamp,
  cinemaHeaders,
  cinemaProxyUrl,
  scopeMessage,
  stampParts,
  megaplayProxyUrl,
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
import { handleProxyHls, handleProxyAnime } from './worker.js';

const KEY = 'demo-cdn-key';
const HOST = 'https://everglow-stream.example.workers.dev';

/** The upstream URL a proxy URL points at, in any shape: `u` (one-off),
 *  `d` + `r` (direct, relative to the signed folder), or `rp` + `d` + `r`
 *  (a relay endpoint fetching a URL under the signed folder). */
function upstreamOf(proxyUrl) {
  const u = proxyUrl instanceof URL ? proxyUrl : new URL(proxyUrl);
  const full = u.searchParams.get('u');
  if (full) return full;
  const d = u.searchParams.get('d') || '';
  const rp = u.searchParams.get('rp');
  if (rp) {
    const rq = u.searchParams.get('rq');
    return `${rp}?url=${encodeURIComponent(d)}${u.searchParams.get('rr') || ''}${rq ? `&${rq}` : ''}`;
  }
  return d + (u.searchParams.get('r') || '');
}

/** fmov's open relay and a CDN folder it fetches from, as real films use. */
const RELAY = 'https://fmov.my/api/proxy';
const CDN = 'https://srv323.truawk.cyou/aes/0/abc/film.mp4/';
const relayOf = (inner) => `${RELAY}?url=${encodeURIComponent(inner)}`;

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

test('stampParts splits relays and refuses URLs that must never be stamped', () => {
  assert.deepEqual(stampParts(relayOf(`${CDN}index.m3u8`)), { relay: RELAY, inner: `${CDN}index.m3u8` });
  const direct = 'https://img.rousav.tech/media/a/index.m3u8?api_key=k';
  assert.deepEqual(stampParts(direct), { relay: '', inner: direct });
  const bridge = `https://dash-hls-bridge.someone.workers.dev/?url=${encodeURIComponent(`${CDN}m.m3u8`)}`;
  assert.equal(stampParts(bridge).relay, 'https://dash-hls-bridge.someone.workers.dev/');
  // Never stampable: a relay host in direct mode, a nested relay, a URL-valued param.
  assert.equal(stampParts('https://fmov.my/api/proxy?url=master.m3u8'), null);
  assert.equal(stampParts('https://fmov.my/api/'), null);
  assert.equal(stampParts(relayOf(relayOf('https://example.com/'))), null);
  assert.equal(stampParts('https://cdn.example/x.ts?next=https%3A%2F%2Fevil.example%2F'), null);
});

test('Cinema stamps bind provider + relay endpoint + inner folder', async () => {
  const url = relayOf(`${CDN}index.m3u8`);
  const proxied = new URL(await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, url, 'fmov', KEY));
  assert.equal(upstreamOf(proxied), url);
  assert.equal(proxied.searchParams.get('d'), CDN);
  assert.equal(proxied.searchParams.get('rp'), RELAY);
  const s = proxied.searchParams.get('s');
  assert.ok(await validCdnStamp(KEY, scopeMessage('fmov', RELAY, CDN), s));
  assert.equal(await validCdnStamp(KEY, scopeMessage('vidbolt', RELAY, CDN), s), false);
  assert.equal(await validCdnStamp(KEY, scopeMessage('fmov', '', CDN), s), false);
  assert.equal(await validCdnStamp(KEY, scopeMessage('fmov', RELAY, 'https://fmov.my/api/'), s), false);
  assert.equal(await validCdnStamp('other-key', scopeMessage('fmov', RELAY, CDN), s), false);
});

test('urlScope returns the containing directory', () => {
  assert.equal(urlScope('https://a.example/x/y/index.m3u8'), 'https://a.example/x/y/');
  assert.equal(urlScope('https://a.example/x/y/tiles/0.png'), 'https://a.example/x/y/tiles/');
  assert.equal(urlScope('https://a.example/index.m3u8'), 'https://a.example/');
});

test('rewriteCinemaPlaylist stamps a whole relayed film with ONE signature', async () => {
  const segs = Array.from({ length: 400 }, (_, i) => `/api/proxy?url=${encodeURIComponent(`${CDN}seg-${i}.ts`)}`).join('\n');
  const out = await rewriteCinemaPlaylist(`#EXTM3U\n${segs}\n`, relayOf(`${CDN}index.m3u8`), `${HOST}/proxyMegavidHls`, 'fmov', KEY);
  const urls = [...out.matchAll(/https:\/\/[^?"\s]+\/proxyMegavidHls\?[^"\s]+/g)].map((m) => new URL(m[0]));
  assert.equal(urls.length, 400);
  assert.equal(new Set(urls.map((u) => u.searchParams.get('s'))).size, 1);
  urls.forEach((u, i) => {
    assert.equal(upstreamOf(u), relayOf(`${CDN}seg-${i}.ts`));
    assert.ok(u.searchParams.get('rr') && u.searchParams.get('rp') && !u.searchParams.get('u'), 'compact form');
  });
  assert.ok(await validCdnStamp(KEY, scopeMessage('fmov', RELAY, CDN), urls[0].searchParams.get('s')));
});

test('vector-shaped relay segments (other folder, extra params) still use one stamp and the compact form', async () => {
  const seg = (i) => `/api/proxy?url=${encodeURIComponent(`https://cdn2.example/content/ab/cd/page-${i}.html`)}&referer=${encodeURIComponent('https://ref.example/')}&va=1`;
  const text = `#EXTM3U\n${Array.from({ length: 50 }, (_, i) => seg(i)).join('\n')}\n`;
  const out = await rewriteCinemaPlaylist(text, relayOf('https://cdn2.example/pl/list.m3u8'), `${HOST}/proxyMegavidHls`, 'fmov', KEY);
  const urls = out.split('\n').filter((l) => l.startsWith(HOST)).map((l) => new URL(l));
  assert.equal(urls.length, 50);
  assert.equal(new Set(urls.map((u) => u.searchParams.get('s'))).size, 1);
  urls.forEach((u, i) => {
    assert.ok(!u.searchParams.get('u'), 'compact');
    assert.equal(upstreamOf(u), `https://fmov.my${seg(i)}`);
    assert.equal(u.searchParams.get('d'), 'https://cdn2.example/content/ab/cd/');
  });
});

test('a direct playlist keeps api_key and stamps its own folder', async () => {
  const base = 'https://img.rousav.tech/media/a/index.m3u8?api_key=k1';
  const out = await rewriteCinemaPlaylist('#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,URI="track_en.m3u8"\nseg0.ts\n', base, `${HOST}/proxyMegavidHls`, 'vidbolt', KEY);
  const urls = [...out.matchAll(/https:\/\/[^?"\s]+\/proxyMegavidHls\?[^"\s]+/g)].map((m) => new URL(m[0]));
  assert.equal(urls.length, 2);
  for (const u of urls) {
    assert.equal(u.searchParams.get('d'), 'https://img.rousav.tech/media/a/');
    assert.ok(upstreamOf(u).includes('api_key=k1'));
  }
});

test('a URI outside the playlist directory gets its own scope; a relay URI is never folder-stamped', async () => {
  const out = await rewriteCinemaPlaylist(
    '#EXTM3U\nhttps://other.example/deep/x.ts\nhttps://fmov.my/api/proxy?url=y.ts\n',
    'https://img.rousav.tech/media/a/index.m3u8',
    `${HOST}/proxyMegavidHls`,
    'vidbolt',
    KEY,
  );
  const lines = out.split('\n');
  assert.equal(new URL(lines[1]).searchParams.get('d'), 'https://other.example/deep/');
  assert.equal(lines[2], 'https://fmov.my/api/proxy?url=y.ts', 'left unstamped, so the proxy refuses it');
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
            sources: [{ url: `/api/proxy?url=${encodeURIComponent(`${CDN}index.m3u8`)}`, type: 'hls' }],
            subtitles: [{ label: 'English', file: 'https://cache.vdrk.site/en.vtt', type: 'vtt' }],
          }),
        };
      }
      if (u.includes('index.m3u8')) {
        return { ok: true, status: 200, text: async () => `#EXTM3U\n#EXTINF:200,\n/api/proxy?url=${encodeURIComponent(`${CDN}seg1.ts`)}\n` };
      }
      if (u.startsWith('https://vidbolt.xyz/')) return { ok: false, status: 502 };
      return segOk;
    };
    const out = await resolveCinema('movie', 603, 1, 1, `${HOST}/proxyMegavidHls`, KEY);
    const src = new URL(out.src);
    assert.equal(src.pathname, '/proxyMegavidHls');
    assert.equal(src.searchParams.get('p'), 'fmov');
    assert.equal(src.searchParams.get('d'), CDN);
    assert.equal(src.searchParams.get('rp'), RELAY);
    assert.equal(upstreamOf(src), relayOf(`${CDN}index.m3u8`));
    assert.ok(await validCdnStamp(KEY, scopeMessage('fmov', RELAY, CDN), src.searchParams.get('s')));
    assert.equal(out.title, 'Movie');
    assert.equal(out.tracks.length, 1);
    assert.equal(new URL(out.tracks[0].file).searchParams.get('d'), 'https://cache.vdrk.site/');
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('the Worker answers format=json with the resolved stream for the watch party', async () => {
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
            sources: [{ url: `/api/proxy?url=${encodeURIComponent(`${CDN}index.m3u8`)}`, type: 'hls' }],
            subtitles: [{ label: 'English', file: 'https://cache.vdrk.site/en.vtt', type: 'vtt' }],
          }),
        };
      }
      if (u.includes('index.m3u8')) {
        return { ok: true, status: 200, text: async () => `#EXTM3U\n#EXTINF:200,\n/api/proxy?url=${encodeURIComponent(`${CDN}seg1.ts`)}\n` };
      }
      if (u.startsWith('https://vidbolt.xyz/')) return { ok: false, status: 502 };
      return segOk;
    };
    const u = new URL(`${HOST}/proxyAnime`);
    u.searchParams.set('source', 'cinema');
    u.searchParams.set('type', 'movie');
    u.searchParams.set('tmdbId', '603');
    u.searchParams.set('title', 'Demo Film');
    u.searchParams.set('format', 'json');
    const res = await handleProxyAnime(new Request(u.toString()), { CDN_STAMP_KEY: KEY });
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /application\/json/);
    const body = await res.json();
    assert.equal(body.title, 'Demo Film');
    assert.equal(body.tracks.length, 1);
    assert.equal(body.tracks[0].label, 'English');
    const src = new URL(body.src);
    assert.equal(src.pathname, '/proxyMegavidHls');
    assert.equal(upstreamOf(src), relayOf(`${CDN}index.m3u8`));
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

test('the Worker refuses every way of pointing a stamp at a URL we never issued', async () => {
  const realFetch = globalThis.fetch;
  const fetched = [];
  globalThis.fetch = async (url) => {
    fetched.push(String(url));
    return new Response('<html>example</html>', { status: 200, headers: { 'content-type': 'text/html' } });
  };
  try {
    const evilRelay = relayOf('https://example.com/');
    // The exact attack from review: lift a real stamp from a public player page.
    const real = new URL(await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, relayOf(`${CDN}index.m3u8`), 'fmov', KEY));
    const lifted = { p: 'fmov', d: real.searchParams.get('d'), s: real.searchParams.get('s') };
    const relayFolder = 'https://fmov.my/api/';
    const cases = [
      { u: evilRelay },
      { u: evilRelay, p: 'fmov', d: relayFolder, s: 'f'.repeat(16) },
      { ...lifted, u: evilRelay },
      { ...lifted, u: relayOf(`${CDN}../../../x`) },
      { ...lifted, rp: RELAY, rr: '..%2F..%2F..%2Fx' },
      { ...lifted, rp: 'https://evil.example/proxy', rr: 'index.m3u8' },
      { ...lifted, r: 'index.m3u8' },
      { ...lifted, p: 'vidbolt', rp: RELAY, rr: 'index.m3u8' },
      // A second url= or an unknown URL-valued param: which one does fmov honour?
      { ...lifted, rp: RELAY, rr: 'index.m3u8', rq: `url=${encodeURIComponent('https://example.com/')}` },
      { ...lifted, rp: RELAY, rr: 'index.m3u8', rq: `target=${encodeURIComponent('https://example.com/')}` },
      { ...lifted, u: `${relayOf(`${CDN}index.m3u8`)}&url=${encodeURIComponent('https://example.com/')}` },
      { ...lifted, u: relayOf(relayOf('https://example.com/')) },
      // A folder stamp on the relay host itself, if one were ever minted.
      { u: evilRelay, p: 'fmov', d: relayFolder, s: await cdnStamp(KEY, scopeMessage('fmov', '', relayFolder)) },
      { u: evilRelay, p: 'fmov', d: relayFolder, s: await cdnStamp(KEY, scopeMessage('fmov', RELAY, relayFolder)) },
      { u: 'https://img.rousav.tech/media/a/index.m3u8' },
      { u: 'http://fmov.my/api/proxy' },
    ];
    for (const q of cases) {
      const res = await handleProxyHls(hlsRequest(q), { CDN_STAMP_KEY: KEY });
      assert.equal(res.status, 400, JSON.stringify(q));
    }
    assert.deepEqual(fetched, [], 'nothing reached an upstream');

    // The genuine stamp still works, and only for the URL it was issued for.
    const ok = await handleProxyHls(new Request(real.toString()), { CDN_STAMP_KEY: KEY });
    assert.equal(ok.status, 200);
    assert.deepEqual(fetched, [relayOf(`${CDN}index.m3u8`)]);

    // A genuine MegaPlay stamp for a rotating CDN still works too.
    fetched.length = 0;
    const rotating = 'https://wintergrove.space/seg.jpg';
    const mp = await megaplayProxyUrl(`${HOST}/proxyMegavidHls`, rotating, KEY);
    const mpRes = await handleProxyHls(new Request(mp), { CDN_STAMP_KEY: KEY });
    assert.equal(mpRes.status, 200);
    assert.deepEqual(fetched, [rotating]);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('the Worker serves a stamped relayed playlist with that provider headers', async () => {
  const realFetch = globalThis.fetch;
  let seen;
  globalThis.fetch = async (url, init) => {
    seen = { url: String(url), headers: init.headers };
    return new Response(`#EXTM3U\n#EXTINF:8,\n/api/proxy?url=${encodeURIComponent(`${CDN}seg1.ts`)}\n`, {
      status: 200,
      headers: { 'content-type': 'application/vnd.apple.mpegurl' },
    });
  };
  try {
    const master = relayOf(`${CDN}master.m3u8`);
    const signed = await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, master, 'fmov', KEY);
    const res = await handleProxyHls(new Request(signed), { CDN_STAMP_KEY: KEY });
    assert.equal(res.status, 200);
    assert.equal(seen.url, master);
    assert.equal(seen.headers.Origin, FMOV_ORIGIN);
    const child = new URL((await res.text()).split('\n').find((l) => l.startsWith('https://')));
    assert.equal(upstreamOf(child), relayOf(`${CDN}seg1.ts`));
    assert.ok(await validCdnStamp(KEY, scopeMessage('fmov', RELAY, CDN), child.searchParams.get('s')));
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
    const signed = await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, relayOf(`${CDN}seg1.ts`), 'fmov', KEY);
    const res = await handleProxyHls(new Request(signed, { headers: { Range: 'bytes=0-3' } }), { CDN_STAMP_KEY: KEY });
    assert.equal(res.status, 206);
    assert.equal(res.headers.get('content-range'), 'bytes 0-3/100');
    assert.equal((await res.arrayBuffer()).byteLength, 4);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('an unstamped MegaPlay master (allowlisted host) rewrites to playable links', async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(
      '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nindex-f1-v1-a1.m3u8\n#EXT-X-I-FRAME-STREAM-INF:URI="iframes.m3u8"\nhttps://wintergrove.space/seg.jpg\n',
      { status: 200, headers: { 'content-type': 'application/vnd.apple.mpegurl' } },
    );
  try {
    const master = 'https://fetch.nexabloom.top/anime/a/b/master.m3u8?token=t';
    const res = await handleProxyHls(hlsRequest({ u: master }), { CDN_STAMP_KEY: KEY });
    assert.equal(res.status, 200);
    const links = [...(await res.text()).matchAll(/https:\/\/[^"\s]+proxyMegavidHls\?[^"\s]+/g)].map((m) => new URL(m[0]));
    assert.equal(links.length, 3);
    // Allowlisted MegaPlay hosts: plain links, no stamp needed.
    assert.equal(links[0].searchParams.get('u'), 'https://fetch.nexabloom.top/anime/a/b/index-f1-v1-a1.m3u8');
    assert.equal(links[0].searchParams.get('s'), null);
    // A rotating CDN: stamped as MegaPlay, and the stamp is real.
    const rot = links[2];
    assert.equal(rot.searchParams.get('p'), 'megaplay');
    assert.ok(await validCdnStamp(KEY, scopeMessage('megaplay', '', 'https://wintergrove.space/'), rot.searchParams.get('s')));
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('Cinema player drops SUB/DUB and Episodes; anime keeps them', () => {
  const cinema = hlsPlayerHtml({ src: 'https://x/y.m3u8', title: 'Fight Club', kind: 'cinema' });
  const anime = hlsPlayerHtml({ src: 'https://x/y.m3u8', title: 'Episode 1', ep: 1 });
  for (const id of ['btn-sub', 'btn-dub', 'btn-eps']) {
    assert.ok(!cinema.includes(`id="${id}"`), `cinema has no ${id}`);
    assert.ok(anime.includes(`id="${id}"`), `anime keeps ${id}`);
  }
  assert.ok(cinema.includes('<span id="hud-title">Fight Club</span>'));
  const code = [...cinema.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
  for (const c of code) new vm.Script(c);
});

test('only the default subtitle track drives the captions (no random language)', () => {
  const html = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Movie',
    kind: 'cinema',
    tracks: [{ file: 'https://x/en.vtt', label: 'English' }, { file: 'https://x/is.vtt', label: 'Icelandic' }],
  });
  const code = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]).pop();
  const el = () => ({ style: {}, hidden: true, classList: { add() {}, remove() {}, toggle() {} }, listeners: {},
    addEventListener(e, h) { (this.listeners[e] ||= []).push(h); }, textContent: '' });
  const tracks = [{ mode: 'showing' }, { mode: 'showing' }];
  const trackEls = [{ hasAttribute: (a) => a === 'default' }, { hasAttribute: () => false }];
  const v = Object.assign(el(), { currentTime: 0, duration: NaN, paused: true, textTracks: tracks,
    querySelectorAll: () => trackEls, play() { return Promise.resolve(); } });
  const subTxt = el();
  const els = { v, 'sub-txt': subTxt, boot: el(), tapw: el(), tap: el(), dead: el() };
  function Hls() {}
  Hls.isSupported = () => true;
  Hls.Events = { ERROR: 'e', MANIFEST_PARSED: 'm' };
  Hls.ErrorTypes = {};
  Hls.prototype.on = () => {};
  Hls.prototype.loadSource = () => {};
  Hls.prototype.attachMedia = () => {};
  const win = el();
  Object.assign(win, { Hls, location: { search: '', origin: 'https://w.example', pathname: '/proxyAnime' }, parent: { postMessage() {} } });
  const ctx = { window: win, Hls, URLSearchParams, Date, document: { getElementById: (id) => els[id] || null, body: el() } };
  vm.createContext(ctx);
  new vm.Script(code).runInContext(ctx);
  for (const h of v.listeners.loadedmetadata || []) h();
  assert.deepEqual(tracks.map((t) => t.mode), ['hidden', 'disabled']);
  assert.equal(typeof tracks[0].oncuechange, 'function');
  assert.equal(tracks[1].oncuechange, null, 'Icelandic can no longer overwrite English');
});

/** Runs the player script in a fake DOM and returns the handles it built. */
function runPlayerDom({ tracks = [], trackEls = [] } = {}) {
  const html = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Movie',
    kind: 'cinema',
    tracks: tracks.map((t) => ({ file: `https://x/${t}.vtt`, label: t })),
  });
  const code = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]).pop();
  const el = () => ({
    style: {}, hidden: false, textContent: '', innerHTML: '', children: [],
    classList: { _s: new Set(), add(c) { this._s.add(c); }, remove(c) { this._s.delete(c); }, toggle(c, v) { v ? this._s.add(c) : this._s.delete(c); }, contains(c) { return this._s.has(c); } },
    listeners: {}, addEventListener(e, h) { (this.listeners[e] ||= []).push(h); },
    appendChild(c) { this.children.push(c); },
    getBoundingClientRect: () => ({ x: 0, y: 0, width: 100, height: 10, left: 0 }),
    setAttribute() {}, getAttribute() { return null; }, hasAttribute() { return false; },
  });
  const textTracks = tracks.map((label) => ({ label, mode: 'showing', oncuechange: null }));
  textTracks.addEventListener = () => {};
  const v = Object.assign(el(), {
    currentTime: 0, duration: 100, paused: true, textTracks,
    querySelectorAll: () => trackEls,
    play: () => Promise.resolve(),
  });
  const els = { v, 'sub-txt': el(), boot: el(), tapw: el(), tap: el(), dead: el(),
    'btn-cc': el(), 'btn-cc-lang': el(), 'cc-menu': el() };
  function Hls() {}
  Hls.isSupported = () => true;
  Hls.Events = { ERROR: 'e', MANIFEST_PARSED: 'm' };
  Hls.ErrorTypes = {};
  Hls.prototype.on = () => {};
  Hls.prototype.loadSource = () => {};
  Hls.prototype.attachMedia = () => {};
  const win = el();
  Object.assign(win, { Hls, location: { search: '', origin: 'https://w.example', pathname: '/proxyAnime' }, parent: { postMessage() {} } });
  const doc = { getElementById: (id) => els[id] || null, body: el(), createElement: () => el() };
  const ctx = { window: win, Hls, URLSearchParams, Date, document: doc };
  vm.createContext(ctx);
  new vm.Script(code).runInContext(ctx);
  for (const h of v.listeners.loadedmetadata || []) h();
  return { els, v, html };
}

test('CC is hidden when the source has no subtitles', () => {
  const none = hlsPlayerHtml({ src: 'https://x/y.m3u8', title: 'Movie', kind: 'cinema' });
  assert.match(none, /id="btn-cc" hidden/, 'no tracks, so no CC button');
  const some = hlsPlayerHtml({
    src: 'https://x/y.m3u8', title: 'Movie', kind: 'cinema',
    tracks: [{ file: 'https://x/en.vtt', label: 'English' }],
  });
  assert.doesNotMatch(some, /id="btn-cc" hidden/);
  // And the script hides it at runtime too, for sources that add tracks late.
  const { els } = runPlayerDom({ tracks: [], trackEls: [] });
  assert.equal(els['btn-cc'].hidden, true);
  assert.equal(els['btn-cc-lang'].hidden, true);
});

test('the language caret lists every subtitle track and switches between them', () => {
  const trackEls = [{ label: 'English' }, { label: 'Icelandic' }, { label: 'Czech' }];
  const { els, v } = runPlayerDom({ tracks: ['English', 'Icelandic', 'Czech'], trackEls });
  const caret = els['btn-cc-lang'];
  const menu = els['cc-menu'];
  assert.equal(caret.hidden, false, 'two or more tracks shows the caret');
  assert.equal(menu.children.length, 3);
  assert.deepEqual(menu.children.map((b) => b.textContent), ['English', 'Icelandic', 'Czech']);
  assert.ok(menu.children[0].className.includes('on'), 'English is the default');
  assert.ok(!menu.children[1].className.includes('on'));

  // Pick Czech.
  menu.children[2].onclick();
  assert.deepEqual(v.textTracks.map((t) => t.mode), ['disabled', 'disabled', 'hidden']);
  assert.equal(menu.hidden, true, 'menu closes after choosing');

  // One track only: no caret, but CC still works.
  const single = runPlayerDom({ tracks: ['English'], trackEls: [{ label: 'English' }] });
  assert.equal(single.els['btn-cc-lang'].hidden, true);
  assert.equal(single.els['btn-cc'].hidden, false);
});
