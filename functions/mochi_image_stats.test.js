'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const imageStats = require('./mochi_image_stats');
const indexExports = require('./index');

test('mochi image+stats group exposes two handlers', () => {
  assert.equal(typeof imageStats.agnesImage, 'function');
  assert.equal(typeof imageStats.mochiStats, 'function');
});

test('index re-exports the image+stats group without renaming', () => {
  assert.equal(indexExports.agnesImage, imageStats.agnesImage);
  assert.equal(indexExports.mochiStats, imageStats.mochiStats);
});
