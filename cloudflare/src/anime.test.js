import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';

import {
  assertPlayableHead,
  cinemaHeaders,
  cinemaProxyUrl,
  stampParts,
  megaplayProxyUrl,
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
  openSeal,
  playlistDuration,
  playlistUris,
  resolveCinema,
  resolveEverglow,
  everglowServerLinks,
  everglowServerList,
  resolveMegavid,
  resolvePlaylistUrl,
  resolveYumeZone,
  rewriteCinemaPlaylist,
  rewritePlaylistWithHosts,
  scopedTarget,
  stripAdCues,
  sealTarget,
  selectCinemaSubtitleTracks,
  validateAnimeParams,
  verifyStream,
  CINEMA_PROVIDERS,
  CINEMA_SERVERS,
  CINEMA_SERVER_IDS,
  cinemaServer,
  FMOV_ORIGIN,
  MEGAPLAY_HOSTS,
  VIDBOLT_ORIGIN,
} from './anime.js';
import { handleProxyHls, handleProxyAnime } from './worker.js';
import { yumeSig } from './yumezone.js';

const KEY = 'demo-cdn-key';
const HOST = 'https://everglow-stream.example.workers.dev';

async function upstreamOf(proxyUrl, key = KEY) {
  const u = proxyUrl instanceof URL ? proxyUrl : new URL(proxyUrl);
  const sealed = await openSeal(key, u.searchParams.get('t') || '');
  if (!sealed) return null;
  if (sealed.u) return sealed.u;
  const scope = sealed.s || '';
  if (sealed.r) {
    const rq = u.searchParams.get('rq');
    return `${sealed.r}?url=${encodeURIComponent(scope)}${u.searchParams.get('rr') || ''}${rq ? `&${rq}` : ''}`;
  }
  return scope + (u.searchParams.get('r') || '');
}

const RELAY = 'https://fmov.my/api/proxy';
const CDN = 'https://srv323.truawk.cyou/aes/0/abc/film.mp4/';
const relayOf = (inner) => `${RELAY}?url=${encodeURIComponent(inner)}`;

test('validateAnimeParams accepts the sources the app actually offers', () => {
  for (const source of ['megavid', 'megaplay', 'everglow']) {
    const p = validateAnimeParams({ source, anilistId: 21, ep: 1, audio: 'sub' });
    assert.equal(p.error, undefined, source);
  }
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
  assert.equal(stampParts('https://fmov.my/api/proxy?url=master.m3u8'), null);
  assert.equal(stampParts('https://fmov.my/api/'), null);
  assert.equal(stampParts(relayOf(relayOf('https://example.com/'))), null);
  assert.equal(stampParts('https://cdn.example/x.ts?next=https%3A%2F%2Fevil.example%2F'), null);
});

test('Cinema seals bind provider + relay endpoint + inner folder', async () => {
  const url = relayOf(`${CDN}index.m3u8`);
  const proxied = new URL(await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, url, 'fmov', KEY));
  assert.equal(await upstreamOf(proxied), url);
  for (const leak of ['d', 's', 'u', 'rp', 'p']) {
    assert.equal(proxied.searchParams.get(leak), null, `no ${leak} param`);
  }
  assert.ok(!proxied.toString().includes('fmov.my'), 'relay host is not printed');
  assert.ok(!proxied.toString().includes('truawk'), 'CDN host is not printed');

  const sealed = await openSeal(KEY, proxied.searchParams.get('t'));
  assert.equal(sealed.p, 'fmov');
  assert.equal(sealed.r, RELAY);
  assert.equal(sealed.s, CDN);

  assert.equal(await openSeal('other-key', proxied.searchParams.get('t')), null);
  const t = proxied.searchParams.get('t');
  const flipped = t.slice(0, -2) + (t.endsWith('AA') ? 'BB' : 'AA');
  assert.equal(await openSeal(KEY, flipped), null);
});

test('rewriteCinemaPlaylist seals a whole relayed film with ONE token', async () => {
  const segs = Array.from({ length: 400 }, (_, i) => `/api/proxy?url=${encodeURIComponent(`${CDN}seg-${i}.ts`)}`).join('\n');
  const out = await rewriteCinemaPlaylist(`#EXTM3U\n${segs}\n`, relayOf(`${CDN}index.m3u8`), `${HOST}/proxyMegavidHls`, 'fmov', KEY);
  const urls = [...out.matchAll(/https:\/\/[^?"\s]+\/proxyMegavidHls\?[^"\s]+/g)].map((m) => new URL(m[0]));
  assert.equal(urls.length, 400);
  assert.equal(new Set(urls.map((u) => u.searchParams.get('t'))).size, 1, 'one seal for the folder');
  for (const [i, u] of urls.entries()) {
    assert.equal(await upstreamOf(u), relayOf(`${CDN}seg-${i}.ts`));
    assert.ok(u.searchParams.get('rr') && !u.searchParams.get('u'), 'compact form');
    assert.ok(!u.toString().includes('truawk'), 'no CDN host in the playlist');
  }
});

test('vector-shaped relay segments (other folder, extra params) still use one token and the compact form', async () => {
  const seg = (i) => `/api/proxy?url=${encodeURIComponent(`https://cdn2.example/content/ab/cd/page-${i}.html`)}&referer=${encodeURIComponent('https://ref.example/')}&va=1`;
  const text = `#EXTM3U\n${Array.from({ length: 50 }, (_, i) => seg(i)).join('\n')}\n`;
  const out = await rewriteCinemaPlaylist(text, relayOf('https://cdn2.example/pl/list.m3u8'), `${HOST}/proxyMegavidHls`, 'fmov', KEY);
  const urls = out.split('\n').filter((l) => l.startsWith(HOST)).map((l) => new URL(l));
  assert.equal(urls.length, 50);
  assert.equal(new Set(urls.map((u) => u.searchParams.get('t'))).size, 1);
  for (const [i, u] of urls.entries()) {
    assert.ok(!u.searchParams.get('u'), 'compact');
    assert.equal(await upstreamOf(u), `https://fmov.my${seg(i)}`);
    assert.ok(!u.toString().includes('cdn2.example'), 'no CDN host in the playlist');
  }
});

test('a direct playlist keeps api_key and seals its own folder', async () => {
  const base = 'https://img.rousav.tech/media/a/index.m3u8?api_key=k1';
  const out = await rewriteCinemaPlaylist('#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,URI="track_en.m3u8"\nseg0.ts\n', base, `${HOST}/proxyMegavidHls`, 'vidbolt', KEY);
  const urls = [...out.matchAll(/https:\/\/[^?"\s]+\/proxyMegavidHls\?[^"\s]+/g)].map((m) => new URL(m[0]));
  assert.equal(urls.length, 2);
  for (const u of urls) {
    const sealed = await openSeal(KEY, u.searchParams.get('t'));
    assert.equal(sealed.s, 'https://img.rousav.tech/media/a/');
    assert.ok((await upstreamOf(u)).includes('api_key=k1'));
    assert.ok(!u.toString().includes('rousav'), 'no CDN host in the playlist');
  }
});

test('a URI outside the playlist directory gets its own scope; a relay URI is never folder-sealed', async () => {
  const out = await rewriteCinemaPlaylist(
    '#EXTM3U\nhttps://other.example/deep/x.ts\nhttps://fmov.my/api/proxy?url=y.ts\n',
    'https://img.rousav.tech/media/a/index.m3u8',
    `${HOST}/proxyMegavidHls`,
    'vidbolt',
    KEY,
  );
  const lines = out.split('\n');
  const sealed = await openSeal(KEY, new URL(lines[1]).searchParams.get('t'));
  assert.equal(sealed.s, 'https://other.example/deep/');
  assert.equal(lines[2], `${HOST}/proxyMegavidHls?t=0`, 'not echoed, so the proxy refuses it');
});

test('a URI we cannot seal is never echoed, so no upstream host reaches the browser', async () => {
  const out = await rewriteCinemaPlaylist(
    '#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,URI="http://fmov.my/api/proxy?url=x"\nhttp://fmov.my/api/proxy?url=y.ts\nseg0.ts\n',
    'https://img.rousav.tech/media/a/index.m3u8',
    `${HOST}/proxyMegavidHls`,
    'vidbolt',
    KEY,
  );
  assert.ok(!out.includes('fmov.my'), 'no upstream host in the rewritten playlist');
  assert.ok(out.includes(`${HOST}/proxyMegavidHls?t=0`), 'unsealable URIs point at the proxy');
  const lines = out.split('\n').filter(Boolean);
  assert.equal(lines.length, 4, 'the playlist keeps its shape');
  assert.ok(lines[3].includes('?t='), 'the sealable segment is still sealed');
});

test('one unsealable URI does not poison its sealable neighbours', async () => {
  const out = await rewriteCinemaPlaylist(
    '#EXTM3U\nhttps://cdn.example/a/seg0.ts#t=1\nseg1.ts\n',
    'https://cdn.example/a/index.m3u8',
    `${HOST}/proxyMegavidHls`,
    'fmov',
    KEY,
  );
  const links = out.split('\n').filter((l) => l.startsWith(HOST));
  assert.equal(links.length, 2);
  for (const link of links) {
    const sealed = await scopedTarget(new URL(link).searchParams, KEY);
    assert.ok(sealed, `${link} opens`);
  }
  assert.ok((await upstreamOf(new URL(links[0]))).startsWith('https://cdn.example/a/seg0.ts'));
  assert.equal(await upstreamOf(new URL(links[1])), 'https://cdn.example/a/seg1.ts');
});

test('a relay URI with a param before url= still gets a real token', async () => {
  const out = await rewriteCinemaPlaylist(
    '#EXTM3U\n/api/proxy?tok=x&url=' +
      encodeURIComponent('https://cdn.example/a/seg0.ts') +
      '\n',
    'https://fmov.my/api/proxy?url=' + encodeURIComponent('https://cdn.example/a/index.m3u8'),
    `${HOST}/proxyMegavidHls`,
    'fmov',
    KEY,
  );
  const link = out.split('\n').find((l) => l.startsWith(HOST));
  assert.ok(link, 'the relay URI is sealed, not dropped');
  assert.ok(!link.endsWith('?t=0'), 'a real token, not the dead one');
  const sealed = await scopedTarget(new URL(link).searchParams, KEY);
  assert.ok(sealed, 'the token opens');
  assert.equal(sealed.relay, 'https://fmov.my/api/proxy');
  assert.equal(sealed.target, 'https://fmov.my/api/proxy?tok=x&url=' +
    encodeURIComponent('https://cdn.example/a/seg0.ts'));
});

test('a folder holding a space or a non-ASCII character still plays', async () => {
  const base = 'https://cdn.example/a b/ëpisode/index.m3u8';
  const out = await rewriteCinemaPlaylist('#EXTM3U\nseg0.ts\n', base, `${HOST}/proxyMegavidHls`, 'fmov', KEY);
  const link = out.split('\n').find((l) => l.startsWith(HOST));
  const sealed = await scopedTarget(new URL(link).searchParams, KEY);
  assert.ok(sealed, 'the sealed link opens');
  assert.equal(sealed.target, 'https://cdn.example/a%20b/%C3%ABpisode/seg0.ts');
});

