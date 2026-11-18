// Port of lib/features/bucket_list/presentation/widgets/bucket_ui.dart.
import { AppColors, withAlpha } from '../../core/theme/colors';
import { DartRandom } from '../../shared/utils/dart';
import type { BucketCategory, BucketItem, BucketPriority, BucketStatus } from './bucketListService';

export const BUCKET_KHENT = 'khentsgdz';
export const BUCKET_CLAIR = 'clairjassen';

export const BUCKET_STATUSES: BucketStatus[] = ['wish', 'planned', 'completed'];
export const BUCKET_PRIORITIES: BucketPriority[] = ['low', 'medium', 'high', 'urgent'];
export const PRIORITY_RANK: Record<BucketPriority, number> = { low: 0, medium: 1, high: 2, urgent: 3 };
export const PRIORITY_NAME: Record<BucketPriority, string> = { low: 'Low', medium: 'Medium', high: 'High', urgent: 'Urgent' };
export const STATUS_EMOJI: Record<BucketStatus, string> = { wish: '🌟', planned: '📋', completed: '✅' };

export const assigneeLabel = (u?: string | null) =>
  u === BUCKET_KHENT ? 'Khent' : u === BUCKET_CLAIR ? 'Clair' : u == null ? 'Unassigned' : u;
export const assigneeHue = (u?: string | null) =>
  u === BUCKET_KHENT ? AppColors.auroraTeal : u === BUCKET_CLAIR ? AppColors.auroraRose : AppColors.mutedPurple;
export const assigneeIcon = (u?: string | null) =>
  u === BUCKET_KHENT ? 'person' : u === BUCKET_CLAIR ? 'favorite' : 'person_outline';
export const nextAssignee = (u?: string | null): string | undefined =>
  u == null ? BUCKET_KHENT : u === BUCKET_KHENT ? BUCKET_CLAIR : undefined;

export const statusHue = (s: BucketStatus) =>
  s === 'wish' ? AppColors.blushGold : s === 'planned' ? AppColors.auroraTeal : AppColors.success;
export const statusIcon = (s: BucketStatus) => (s === 'wish' ? 'auto_awesome' : s === 'planned' ? 'map' : 'check_circle');
export const statusLabel = (s: BucketStatus) => (s === 'wish' ? 'Wished' : s === 'planned' ? 'Planned' : 'Fulfilled');

export const priorityHue = (p: BucketPriority) =>
  ({ low: AppColors.softLavender, medium: AppColors.blushGold, high: AppColors.warmAmber, urgent: AppColors.error })[p];
export const priorityShort = (p: BucketPriority) => ({ low: 'Low', medium: 'Med', high: 'High', urgent: 'Urgent' })[p];

const CATEGORY: Record<BucketCategory, [name: string, emoji: string, hue: string]> = {
  travel: ['Travel', '✈️', AppColors.auroraTeal],
  experience: ['Experience', '🎭', AppColors.softLavender],
  food: ['Food & Drink', '🍽️', AppColors.warmAmber],
  adventure: ['Adventure', '🏔️', AppColors.success],
  milestone: ['Milestone', '🏆', AppColors.blushGold],
  other: ['Other', '💫', AppColors.roseQuartz],
};
export const BUCKET_CATEGORY_IDS = Object.keys(CATEGORY) as BucketCategory[];
export const categoryInfo = (c: string) => {
  const [name, emoji, hue] = CATEGORY[c as BucketCategory] ?? CATEGORY.other;
  return { name, emoji, hue };
};

/** Flutter's sort: pace first, then the nearest dream date, then newest. */
export function sortDreams(a: BucketItem, b: BucketItem): number {
  const pr = PRIORITY_RANK[b.priority] - PRIORITY_RANK[a.priority];
  if (pr !== 0) return pr;
  if (a.dueDate && b.dueDate) return a.dueDate.getTime() - b.dueDate.getTime();
  if (a.dueDate) return -1;
  if (b.dueDate) return 1;
  return b.createdAt.getTime() - a.createdAt.getTime();
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
export const MMMd = (d: Date) => `${MONTHS[d.getMonth()]} ${d.getDate()}`;
export const yMMMd = (d: Date) => `${MMMd(d)}, ${d.getFullYear()}`;

/** BucketStarsPainter: 48 dots and five gold sparkles from Random(11). */
export function paintBucketStars(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const rng = new DartRandom(11);
  for (let i = 0; i < 48; i++) {
    const x = rng.nextDouble() * w;
    const y = rng.nextDouble() * h;
    const r = 0.6 + rng.nextDouble() * 1.4;
    const a = 0.1 + rng.nextDouble() * 0.45;
    ctx.fillStyle = withAlpha(AppColors.petalWhite, a);
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.strokeStyle = withAlpha(AppColors.blushGold, 0.55);
  ctx.lineWidth = 1.2;
  ctx.lineCap = 'round';
  for (let i = 0; i < 5; i++) {
    const x = rng.nextDouble() * w;
    const y = rng.nextDouble() * h;
    const s = 3 + rng.nextDouble() * 3;
    ctx.beginPath();
    ctx.moveTo(x - s, y);
    ctx.lineTo(x + s, y);
    ctx.moveTo(x, y - s);
    ctx.lineTo(x, y + s);
    ctx.stroke();
  }
}
