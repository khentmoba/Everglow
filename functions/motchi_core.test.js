'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  composeTodayRecap,
  getMessageText,
  estimateTokens,
  LLM_INPUT_TOKEN_BUDGET,
} = require('./motchi_core');

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

test('LLM input budget stays at 120k', () => {
  assert.equal(LLM_INPUT_TOKEN_BUDGET, 120000);
});

test('the recap names the Manila date, not the UTC one', (t) => {
  // 00:30 on the 24th in Manila is still the 23rd in UTC.
  t.mock.timers.enable({ apis: ['Date'], now: new Date('2026-11-23T16:30:00Z') });
  assert.match(composeTodayRecap({}), /^Today is 2026-11-24\./);
});
