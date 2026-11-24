// The XP progress doc keeps only today's award counters; it must not grow one
// key per active day for the life of the account.
import test from 'node:test';
import assert from 'node:assert/strict';

const { computeDailyAward, levelForXp, xpIntoLevel, xpToNextLevel } = await import('../src/features/xp/xpPure.ts');

const award = { amount: 3, dailyCap: 2 };

test('award counters drop older days instead of piling up', () => {
  const data = {
    xpTotal: 10,
    level: 1,
    dailyXp: { '2026-01-01': { play: 2 }, '2026-01-02': { play: 1 } },
  };
  const out = computeDailyAward(data, 'play', award, '2026-01-03');
  assert.deepEqual(out.counters, { '2026-01-03': { play: 1 } });
  assert.equal(out.newXp, 13);
});

test('today keeps counting from its own entry', () => {
  const data = { xpTotal: 0, level: 1, dailyXp: { '2026-01-03': { play: 1 } } };
  assert.deepEqual(computeDailyAward(data, 'play', award, '2026-01-03').counters, {
    '2026-01-03': { play: 2 },
  });
});

test("the cap still stops an award once today's count is used up", () => {
  const data = { xpTotal: 5, level: 1, dailyXp: { '2026-01-03': { play: 2 } } };
  assert.equal(computeDailyAward(data, 'play', award, '2026-01-03'), null);
  // Another action still gets its own counter.
  assert.deepEqual(computeDailyAward(data, 'journal', { amount: 30, dailyCap: 2 }, '2026-01-03').counters, {
    '2026-01-03': { play: 2, journal: 1 },
  });
});

test('level math stays in step with the counters', () => {
  assert.equal(levelForXp(0), 1);
  assert.equal(levelForXp(199), 1);
  assert.equal(levelForXp(200), 2);
  assert.equal(xpIntoLevel(240), 40);
  assert.equal(xpToNextLevel(240), 160);
  assert.equal(computeDailyAward({ xpTotal: 197, level: 1 }, 'play', award, '2026-01-03').leveledUp, true);
});