test('rewritePlaylistWithHosts seals every host, allowlisted or not', async () => {
  const out = await rewritePlaylistWithHosts(
    '#EXTM3U\n#EXTINF:8,\nhttps://s-90.megavid.se/a.ts\nhttps://evil.example/b.ts\n',
    'https://megavid.buzz/v.m3u8',
    `${HOST}/proxyMegavidHls`,
    'megaplay',
    KEY,
  );
  assert.ok(!out.includes('megavid.se'), 'allowlisted host is not printed');
  assert.ok(!out.includes('evil.example'), 'unlisted host is not printed');
  const urls = out.split('\n').filter((l) => l.startsWith(HOST)).map((l) => new URL(l));
  assert.equal(urls.length, 2);
  assert.equal(await upstreamOf(urls[0]), 'https://s-90.megavid.se/a.ts');
  assert.equal(await upstreamOf(urls[1]), 'https://evil.example/b.ts');

  const stamped = await rewritePlaylistWithHosts(
    '#EXTM3U\n#EXTINF:8,\nhttps://wintergrove.space/a.jpg\n',
    'https://fetch.nexabloom.top/v.m3u8',
    `${HOST}/proxyMegavidHls`,
    'megaplay',
    KEY,
  );
  assert.ok(stamped.includes('?t='), 'rotating MegaPlay CDN gets sealed');
  assert.ok(!stamped.includes('wintergrove'), 'and its host stays hidden');
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
    assert.equal(await upstreamOf(src), relayOf(`${CDN}index.m3u8`));
    const sealed = await openSeal(KEY, src.searchParams.get('t'));
    assert.equal(sealed.p, 'fmov');
    assert.equal(sealed.r, RELAY);
    assert.equal(sealed.s, CDN);
    assert.equal(out.title, 'Movie');
    assert.equal(out.tracks.length, 1);
    const track = new URL(out.tracks[0].file);
    assert.equal(await upstreamOf(track), 'https://cache.vdrk.site/en.vtt');
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
      if (u.startsWith('https://fmov.my/api/stream/movie/603?source=core')) {
        return {
          ok: true, status: 200,
          json: async () => ({
            success: true,
            sources: [{ url: `/api/proxy?url=${encodeURIComponent(`${CDN}index.m3u8`)}`, type: 'hls' }],
            subtitles: [{ label: 'English', file: 'https://cache.vdrk.site/en.vtt', type: 'vtt' }],
          }),
        };
      }
      if (u.startsWith('https://fmov.my/api/stream/')) return { ok: false, status: 404 };
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
    assert.equal(await upstreamOf(src), relayOf(`${CDN}index.m3u8`));
    assert.deepEqual(
      body.servers.map((s) => s.label),
      ['Reel', 'Matinee', 'Marquee', 'Encore', 'Premiere'],
    );
    assert.equal(body.current, 'cine-3', 'only the fmov core row was allowed to answer');
    assert.ok(body.servers.every((s) => s.url.includes('format=json')));
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('the Worker answers format=json errors as JSON', async () => {
  const u = new URL(`${HOST}/proxyAnime`);
  u.searchParams.set('source', 'cinema');
  u.searchParams.set('format', 'json');
  const res = await handleProxyAnime(new Request(u.toString()), { CDN_STAMP_KEY: KEY });
  assert.equal(res.status, 400);
  assert.match(res.headers.get('content-type'), /application\/json/);
  const body = await res.json();
  assert.ok(body.error);
});

test('a picker pick resolves only that row, and reports which row is playing', async () => {
  const realFetch = globalThis.fetch;
  const segOk = { ok: true, status: 200, arrayBuffer: async () => new Uint8Array([0x47, 0, 0, 0]).buffer };
  const seen = [];
  try {
    globalThis.fetch = async (url) => {
      const u = String(url);
      seen.push(u);
      if (u.startsWith('https://fmov.my/api/stream/movie/603?source=core')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({
            success: true,
            sources: [{ url: `/api/proxy?url=${encodeURIComponent(`${CDN}index.m3u8`)}`, type: 'hls' }],
          }),
        };
      }
      if (u.startsWith('https://fmov.my/api/stream/')) return { ok: false, status: 404 };
      if (u.includes('index.m3u8')) {
        return { ok: true, status: 200, text: async () => `#EXTM3U
#EXTINF:200,
/api/proxy?url=${encodeURIComponent(`${CDN}seg1.ts`)}
` };
      }
      if (u.startsWith('https://vidbolt.xyz/')) throw new Error('a pick of an fmov row must not ask vidbolt');
      return segOk;
    };
    const out = await resolveCinema('movie', 603, 1, 1, `${HOST}/proxyMegavidHls`, KEY, {
      server: 'cine-3',
    });
    assert.equal(out.server, 'cine-3', 'the row she tapped is the row reported back');
    assert.deepEqual(
      out.servers.map((s) => s.label),
      ['Reel', 'Matinee', 'Marquee', 'Encore', 'Premiere'],
    );
    assert.ok(!seen.some((u) => u.startsWith('https://vidbolt.xyz/')), 'vidbolt was not asked');
    const sealed = await openSeal(KEY, new URL(out.src).searchParams.get('t'));
    assert.equal(sealed.p, 'fmov');

    await assert.rejects(
      resolveCinema('movie', 603, 1, 1, `${HOST}/proxyMegavidHls`, KEY, { server: 'cine-99' }),
      /unknown server/,
    );
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('validateAnimeParams accepts a cinema picker row and refuses anything else', () => {
  const ok = validateAnimeParams({
    source: 'cinema',
    type: 'tv',
    tmdbId: '1399',
    s: '1',
    e: '2',
    server: 'cine-4',
  });
  assert.equal(ok.error, undefined);
  assert.equal(ok.server, 'cine-4');
  assert.equal(ok.ep, 2);
  assert.equal(validateAnimeParams({ source: 'cinema', type: 'movie', tmdbId: '603' }).server, '');
  assert.match(
    validateAnimeParams({ source: 'cinema', type: 'movie', tmdbId: '603', server: 'cine-99' }).error,
    /unknown server/,
  );
  for (const server of CINEMA_SERVERS) {
    assert.equal(
      validateAnimeParams({ source: 'cinema', type: 'movie', tmdbId: '603', server: server.id }).error,
      undefined,
      server.id,
    );
  }
  assert.match(
    validateAnimeParams({ source: 'cinema', type: 'movie', tmdbId: '603', server: 'cine-v1' }).error,
    /unknown server/,
  );
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

function mockMegavid(source, { tracks = [] } = {}) {
  return async (url) => {
    const u = String(url);
    if (u.includes('/source')) {
      return new Response(JSON.stringify({ status: 'ok', source, tracks }), { status: 200 });
    }
    if (u.includes('master.m3u8')) {
      return new Response('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nv.m3u8\n', { status: 200 });
    }
    if (u.includes('v.m3u8')) {
      const segs = Array.from({ length: 25 }, (_, i) => `#EXTINF:6,\nseg-${i}.ts`).join('\n');
      return new Response(`#EXTM3U\n#EXT-X-TARGETDURATION:6\n${segs}\n`, { status: 200 });
    }
    return new Response(new Uint8Array([0x47, 1, 2, 3]), { status: 200 });
  };
}

test('resolveMegavid seals the stream and its subtitle tracks', async () => {
  const realFetch = globalThis.fetch;
  const master = 'https://megavid.buzz/stream/master.m3u8?token=t';
  globalThis.fetch = mockMegavid(master, {
    tracks: [{ label: 'English', file: 'https://megavid.buzz/subs/en.vtt' }],
  });
  try {
    const out = await resolveMegavid(21, 21, 1, 'sub', `${HOST}/proxyMegavidHls`, KEY);
    assert.equal(typeof out.src, 'string');
    assert.equal(await upstreamOf(new URL(out.src)), master);
    assert.equal(out.tracks.length, 1);
    assert.equal(typeof out.tracks[0].file, 'string', 'tracks are awaited, not promises');
    assert.equal(await upstreamOf(new URL(out.tracks[0].file)), 'https://megavid.buzz/subs/en.vtt');
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('resolveMegavid throws instead of returning a null src on a keyless Worker', async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = mockMegavid('https://megavid.buzz/stream/master.m3u8?token=t');
  try {
    await assert.rejects(
      resolveMegavid(21, 21, 1, 'sub', `${HOST}/proxyMegavidHls`, null),
      /cannot be sealed/,
    );
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('a keyless Worker answers with the failover marker, not a dead player page', async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = mockMegavid('https://megavid.buzz/stream/master.m3u8?token=t');
  try {
    const u = new URL(`${HOST}/proxyAnime`);
    u.searchParams.set('source', 'megavid');
    u.searchParams.set('anilistId', '21');
    u.searchParams.set('malId', '21');
    u.searchParams.set('ep', '1');
    u.searchParams.set('audio', 'sub');
    const res = await handleProxyAnime(new Request(u.toString()), {});
    assert.equal(res.status, 502, 'not a 200 page with var src=null');
    const body = await res.text();
    assert.ok(body.includes(NO_SOURCE_MARKER), 'the app probe can advance');
    assert.ok(!body.includes('var src=null'), 'no dead player page');
  } finally {
    globalThis.fetch = realFetch;
  }
});

function yumeEncrypt(payload, sig) {
  const key = new TextEncoder().encode(sig);
  const json = new TextEncoder().encode(JSON.stringify(payload));
  const out = new Uint8Array(json.length);
  for (let i = 0; i < json.length; i++) out[i] = json[i] ^ key[i % key.length] ^ ((i * 3) % 256);
  return btoa(String.fromCharCode(...out));
}

const YUME_TS = 1767225600;
const YUME_MASTER = 'https://yumezone.live/p/abc/master.m3u8?pk=t';

function mockYume(answers, { calls = [] } = {}) {
  return async (url, init) => {
    const u = String(url);
    calls.push(u);
    if (u === 'https://yumezone.live/api/yume/watch/sources') {
      const body = JSON.parse(init.body);
      const answer = answers[body.provider];
      if (answer === undefined || answer === 'fail') return new Response('nope', { status: 500 });
      const sig = await yumeSig(body.anime_id, body.episode_number, body.ts);
      return new Response(JSON.stringify({ ct: yumeEncrypt(answer, sig) }), { status: 200 });
    }
    if (u.includes('master.m3u8')) {
      return new Response('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nv.m3u8\n', { status: 200 });
    }
    if (u.includes('v.m3u8')) {
      const segs = Array.from({ length: 25 }, (_, i) => `#EXTINF:6,\nseg-${i}.ts`).join('\n');
      return new Response(`#EXTM3U\n#EXT-X-TARGETDURATION:6\n${segs}\n`, { status: 200 });
    }
    return new Response(new Uint8Array([0x47, 1, 2, 3]), { status: 200 });
  };
}

function yumeAnswer(overrides = {}) {
  return { available: true, source_type: 'hls', hls_sources: [{ url: YUME_MASTER }], ...overrides };
}

test('validateAnimeParams accepts yumezone and rejects an unknown server', () => {
  const ok = validateAnimeParams({ source: 'yumezone', anilistId: '21', ep: '3', audio: 'sub' });
  assert.equal(ok.source, 'yumezone');
  assert.equal(ok.anilistId, 21);
  assert.equal(ok.ep, 3);
  assert.equal(ok.server, '');

  const picked = validateAnimeParams({ source: 'yumezone', anilistId: '21', ep: '1', server: 'yume-5' });
  assert.equal(picked.server, 'yume-5');

  for (const id of ['megaplay', 'megavid', 'yume-1']) {
    const pin = validateAnimeParams({ source: 'everglow', anilistId: '21', ep: '1', server: id });
    assert.equal(pin.error, undefined, id);
    assert.equal(pin.server, id);
  }
  assert.match(
    validateAnimeParams({ source: 'megaplay', anilistId: '21', ep: '1', server: 'megavid' }).error,
    /unknown server/,
    'a direct id belongs to Everglow only',
  );

  assert.match(validateAnimeParams({ source: 'yumezone', anilistId: '21', ep: '1', server: 'evil' }).error, /unknown server/);
  assert.match(validateAnimeParams({ source: 'nope', anilistId: '21', ep: '1' }).error, /source must be/);
});

test('resolveYumeZone seals the master and hands the player its server list', async () => {
  const realFetch = globalThis.fetch;
  const realNow = Date.now;
  Date.now = () => YUME_TS * 1000;
  const calls = [];
  globalThis.fetch = mockYume({ 'Karl - 3': yumeAnswer() }, { calls });
  try {
    const out = await resolveYumeZone(21, 1, 'sub', '', `${HOST}/proxyMegavidHls`, KEY);
    assert.equal(out.server, 'yume-1', 'hardsub server wins for subbed audio');
    const src = new URL(out.src);
    assert.equal(src.pathname, '/proxyMegavidHls');
    assert.equal(await upstreamOf(src), YUME_MASTER);
    const sealed = await openSeal(KEY, src.searchParams.get('t'));
    assert.equal(sealed.p, 'yumezone');
    assert.ok(!out.src.includes('yumezone.live'), 'the upstream never reaches the browser');

    assert.equal(out.servers.length, 11);
    assert.deepEqual(out.servers.slice(0, 4).map((s) => s.id), [
      'megaplay',
      'megavid',
      'yume-1',
      'yume-2',
    ]);
    for (const server of out.servers) {
      const u = new URL(server.url);
      assert.equal(u.origin + u.pathname, `${HOST}/proxyAnime`);
      assert.equal(u.searchParams.get('format'), 'json');
      if (server.id.startsWith('yume-')) {
        assert.equal(u.searchParams.get('source'), 'yumezone');
        assert.equal(u.searchParams.get('server'), server.id);
      } else {
        assert.equal(u.searchParams.get('source'), server.id);
        assert.equal(u.searchParams.get('server'), null, 'no picker id for a direct upstream');
      }
      assert.ok(server.label);
    }
    assert.equal(calls.filter((u) => u.includes('/api/yume/watch/sources')).length, 1);
    assert.equal(out.tracks.length, 0, 'ASS/SRT cannot ride a <track>');
  } finally {
    globalThis.fetch = realFetch;
    Date.now = realNow;
  }
});

test('resolveYumeZone falls through dead servers, in order', async () => {
  const realFetch = globalThis.fetch;
  const realNow = Date.now;
  Date.now = () => YUME_TS * 1000;
  const calls = [];
  globalThis.fetch = mockYume(
    { 'Karl - 3': 'fail', Goku: { available: false }, Nexus: yumeAnswer() },
    { calls },
  );
  try {
    const out = await resolveYumeZone(21, 1, 'sub', '', `${HOST}/proxyMegavidHls`, KEY);
    assert.equal(out.server, 'yume-3');
    assert.equal(calls.filter((u) => u.includes('/api/yume/watch/sources')).length, 3);
  } finally {
    globalThis.fetch = realFetch;
    Date.now = realNow;
  }
});

test('a picked YumeZone server is the only one tried, so the picker cannot lie', async () => {
  const realFetch = globalThis.fetch;
  const realNow = Date.now;
  Date.now = () => YUME_TS * 1000;
  const calls = [];
  globalThis.fetch = mockYume({ 'Karl - 3': yumeAnswer() }, { calls });
  try {
    await assert.rejects(
      resolveYumeZone(21, 1, 'sub', 'yume-6', `${HOST}/proxyMegavidHls`, KEY),
      /no playable stream/,
    );
    assert.equal(calls.filter((u) => u.includes('/api/yume/watch/sources')).length, 1);

    await assert.rejects(
      resolveYumeZone(21, 1, 'sub', 'nope', `${HOST}/proxyMegavidHls`, KEY),
      /unknown server/,
    );
  } finally {
    globalThis.fetch = realFetch;
    Date.now = realNow;
  }
});

test('resolveYumeZone fails closed without a key or an AniList id', async () => {
  await assert.rejects(resolveYumeZone(21, 1, 'sub', '', `${HOST}/proxyMegavidHls`, null), /seal key/);
  await assert.rejects(resolveYumeZone(0, 1, 'sub', '', `${HOST}/proxyMegavidHls`, KEY), /AniList id/);
});

test('the Worker answers format=json for yumezone with the server list', async () => {
  const realFetch = globalThis.fetch;
  const realNow = Date.now;
  Date.now = () => YUME_TS * 1000;
  globalThis.fetch = mockYume({ 'Karl - 3': yumeAnswer() });
  try {
    const u = new URL(`${HOST}/proxyAnime`);
    u.searchParams.set('source', 'yumezone');
    u.searchParams.set('anilistId', '21');
    u.searchParams.set('ep', '1');
    u.searchParams.set('audio', 'sub');
    u.searchParams.set('format', 'json');
    const res = await handleProxyAnime(new Request(u.toString()), { CDN_STAMP_KEY: KEY });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.current, 'yume-1');
    assert.equal(body.servers.length, 11);
    assert.equal(await upstreamOf(new URL(body.src)), YUME_MASTER);
    assert.deepEqual(body.tracks, []);
  } finally {
    globalThis.fetch = realFetch;
    Date.now = realNow;
  }
});

function mockShelf({ dead = [], calls = [], megavid = null, yume = null } = {}) {
  const megavidStub = megavid || mockMegavid('https://megavid.buzz/stream/master.m3u8?token=t');
  const yumeStub = yume || mockYume({ 'Karl - 3': yumeAnswer() }, { calls });
  return async (url, init) => {
    const u = String(url);
    if (u.startsWith('https://megaplay.buzz/')) {
      calls.push(u);
      if (dead.includes('megaplay')) return new Response('gone', { status: 404 });
      return new Response('no player here', { status: 200 });
    }
    if (u.startsWith('https://megavid.buzz/')) {
      if (dead.includes('megavid')) {
        calls.push(u);
        return new Response('nope', { status: 500 });
      }
      return megavidStub(url, init);
    }
    return yumeStub(url, init);
  };
}

test('the Everglow picker lists every stream under a warm name', () => {
  const sub = everglowServerList('sub', { anilistId: 21 });
  assert.deepEqual(
    sub.slice(0, 2).map((s) => [s.id, s.label]),
    [
      ['megaplay', 'Nova'],
      ['megavid', 'Iris'],
    ],
  );
  assert.equal(sub.length, 11);
  assert.equal(sub[2].id, 'yume-1');
  assert.equal(everglowServerList('dub', { anilistId: 21 })[2].id, 'yume-4');
  for (const s of sub) assert.doesNotMatch(s.label, /mega|yume|vid/i, s.label);
  assert.deepEqual(
    everglowServerList('sub', { anilistId: 0 }).map((s) => s.id),
    ['megaplay', 'megavid'],
  );
});

test('the Everglow picker links are lazy and point back at the Worker', () => {
  const links = everglowServerLinks(`${HOST}/proxyMegavidHls`, {
    anilistId: 21,
    malId: 21,
    ep: 3,
    audio: 'dub',
  });
  assert.equal(links.length, 11);
  assert.equal(
    links.find((l) => l.id === 'megaplay').url,
    `${HOST}/proxyAnime?source=megaplay&format=json&anilistId=21&malId=21&ep=3&audio=dub`,
  );
  assert.equal(
    links.find((l) => l.id === 'yume-1').url,
    `${HOST}/proxyAnime?source=yumezone&format=json&anilistId=21&malId=21&ep=3&audio=dub&server=yume-1`,
  );
});

test('resolveEverglow walks MegaPlay, then Megavid, then YumeZone', async () => {
  const realFetch = globalThis.fetch;
  const realNow = Date.now;
  Date.now = () => YUME_TS * 1000;
  const calls = [];
  globalThis.fetch = mockShelf({ dead: ['megaplay'], calls });
  try {
    const out = await resolveEverglow(21, 21, 1, 'sub', '', `${HOST}/proxyMegavidHls`, KEY);
    assert.equal(out.server, 'megavid', 'MegaPlay is dead, so Megavid answers');
    assert.equal(out.servers.length, 11, 'the picker still lists everything');
    assert.equal(
      await upstreamOf(new URL(out.src)),
      'https://megavid.buzz/stream/master.m3u8?token=t',
    );
  } finally {
    globalThis.fetch = realFetch;
    Date.now = realNow;
  }
});

test('resolveEverglow reaches YumeZone when both direct upstreams die', async () => {
  const realFetch = globalThis.fetch;
  const realNow = Date.now;
  Date.now = () => YUME_TS * 1000;
  const calls = [];
  globalThis.fetch = mockShelf({ dead: ['megaplay', 'megavid'], calls });
  try {
    const out = await resolveEverglow(21, 21, 1, 'sub', '', `${HOST}/proxyMegavidHls`, KEY);
    assert.equal(out.server, 'yume-1');
    assert.equal(await upstreamOf(new URL(out.src)), YUME_MASTER);
    assert.equal(calls.filter((u) => u.includes('/api/yume/watch/sources')).length, 1);
  } finally {
    globalThis.fetch = realFetch;
    Date.now = realNow;
  }
});

test('a pinned Everglow server is the only one tried, so the picker cannot lie', async () => {
  const realFetch = globalThis.fetch;
  const realNow = Date.now;
  Date.now = () => YUME_TS * 1000;
  const calls = [];
  globalThis.fetch = mockShelf({ dead: ['megaplay'], calls });
  try {
    await assert.rejects(
      resolveEverglow(21, 21, 1, 'sub', 'megaplay', `${HOST}/proxyMegavidHls`, KEY),
      /no playable stream/,
    );
    assert.equal(calls.filter((u) => u.includes('megavid.buzz')).length, 0);
    await assert.rejects(
      resolveEverglow(21, 21, 1, 'sub', 'nope', `${HOST}/proxyMegavidHls`, KEY),
      /unknown server/,
    );
  } finally {
    globalThis.fetch = realFetch;
    Date.now = realNow;
  }
});

test('resolveEverglow fails inside its budget instead of walking forever', async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = (url, init) =>
    new Promise((_, reject) => {
      const signal = init && init.signal;
      if (!signal) return;
      if (signal.aborted) reject(new Error('aborted'));
      else signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
    });
  try {
    const started = Date.now();
    await assert.rejects(
      resolveEverglow(21, 21, 1, 'sub', '', `${HOST}/proxyMegavidHls`, KEY, { budgetMs: 50 }),
      /no playable stream/,
    );
    assert.ok(Date.now() - started < 1000);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('the Worker answers format=json for everglow with the whole shelf', async () => {
  const realFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = mockShelf({ dead: ['megaplay'], calls });
  try {
    const u = new URL(`${HOST}/proxyAnime`);
    u.searchParams.set('source', 'everglow');
    u.searchParams.set('anilistId', '21');
    u.searchParams.set('malId', '21');
    u.searchParams.set('ep', '1');
    u.searchParams.set('audio', 'sub');
    u.searchParams.set('format', 'json');
    const res = await handleProxyAnime(new Request(u.toString()), { CDN_STAMP_KEY: KEY });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.current, 'megavid', 'the picker knows which one is playing');
    assert.equal(body.servers.length, 11);
    assert.equal(
      await upstreamOf(new URL(body.src)),
      'https://megavid.buzz/stream/master.m3u8?token=t',
    );
  } finally {
    globalThis.fetch = realFetch;
  }
});

function hlsRequest(query) {
  const u = new URL(`${HOST}/proxyMegavidHls`);
  for (const [k, v] of Object.entries(query)) u.searchParams.set(k, v);
  return new Request(u.toString());
}

test('the Worker refuses every way of pointing a token at a URL we never issued', async () => {
  const realFetch = globalThis.fetch;
  const fetched = [];
  globalThis.fetch = async (url) => {
    fetched.push(String(url));
    return new Response('<html>example</html>', { status: 200, headers: { 'content-type': 'text/html' } });
  };
  try {
    const evilRelay = relayOf('https://example.com/');
    const real = new URL(await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, relayOf(`${CDN}index.m3u8`), 'fmov', KEY));
    const token = real.searchParams.get('t');
    const relayFolder = 'https://fmov.my/api/';
    const cases = [
      { u: evilRelay },
      { u: evilRelay, p: 'fmov', d: relayFolder, s: 'f'.repeat(16) },
      { u: 'https://img.rousav.tech/media/a/index.m3u8' },
      { u: 'http://fmov.my/api/proxy' },
      { t: 'not-a-token' },
      { t: await sealTarget('some-other-key', { p: 'fmov', u: evilRelay }) },
      { t: token.slice(0, -4) + 'AAAA' },
      { t: token, r: '..%2F..%2F..%2Fx' },
      { t: token, r: '/etc/passwd' },
      { t: token, r: 'https://evil.example/x.ts' },
      { t: token, rr: '..%2F..%2Fx' },
      { t: token, rr: 'https://evil.example/x.ts' },
      { t: token, rr: 'index.m3u8', rq: `url=${encodeURIComponent('https://example.com/')}` },
      { t: token, rr: 'index.m3u8', rq: `target=${encodeURIComponent('https://example.com/')}` },
      { t: await sealTarget(KEY, { p: 'fmov', s: relayFolder }) },
      { t: await sealTarget(KEY, { p: 'fmov', s: relayFolder, r: RELAY }) },
    ];
    for (const q of cases) {
      const res = await handleProxyHls(hlsRequest(q), { CDN_STAMP_KEY: KEY });
      assert.equal(res.status, 400, JSON.stringify(q));
    }
    assert.deepEqual(fetched, [], 'nothing reached an upstream');

    const ok = await handleProxyHls(new Request(real.toString()), { CDN_STAMP_KEY: KEY });
    assert.equal(ok.status, 200);
    assert.deepEqual(fetched, [relayOf(`${CDN}index.m3u8`)]);

    fetched.length = 0;
    const legacy = await handleProxyHls(
      hlsRequest({ t: token, rr: 'index.m3u8', rp: 'https://evil.example/proxy' }),
      { CDN_STAMP_KEY: KEY },
    );
    assert.equal(legacy.status, 200);
    assert.deepEqual(fetched, [relayOf(`${CDN}index.m3u8`)], 'the sealed relay is used, not rp');

    fetched.length = 0;
    const rotating = 'https://wintergrove.space/seg.jpg';
    const mp = await megaplayProxyUrl(`${HOST}/proxyMegavidHls`, rotating, KEY);
    const mpRes = await handleProxyHls(new Request(mp), { CDN_STAMP_KEY: KEY });
    assert.equal(mpRes.status, 200);
    assert.deepEqual(fetched, [rotating]);

    fetched.length = 0;
    const noKey = await handleProxyHls(new Request(real.toString()), {});
    assert.equal(noKey.status, 400);
    assert.deepEqual(fetched, [], 'a keyless Worker is closed, not open');
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('the Worker serves a sealed relayed playlist with that provider headers', async () => {
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
    assert.equal(await upstreamOf(child), relayOf(`${CDN}seg1.ts`));
    const sealed = await openSeal(KEY, child.searchParams.get('t'));
    assert.equal(sealed.p, 'fmov');
    assert.equal(sealed.s, CDN);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('a VidBolt-sealed URL plays back with VidBolt headers, not Megavid ones', async () => {
  const realFetch = globalThis.fetch;
  let seen;
  globalThis.fetch = async (url, init) => {
    seen = { url: String(url), headers: init.headers };
    return new Response('#EXTM3U\n#EXTINF:8,\nhttps://vidbolt.xyz/seg1.ts\n', {
      status: 200,
      headers: { 'content-type': 'application/vnd.apple.mpegurl' },
    });
  };
  try {
    const master = 'https://vidbolt.xyz/movie/abc/master.m3u8';
    const signed = await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, master, 'vidbolt', KEY);
    const res = await handleProxyHls(new Request(signed), { CDN_STAMP_KEY: KEY });
    assert.equal(res.status, 200);
    assert.equal(seen.url, master);
    assert.equal(seen.headers.Origin, VIDBOLT_ORIGIN);
    assert.equal(seen.headers.Referer, `${VIDBOLT_ORIGIN}/`);
    const sealed = await openSeal(KEY, new URL(signed).searchParams.get('t'));
    assert.equal(sealed.p, 'vidbolt');
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('every Cinema provider has a picker row, so "current" can never point at nothing', () => {
  for (const provider of CINEMA_PROVIDERS) {
    const rows = CINEMA_SERVERS.filter((s) => s.provider === provider);
    assert.ok(rows.length > 0, `${provider} has no row in the picker`);
  }
  for (const id of CINEMA_SERVER_IDS) {
    assert.ok(cinemaServer(id), `${id} is a valid id with no server behind it`);
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

test('a sealed MegaPlay master rewrites to playable links, and nothing else is reachable', async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(
      '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nindex-f1-v1-a1.m3u8\n#EXT-X-I-FRAME-STREAM-INF:URI="iframes.m3u8"\nhttps://wintergrove.space/seg.jpg\n',
      { status: 200, headers: { 'content-type': 'application/vnd.apple.mpegurl' } },
    );
  try {
    const master = 'https://fetch.nexabloom.top/anime/a/b/master.m3u8?token=t';
    const refused = await handleProxyHls(hlsRequest({ u: master }), { CDN_STAMP_KEY: KEY });
    assert.equal(refused.status, 400);

    const sealed = await sealTarget(KEY, { p: 'megaplay', u: master });
    const res = await handleProxyHls(hlsRequest({ t: sealed }), { CDN_STAMP_KEY: KEY });
    assert.equal(res.status, 200);
    const text = await res.text();
    const links = [...text.matchAll(/https:\/\/[^"\s]+proxyMegavidHls\?[^"\s]+/g)].map((m) => new URL(m[0]));
    assert.equal(links.length, 3);
    assert.ok(!text.includes('wintergrove'), 'no upstream host survives in the playlist');
    assert.ok(!text.includes('nexabloom'), 'not even the allowlisted one');
    for (const link of links) {
      assert.ok(link.searchParams.get('t'), 'every link is sealed');
      const opened = await openSeal(KEY, link.searchParams.get('t'));
      assert.equal(opened.p, 'megaplay');
    }
    assert.equal(await upstreamOf(links[0]), 'https://fetch.nexabloom.top/anime/a/b/index-f1-v1-a1.m3u8');
    assert.equal(await upstreamOf(links[2]), 'https://wintergrove.space/seg.jpg');
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

function runPlayerDom({ tracks = [], trackEls = [], store = new Map(), finePointer = true, servers = [], current = '', fetchImpl = null } = {}) {
  const html = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Movie',
    kind: 'cinema',
    servers,
    current,
    tracks: tracks.map((t) => {
      const spec = typeof t === 'string' ? { label: t } : t;
      return { file: `https://x/${spec.label}.vtt`, label: spec.label };
    }),
  });
  const code = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]).pop();
  const el = () => {
    const node = {
      style: {
        _v: {},
        setProperty(k, v) { this._v[k] = v; },
        getPropertyValue(k) { return this._v[k] || ''; },
      },
      hidden: false, textContent: '', children: [],
      classList: { _s: new Set(), add(c) { this._s.add(c); }, remove(c) { this._s.delete(c); }, toggle(c, v) { if (v) { this._s.add(c); } else { this._s.delete(c); } }, contains(c) { return this._s.has(c); } },
      listeners: {}, addEventListener(e, h) { (this.listeners[e] ||= []).push(h); },
      dispatch(e, data) { for (const h of this.listeners[e] || []) h(data); },
      appendChild(c) { c.parentNode = this; this.children.push(c); },
      removeChild(c) {
        const at = this.children.indexOf(c);
        if (at >= 0) this.children.splice(at, 1);
        return c;
      },
      scrolled: null,
      scrollIntoView(opts) { this.scrolled = opts; },
      getBoundingClientRect: () => ({ x: 0, y: 0, width: 100, height: 10, left: 0 }),
      attrs: {},
      setAttribute(k, val) { this.attrs[k] = String(val); },
      getAttribute(k) { return Object.prototype.hasOwnProperty.call(this.attrs, k) ? this.attrs[k] : null; },
      hasAttribute(k) { return Object.prototype.hasOwnProperty.call(this.attrs, k); },
      contains(target) {
        if (target === this) return true;
        return this.children.some((c) => c === target || (c && typeof c.contains === 'function' && c.contains(target)));
      },
    };
    Object.defineProperty(node, 'innerHTML', {
      get() { return ''; },
      set() { node.children.length = 0; },
    });
    return node;
  };
  const textTracks = tracks.map((t) => {
    const spec = typeof t === 'string' ? { label: t } : t;
    return { label: spec.label, cues: spec.cues || [], mode: 'showing', oncuechange: null };
  });
  textTracks.addEventListener = () => {};
  const v = Object.assign(el(), {
    currentTime: 0, duration: 100, paused: true, volume: 1, muted: false, textTracks,
    querySelectorAll: () => trackEls,
    play() { this.paused = false; return Promise.resolve(); },
    pause() { this.paused = true; },
  });
  const els = { v, 'sub-txt': el(), 'sub-box': el(), boot: el(), 'hud-title': el(), 'hud-ep': el(),
    tapw: Object.assign(el(), { hidden: true }), tap: el(),
    dead: Object.assign(el(), { hidden: true }),
    'btn-cc': el(), 'cc-menu': Object.assign(el(), { hidden: true }),
    'btn-play': el(), 'btn-vol': el(), 'vol-w': el(), 'vol-x': Object.assign(el(), { hidden: true }),
    'btn-speed': el(), 'btn-pip': el(), 'vol-range': el(),
    's-buf': el(), 's-hover': el(), 's-fill': el(), 's-thumb': el(),
    'time-lbl': el(), scrub: el(), 'scrub-wrap': el(),
    'scrub-prev': Object.assign(el(), { hidden: true }),
    pv: Object.assign(el(), { removeAttribute() {}, load() {} }),
    'pv-c': Object.assign(el(), { hidden: false }),
    'pv-time': el(), 'pv-tag': Object.assign(el(), { hidden: true }),
    'sp-menu': Object.assign(el(), { hidden: true }),
    'btn-more': el(), 'more-menu': Object.assign(el(), { hidden: true }),
    'btn-q': el(), 'q-menu': Object.assign(el(), { hidden: true }),
    'btn-sv': el(), 'sv-menu': Object.assign(el(), { hidden: true }),
    'btn-fs': el(), 'fs-p': el(),
    'btn-lock': el(), 'unlock-w': Object.assign(el(), { hidden: true }), 'unlock-btn': el(),
    'btn-nx': Object.assign(el(), { hidden: true }), 'btn-next': Object.assign(el(), { hidden: true }), 'btn-next-x': el(),
    'next-tok': el(), 'next-cd': el(), 'keys-menu': Object.assign(el(), { hidden: true }),
    buf: Object.assign(el(), { hidden: true }) };
  function Hls(opts) {
    this.opts = opts || {};
    this.destroyed = false;
    instances.push(this);
  }
  Hls.isSupported = () => true;
  Hls.Events = { ERROR: 'e', MANIFEST_PARSED: 'm' };
  Hls.ErrorTypes = {};
  const handlers = {};
  const instances = [];
  Hls.prototype.on = function (event, fn) {
    (this._handlers ||= {})[event] = fn;
    handlers[event] = fn;
  };
  const loads = [];
  Hls.prototype.loadSource = function (u) {
    if (this.destroyed) return;
    loads.push(u);
  };
  Hls.prototype.attachMedia = () => {};
  Hls.prototype.destroy = function () { this.destroyed = true; };
  Hls.prototype.startLoad = () => {};
  Hls.prototype.recoverMediaError = () => {};
  const win = el();
  const localStorage = {
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, val) => store.set(k, String(val)),
  };
  Object.assign(win, { Hls, localStorage, matchMedia: (q) => ({ matches: finePointer, media: q }),
    location: { search: '', origin: 'https://w.example', pathname: '/proxyAnime' }, parent: { postMessage() {} } });
  const doc = {
    getElementById: (id) => els[id] || null,
    body: el(),
    documentElement: el(),
    createElement: () => el(),
    pictureInPictureEnabled: true,
    fullscreenElement: null,
    listeners: {},
    addEventListener(e, h) { (this.listeners[e] ||= []).push(h); },
    dispatch(e, data) { for (const h of this.listeners[e] || []) h(data); },
  };
  const ctx = { window: win, Hls, URLSearchParams, Date, setTimeout, clearTimeout, document: doc, fetch: fetchImpl || (() => Promise.reject(new Error('no fetch'))) };
  vm.createContext(ctx);
  new vm.Script(code).runInContext(ctx);
  for (const h of v.listeners.loadedmetadata || []) h();
  const fire = (event, data) => { for (const h of v.listeners[event] || []) h(data); };
  const key = (k) => {
    for (const h of win.listeners.keydown || []) h({ key: k, preventDefault() {} });
  };
  const tap = (x) => fire('click', { clientX: x });
  const relay = (data) => {
    for (const h of win.listeners.message || []) {
      h({ source: win.parent, origin: 'https://everglow-1c6db.web.app', data });
    }
  };
  return { els, v, html, window: win, doc, fire, key, tap, relay, loads, handlers, instances, Hls };
}

function menuFlat(node) {
  const out = [];
  for (const c of (node && node.children) || []) {
    out.push(c, ...menuFlat(c));
  }
  return out;
}

function findMenuBtn(menu, text) {
  return menuFlat(menu).find((c) => c.textContent === text);
}

function ccRow(menu, header) {
  const nodes = menuFlat(menu);
  const at = nodes.findIndex((c) => c.textContent === header);
  assert.ok(at >= 0, `CC panel has a "${header}" section`);
  const parent = nodes[at].parentNode;
  const idx = parent.children.indexOf(nodes[at]);
  return parent.children[idx + 1];
}

test('the server picker appears only when there is more than one server', () => {
  const none = hlsPlayerHtml({ src: 'https://x/y.m3u8', title: 'Episode 1', ep: 1 });
  assert.match(none, /id="btn-sv"[^>]*hidden/, 'one upstream, no picker');

  const one = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Episode 1',
    ep: 1,
    servers: [{ id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' }],
  });
  assert.match(one, /id="btn-sv"[^>]*hidden/, 'still one, still no picker');

  const many = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Episode 1',
    ep: 1,
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' },
      { id: 'yume-2', label: 'Yume 2', url: 'https://w/proxyAnime?server=yume-2' },
    ],
  });
  assert.doesNotMatch(many, /id="btn-sv"[^>]*hidden/, 'two servers, so the picker shows');
  assert.ok(many.includes('Yume 2'), 'the labels reach the page');
  assert.ok(!many.includes('yumezone.live'), 'no upstream host in the page');
});

test('picking a server swaps the source and keeps the playhead', async () => {
  const asked = [];
  const { els, v } = runPlayerDom({
    tracks: [],
    trackEls: [],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' },
      { id: 'yume-2', label: 'Yume 2', url: 'https://w/proxyAnime?server=yume-2' },
    ],
    fetchImpl: async (url) => {
      asked.push(String(url));
      return { json: async () => ({ src: 'https://w/proxyMegavidHls?t=swapped' }) };
    },
  });
  v.currentTime = 42;

  els['btn-sv'].dispatch('click');
  assert.equal(els['sv-menu'].hidden, false);
  assert.equal(els['sv-menu'].children.length, 2);
  assert.deepEqual(
    els['sv-menu'].children.map((c) => (c.scrolled ? c.scrolled.block : null)),
    ['nearest', null],
    'only the current row is scrolled into view',
  );

  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));

  assert.deepEqual(asked, ['https://w/proxyAnime?server=yume-2']);
  assert.equal(els['sv-menu'].hidden, false, 'the menu waits for a play');
  assert.equal(els['btn-sv'].textContent, 'Servers', 'the button is not left saying Loading');
  v.currentTime = 0;
  for (const h of v.listeners.loadedmetadata || []) h();
  assert.equal(v.currentTime, 42, 'the playhead is restored after the swap');
});

test('a pick swaps the captions with the source, never leaving stale tracks', async () => {
  const oldTrack = { kind: 'captions', label: 'English', src: 'https://x/English.vtt' };
  const { els, v } = runPlayerDom({
    tracks: [],
    trackEls: [oldTrack],
    current: 'megaplay',
    servers: [
      { id: 'megaplay', label: 'Nova', url: 'https://w/p?server=megaplay' },
      { id: 'yume-1', label: 'Dawn', url: 'https://w/p?server=yume-1' },
    ],
    fetchImpl: async () => ({
      json: async () => ({ src: 'https://w/proxyMegavidHls?t=swapped', tracks: [] }),
    }),
  });
  v.children.push(oldTrack);

  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));

  assert.deepEqual(v.children, [], 'the old captions went with the old source');
});

test('a pick attaches the new source\'s captions', async () => {
  const { els, v } = runPlayerDom({
    tracks: [],
    trackEls: [],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Dawn', url: 'https://w/p?server=yume-1' },
      { id: 'megaplay', label: 'Nova', url: 'https://w/p?server=megaplay' },
    ],
    fetchImpl: async () => ({
      json: async () => ({
        src: 'https://w/proxyMegavidHls?t=swapped',
        tracks: [{ file: 'https://w/proxyMegavidHls?t=sub', label: 'English' }],
      }),
    }),
  });

  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));

  assert.equal(v.children.length, 1, 'one track for the new source');
  assert.equal(v.children[0].src, 'https://w/proxyMegavidHls?t=sub');
  assert.equal(v.children[0].label, 'English');
  assert.equal(v.children[0].kind, 'captions');
});

test('a pick keeps her caption language when the new source still has it', async () => {
  const store = new Map();
  const { els, v } = runPlayerDom({
    tracks: ['English', 'Spanish'],
    trackEls: [],
    store,
    current: 'megaplay',
    servers: [
      { id: 'megaplay', label: 'Nova', url: 'https://w/p?server=megaplay' },
      { id: 'megavid', label: 'Iris', url: 'https://w/p?server=megavid' },
    ],
    fetchImpl: async () => ({
      json: async () => ({
        src: 'https://w/proxyMegavidHls?t=swapped',
        tracks: [
          { file: 'https://w/a.vtt', label: 'English' },
          { file: 'https://w/b.vtt', label: 'Spanish' },
        ],
      }),
    }),
  });

  els['btn-cc'].dispatch('click');
  const spanish = findMenuBtn(els['cc-menu'], 'Spanish');
  assert.ok(spanish, 'the language row is there to pick');
  spanish.onclick();

  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[0].onclick();
  await new Promise((r) => setTimeout(r, 0));

  assert.equal(v.textTracks[1].mode, 'hidden', 'Spanish is still the live track');
  assert.equal(v.textTracks[0].mode, 'disabled', 'English did not take over');
  const prefs = JSON.parse(store.get('everglow.player.prefs'));
  assert.equal(prefs.lang, 1, 'the pick and the persisted language agree');
});

test('a pick onto a source with no captions keeps her remembered language', async () => {
  const store = new Map();
  const { els } = runPlayerDom({
    tracks: ['English', 'Spanish'],
    trackEls: [],
    store,
    current: 'megaplay',
    servers: [
      { id: 'megaplay', label: 'Nova', url: 'https://w/p?server=megaplay' },
      { id: 'yume-1', label: 'Dawn', url: 'https://w/p?server=yume-1' },
    ],
    fetchImpl: async () => ({
      json: async () => ({ src: 'https://w/proxyMegavidHls?t=swapped', tracks: [] }),
    }),
  });

  els['btn-cc'].dispatch('click');
  findMenuBtn(els['cc-menu'], 'Spanish').onclick();
  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));

  const prefs = JSON.parse(store.get('everglow.player.prefs'));
  assert.equal(prefs.lang, 1, 'the caption-less source did not erase her language');
});

test('a pick marks default on the first caption it actually attaches', async () => {
  const { els, v } = runPlayerDom({
    tracks: [],
    trackEls: [],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Dawn', url: 'https://w/p?server=yume-1' },
      { id: 'megaplay', label: 'Nova', url: 'https://w/p?server=megaplay' },
    ],
    fetchImpl: async () => ({
      json: async () => ({
        src: 'https://w/proxyMegavidHls?t=swapped',
        tracks: [{ label: 'Broken' }, { file: 'https://w/b.vtt', label: 'English' }],
      }),
    }),
  });

  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));

  assert.equal(v.children.length, 1, 'the fileless entry is skipped');
  assert.equal(v.children[0].default, true, 'the one it attached is the default');
});

