// Renewal dates must count from the day the subscription was set up, so a
// month-end bill never drifts earlier month after month.
import test from 'node:test';
import assert from 'node:assert/strict';

const { nextRenewal, daysUntilRenewal } = await import('../src/features/subs/renewalPure.ts');

const sub = (renewalDate, cycle = 'monthly') => ({ renewalDate, cycle });

test('a 31st bill returns to the 31st after a short month', () => {
  const jan31 = new Date(2026, 0, 31);
  assert.equal(nextRenewal(sub(jan31), new Date(2026, 1, 1)).getDate(), 28);
  // Feb 28 is the clamp; March must be the 31st again, not the 28th.
  const march = nextRenewal(sub(jan31), new Date(2026, 2, 1));
  assert.deepEqual([march.getMonth(), march.getDate()], [2, 31]);
  const march30 = nextRenewal(sub(jan31), new Date(2026, 2, 30));
  assert.deepEqual([march30.getMonth(), march30.getDate()], [2, 31]);
  // Past March 31 the next one is April 30, still anchored on the 31st.
  const april = nextRenewal(sub(jan31), new Date(2026, 3, 1));
  assert.deepEqual([april.getMonth(), april.getDate()], [3, 30]);
});

test('a monthly bill on the 31st stays on the last day of every month', () => {
  const anchor = new Date(2026, 0, 31);
  for (let month = 0; month < 12; month++) {
    const daysInMonth = new Date(2026, month + 1, 0).getDate();
    const next = nextRenewal(sub(anchor), new Date(2026, month, 1));
    assert.deepEqual(
      [next.getMonth(), next.getDate()],
      [month, Math.min(31, daysInMonth)],
      `month ${month}`,
    );
  }
});

test('today and past dates are handled without a loop budget', () => {
  const today = new Date(2026, 5, 15);
  assert.equal(daysUntilRenewal(sub(today), today), 0);
  assert.equal(daysUntilRenewal(sub(new Date(2026, 5, 14)), today), 29);
  // A long-dormant subscription lands on the current month, not 1200 steps later.
  const old = nextRenewal(sub(new Date(1990, 0, 31)), today);
  assert.deepEqual([old.getFullYear(), old.getMonth(), old.getDate()], [2026, 5, 30]);
});

test('yearly bills stay anchored, including a leap day', () => {
  const leap = new Date(2024, 1, 29);
  assert.equal(nextRenewal(sub(leap, 'yearly'), new Date(2025, 2, 1)).getFullYear(), 2026);
  assert.equal(nextRenewal(sub(leap, 'yearly'), new Date(2026, 0, 1)).getDate(), 28);
  assert.equal(daysUntilRenewal(sub(new Date(2026, 1, 20), 'yearly'), new Date(2026, 1, 14)), 6);
});
