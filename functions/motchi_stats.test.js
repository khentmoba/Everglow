'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const stats = require('./motchi_stats');
const indexExports = require('./index');

test('motchi stats group exposes the rollup handler', () => {
  assert.equal(typeof stats.motchiStats, 'function');
  assert.equal(stats.agnesImage, undefined);
});

test('index re-exports the stats group without renaming', () => {
  assert.equal(indexExports.motchiStats, stats.motchiStats);
  assert.equal(indexExports.agnesImage, undefined);
});
