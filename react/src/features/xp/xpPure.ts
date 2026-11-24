// XP level math and the daily-capped award counter. Kept import-free (like
// milestonePure.ts) so it can be unit-tested in Node.

export type XpAward = { amount: number; dailyCap: number };

export const XP_PER_LEVEL = 200;
export const levelForXp = (xp: number) => (xp <= 0 ? 1 : Math.floor(xp / XP_PER_LEVEL) + 1);
export const xpIntoLevel = (xp: number) => (xp <= 0 ? 0 : xp % XP_PER_LEVEL);
export const xpToNextLevel = (xp: number) => XP_PER_LEVEL - xpIntoLevel(xp);

/**
 * `XPService.computeDailyAward`: null once today's cap for this action is used
 * up. Only today's counters are written back — the progress doc would otherwise
 * grow one key per active day forever.
 */
export function computeDailyAward(
  data: Record<string, unknown>,
  action: string,
  award: XpAward,
  today: string,
) {
  const raw = data.dailyXp;
  const entry = raw && typeof raw === 'object' ? (raw as Record<string, unknown>)[today] : undefined;
  const todayCounts: Record<string, unknown> =
    entry && typeof entry === 'object' ? { ...(entry as Record<string, unknown>) } : {};
  const used = typeof todayCounts[action] === 'number' ? Math.trunc(todayCounts[action] as number) : 0;
  if (used >= award.dailyCap) return null;
  todayCounts[action] = used + 1;
  const newXp = (typeof data.xpTotal === 'number' ? Math.trunc(data.xpTotal) : 0) + award.amount;
  const newLevel = levelForXp(newXp);
  const storedLevel = typeof data.level === 'number' ? Math.trunc(data.level) : 1;
  return {
    counters: { [today]: todayCounts },
    newXp,
    newLevel,
    leveledUp: newLevel > storedLevel,
  };
}
