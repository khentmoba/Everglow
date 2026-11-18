// Port of lib/features/dashboard/domain/models/anniversary_counter.dart.

export type AnniversaryCounter = {
  years: number;
  months: number;
  days: number;
  hours: number;
  minutes: number;
  seconds: number;
};

export const ANNIVERSARY_DATE = new Date(2026, 1, 14);

export function calculateAnniversary(startDate: Date, now: Date): AnniversaryCounter {
  if (now.getTime() < startDate.getTime()) {
    return { years: 0, months: 0, days: 0, hours: 0, minutes: 0, seconds: 0 };
  }
  let years = now.getFullYear() - startDate.getFullYear();
  let months = now.getMonth() - startDate.getMonth();
  let days = now.getDate() - startDate.getDate();
  if (days < 0) {
    months -= 1;
    // Days in the previous month of `now` (Dart DateTime(now.year, now.month, 0).day).
    days += new Date(now.getFullYear(), now.getMonth(), 0).getDate();
  }
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  const diffSec = Math.floor((now.getTime() - startDate.getTime()) / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHr = Math.floor(diffMin / 60);
  return {
    years,
    months,
    days,
    hours: diffHr % 24,
    minutes: diffMin % 60,
    seconds: diffSec % 60,
  };
}

export function totalDaysSinceAnniversary(now: Date): number {
  return Math.floor((now.getTime() - ANNIVERSARY_DATE.getTime()) / 86_400_000);
}
