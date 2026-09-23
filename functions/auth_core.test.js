'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  normalizePasscode,
  isValidPasscodeFormat,
  advanceAttemptBudget,
} = require('./auth_core');

test('normalizePasscode trims string input safely', () => {
  assert.equal(normalizePasscode('  correct horse battery staple  '), 'correct horse battery staple');
  assert.equal(normalizePasscode(null), '');
});

test('gateway requires a bounded strong passphrase', () => {
  assert.equal(isValidPasscodeFormat('correct horse battery staple'), true);
  assert.equal(isValidPasscodeFormat('  correct horse battery staple  '), true);
  assert.equal(isValidPasscodeFormat('0938'), false);
  assert.equal(isValidPasscodeFormat('a'.repeat(15)), false);
  assert.equal(isValidPasscodeFormat('a'.repeat(257)), false);
});

test('global attempt budget locks atomically and success cannot reset it', () => {
  const options = { now: 1_000, maxFails: 2, windowMs: 100, lockMs: 500 };
  const first = advanceAttemptBudget(null, options, true);
  assert.equal(first.fails, 1);
  assert.equal(first.locked, false);
  const second = advanceAttemptBudget(first, options, true);
  assert.equal(second.fails, 2);
  assert.equal(second.locked, true);
  const success = advanceAttemptBudget(second, options, false);
  assert.equal(success.locked, true);
  assert.equal(success.fails, 2);
});