test('a failed server pick stays in the player and never condemns the server', async () => {
  const { els, window } = runPlayerDom({
    tracks: [],
    trackEls: [],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' },
      { id: 'yume-2', label: 'Yume 2', url: 'https://w/proxyAnime?server=yume-2' },
    ],
    fetchImpl: async () => ({ json: async () => ({ error: 'no stream' }) }),
  });
  const posted = [];
  window.parent.postMessage = (msg) => posted.push(msg);

  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));

  assert.deepEqual(posted, [], 'the app is not told the server died');
  assert.equal(els['btn-sv'].textContent, 'Server failed', 'the player says so itself');
  assert.equal(els['sv-menu'].hidden, false, 'the menu reopens so she can try another');
});

test('the last tap wins when two server picks overlap', async () => {
  let releaseFirst;
  const { els, loads } = runPlayerDom({
    tracks: [],
    trackEls: [],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' },
      { id: 'yume-2', label: 'Yume 2', url: 'https://w/proxyAnime?server=yume-2' },
      { id: 'yume-3', label: 'Yume 3', url: 'https://w/proxyAnime?server=yume-3' },
    ],
    fetchImpl: (url) => {
      if (String(url).includes('yume-2')) {
        return new Promise((resolve) => {
          releaseFirst = () => resolve({ json: async () => ({ src: 'https://w/slow' }) });
        });
      }
      return Promise.resolve({ json: async () => ({ src: 'https://w/fast' }) });
    },
  });

  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  els['sv-menu'].hidden = false;
  els['sv-menu'].children[2].onclick();
  await new Promise((r) => setTimeout(r, 0));

  releaseFirst();
  await new Promise((r) => setTimeout(r, 0));

  assert.equal(loads.at(-1), 'https://w/fast', 'the later tap is what plays');
  assert.ok(!loads.includes('https://w/slow'), 'the stale response never loads');
});

