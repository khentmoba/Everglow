'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const imageStats = require('./motchi_image_stats');
const indexExports = require('./index');

test('motchi image+stats group exposes two handlers', () => {
  assert.equal(typeof imageStats.agnesImage, 'function');
  assert.equal(typeof imageStats.motchiStats, 'function');
});

test('index re-exports the image+stats group without renaming', () => {
  assert.equal(indexExports.agnesImage, imageStats.agnesImage);
  assert.equal(indexExports.motchiStats, imageStats.motchiStats);
});
