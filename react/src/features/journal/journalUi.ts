// Port of lib/features/journal/presentation/widgets/journal_ui.dart.
import { AppColors } from '../../core/theme/colors';
import type { JournalCategory } from './journalService';

const months = [
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

export function journalCategoryColor(c: JournalCategory): string {
  switch (c) {
    case 'daily':
      return AppColors.softLavender;
    case 'gratitude':
      return AppColors.blushGold;
    case 'memory':
      return AppColors.auroraTeal;
    case 'letter':
      return AppColors.deepRose;
    case 'dream':
      return AppColors.auroraLilac;
    case 'idea':
      return AppColors.warmAmber;
  }
}

export function journalAuthorHue(author: string): string {
  switch (author.toLowerCase()) {
    case 'khentsgdz':
      return AppColors.auroraTeal;
    case 'clairjassen':
      return AppColors.auroraRose;
    default:
      return AppColors.softLavender;
  }
}

export function journalAuthorName(author: string): string {
  switch (author.toLowerCase()) {
    case 'khentsgdz':
      return 'Khent';
    case 'clairjassen':
      return 'Clair';
    default:
      return author === '' ? 'Us' : author[0].toUpperCase() + author.slice(1);
  }
}

export function journalAuthorInitial(author: string): string {
  const name = journalAuthorName(author);
  return name === '' ? '♥' : name[0].toUpperCase();
}

/** DateFormat.yMMMd(): "Nov 17, 2026". */
export function yMMMd(d: Date): string {
  return `${months[d.getMonth()].slice(0, 3)} ${d.getDate()}, ${d.getFullYear()}`;
}

/** DateFormat.jm(): "3:07 PM". */
export function jm(d: Date): string {
  const h = d.getHours() % 12 || 12;
  return `${h}:${String(d.getMinutes()).padStart(2, '0')} ${d.getHours() < 12 ? 'AM' : 'PM'}`;
}

export function journalRelativeDate(d: Date): string {
  const now = new Date();
  const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  const day = Date.UTC(d.getFullYear(), d.getMonth(), d.getDate());
  const diff = Math.floor((today - day) / 86_400_000);
  if (diff <= 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  if (diff < 7) return `${diff}d ago`;
  return yMMMd(d);
}

export function journalReadingTime(words: number): string {
  if (words <= 0) return 'a quick note';
  const mins = Math.min(999, Math.max(1, Math.ceil(words / 200)));
  return `${mins} min read`;
}

export const journalMonthLabel = (d: Date) => `${months[d.getMonth()]} ${d.getFullYear()}`;

export const journalNumberFormat = (n: number) => n.toLocaleString('en-US');

export const journalDayKey = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