test('a stream that dies after a pick does not condemn the whole server', async () => {
  const { els, window, handlers } = runPlayerDom({
    tracks: [],
    trackEls: [],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' },
      { id: 'yume-2', label: 'Yume 2', url: 'https://w/proxyAnime?server=yume-2' },
    ],
    fetchImpl: async () => ({ json: async () => ({ src: 'https://w/picked' }) }),
  });
  const posted = [];
  window.parent.postMessage = (msg) => posted.push(msg);
  const die = () => {
    for (let i = 0; i < 4; i++) handlers.e({}, { fatal: true, type: 'other' });
  };

  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));
  assert.deepEqual(posted, [], 'a successful pick says nothing');

  die();
  assert.deepEqual(posted, [], 'one dead pick is not a dead source');
  assert.equal(els['sv-menu'].hidden, false, 'the picker is reachable again');
  assert.equal(els['sv-menu'].children.length, 2, 'and it is rebuilt');
});

test('a working pick clears the stalled card', async () => {
  const { els, handlers, fire } = runPlayerDom({
    tracks: [],
    trackEls: [],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' },
      { id: 'yume-2', label: 'Yume 2', url: 'https://w/proxyAnime?server=yume-2' },
    ],
    fetchImpl: async () => ({ json: async () => ({ src: 'https://w/picked' }) }),
  });

  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));
  for (let i = 0; i < 4; i++) handlers.e({}, { fatal: true, type: 'other' });
  assert.equal(els.dead.hidden, false, 'the card is up');

  els['sv-menu'].children[0].onclick();
  await new Promise((r) => setTimeout(r, 0));
  assert.equal(els.dead.hidden, false, 'card up while the pick loads');
  assert.equal(els['sv-menu'].hidden, false, 'picker still reachable');
  assert.equal(els.dead.style.paddingRight, '190px', 'card clear of the menu');
  fire('playing');
  assert.equal(els.dead.hidden, true, 'the card is gone once it plays');
  assert.equal(els['sv-menu'].hidden, true, 'and the picker closes with it');
  assert.equal(els.dead.style.paddingRight, '', 'the inset is cleared');
});

