'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { Writable } = require('node:stream');
const common = require('./common');
const { signedStreamUrl, validStreamSignature, rewritePlaylist, STREAM_LIFETIME_MS } = require('./watch_stream_access');

const keys = new Map();
common.getDb = () => ({ collection: () => ({ doc: (uid) => ({
  get: async () => ({ exists: keys.has(uid), data: () => keys.get(uid) }),
  set: (value) => keys.set(uid, value),
}) }), runTransaction: async (fn) => fn({ get: (ref) => ref.get(), set: (ref, value) => ref.set(value) }) });
common.enforceRateLimit = () => false;
common.requireAuth = async (req, res) => {
  if (req.get('Authorization') === 'Bearer demo-token') return { uid: 'demo-user' };
  res.status(401).json({ error: 'Authentication required' }); return null;
};
let fetched;
let segment = false;
common.fetchPublicUrl = async (url, options) => {
  fetched = { url, options };
  if (segment) return { ok: true, status: 206, url,
    headers: new Headers({ 'content-type': 'video/mp2t', 'content-range': 'bytes 0-3/8',
      'content-length': '4', 'accept-ranges': 'bytes' }), body: new Response('DEMO').body };
  return { ok: true, status: 200, url: 'https://cdn.example/redirected/master.m3u8',
    headers: new Headers({ 'content-type': 'application/vnd.apple.mpegurl' }),
    body: new Response('#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="keys/key.bin"\nvariant/child.m3u8').body };
};
const { proxyWatchStream } = require('./media_proxy_video');
class ResponseSink extends Writable {
  constructor() { super(); this.headers = {}; this.code = 200; this.chunks = []; }
  _write(chunk, _, done) { this.chunks.push(chunk); done(); }
  set(name, value) { this.headers[name.toLowerCase()] = value; return this; }
  status(code) { this.code = code; return this; }
  json(body) { this.body = body; }
  send(body) { this.body = body; }
}
function request(url, { method = 'GET', body, token, range } = {}) {
  return { method, body, query: Object.fromEntries(new URL(url).searchParams),
    get: (name) => name === 'Authorization' ? token : name === 'Range' ? range : undefined };
}

test('signed media access is bound to the target, referer, uid, and six-hour expiry', () => {
  const now = Date.now();
  const access = { uid: 'demo', expires: now + STREAM_LIFETIME_MS, secret: 'demo-only', referer: 'https://media.example/' };
  const url = 'https://media.example/movie.m3u8';
  const signed = new URL(signedStreamUrl(url, access));
  const sig = signed.searchParams.get('signature');
  assert.ok(validStreamSignature(url, access, sig, now));
  for (const patch of [{ uid: 'other' }, { referer: '' }, { expires: access.expires + 1 }, { secret: 'other' }]) {
    assert.equal(validStreamSignature(url, { ...access, ...patch }, sig, now), false);
  }
  assert.equal(validStreamSignature('https://other.example/', access, sig, now), false);
  assert.equal(validStreamSignature(url, access, sig, access.expires), false);
  assert.throws(() => signedStreamUrl('file:///demo', access));
  const playlist = rewritePlaylist('#EXTM3U\n#EXT-X-MAP:URI="init.mp4"\n../seg.ts', url, access);
  assert.ok(!playlist.includes('demo-only'));
  assert.match(playlist, /init.mp4/);
  assert.match(playlist, /seg.ts/);
});

test('authenticated issuance lets headerless native media load rewritten playlists, not arbitrary URLs', async () => {
  const endpoint = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyWatchStream';
  let res = new ResponseSink();
  await proxyWatchStream(request(endpoint, { method: 'POST', body: { url: 'https://media.example/master.m3u8' } }), res);
  assert.equal(res.code, 401);
  res = new ResponseSink();
  await proxyWatchStream(request(endpoint, { method: 'POST', token: 'Bearer demo-token',
    body: { url: 'https://media.example/master.m3u8' } }), res);
  const signed = res.body.url;
  assert.ok(signed && !signed.includes('demo-token'));
  res = new ResponseSink();
  await proxyWatchStream(request(signed), res);
  assert.equal(res.code, 200);
  assert.equal(res.headers['cache-control'], 'private, no-store');
  const lines = res.body.split('\n');
  const nested = new URL(lines[2]);
  assert.equal(nested.searchParams.get('url'), 'https://cdn.example/redirected/variant/child.m3u8');
  assert.match(lines[1], /signature=/);
  const modified = new URL(signed);
  modified.searchParams.set('url', 'http://127.0.0.1/secret');
  res = new ResponseSink();
  await proxyWatchStream(request(modified), res);
  assert.equal(res.code, 401);
  assert.equal(fetched.url, 'https://media.example/master.m3u8');
  segment = true;
  const media = signedStreamUrl('https://media.example/segment.ts', {
    uid: 'demo-user', expires: Date.now() + STREAM_LIFETIME_MS, secret: keys.get('demo-user').secret,
  });
  res = new ResponseSink();
  await proxyWatchStream(request(media, { range: 'bytes=0-3' }), res);
  assert.equal(fetched.options.headers.Range, 'bytes=0-3');
  assert.equal(res.code, 206);
  assert.equal(res.headers['content-range'], 'bytes 0-3/8');
  assert.equal(Buffer.concat(res.chunks).toString(), 'DEMO');
});
