'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { Readable } = require('node:stream');
const dns = require('node:dns').promises;
const https = require('node:https');
const { getAdmin } = require('./common');
const { proxyBookFile, proxyBookText } = require('./media_proxy_books');

function mockHttpsResponse(statusCode, headers, body) {
  const stream = Readable.from([Buffer.isBuffer(body) ? body : Buffer.from(body)]);
  stream.statusCode = statusCode;
  stream.headers = headers;
  return stream;
}

test('EPUB proxy supports binary responses and older JSON clients', async (t) => {
  t.mock.method(getAdmin().auth(), 'verifyIdToken', async () => ({
    uid: 'synthetic-books', username: 'clairjassen', firebase: { sign_in_provider: 'custom' },
  }));
  t.mock.method(dns, 'lookup', async () => [{ address: '8.8.8.8', family: 4 }]);
  const bytes = Buffer.from([0x50, 0x4b, 0x03, 0x04, 0]);
  t.mock.method(https, 'request', (_url, _opts, cb) => {
    const req = new EventEmitter();
    req.end = () => cb(mockHttpsResponse(200, { 'content-type': 'application/epub+zip' }, bytes));
    return req;
  });
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

test('book proxies block redirects to private IPs and cap candidate urls at 10', async (t) => {
  t.mock.method(getAdmin().auth(), 'verifyIdToken', async () => ({
    uid: 'synthetic-books-ssrf', username: 'clairjassen', firebase: { sign_in_provider: 'custom' },
  }));
  t.mock.method(dns, 'lookup', async (host) => [
    { address: host.endsWith('gutenberg.org') ? '8.8.8.8' : '169.254.169.254', family: 4 },
  ]);
  let requests = 0;
  t.mock.method(https, 'request', (_url, _opts, cb) => {
    requests++;
    const req = new EventEmitter();
    req.end = () => cb(mockHttpsResponse(302, { location: 'https://metadata.internal/latest' }, ''));
    return req;
  });
  const urls = Array.from({ length: 15 }, (_, i) => `https://www.gutenberg.org/files/${i}/book.txt`);
  const response = { headers: {}, set(k, v) { this.headers[k] = v; return this; },
    status(code) { this.code = code; return this; },
    send(body) { this.body = body; }, json(body) { this.body = body; },
  };
  await proxyBookText({
    method: 'POST',
    body: { urls },
    headers: {},
    get(name) { return name === 'Authorization' ? 'Bearer synthetic' : ''; },
  }, response);
  assert.equal(requests, 10);
  assert.equal(response.body.text, '');
  assert.equal(response.body.attempted.length, 10);
});
