'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  getMessageText,
  estimateTokens,
  AGNES_INPUT_TOKEN_BUDGET,
} = require('./mochi_core');

test('getMessageText passes strings through', () => {
  assert.equal(getMessageText('hello'), 'hello');
});

test('getMessageText joins parts arrays', () => {
  assert.equal(
    getMessageText([{ text: 'hi' }, 'there', { nope: 1 }]),
    'hi there ',
  );
});

test('getMessageText returns empty for other shapes', () => {
  assert.equal(getMessageText(null), '');
  assert.equal(getMessageText(42), '');
});

test('estimateTokens is zero for empty input', () => {
  assert.equal(estimateTokens(''), 0);
  assert.equal(estimateTokens(null), 0);
});

test('estimateTokens counts ~4 chars per token', () => {
  assert.equal(estimateTokens('abcd'), 1);
  assert.equal(estimateTokens('abcdefgh'), 2);
});

test('estimateTokens weights CJK higher', () => {
  const cjk = estimateTokens('中文');
  const latin = estimateTokens('ab');
  assert.ok(cjk > latin, `cjk=${cjk} latin=${latin}`);
});

test('AGNES input budget stays at 120k', () => {
  assert.equal(AGNES_INPUT_TOKEN_BUDGET, 120000);
});
