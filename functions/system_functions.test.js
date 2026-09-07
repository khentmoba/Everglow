'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const systemFunctions = require('./system_functions');
const indexExports = require('./index');

test('system group exposes health + presence sweeper', () => {
  assert.equal(typeof systemFunctions.health, 'function');
  assert.equal(typeof systemFunctions.sweepStalePresence, 'function');
});

test('index re-exports the system group without renaming', () => {
  assert.equal(indexExports.health, systemFunctions.health);
  assert.equal(indexExports.sweepStalePresence, systemFunctions.sweepStalePresence);
});

test('deploy surface still includes core + system functions', () => {
  const names = Object.keys(indexExports);
  for (const expected of [
    'health',
    'sweepStalePresence',
    'proxyTmdb',
    'proxyLastfm',
    'proxyAI',
    'verifyPasscode',
  ]) {
    assert.ok(names.includes(expected), `missing export: ${expected}`);
  }
});
