// The intl DateFormat patterns the calendar screens use, plus shared shapes.
import { AppColors } from '../../core/theme/colors';
import { linear } from '../../core/theme/paint';

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/** EEEE */
export const weekday = (d: Date) => DAYS[d.getDay()];
/** MMMM d, y */
export const longDate = (d: Date) => `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
/** EEEE, MMM d */
export const dayMonth = (d: Date) => `${DAYS[d.getDay()]}, ${MONTHS[d.getMonth()].slice(0, 3)} ${d.getDate()}`;
/** EEE, MMM d */
export const shortDayMonth = (d: Date) => `${DAYS[d.getDay()].slice(0, 3)}, ${MONTHS[d.getMonth()].slice(0, 3)} ${d.getDate()}`;
/** MMMM y as the grid writes it. */
export const monthYear = (d: Date) => `${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
/** MMMd */
export const monthDay = (d: Date) => `${MONTHS[d.getMonth()].slice(0, 3)} ${d.getDate()}`;
/** DateFormat.jm() / TimeOfDay.format: 7:00 PM */
export function jm(d: Date): string {
  const h = d.getHours() % 12 || 12;
  return `${h}:${String(d.getMinutes()).padStart(2, '0')} ${d.getHours() < 12 ? 'AM' : 'PM'}`;
}

export function sameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/** Duration.inDays: whole days, truncated toward zero. */
export function inDays(from: Date, to: Date): number {
  return Math.trunc((to.getTime() - from.getTime()) / 86_400_000);
}

/** AppTheme.roseGoldGradient on a w x h box. */
export function roseGold(w: number, h: number): string {
  return linear([AppColors.auroraRose, AppColors.deepRose, AppColors.blushGold], {
    begin: [-1, -1],
    end: [1, 1],
    size: [w, h],
  });
}
