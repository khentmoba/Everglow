'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { fetchPublicStream } = require('./media_proxy_video.js');

test('watch stream proxy rejects cloud metadata and loopback targets', async () => {
  await assert.rejects(
    fetchPublicStream('http://169.254.169.254/latest/meta-data', ''),
    /Host not allowed/,
  );
  await assert.rejects(
    fetchPublicStream('http://127.0.0.1:8080/', ''),
    /Host not allowed/,
  );
});

test('watch stream proxy rejects non-http protocols before fetch', async () => {
  await assert.rejects(
    fetchPublicStream('file:///etc/passwd', ''),
    /Only http\(s\) urls are allowed/,
  );
});