test('a recovery attempt that throws still kills the instance', async () => {
  const { handlers, instances, Hls } = runPlayerDom({ tracks: [], trackEls: [] });
  assert.equal(instances.length, 1, 'one instance at boot');
  Hls.ErrorTypes.NETWORK_ERROR = 'net';
  instances[0].startLoad = () => {
    throw new Error('boom');
  };
  handlers.e({}, { fatal: true, type: 'net' });
  assert.equal(instances[0].destroyed, true, 'the throwing instance is destroyed');
});

test('a stray play does not close a picker she opened by hand', () => {
  const { els, fire } = runPlayerDom({ tracks: [], trackEls: [] });
  els['btn-sv'].dispatch('click');
  assert.equal(els['sv-menu'].hidden, false, 'she opened it');
  fire('playing');
  assert.equal(els['sv-menu'].hidden, false, 'and it stays open');
});

test('a pick after a dead stream really loads', async () => {
  const { els, handlers, loads } = runPlayerDom({
    tracks: [],
    trackEls: [],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' },
      { id: 'yume-2', label: 'Yume 2', url: 'https://w/proxyAnime?server=yume-2' },
    ],
    fetchImpl: async () => ({ json: async () => ({ src: 'https://w/picked' }) }),
  });

  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));
  for (let i = 0; i < 4; i++) handlers.e({}, { fatal: true, type: 'other' });

  const before = loads.length;
  els['sv-menu'].children[0].onclick();
  await new Promise((r) => setTimeout(r, 0));
  assert.ok(loads.length > before, 'the new source reached a live instance');
  assert.equal(loads[loads.length - 1], 'https://w/picked');
});

test('a stream that dies before any pick still reports the source dead', () => {
  const { window, handlers } = runPlayerDom({ tracks: [], trackEls: [] });
  const posted = [];
  window.parent.postMessage = (msg) => posted.push(msg);
  for (let i = 0; i < 4; i++) handlers.e({}, { fatal: true, type: 'other' });
  assert.ok(posted.includes('animex-content-error'), 'the app can advance servers');
});

test('CC is hidden when the source has no subtitles', () => {
  const none = hlsPlayerHtml({ src: 'https://x/y.m3u8', title: 'Movie', kind: 'cinema' });
  assert.match(none, /id="btn-cc"[^>]*hidden/, 'no tracks, so no CC button');
  const some = hlsPlayerHtml({
    src: 'https://x/y.m3u8', title: 'Movie', kind: 'cinema',
    tracks: [{ file: 'https://x/en.vtt', label: 'English' }],
  });
  assert.doesNotMatch(some, /id="btn-cc"[^>]*hidden/);
  const { els } = runPlayerDom({ tracks: [], trackEls: [] });
  assert.equal(els['btn-cc'].hidden, true);
});

