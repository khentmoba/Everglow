'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { normalizePasscode, isValidPasscodeFormat } = require('./auth_core');

test('normalizePasscode trims string input safely', () => {
  assert.equal(normalizePasscode(' 0938 '), '0938');
  assert.equal(normalizePasscode(null), '');
});

test('passcode format accepts exactly four digits', () => {
  assert.equal(isValidPasscodeFormat('0938'), true);
  assert.equal(isValidPasscodeFormat(' 0938 '), true);
  assert.equal(isValidPasscodeFormat('09381'), false);
  assert.equal(isValidPasscodeFormat('093a'), false);
  assert.equal(isValidPasscodeFormat('\\d123'), false);
});
