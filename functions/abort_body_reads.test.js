'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const test = require('node:test');

const { readJsonOrAbort, readTextOrAbort } = require('./common.js');

async function withPartialServer(fn) {
  let release;
  const released = new Promise((resolve) => {
    release = resolve;
  });
  const server = http.createServer(async (_req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.write('{"partial":');
    await released;
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    return await fn(`http://127.0.0.1:${port}/`);
  } finally {
    release();
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
}

test('readJsonOrAbort returns null on aborted or timed-out fetch body', async () => {
  await withPartialServer(async (url) => {
    const abortCtrl = new AbortController();
    const abortResp = await fetch(url, { signal: abortCtrl.signal });
    const pendingAbort = readJsonOrAbort(abortResp);
    abortCtrl.abort();
    assert.equal(await pendingAbort, null);

    const timeoutCtrl = new AbortController();
    const timeoutResp = await fetch(url, { signal: timeoutCtrl.signal });
    const pendingTimeout = readJsonOrAbort(timeoutResp);
    timeoutCtrl.abort(new DOMException('timed out', 'TimeoutError'));
    assert.equal(await pendingTimeout, null);
  });
});

test('readTextOrAbort returns empty string on aborted or timed-out fetch body', async () => {
  await withPartialServer(async (url) => {
    const abortCtrl = new AbortController();
    const abortResp = await fetch(url, { signal: abortCtrl.signal });
    const pendingAbort = readTextOrAbort(abortResp);
    abortCtrl.abort();
    assert.equal(await pendingAbort, '');

    const timeoutCtrl = new AbortController();
    const timeoutResp = await fetch(url, { signal: timeoutCtrl.signal });
    const pendingTimeout = readTextOrAbort(timeoutResp);
    timeoutCtrl.abort(new DOMException('timed out', 'TimeoutError'));
    assert.equal(await pendingTimeout, '');
  });
});

test('readJsonOrAbort parses valid JSON and rethrows non-abort parse errors', async () => {
  assert.deepEqual(await readJsonOrAbort(new Response('{"ok":true}')), { ok: true });
  await assert.rejects(
    () => readJsonOrAbort(new Response('not-json')),
    (err) => err?.name === 'SyntaxError',
  );
  assert.equal(await readTextOrAbort(new Response('Sunny 28C')), 'Sunny 28C');
});

test('timed backend body reads wire the abort-safe helpers', () => {
  for (const file of ['motchi_chat.js', 'motchi_study.js', 'motchi_memory.js', 'motchi_schedules.js']) {
    const src = fs.readFileSync(path.join(__dirname, file), 'utf8');
    assert.match(src, /readJsonOrAbort:\s*readModelJson/, `${file} must import readJsonOrAbort`);
  }
  const chat = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  for (const name of ['response', 'finalResp', 'repairResp', 'danglingResp']) {
    assert.match(chat, new RegExp(`await readModelJson\\(${name}\\)`));
  }
  const planning = fs.readFileSync(path.join(__dirname, 'motchi_exec_planning.js'), 'utf8');
  assert.match(planning, /readTextOrAbort:\s*readWeatherText/);
  assert.match(planning, /await readWeatherText\(weatherRes\)/);
});
