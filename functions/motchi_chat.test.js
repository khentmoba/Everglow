'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const chat = require('./motchi_chat');
const indexExports = require('./index');

test('motchi chat group exposes the chat handler', () => {
  assert.equal(typeof chat.handleProxyAI, 'function');
});

test('index wraps the chat handler as proxyAI + proxyAIv2', () => {
  assert.equal(typeof indexExports.proxyAI, 'function');
  assert.equal(typeof indexExports.proxyAIv2, 'function');
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