test('the picture is clickable, not buried under the HUD gradient', () => {
  const { html } = runPlayerDom({ tracks: [], trackEls: [] });
  assert.match(html, /#hud\{[^}]*pointer-events:none/);
  assert.ok(html.includes('.h-top,.h-bot{pointer-events:auto}'));
  assert.ok(html.includes('v.addEventListener("click"'));
});

test('clicking the picture toggles playback on a mouse', () => {
  const { v, tap } = runPlayerDom({ tracks: [], trackEls: [], finePointer: true });
  assert.equal(v.paused, true);
  tap(500);
  assert.equal(v.paused, false, 'first click resumes');
  tap(500);
  assert.equal(v.paused, true, 'second click pauses');
});

test('a finger never pauses the picture', () => {
  const { v, tap } = runPlayerDom({ tracks: [], trackEls: [], finePointer: false });
  assert.equal(v.paused, true);
  tap(500);
  assert.equal(v.paused, true, 'one tap must not pause on touch');
  tap(500);
  assert.equal(v.paused, true, 'and two taps in the middle only toggle play');
});

test('double tap on either side seeks ten seconds', () => {
  const { v, tap } = runPlayerDom({ tracks: [], trackEls: [], finePointer: false });
  v.currentTime = 50;
  tap(10);
  tap(10);
  assert.equal(v.currentTime, 40, 'left third rewinds');
  tap(90);
  tap(90);
  assert.equal(v.currentTime, 50, 'right third forwards');
});

test('the scrubber drags and only seeks when the pointer lifts', () => {
  const { els, v, window } = runPlayerDom({ tracks: [], trackEls: [] });
  const scrub = els.scrub;
  scrub.dispatch('pointerdown', { clientX: 20, pointerId: 1 });
  assert.equal(v.currentTime, 0, 'grabbing the bar does not jump yet');
  window.dispatch('pointermove', { clientX: 80 });
  assert.equal(v.currentTime, 0, 'dragging previews without seeking');
  assert.equal(els['s-fill'].style.width, '80%', 'the bar follows the finger');
  window.dispatch('pointerup', {});
  assert.equal(v.currentTime, 80, 'lifting commits the seek');
});

test('the scrubber answers the keyboard', () => {
  const { els, v } = runPlayerDom({ tracks: [], trackEls: [] });
  const scrub = els.scrub;
  scrub.dispatch('keydown', { key: 'ArrowRight', preventDefault() {} });
  assert.equal(v.currentTime, 10);
  scrub.dispatch('keydown', { key: 'ArrowLeft', preventDefault() {} });
  assert.equal(v.currentTime, 0);
  scrub.dispatch('keydown', { key: 'End', preventDefault() {} });
  assert.equal(v.currentTime, 100);
  scrub.dispatch('keydown', { key: 'Home', preventDefault() {} });
  assert.equal(v.currentTime, 0);
});

test('the volume slider drives the video and survives a reload', () => {
  const store = new Map();
  const first = runPlayerDom({ tracks: [], trackEls: [], store });
  first.els['vol-range'].value = '0.4';
  first.els['vol-range'].dispatch('input', {});
  assert.equal(first.v.volume, 0.4);
  assert.equal(first.v.muted, false);

  const second = runPlayerDom({ tracks: [], trackEls: [], store });
  assert.equal(second.v.volume, 0.4, 'volume is remembered');
  assert.equal(second.els['vol-range'].value, '0.4', 'the slider starts where she left it');
});

test('speed runs from 0.25x to 2x and persists', () => {
  const store = new Map();
  const first = runPlayerDom({ tracks: [], trackEls: [], store });
  first.els['btn-speed'].dispatch('click');
  const menu = first.els['sp-menu'];
  assert.equal(menu.hidden, false);
  assert.deepEqual(
    menu.children.map((b) => b.textContent),
    ['0.25x', '0.5x', '0.75x', '1x', '1.25x', '1.5x', '1.75x', '2x'],
  );
  assert.equal(menu.children[3].className, 'qi on', '1x is the default');

  menu.children[5].onclick();
  assert.equal(first.v.playbackRate, 1.5);
  assert.equal(first.els['btn-speed'].textContent, '1.5x');
  assert.equal(first.els['btn-speed'].classList.contains('on'), true,
    'a non-default speed is visible');

  const second = runPlayerDom({ tracks: [], trackEls: [], store });
  assert.equal(second.v.playbackRate, 1.5, 'speed is remembered');
});

test('the picture-in-picture button hands the video to the browser', () => {
  const { els, v } = runPlayerDom({ tracks: [], trackEls: [] });
  let asked = 0;
  v.requestPictureInPicture = () => { asked += 1; return Promise.resolve(); };
  els['btn-pip'].dispatch('click');
  assert.equal(asked, 1, 'standard W3C PiP requested');

  const safari = runPlayerDom({ tracks: [], trackEls: [] });
  let safariMode = '';
  safari.v.requestPictureInPicture = null;
  safari.v.webkitSupportsPresentationMode = true;
  safari.v.webkitPresentationMode = 'inline';
  safari.v.webkitSetPresentationMode = (m) => { safariMode = m; };
  safari.els['btn-pip'].dispatch('click');
  assert.equal(safariMode, 'picture-in-picture', 'Safari iPad webkit mode toggled');
});

test('a mid-play stall shows a ring, not the boot wave', () => {
  const { els, fire } = runPlayerDom({ tracks: [], trackEls: [] });
  const boot = els.boot;
  const buf = els.buf;

  fire('waiting');
  assert.equal(boot.style.display, 'flex');
  assert.equal(buf.hidden, true);

  fire('playing');
  assert.equal(buf.hidden, true);
  boot.style.display = '';

  fire('waiting');
  assert.equal(buf.hidden, false);
  assert.equal(boot.style.display, '', 'the wordmark stays gone');
  fire('canplay');
  assert.equal(buf.hidden, true);
});

test('the scrubber does not seek twice on one key', () => {
  const { els } = runPlayerDom({ tracks: [], trackEls: [] });
  let stopped = 0;
  els.scrub.dispatch('keydown', {
    key: 'ArrowRight',
    preventDefault() {},
    stopPropagation() { stopped += 1; },
  });
  assert.equal(stopped, 1, 'the window handler must not see the same key');
});

test('captions scale with the picture instead of capping at 22px', () => {
  const { html } = runPlayerDom({ tracks: [], trackEls: [] });
  const m = html.match(/font-size:calc\(clamp\(15px,2\.4vw,(\d+)px\)/);
  assert.ok(m, 'caption size is a clamp');
  assert.ok(Number(m[1]) >= 40, `ceiling ${m[1]}px must scale with the picture`);
  assert.ok(html.includes('var(--sub-scale,1)'), 'the size control still applies');
});

test('Skip and Next sit outside the HUD so they survive the fade', () => {
  const { html } = runPlayerDom({ tracks: [], trackEls: [] });
  const at = html.indexOf('id="binge"');
  const open = html.lastIndexOf('<div', at);
  let depth = 0;
  for (const tag of html.slice(0, open).match(/<div\b|<\/div>/g) || []) {
    depth += tag === '</div>' ? -1 : 1;
  }
  assert.equal(depth, 0, '#binge must be a body-level sibling of #hud');
  assert.ok(html.includes('#binge{position:fixed'), 'it is pinned on its own');
  assert.ok(html.includes('#binge .b-act{pointer-events:auto}'));
});

test('the app can relay keys into the player', () => {
  const { v, relay } = runPlayerDom({ tracks: [], trackEls: [] });
  relay({ type: 'everglow-key', key: 'ArrowRight' });
  assert.equal(v.currentTime, 10, 'a key from the parent document seeks');
  relay({ type: 'everglow-key', key: '5' });
  assert.equal(v.currentTime, 50);
});

test('the keyboard seeks, toggles and jumps', () => {
  const { v, key } = runPlayerDom({ tracks: [], trackEls: [] });
  key('ArrowRight');
  assert.equal(v.currentTime, 10);
  key('ArrowLeft');
  assert.equal(v.currentTime, 0, 'never rewinds past zero');
  key('l');
  assert.equal(v.currentTime, 10);
  key('j');
  assert.equal(v.currentTime, 0);
  key(' ');
  assert.equal(v.paused, false);
  key(' ');
  assert.equal(v.paused, true);
  key('5');
  assert.equal(v.currentTime, 50, '0-9 jump to that tenth');
  key('ArrowUp');
  assert.equal(v.volume, 1, 'volume clamps at full');
  key('ArrowDown');
  assert.ok(v.volume < 1);
});

test('the CC panel holds captions, language, delay and size', () => {
  const trackEls = [{ label: 'English' }, { label: 'Icelandic' }];
  const { els, v } = runPlayerDom({ tracks: ['English', 'Icelandic'], trackEls });
  const menu = els['cc-menu'];
  els['btn-cc'].dispatch('click');
  assert.equal(menu.hidden, false, 'the CC button opens the panel');
  const headers = menuFlat(menu).filter((c) => c.className === 'cc-h').map((c) => c.textContent);
  assert.deepEqual(headers, [
    'Captions',
    'Language',
    'Subtitle delay',
    'Text size',
    'Caption style',
    'Caption color',
    'Position',
  ]);
  const capRow = ccRow(menu, 'Captions');
  assert.equal(capRow.children[1].className, 'qi on', 'captions start on');
  assert.equal(capRow.children[1].getAttribute('role'), 'menuitem', 'menu items expose ARIA role');
  const eng = findMenuBtn(menu, 'English');
  assert.equal(eng.className, 'qi on', 'first track is the default');

  const delayRow = ccRow(menu, 'Subtitle delay');
  assert.deepEqual(delayRow.children.map((b) => b.textContent), ['\u2212', '0.0s', '+']);
  delayRow.children[2].onclick();
  assert.equal(ccRow(menu, 'Subtitle delay').children[1].textContent, '+0.1s');
  ccRow(menu, 'Subtitle delay').children[2].onclick();
  assert.equal(ccRow(menu, 'Subtitle delay').children[1].textContent, '+0.2s');
  ccRow(menu, 'Subtitle delay').children[1].onclick();
  assert.equal(ccRow(menu, 'Subtitle delay').children[1].textContent, '0.0s', 'tap the value to reset');
  ccRow(menu, 'Subtitle delay').children[0].onclick();
  assert.equal(ccRow(menu, 'Subtitle delay').children[1].textContent, '-0.1s');

  const sizeRow = ccRow(menu, 'Text size');
  assert.deepEqual(sizeRow.children.map((b) => b.textContent), ['Small', 'Medium', 'Large']);
  assert.equal(sizeRow.children[1].className, 'qi on', 'medium is the default');
  sizeRow.children[2].onclick();
  assert.equal(els['sub-txt'].style.getPropertyValue('--sub-scale'), '1.3', 'large text');

  const posRow = ccRow(menu, 'Position');
  posRow.children[2].onclick();
  assert.equal(els['sub-box'].style.getPropertyValue('--sub-pos'), '44px', 'high subtitle position');

  findMenuBtn(menu, 'Icelandic').onclick();
  assert.deepEqual(v.textTracks.map((t) => t.mode), ['disabled', 'hidden']);
  assert.equal(menu.hidden, false, 'the panel stays open for more tuning');
});

test('subtitle delay shifts which line is on screen', () => {
  const cues = [{ startTime: 10, endTime: 12, text: 'hello' }];
  const { els, v, fire } = runPlayerDom({
    tracks: [{ label: 'English', cues }],
    trackEls: [{ label: 'English' }],
  });
  const sub = els['sub-txt'];
  const bump = (n) => {
    const step = n > 0 ? 1 : -1;
    for (let i = 0; i < Math.abs(n); i++) {
      ccRow(els['cc-menu'], 'Subtitle delay').children[step > 0 ? 2 : 0].onclick();
    }
  };

  v.currentTime = 10.5;
  fire('timeupdate');
  assert.equal(sub.textContent, 'hello');

  bump(10);
  v.currentTime = 10.5;
  fire('timeupdate');
  assert.equal(sub.textContent, '');
  v.currentTime = 11.5;
  fire('timeupdate');
  assert.equal(sub.textContent, 'hello');

  bump(-20);
  v.currentTime = 9.5;
  fire('timeupdate');
  assert.equal(sub.textContent, 'hello');
  v.currentTime = 8.5;
  fire('timeupdate');
  assert.equal(sub.textContent, '');

  ccRow(els['cc-menu'], 'Captions').children[0].onclick();
  v.currentTime = 9.5;
  fire('timeupdate');
  assert.equal(sub.textContent, '');
});

test('the CC panel lifts the captions instead of covering them', () => {
  const { els } = runPlayerDom({ tracks: ['English'], trackEls: [{ label: 'English' }] });
  const box = els['sub-box'];
  const menu = els['cc-menu'];
  menu.getBoundingClientRect = () => ({ x: 0, y: 0, width: 100, height: 160, left: 0 });
  assert.equal(box.style.getPropertyValue('--sub-lift'), '0px', 'no panel, no lift');

  els['btn-cc'].dispatch('click');
  assert.equal(menu.hidden, false);
  assert.equal(box.style.getPropertyValue('--sub-lift'), '142px', 'panel height - 18px');

  els['btn-cc'].dispatch('click');
  assert.equal(menu.hidden, true);
  assert.equal(box.style.getPropertyValue('--sub-lift'), '0px', 'lift drops with the panel');
});

test('binge scrim is hidden when both skip and next are hidden', () => {
  const { html } = runPlayerDom({ tracks: [], trackEls: [] });
  assert.ok(html.includes('id="b-scrim" hidden'), 'scrim starts hidden');
  assert.ok(html.includes('#b-scrim[hidden]{display:none!important}'));
});

test('subtitle settings survive the next episode', () => {
  const store = new Map();
  const first = runPlayerDom({
    tracks: ['English'], trackEls: [{ label: 'English' }], store,
  });
  const firstMenu = first.els['cc-menu'];
  ccRow(firstMenu, 'Subtitle delay').children[2].onclick();
  ccRow(firstMenu, 'Subtitle delay').children[2].onclick();
  ccRow(firstMenu, 'Text size').children[0].onclick();
  ccRow(firstMenu, 'Captions').children[0].onclick();

  const second = runPlayerDom({
    tracks: ['English'], trackEls: [{ label: 'English' }], store,
  });
  const menu = second.els['cc-menu'];
  assert.equal(ccRow(menu, 'Subtitle delay').children[1].textContent, '+0.2s');
  assert.equal(ccRow(menu, 'Text size').children[0].className, 'qi on', 'small text kept');
  assert.equal(ccRow(menu, 'Captions').children[0].className, 'qi on', 'captions stay off');
  assert.equal(second.els['btn-cc'].classList.contains('on'), false);
});

test('stripAdCues removes the advert spliced into a subtitle track', () => {
  const vtt = [
    'WEBVTT',
    '',
    '00:00:06.000 --> 00:00:12.074',
    'Visit hoofoot.ru to watch all sports livestream and highlights for free',
    '',
    '00:01:09.386 --> 00:01:11.221',
    'Oh, my god.',
    '',
    '00:57:13.305 --> 00:58:13.432',
    'Visit hoofoot.ru to watch all sports livestream and highlights for free',
    '',
  ].join('\n');

  const out = stripAdCues(vtt);

  assert.equal(out.includes('hoofoot'), false, 'the advert is gone');
  assert.equal(out.includes('Oh, my god.'), true, 'real dialogue is kept');
  assert.equal(out.startsWith('WEBVTT'), true, 'the header survives');
  assert.equal(out.includes('00:01:09.386 --> 00:01:11.221'), true);
});

test('stripAdCues leaves dialogue that mentions no website untouched', () => {
  const vtt = [
    'WEBVTT',
    '',
    '00:00:01.000 --> 00:00:02.000',
    'Mr. Smith went to St. Petersburg in 1999.',
    '',
    '00:00:03.000 --> 00:00:04.000',
    'It cost 3.14 dollars, e.g. about a third.',
    '',
  ].join('\n');

  assert.equal(stripAdCues(vtt), vtt, 'no cue is dropped');
});

test('stripAdCues keeps cue identifiers and NOTE blocks', () => {
  const vtt = [
    'WEBVTT',
    '',
    'NOTE this is a note',
    '',
    'cue-1',
    '00:00:01.000 --> 00:00:02.000',
    'Hello there.',
    '',
    'cue-2',
    '00:00:03.000 --> 00:00:04.000',
    'Buy it at www.example.com now',
    '',
  ].join('\n');

  const out = stripAdCues(vtt);

  assert.equal(out.includes('NOTE this is a note'), true);
  assert.equal(out.includes('cue-1'), true, 'the kept cue keeps its id');
  assert.equal(out.includes('www.example.com'), false);
  assert.equal(out.includes('Hello there.'), true);
});

test('stripAdCues returns non-VTT bodies unchanged', () => {
  assert.equal(stripAdCues(''), '');
  assert.equal(stripAdCues('not a subtitle'), 'not a subtitle');
  assert.equal(stripAdCues(null), null);
});

test('handleProxyHls strips the advert from a subtitle it proxies', async () => {
  const KEY = 'subtitle-key';
  const HOST = 'https://everglow-stream.example.workers.dev';
  const realFetch = globalThis.fetch;
  const vtt = [
    'WEBVTT',
    '',
    '00:00:06.000 --> 00:00:12.074',
    'Visit hoofoot.ru to watch all sports livestream and highlights for free',
    '',
    '00:01:09.386 --> 00:01:11.221',
    'Oh, my god.',
    '',
  ].join('\n');
  const seen = [];
  try {
    globalThis.fetch = async (url) => {
      seen.push(String(url));
      return {
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'text/vtt' }),
        text: async () => vtt,
      };
    };
    const track = 'https://cache.vdrk.site/v1/vtt/tv/1396/1/1/English.vtt';
    const sealed = await cinemaProxyUrl(`${HOST}/proxyMegavidHls`, track, 'fmov', KEY);
    assert.ok(sealed, 'the track can be sealed');

    const res = await handleProxyHls(new Request(sealed), { CDN_STAMP_KEY: KEY });

    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type') || '', /text\/vtt/);
    const body = await res.text();
    assert.equal(body.includes('hoofoot'), false, 'the advert is gone');
    assert.equal(body.includes('Oh, my god.'), true, 'the dialogue survives');
    assert.deepEqual(seen, [track], 'the upstream was asked once');
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('the player forwards wheel events to the parent page except in menus or fullscreen', () => {
  const { els, v, window, doc } = runPlayerDom({ tracks: ['English'], trackEls: [{ label: 'English' }] });
  const posted = [];
  window.parent.postMessage = (msg) => posted.push({ ...msg });

  window.dispatch('wheel', { deltaX: 0, deltaY: 120, deltaMode: 0, target: v });
  assert.deepEqual(posted, [
    { type: 'everglow-embed-scroll', deltaX: 0, deltaY: 120, deltaMode: 0 },
  ]);

  els['btn-cc'].dispatch('click');
  assert.equal(els['cc-menu'].hidden, false);
  window.dispatch('wheel', {
    deltaX: 0,
    deltaY: 80,
    deltaMode: 0,
    target: els['cc-menu'].children[0],
  });
  assert.equal(posted.length, 1, 'scrolling inside an open menu stays in the menu');

  els['btn-cc'].dispatch('click');
  doc.fullscreenElement = doc.documentElement;
  window.dispatch('wheel', { deltaX: 0, deltaY: 120, deltaMode: 0, target: v });
  assert.equal(posted.length, 1, 'fullscreen suppresses parent page scroll');
});

test('fullscreenchange syncs the fullscreen button state and settle class', () => {
  const { els, doc } = runPlayerDom({ tracks: [], trackEls: [] });
  assert.equal(els['btn-fs'].classList.contains('on'), false);

  doc.fullscreenElement = doc.documentElement;
  doc.dispatch('fullscreenchange');
  assert.equal(els['btn-fs'].classList.contains('on'), true);
  assert.equal(els['btn-fs'].getAttribute('aria-label'), 'Exit fullscreen');
  assert.equal(doc.body.classList.contains('is-fs'), true);
  assert.equal(doc.body.classList.contains('fs-settle'), true);
  assert.match(els['fs-p'].getAttribute('d') || '', /M7 3v4H3/, 'compress icon');

  doc.fullscreenElement = null;
  doc.dispatch('fullscreenchange');
  assert.equal(els['btn-fs'].classList.contains('on'), false);
  assert.equal(els['btn-fs'].getAttribute('aria-label'), 'Fullscreen');
  assert.equal(doc.body.classList.contains('is-fs'), false);
  assert.match(els['fs-p'].getAttribute('d') || '', /M3 7V3h4/, 'expand icon');
});

test('seek bar hover shows the Netflix-style preview card with timestamp, chapter tag, and clamped position', () => {
  const { els, v, relay } = runPlayerDom({ tracks: [], trackEls: [] });
  v.duration = 200;
  els['scrub-wrap'].offsetWidth = 400;
  els['scrub-prev'].offsetWidth = 168;
  relay({ type: 'animex-skip-times', op: [20, 60], ed: [170, 195] });

  els.scrub.dispatch('pointermove', { clientX: 25, pointerType: 'mouse' });
  assert.equal(els['scrub-prev'].hidden, false);
  assert.equal(els['pv-time'].textContent, '00:50');
  assert.equal(els['pv-tag'].hidden, false);
  assert.equal(els['pv-tag'].textContent, 'Intro');
  assert.equal(els['s-hover'].style.width, '25%');
  assert.equal(els['scrub-prev'].style.left, '100px');

  els.scrub.dispatch('pointermove', { clientX: 2, pointerType: 'mouse' });
  assert.equal(els['scrub-prev'].style.left, '84px');
  assert.equal(els['pv-tag'].hidden, true);

  els.scrub.dispatch('pointermove', { clientX: 95, pointerType: 'mouse' });
  assert.equal(els['scrub-prev'].style.left, '316px');
  assert.equal(els['pv-tag'].hidden, false);
  assert.equal(els['pv-tag'].textContent, 'Ending');
});

test('leaving the seek bar hides the preview card and resets the hover bar', () => {
  const { els, v } = runPlayerDom({ tracks: [], trackEls: [] });
  v.duration = 100;
  els.scrub.dispatch('pointermove', { clientX: 50, pointerType: 'mouse' });
  assert.equal(els['scrub-prev'].hidden, false);
  assert.equal(els['s-hover'].style.width, '50%');

  els.scrub.dispatch('pointerleave');
  assert.equal(els['scrub-prev'].hidden, true);
  assert.equal(els['s-hover'].style.width, '0%');
});

test('preview Hls initializes lazily on hover at lowest level and resets on server switch', async () => {
  const { els, v, instances, loads } = runPlayerDom({
    tracks: [],
    trackEls: [],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' },
      { id: 'yume-2', label: 'Yume 2', url: 'https://w/proxyAnime?server=yume-2' },
    ],
    fetchImpl: async () => ({ json: async () => ({ src: 'https://w/picked-2' }) }),
  });
  v.duration = 100;

  assert.equal(instances.length, 1, 'boot starts only one Hls instance');

  els.scrub.dispatch('pointermove', { clientX: 40, pointerType: 'mouse' });
  assert.equal(instances.length, 2, 'hover lazily spins up preview Hls');
  assert.equal(instances[1].opts.startLevel, 0, 'preview picks lowest rendition');
  assert.equal(loads[1], 'https://x/y.m3u8');

  els.scrub.dispatch('pointermove', { clientX: 40, pointerType: 'mouse' });
  els['pv-c'].hidden = false;
  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));
  assert.equal(instances[1].destroyed, true, 'server pick destroys old preview instance');
  assert.equal(els['pv-c'].hidden, true, 'server pick clears previous preview canvas');

  els.scrub.dispatch('pointermove', { clientX: 60, pointerType: 'mouse' });
  assert.equal(instances.length, 3);
  assert.equal(loads[loads.length - 1], 'https://w/picked-2');
});

