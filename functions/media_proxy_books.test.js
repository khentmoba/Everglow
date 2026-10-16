'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const dns = require('node:dns').promises;
const { getAdmin } = require('./common');
const { proxyBookFile } = require('./media_proxy_books');

test('EPUB proxy supports binary responses and older JSON clients', async (t) => {
  t.mock.method(getAdmin().auth(), 'verifyIdToken', async () => ({ uid: 'synthetic-books' }));
  t.mock.method(dns, 'lookup', async () => [{ address: '203.0.113.8', family: 4 }]);
  const bytes = Buffer.from([0x50, 0x4b, 0x03, 0x04, 0]);
  t.mock.method(global, 'fetch', async () => new Response(bytes, {
    headers: { 'Content-Type': 'application/epub+zip' },
  }));
  const url = 'https://www.gutenberg.org/ebooks/1.epub.noimages';
  for (const binary of [true, false]) {
    const response = { headers: {}, set(k, v) { this.headers[k] = v; return this; },
      status(code) { this.code = code; return this; },
      send(body) { this.body = body; }, json(body) { this.body = body; },
    };
    await proxyBookFile({ method: 'POST', body: { urls: [url] }, headers: {},
      get(name) {
        if (name === 'Authorization') return 'Bearer synthetic';
        if (name === 'Accept') return binary ? 'application/epub+zip' : 'application/json';
        return '';
      },
    }, response);
    if (binary) {
      assert.deepEqual(response.body, bytes);
      assert.equal(decodeURIComponent(response.headers['X-Book-Source']), url);
      assert.equal(response.headers['Content-Type'], 'application/epub+zip');
    } else {
      assert.equal(response.body.base64, bytes.toString('base64'));
      assert.equal(response.body.usedUrl, url);
    }
  }
});
