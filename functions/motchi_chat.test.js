'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const chat = require('./motchi_chat');
const indexExports = require('./index');

test('motchi chat group exposes the chat handler', () => {
  assert.equal(typeof chat.handleProxyAI, 'function');
});

test('index wraps the chat handler as proxyAI + proxyAIv2', () => {
  assert.equal(typeof indexExports.proxyAI, 'function');
  assert.equal(typeof indexExports.proxyAIv2, 'function');
});

test('fallback persona renders its tool list from attached tools', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Placeholder in the fallback persona + includes/replace wiring — the
  // prompt must never advertise tools that routing removed.
  assert.equal(src.split('%%MOTCHI_TOOL_LIST%%').length - 1, 3);
  // nimMessages is built before routing, so the rendered prompt must be
  // pushed back into it (otherwise the model sees the placeholder).
  assert.match(src, /nimMessages\[0\]\.content = systemPrompt/);
  // The old static 50-tool list must stay out of the fallback persona.
  assert.ok(!src.includes('- get_trips — Read trips'));
});

test('deploy surface still includes chat + schedules + catalog', () => {
  for (const name of [
    'proxyAI',
    'proxyAIv2',
    'agnesImage',
    'motchiStats',
    'motchiDailyDigest',
    'motchiMemorySweep',
    'proxyTmdb',
    'proxyLastfm',
  ]) {
    assert.ok(indexExports[name], `missing export: ${name}`);
  }
});