test('dragging the scrub bar shows preview and thumb without seeking until release', () => {
  const { els, v, window, doc } = runPlayerDom({ tracks: [], trackEls: [] });
  v.duration = 100;
  v.currentTime = 10;

  els.scrub.dispatch('pointermove', { clientX: 40, pointerType: 'touch' });
  assert.equal(els['scrub-prev'].hidden, true);

  els.scrub.dispatch('pointerdown', { clientX: 30, preventDefault() {} });
  assert.equal(doc.body.classList.contains('scrubbing'), true);
  assert.equal(els['scrub-prev'].hidden, false);
  assert.equal(els['pv-time'].textContent, '00:30');
  assert.equal(els['s-fill'].style.width, '30%');
  assert.equal(els['s-thumb'].style.left, '30%');
  assert.equal(v.currentTime, 10, 'drag does not commit seek mid-scrub');

  window.dispatch('pointermove', { clientX: 70 });
  assert.equal(els['pv-time'].textContent, '01:10');
  assert.equal(v.currentTime, 10);

  els.scrub.dispatch('pointerleave');
  window.dispatch('pointerup', { clientX: 70, clientY: 999 });
  assert.equal(doc.body.classList.contains('scrubbing'), false);
  assert.equal(els['scrub-prev'].hidden, true);
  assert.equal(v.currentTime, 70, 'release commits the final seek position');

  els.scrub.dispatch('pointerdown', { clientX: 20, preventDefault() {} });
  assert.equal(els['scrub-prev'].hidden, false);
  window.dispatch('pointercancel');
  assert.equal(els['scrub-prev'].hidden, true);
  assert.equal(v.currentTime, 70, 'pointercancel discards uncommitted scrub');
});

test('fatal error on preview Hls shuts down preview once without retrying or condemning main playback', () => {
  const { els, v, instances, window } = runPlayerDom({ tracks: [], trackEls: [] });
  v.duration = 100;
  const posted = [];
  window.parent.postMessage = (msg) => posted.push(msg);

  els.scrub.dispatch('pointermove', { clientX: 50, pointerType: 'mouse' });
  assert.equal(instances.length, 2);
  assert.equal(els['scrub-prev'].classList.contains('loading'), true);

  instances[1]._handlers.e({}, { fatal: true, type: 'other' });
  assert.equal(instances[1].destroyed, true, 'broken preview shuts itself down');
  assert.equal(els['scrub-prev'].classList.contains('loading'), false);
  assert.equal(instances[0].destroyed, false, 'main stream stays alive');
  assert.deepEqual(posted, [], 'main player never gives up over a preview failure');

  els.scrub.dispatch('pointermove', { clientX: 60, pointerType: 'mouse' });
  assert.equal(instances.length, 2, 'no preview retry storm after fatal error');
  assert.equal(els['scrub-prev'].classList.contains('loading'), false);
});

test('preview seeks debounce, cache decoded frames, and fall back to video tag on canvas error', async () => {
  const { els, v, doc } = runPlayerDom({ tracks: [], trackEls: [] });
  v.duration = 100;
  const drawn = [];
  const offscreen = () => ({
    width: 0,
    height: 0,
    getContext: () => ({
      drawImage(srcEl) { drawn.push(srcEl); },
      clearRect() {},
    }),
  });
  doc.createElement = offscreen;
  els['pv-c'].getContext = () => ({
    drawImage(srcEl) { drawn.push(srcEl); },
    clearRect() {},
  });
  els.pv.readyState = 2;
  els.pv.videoWidth = 640;
  els.pv.videoHeight = 360;

  els.scrub.dispatch('pointermove', { clientX: 50, pointerType: 'mouse' });
  els.pv.dispatch('loadedmetadata');
  await new Promise((r) => setTimeout(r, 70));
  assert.equal(els.pv.currentTime, 50, 'debounced preview seek reaches target bucket');

  els.pv.dispatch('seeked');
  assert.equal(els['scrub-prev'].classList.contains('loading'), false);
  assert.equal(els['pv-c'].hidden, false);
  assert.ok(drawn.length >= 2, 'cached offscreen canvas and display canvas both populated');

  const countBefore = drawn.length;
  els.pv.currentTime = 0;
  els.scrub.dispatch('pointermove', { clientX: 50, pointerType: 'mouse' });
  assert.equal(drawn.length, countBefore + 1);
  assert.equal(els.pv.currentTime, 0, 'cache hit skips redundant seek');

  els['pv-c'].getContext = () => ({
    drawImage() { throw new Error('SecurityError'); },
    clearRect() {},
  });
  els.pv.dispatch('seeked');
  assert.equal(els['pv-c'].hidden, true, 'taint fallback hides canvas to reveal preview video');
});

