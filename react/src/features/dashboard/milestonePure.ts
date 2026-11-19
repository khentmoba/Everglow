import type { MilestoneFixture } from '../../core/agent/fixtures';

function milestoneDayKey(date: Date): string {
  if (Number.isNaN(date.getTime())) return '';
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
}

export function dedupeMilestones<T extends MilestoneFixture>(items: T[]): T[] {
  const out: T[] = [];
  const indexByKey = new Map<string, number>();

  for (const item of items) {
    const key = [
      item.title.trim().toLowerCase(),
      milestoneDayKey(item.date),
      item.description.trim().toLowerCase(),
      item.author.trim().toLowerCase(),
    ].join('\u241f');

    const existingIdx = indexByKey.get(key);
    if (existingIdx === undefined) {
      indexByKey.set(key, out.length);
      out.push(item);
    } else if (item.imageUrls.length > out[existingIdx].imageUrls.length) {
      out[existingIdx] = item;
    }
  }

  return out;
}
