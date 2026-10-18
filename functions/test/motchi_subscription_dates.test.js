'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { subNextRenewal, exec_get_subscriptions } = require('../motchi_exec_planning.js');

// The picker saves local midnight in PHT as 16:00Z on the previous day.
const phtMidnight = (day) => new Date(`${day}T00:00:00+08:00`);
const nextDay = (stored, cycle, now) =>
  subNextRenewal(stored, cycle, new Date(now)).toISOString();

test('subscription renewals use the stored Philippine day, not the UTC day', () => {
  assert.equal(nextDay(phtMidnight('2026-10-15'), 'monthly', '2026-10-14T15:59:59Z'),
    '2026-10-15T00:00:00.000Z');
  for (const now of ['2026-10-14T16:00:00Z', '2026-10-15T15:59:59Z']) {
    assert.equal(nextDay(phtMidnight('2026-10-15'), 'monthly', now),
      '2026-10-15T00:00:00.000Z');
  }
  assert.equal(nextDay(phtMidnight('2026-10-15'), 'monthly', '2026-10-15T16:00:00Z'),
    '2026-11-15T00:00:00.000Z');
  // Motchi's date-only writes are UTC midnight, also the same PHT day.
  assert.equal(nextDay(new Date('2026-10-15'), 'monthly', '2026-10-14T16:00:00Z'),
    '2026-10-15T00:00:00.000Z');
});

test('subscription recurrence matches Dart stepwise month-end clamping', () => {
  const cases = [
    ['2026-01-31', 'monthly', '2026-02-10', '2026-02-28'],
    ['2026-01-31', 'monthly', '2026-03-01', '2026-03-28'],
    ['2024-01-31', 'monthly', '2024-02-10', '2024-02-29'],
    ['2024-01-31', 'monthly', '2024-03-01', '2024-03-29'],
    ['2026-12-31', 'monthly', '2027-01-01', '2027-01-31'],
    ['2024-02-29', 'yearly', '2025-02-01', '2025-02-28'],
    ['2024-02-29', 'yearly', '2028-02-01', '2028-02-28'],
  ];
  for (const [stored, cycle, today, expected] of cases) {
    assert.equal(nextDay(phtMidnight(stored), cycle, phtMidnight(today)),
      `${expected}T00:00:00.000Z`, `${stored} / ${cycle} / ${today}`);
  }
});

test('missing and invalid subscription dates fall back to the Philippine day', () => {
  for (const stored of [null, undefined, new Date('invalid')]) {
    assert.equal(nextDay(stored, 'monthly', '2026-12-31T16:00:00Z'),
      '2027-01-01T00:00:00.000Z');
  }
});

test('subscription tool reports PHT countdowns, date labels and window boundaries', async (t) => {
  t.mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-14T16:00:00Z') });
  const rows = [
    ['tomorrow', '2026-10-16'], ['outside', '2026-10-23'],
    ['today', '2026-10-15'], ['boundary', '2026-10-22'],
  ];
  const docs = rows.map(([id, day]) => ({
    id,
    data: () => ({ name: id, price: 100, renewalDate: { toDate: () => phtMidnight(day) } }),
  }));
  const query = {
    orderBy: () => query, limit: () => query,
    get: async () => ({ docs, empty: false }),
  };
  const ctx = { db: { collection: () => query } };
  const out = JSON.parse(await exec_get_subscriptions(ctx, { renewing_within_days: 7 }));
  assert.deepEqual(out.items.map(({ id, days_until, next_renewal }) =>
    [id, days_until, next_renewal]), [
    ['today', 0, '2026-10-15'], ['tomorrow', 1, '2026-10-16'], ['boundary', 7, '2026-10-22'],
  ]);
  assert.equal(out.count, 3);
  assert.equal(out.monthly_total, 400);
});
