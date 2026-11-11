import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  YUME_ORIGIN,
  YUME_SERVERS,
  YUME_SERVER_IDS,
  yumeCipherToken,
  yumeDecrypt,
  yumeHeaders,
  yumeMasterUrl,
  yumeSalt,
  yumeServer,
  yumeServerOrder,
  yumeSig,
  yumeSources,
} from './yumezone.js';

/** The wire cipher, inverted. `yumeDecrypt` XORs with a repeating key and a
 *  stride-3 counter, so the same loop encrypts. */
function encrypt(payload, sig) {
  const key = new TextEncoder().encode(String(sig));
  const json = new TextEncoder().encode(JSON.stringify(payload));
  const out = new Uint8Array(json.length);
  for (let i = 0; i < json.length; i++) {
    out[i] = json[i] ^ key[i % key.length] ^ ((i * 3) % 256);
  }
  return btoa(String.fromCharCode(...out));
}

test('the signature is deterministic for a fixed clock', async () => {
  const ts = 1767225600;
  assert.equal(yumeSalt(ts), 'J+B@ZZ8tUQ<*5%[c_%:H:Nb$x%H>OgHz)0aA:B,.A');
  assert.equal(
    await yumeSig(21, 1, ts),
    'd439a82bf3afdea594df6c493abc36210d9872eeedba2cde3c0849c680ff0d69',
  );
  // A different clock is a different signature: the site rejects replays.
  assert.notEqual(await yumeSig(21, 1, ts + 1), await yumeSig(21, 1, ts));
});

test('client_cipher_token is the reversed signature, base64', () => {
  const sig = 'abc123';
  assert.equal(yumeCipherToken(sig), btoa('321cba'));
});

test('the payload cipher round-trips', async () => {
  const sig = await yumeSig(21, 1, 1767225600);
  const payload = {
    available: true,
    source_type: 'hls',
    hls_sources: [{ url: 'https://x/y/master.m3u8' }],
    subtitles: [{ label: 'English', file: 'https://x/en.ass' }],
  };
  assert.deepEqual(yumeDecrypt(encrypt(payload, sig), sig), payload);
  // A wrong key must not throw a TypeError or return half a payload.
  assert.throws(() => yumeDecrypt(encrypt(payload, sig), 'f'.repeat(64)), /undecryptable/);
  assert.throws(() => yumeDecrypt('not base64!!', sig), /not base64/);
  assert.throws(() => yumeDecrypt(encrypt(payload, sig), ''), /empty cipher key/);
});

test('subbed audio tries the hardsub servers first, dubbed audio the softsub ones', () => {
  const sub = yumeServerOrder('sub').map((s) => s.id);
  const dub = yumeServerOrder('dub').map((s) => s.id);
  // Our player renders WebVTT only and YumeZone ships ASS/SRT, so a softsub
  // server would play with no subtitles. Hardsub carries them in the picture.
  assert.deepEqual(sub.slice(0, 3), ['yume-1', 'yume-2', 'yume-3']);
  assert.deepEqual(dub.slice(0, 3), ['yume-4', 'yume-5', 'yume-6']);
  assert.deepEqual([...sub].sort(), [...dub].sort(), 'same servers, different order');
  assert.equal(sub.length, YUME_SERVERS.length);
  assert.equal(yumeServerOrder(undefined).length, YUME_SERVERS.length);
});

test('the server table has unique ids and every id resolves', () => {
  assert.equal(YUME_SERVER_IDS.size, YUME_SERVERS.length);
  for (const server of YUME_SERVERS) {
    assert.equal(yumeServer(server.id), server);
    assert.ok(server.label && server.provider);
  }
  assert.equal(yumeServer('nope'), null);
});

test('the master URL is the first absolute https HLS source', () => {
  assert.equal(
    yumeMasterUrl({ hls_sources: [{ url: 'https://a/b/master.m3u8' }] }),
    'https://a/b/master.m3u8',
  );
  // A relative path is made absolute against the site, a bad entry is skipped.
  assert.equal(
    yumeMasterUrl({ hls_sources: [{ url: '/p/abc' }, { url: 'https://a/b/master.m3u8' }] }),
    `${YUME_ORIGIN}/p/abc`,
  );
  assert.equal(yumeMasterUrl({ hls_sources: [{ file: 'https://a/b/master.m3u8' }] }), 'https://a/b/master.m3u8');
  assert.equal(yumeMasterUrl({ hls_sources: [{ url: 'http://insecure/x.m3u8' }] }), '');
  assert.equal(yumeMasterUrl({ hls_sources: [] }), '');
  assert.equal(yumeMasterUrl({}), '');
  assert.equal(yumeMasterUrl(null), '');
});

test('yumeSources sends the signed body and decrypts the answer', async () => {
  const realFetch = globalThis.fetch;
  let seen;
  const realNow = Date.now;
  Date.now = () => 1767225600 * 1000;
  try {
    globalThis.fetch = async (url, init) => {
      seen = { url: String(url), init };
      const body = JSON.parse(init.body);
      const sig = await yumeSig(body.anime_id, body.episode_number, body.ts);
      assert.equal(body.sig, sig, 'the signature matches the body it signs');
      return new Response(
        JSON.stringify({ ct: encrypt({ available: true, hls_sources: [{ url: 'https://a/b/master.m3u8' }] }, sig) }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    };
    const out = await yumeSources({ animeId: 21, episode: 1, language: 'sub', provider: 'Goku' });
    assert.equal(seen.url, `${YUME_ORIGIN}/api/yume/watch/sources`);
    assert.equal(seen.init.method, 'POST');
    assert.equal(seen.init.headers.Referer, `${YUME_ORIGIN}/`);
    const sent = JSON.parse(seen.init.body);
    assert.equal(sent.anime_id, '21');
    assert.equal(sent.episode_number, 1);
    assert.equal(sent.language, 'sub');
    assert.equal(sent.provider, 'Goku');
    assert.equal(sent.client_cipher_token, yumeCipherToken(sent.sig));
    assert.equal(out.available, true);
    assert.equal(out.hls_sources[0].url, 'https://a/b/master.m3u8');
  } finally {
    globalThis.fetch = realFetch;
    Date.now = realNow;
  }
});

test('yumeSources passes an unencrypted body through and throws on a bad status', async () => {
  const realFetch = globalThis.fetch;
  try {
    globalThis.fetch = async () =>
      new Response(JSON.stringify({ available: false, message: 'no sources' }), { status: 200 });
    assert.deepEqual(await yumeSources({ animeId: 21, episode: 1, language: 'sub', provider: 'Goku' }), {
      available: false,
      message: 'no sources',
    });

    globalThis.fetch = async () => new Response('nope', { status: 503 });
    await assert.rejects(
      yumeSources({ animeId: 21, episode: 1, language: 'sub', provider: 'Goku' }),
      /yumezone Goku 503/,
    );
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('yumeHeaders name the site and never carry a cookie', () => {
  const headers = yumeHeaders();
  assert.equal(headers.Referer, `${YUME_ORIGIN}/`);
  assert.equal(headers.Origin, YUME_ORIGIN);
  assert.match(headers['User-Agent'], /Chrome/);
  assert.equal(headers.Cookie, undefined);
  assert.equal(yumeHeaders({ Accept: 'application/json' }).Accept, 'application/json');
});