test('Cinema player exposes Episodes button when hasEpisodes is enabled and routes theater exit', () => {
  const withEps = hlsPlayerHtml({
    src: 'https://x/y.m3u8',
    title: 'Breaking Bad',
    kind: 'cinema',
    hasEpisodes: true,
  });
  assert.ok(withEps.includes('id="btn-eps"'), 'cinema series keeps episodes button');
  assert.ok(!withEps.includes('id="btn-sub"'), 'cinema still drops SUB/DUB');

  const { els, window, doc } = runPlayerDom({ tracks: [], trackEls: [] });
  const posted = [];
  window.parent.postMessage = (msg) => posted.push(msg);
  const ctrlRt = Object.assign(els['btn-fs'], {
    insertBefore(node) { this.children.push(node); },
  });
  els['btn-cc'].parentNode = ctrlRt;
  doc.querySelector = (sel) => (sel === '.ctrl-rt' ? ctrlRt : null);

  window.dispatch('message', {
    source: window.parent,
    origin: 'https://everglow-1c6db.web.app',
    data: { type: 'animex-player-state', hasEpisodes: true, theater: true },
  });
  const dynBtn = ctrlRt.children.find((c) => c.getAttribute && c.getAttribute('id') === 'btn-eps');
  assert.ok(dynBtn, 'animex-player-state creates episodes button when missing');
  dynBtn.dispatch('click');
  assert.deepEqual(JSON.parse(JSON.stringify(posted[0])), { type: 'animex-action', action: 'episodes' });

  els['btn-fs'].dispatch('click');
  assert.deepEqual(JSON.parse(JSON.stringify(posted[1])), { type: 'animex-action', action: 'exit-theater' });
});

test('Quality menu items carry ARIA menuitem role and time label toggles elapsed vs -remaining', () => {
  const { els, v, instances, fire } = runPlayerDom({ tracks: [], trackEls: [] });
  v.duration = 120;
  v.currentTime = 30;
  instances[0].levels = [{ height: 720 }, { height: 1080 }];
  instances[0]._handlers.m();
  assert.equal(els['q-menu'].children.length, 3);
  assert.equal(els['q-menu'].children[0].getAttribute('role'), 'menuitem');
  assert.equal(els['q-menu'].children[0].type, 'button');

  fire('timeupdate');
  assert.equal(els['time-lbl'].textContent, '00:30 / 02:00');
  els['time-lbl'].dispatch('click');
  assert.equal(els['time-lbl'].textContent, '-01:30');
});

test('Cinema keeps neutral styling without Everglow badge, and Z/I keys cycle aspect and stats', () => {
  const cinemaHtml = hlsPlayerHtml({ src: 'https://x/y.m3u8', title: 'Movie', kind: 'cinema' });
  const animeHtml = hlsPlayerHtml({ src: 'https://x/y.m3u8', title: 'Ep 1', kind: 'anime' });
  assert.ok(cinemaHtml.includes('<body class="is-cinema">'), 'cinema gets neutral theme class');
  assert.ok(!cinemaHtml.includes('class="eg-badge"'), 'cinema omits Everglow badge');
  assert.ok(!cinemaHtml.includes('class="eg-cat"'), 'cinema omits cat icon');
  assert.ok(animeHtml.includes('class="eg-badge"'), 'anime keeps Everglow badge');

  const { els, v, key } = runPlayerDom({ tracks: [], trackEls: [] });
  els['stats-card'] = Object.assign({}, els['q-menu'], { hidden: true, innerHTML: '' });
  key('z');
  assert.equal(v.classList.contains('fill'), true);
  key('z');
  assert.equal(v.classList.contains('zoom'), true);
  key('z');
  assert.equal(v.classList.contains('fill'), false);
  assert.equal(v.classList.contains('zoom'), false);
});

test('screen lock blocks keyboard shortcuts and floating Next hides bottom Next icon', () => {
  const { els, v, window, fire, key } = runPlayerDom({
    tracks: [{ label: 'English - English (SDH)' }, { label: 'Spanish' }],
    trackEls: [{ label: 'English - English (SDH)' }, { label: 'Spanish' }],
  });
  v.duration = 200;
  v.currentTime = 50;
  els['btn-cc'].dispatch('click');
  assert.ok(findMenuBtn(els['cc-menu'], 'English (SDH)'), 'dedupes repeated language label');

  els['btn-lock'].dispatch('click');
  const before = v.currentTime;
  const pausedBefore = v.paused;
  key(' ');
  key('l');
  assert.equal(v.paused, pausedBefore);
  assert.equal(v.currentTime, before);
  assert.equal(els['unlock-w'].hidden, false);
  els['unlock-btn'].dispatch('click');

  window.dispatch('message', {
    source: window.parent,
    origin: 'https://everglow-1c6db.web.app',
    data: { type: 'animex-player-state', next: 'EP 2', nextKind: 'episode' },
  });
  assert.equal(els['btn-nx'].hidden, false);
  assert.equal(els['btn-next'].hidden, true);

  v.currentTime = 150;
  fire('timeupdate');
  assert.equal(els['btn-next'].hidden, false);
  assert.equal(els['btn-nx'].hidden, true, 'bottom Next steps aside when pill appears');

  els['btn-next-x'].dispatch('click', {});
  assert.equal(els['btn-next'].hidden, true, 'dismiss X hides floating Next pill');
  assert.equal(els['btn-nx'].hidden, false, 'bottom Next restores after dismiss');

  key('m');
  assert.equal(els['vol-w'].hidden, true, 'mute hides sound waves');
  assert.equal(els['vol-x'].hidden, false, 'mute reveals X glyph');
  key('m');
  assert.equal(els['vol-w'].hidden, false);
  assert.equal(els['vol-x'].hidden, true);
});

test('mobile settings falls back to Auto quality on native HLS and desktop settings keep 416px width', () => {
  const { els, html, window } = runPlayerDom({ tracks: [], trackEls: [] });
  assert.ok(html.includes('#more-menu{width:min(416px'), 'desktop settings matches 416px width');
  assert.ok(html.includes('#more-menu .cc-row .qi{min-width:0;padding:5px 4px}'));
  assert.ok(html.includes('#binge{padding:0 12px;bottom:92px}'));
  assert.ok(html.includes('Intro: Off') && html.includes('Intro: Auto'), 'plain Intro label in settings');
  assert.ok(html.includes('binge-left'), 'compact subtitle clearance');
  const animeHtml = hlsPlayerHtml({ src: 'https://x/y.m3u8', title: 'Ep 1', kind: 'anime' });
  assert.ok(!animeHtml.includes('id="tap-opts"') && !animeHtml.includes('id="tapw"'), 'pre-play splash overlay removed');
  assert.ok(animeHtml.includes('id="btn-sv"') && animeHtml.includes('id="btn-sub"') && animeHtml.includes('id="btn-dub"'), 'anime HUD exposes quick selectors');

  els['btn-more'].dispatch('click');
  assert.ok(findMenuBtn(els['more-menu'], '\u2715'), 'desktop/tablet settings has close button');
  els['btn-more'].dispatch('click');

  window.innerWidth = 430;
  window.innerHeight = 242;
  els['btn-more'].dispatch('click');
  assert.ok(findMenuBtn(els['more-menu'], 'Auto'), 'native HLS keeps Quality -> Auto row on narrow screens');
});

test('CC menu exposes Audio track switching when subtitles are absent and labels Subtitles accurately', () => {
  const { els, instances } = runPlayerDom({ tracks: [], trackEls: [] });
  assert.equal(els['btn-cc'].hidden, true, 'no subs and no multi-audio hides button');

  instances[0].audioTracks = [{ name: 'Japanese' }, { name: 'English' }];
  instances[0]._handlers.m();
  assert.equal(els['btn-cc'].hidden, false, 'multi-audio without subtitles shows CC/Audio button');
  els['btn-cc'].dispatch('click');
  assert.ok(findMenuBtn(els['cc-menu'], 'Japanese') && findMenuBtn(els['cc-menu'], 'English'), 'audio options render');
  assert.equal(findMenuBtn(els['cc-menu'], 'Outline'), undefined, 'subtitle-only controls omitted');
});

test('shortcuts guide, mute slider collapse, next-ep countdown, and server title hint preserve DOM contracts', async () => {
  const { els, v, doc, key, fire, relay } = runPlayerDom({
    tracks: ['English'],
    trackEls: [{ label: 'English', src: 'https://x/English.vtt' }],
    current: 'yume-1',
    servers: [
      { id: 'yume-1', label: 'Yume 1', url: 'https://w/proxyAnime?server=yume-1' },
      { id: 'yume-2', label: 'Yume 2', url: 'https://w/proxyAnime?server=yume-2' },
    ],
    fetchImpl: async () => ({ json: async () => ({ src: 'https://w/proxyMegavidHls?t=s2' }) }),
  });

  assert.equal(els['btn-sv'].getAttribute('title'), 'Server: Yume 1');
  assert.equal(els['btn-sv'].getAttribute('data-sv'), 'Yume 1');
  els['btn-sv'].dispatch('click');
  els['sv-menu'].children[1].onclick();
  await new Promise((r) => setTimeout(r, 0));
  assert.equal(els['btn-sv'].textContent, 'Servers');
  assert.equal(els['btn-sv'].getAttribute('title'), 'Server: Yume 2');
  assert.equal(els['btn-sv'].getAttribute('data-sv'), 'Yume 2');

  key('m');
  assert.equal(doc.body.classList.contains('is-muted'), true);
  key('m');
  assert.equal(doc.body.classList.contains('is-muted'), false);

  relay({ type: 'animex-player-state', next: 'EP 2', nextKind: 'episode' });
  v.duration = 200;
  v.currentTime = 175;
  fire('timeupdate');
  assert.equal(els['btn-next'].hidden, false);
  assert.equal(els['next-tok'].textContent, 'EP 2');
  assert.equal(els['next-cd'].textContent, '00:25');

  key('?');
  assert.equal(els['keys-menu'].hidden, false, '? opens keyboard shortcuts dialog');
  key('Escape');
  assert.equal(els['keys-menu'].hidden, true, 'Escape closes keyboard shortcuts dialog');

  relay({ type: 'animex-player-state', title: 'My Hero Academia: Vigilantes · S1 E12', next: 'S1 E13', nextKind: 'episode', autoNext: true });
  assert.equal(els['hud-title'].textContent, 'My Hero Academia: Vigilantes');
  assert.equal(els['hud-ep'].textContent, ' \u00b7 S1 E12');
  assert.equal(els['hud-ep'].hidden, false);

  els['btn-more'].dispatch('click');
  const autoNextBtn = findMenuBtn(els['more-menu'], 'Auto next: On');
  assert.ok(autoNextBtn, 'Cinema player settings exposes Auto next toggle');
  assert.equal(findMenuBtn(els['more-menu'], '+85s'), undefined, 'Cinema keeps anime +85s hidden');
  els['btn-more'].dispatch('click');

  key('?');
  assert.equal(findMenuBtn(els['keys-menu'], 'S / N'), undefined);
  assert.ok(menuFlat(els['keys-menu']).some((n) => n.textContent === 'N'), 'Cinema shortcuts omit inactive Skip key');
  key('Escape');

  v.currentTime = 20;
  fire('timeupdate');
  assert.equal(els['btn-next'].hidden, true);
  assert.equal(els['btn-nx'].hidden, false);
  let nxClicked = 0;
  const origNxClick = els['btn-nx'].click;
  els['btn-nx'].click = () => { nxClicked++; if (origNxClick) origNxClick.call(els['btn-nx']); };
  key('n');
  assert.equal(nxClicked, 1, 'N triggers bottom Next button mid-episode');

  els['btn-cc'].dispatch('click');
  const topPosBtn = findMenuBtn(els['cc-menu'], 'Top');
  assert.ok(topPosBtn, 'CC Position menu exposes Top option for OP/ED avoidance');
  topPosBtn.onclick();
  assert.equal(doc.body.classList.contains('sub-top'), true);
  assert.equal(els.scrub.getAttribute('role'), 'slider');
  assert.equal(els.scrub.getAttribute('aria-label'), 'Seek timeline');
  assert.equal(els.scrub.getAttribute('aria-valuenow'), '20');
  const renderedHtml = hlsPlayerHtml({ streamUrl: 'https://x/master.m3u8', title: 'Test' });
  assert.ok(renderedHtml.includes('<button type="button" id="time-lbl"'), '#time-lbl uses semantic button element');
  assert.ok(renderedHtml.includes('id="scrub" role="slider" tabindex="0"'), '#scrub carries static ARIA slider attrs');
});
