'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { Writable } = require('node:stream');
const { streamMediaBody } = require('./stream_media_body');

test('slow media consumers bound upstream reads and retain all bytes', async () => {
  let pulled = 0;
  let consumed = 0;
  let peakQueued = 0;
  const source = new ReadableStream({
    pull(controller) {
      if (pulled === 100) { controller.close(); return; }
      pulled++;
      peakQueued = Math.max(peakQueued, pulled - consumed);
      controller.enqueue(new Uint8Array(64 * 1024));
    },
  });
  const response = new Writable({ highWaterMark: 64 * 1024,
    write(chunk, encoding, done) { setTimeout(() => { consumed++; done(); }, 1); },
  });
  await streamMediaBody(source, response);
  assert.equal(consumed, 100);
  assert.ok(peakQueued < 10, `queued ${peakQueued} chunks`);
});

test('leaving a player cancels its upstream body', async () => {
  let cancelled = false;
  const source = new ReadableStream({
    pull(controller) { controller.enqueue(new Uint8Array(64 * 1024)); },
    cancel() { cancelled = true; },
  });
  const response = new Writable({ write(chunk, encoding, done) {
    this.destroy(); done();
  } });
  await streamMediaBody(source, response);
  assert.equal(cancelled, true);
});

test('an upstream failure is propagated for the proxy to log', async () => {
  const failure = new Error('source failed');
  const source = new ReadableStream({ start(controller) { controller.error(failure); } });
  const response = new Writable({ write(chunk, encoding, done) { done(); } });
  await assert.rejects(streamMediaBody(source, response), failure);
});
