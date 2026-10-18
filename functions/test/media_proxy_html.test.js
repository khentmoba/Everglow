'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { Writable } = require('node:stream');
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
  t.mock.method(global, 'fetch', async () => ({
    ok: true,
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
