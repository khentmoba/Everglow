'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { Writable } = require('node:stream');
const common = require('../common.js');
const html = require('../media_proxy_html.js');
const video = require('../media_proxy_video.js');
const index = require('../index.js');
const triggers = require('../triggers.js');

test('scanlation images stream without buffering the whole response', async (t) => {
  const chunks = [];
  const response = new Writable({ write(chunk, _encoding, done) { chunks.push(chunk); done(); } });
  response.set = () => response;
  response.status = () => response;
  response.json = () => assert.fail('must not try JSON after streaming');
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: true,
    status: 200,
    headers: new Headers({ 'content-type': 'image/jpeg' }),
    body: new ReadableStream({ start(controller) {
      controller.enqueue(Buffer.from('first'));
      controller.enqueue(Buffer.from('second'));
      controller.close();
    } }),
    arrayBuffer() { assert.fail('must not buffer image body'); },
  }));
  await html.proxyScanlation({ method: 'GET', headers: {}, get: () => '',
    ip: '8.8.8.8', query: { url: 'https://demo.blogspot.com/synthetic.jpg' },
  }, response);
  assert.equal(Buffer.concat(chunks).toString(), 'firstsecond');
  assert.equal(response.writableFinished, true);
});

test('proxyFetchHtml rejects lookalike suffix bypass hosts', async () => {
  const send = async (url) => {
    const res = {
      code: 200,
      headers: {},
      set(k, v) { this.headers[k] = v; return this; },
      status(n) { this.code = n; return this; },
      json(b) { this.body = b; },
      send(b) { this.body = b; },
    };
    await html.proxyFetchHtml({ method: 'GET', headers: {}, get: () => '', ip: '8.8.8.8', query: { url } }, res);
    return res;
  };
  assert.equal((await send('https://evileverglow-1c6db.web.app/')).code, 400);
  assert.equal((await send('https://verglow-1c6db.web.app/')).code, 400);
});

test('only active HTML scraping and watch stream proxies are exported', () => {
  assert.equal(typeof html.proxyScanlation, 'function');
  assert.equal(typeof html.proxyFetchHtml, 'function');
  assert.equal('proxyEmbed' in html, false);
  assert.equal(typeof video.proxyWatchStream, 'function');
  assert.equal('proxyVideoStream' in video, false);
  assert.equal('proxyEmbed' in index, false);
  assert.equal('proxyVideoStream' in index, false);
  assert.equal('onWatchPartyInvite' in index, false);
  assert.equal('onWatchPartyInvite' in triggers, false);
});

test('proxyFetchHtml returns text/plain with sandbox CSP and readLimitedText enforces byte cap', async (t) => {
  t.mock.method(common, 'fetchPublicUrl', async () => ({
    ok: true,
    status: 200,
    headers: new Headers({ 'content-type': 'text/html' }),
    body: new ReadableStream({
      start(controller) {
        controller.enqueue(Buffer.from('<html><script>alert(1)</script></html>'));
        controller.close();
      },
    }),
  }));
  const res = {
    code: 200,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(n) { this.code = n; return this; },
    json(b) { this.body = b; },
    send(b) { this.body = b; },
  };
  await html.proxyFetchHtml(
    { method: 'GET', headers: { origin: 'https://everglow-1c6db.web.app' }, get: () => '', ip: '8.8.8.8', query: { url: 'https://mangakatana.com/test' } },
    res,
  );
  assert.equal(res.code, 200);
  assert.equal(res.headers['Content-Type'], 'text/plain; charset=utf-8');
  assert.equal(res.headers['Content-Security-Policy'], 'sandbox');
  assert.equal(res.headers['X-Content-Type-Options'], 'nosniff');

  const oversized = new ReadableStream({
    start(controller) {
      controller.enqueue(Buffer.alloc(1024, 65));
      controller.close();
    },
  });
  await assert.rejects(() => common.readLimitedText(oversized, 512), /size limit/i);
});
