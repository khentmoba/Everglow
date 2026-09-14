'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { detectAnomalies } = require('./usage_alerts');

test('detectAnomalies stays quiet on normal usage', () => {
  assert.deepEqual(detectAnomalies('khentsgdz', { proxyAI: 40 }, { proxyAI: 35 }), []);
  assert.deepEqual(detectAnomalies('khentsgdz', {}, {}), []);
});

test('detectAnomalies warns near the daily cap', () => {
  const lines = detectAnomalies('clairjassen', { proxyAI: 280 }, { proxyAI: 100 });
  assert.equal(lines.length, 1);
  assert.match(lines[0], /clairjassen: proxyAI at 280/);
});

test('detectAnomalies flags a day-over-day spike', () => {
  const lines = detectAnomalies('breyan', { proxyAI: 60 }, { proxyAI: 10 });
  assert.equal(lines.length, 1);
  assert.match(lines[0], /spiked 10 → 60/);
});

test('detectAnomalies ignores tiny counts even at high ratios', () => {
  assert.deepEqual(detectAnomalies('khentsgdz', { proxyAI: 10 }, { proxyAI: 1 }), []);
});

test('detectAnomalies skips the spike check with no yesterday baseline', () => {
  assert.deepEqual(detectAnomalies('khentsgdz', { proxyAI: 100 }, {}), []);
});

test('detectAnomalies checks every watched endpoint', () => {
  const lines = detectAnomalies(
    'khentsgdz',
    { proxyAI: 10, agnesImage: 28 },
    { proxyAI: 10, agnesImage: 5 },
  );
  assert.ok(lines.some((l) => l.includes('agnesImage at 28')));
});
