// Renewal-date math for the subscription tracker. Kept import-free (like
// milestonePure.ts) so it can be unit-tested in Node.

export type RenewalCycle = 'monthly' | 'yearly';
export type RenewableSubscription = { renewalDate: Date; cycle: RenewalCycle };

/** Local midnight, so a day count never drifts across a DST change. */
const dateOnly = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

/** Whole months later, clamped to the last day of a shorter month (Jan 31 → Feb 28). */
function addMonths(d: Date, months: number): Date {
  const m = d.getMonth() + months;
  const y = d.getFullYear() + Math.floor(m / 12);
  const mm = ((m % 12) + 12) % 12;
  const lastDay = new Date(y, mm + 1, 0).getDate();
  return new Date(y, mm, Math.min(d.getDate(), lastDay));
}

const monthsBetween = (from: Date, to: Date) =>
  (to.getFullYear() - from.getFullYear()) * 12 + (to.getMonth() - from.getMonth());

/**
 * The first renewal on or after `now`. Every step is counted from the original
 * renewal day, so a 31st that has to clamp in February returns to the 31st in
 * March instead of drifting to the 28th forever.
 */
export function nextRenewal(sub: RenewableSubscription, now: Date = new Date()): Date {
  const anchor = dateOnly(sub.renewalDate);
  const today = dateOnly(now);
  if (anchor >= today) return anchor;
  const span = sub.cycle === 'yearly'
    ? today.getFullYear() - anchor.getFullYear()
    : monthsBetween(anchor, today);
  const step = sub.cycle === 'yearly' ? 12 : 1;
  let steps = Math.max(1, span);
  let next = addMonths(anchor, steps * step);
  while (next < today) next = addMonths(anchor, ++steps * step);
  return next;
}

/** Whole days until the next renewal, like Dart's `Duration.inDays`. */
export function daysUntilRenewal(sub: RenewableSubscription, now: Date = new Date()): number {
  const today = dateOnly(now);
  const next = nextRenewal(sub, now);
  return Math.round(
    (Date.UTC(next.getFullYear(), next.getMonth(), next.getDate()) -
      Date.UTC(today.getFullYear(), today.getMonth(), today.getDate())) / 86_400_000,
  );
}
