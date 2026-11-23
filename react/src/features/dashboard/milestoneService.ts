// Port of lib/features/dashboard/data/services/milestone_service.dart + Milestone.
import {
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type MilestoneCategory, type MilestoneFixture } from '../../core/agent/fixtures';
import { db, loadStorage } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { clearOnLogout, setBoundedCache } from '../../core/utils/boundedCache';
import { just, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';
import { dedupeMilestones } from './milestonePure';

export { dedupeMilestones };
export type Milestone = MilestoneFixture;

export const MILESTONE_META: Record<MilestoneCategory, { label: string; emoji: string }> = {
  firstDate: { label: 'First Date', emoji: '☕' },
  anniversary: { label: 'Anniversary', emoji: '💍' },
  trip: { label: 'Trip', emoji: '🚗' },
  memory: { label: 'Memory', emoji: '✨' },
  other: { label: 'Milestone', emoji: '🌸' },
};

const LEGACY_ASSET_PATH_FIXES: Record<string, string> = {
  'assets/images/milestones/valentines_khent_2.png': 'assets/images/milestones/valentines_khent_2.jpg',
  'assets/images/milestones/kiss_khent_4.png': 'assets/images/milestones/kiss_khent_4.jpg',
  'assets/images/milestones/birthday_pre_khent_5.png': 'assets/images/milestones/birthday_pre_khent_5.jpg',
  'assets/images/milestones/puting_bato_khent_2.png': 'assets/images/milestones/puting_bato_khent_2.jpg',
  'assets/images/milestones/puting_bato_khent_3.png': 'assets/images/milestones/puting_bato_khent_3.jpg',
};

export function repairLegacyMilestoneImageUrl(url: string): string {
  const trimmed = url.trim();
  const repaired = LEGACY_ASSET_PATH_FIXES[trimmed] ?? trimmed;
  const prefix = 'assets/images/milestones/';
  if (!repaired.startsWith(prefix)) return repaired;
  const filename = repaired.slice(prefix.length);
  if (!/^[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp)$/i.test(filename)) return repaired;
  return `milestones/legacy/${filename}`;
}

const STORAGE_URL_CACHE_MAX = 200;
const resolvedStorageUrlCache = new Map<string, Promise<string | null>>();
const resolvedStorageUrlStrings = new Map<string, string>();
let storageUrlGeneration = 0;

clearOnLogout(resolvedStorageUrlCache, resolvedStorageUrlStrings);
if (typeof window !== 'undefined') {
  window.addEventListener('everglow:logout', () => {
    storageUrlGeneration += 1;
  });
}

export function getCachedMilestoneImageUrl(path: string): string | null {
  const normalized = repairLegacyMilestoneImageUrl(path);
  if (!normalized) return null;
  if (/^(https?:|data:|blob:|\/)/i.test(normalized)) return normalized;
  return resolvedStorageUrlStrings.get(normalized) ?? null;
}

export function resolveMilestoneImageUrl(path: string): Promise<string | null> {
  const normalized = repairLegacyMilestoneImageUrl(path);
  if (!normalized) return Promise.resolve(null);
  if (/^(https?:|data:|blob:|\/)/i.test(normalized)) {
    return Promise.resolve(normalized);
  }
  const known = resolvedStorageUrlStrings.get(normalized);
  if (known) return Promise.resolve(known);
  const cached = resolvedStorageUrlCache.get(normalized);
  if (cached) return cached;
  const gen = storageUrlGeneration;
  const pending = loadStorage()
    .then(({ storage, mod }) => mod.getDownloadURL(mod.ref(storage, normalized)))
    .then((url) => {
      if (gen !== storageUrlGeneration) return null;
      if (url) setBoundedCache(resolvedStorageUrlStrings, normalized, url, STORAGE_URL_CACHE_MAX);
      return url;
    })
    .catch((e: unknown) => {
      Logger.e(`Milestone photo could not load (${normalized})`, e);
      if (gen === storageUrlGeneration) resolvedStorageUrlCache.delete(normalized);
      return null;
    });
  setBoundedCache(resolvedStorageUrlCache, normalized, pending, STORAGE_URL_CACHE_MAX);
  return pending;
}

function parseCategory(v: unknown): MilestoneCategory {
  if (v === 'firstDate' || v === 'anniversary' || v === 'trip' || v === 'memory') return v;
  return 'other';
}

function parseMilestoneDate(v: unknown): Date {
  if (v && typeof (v as Timestamp).toDate === 'function') return (v as Timestamp).toDate();
  if (typeof v === 'number' && Number.isFinite(v)) return new Date(v);
  if (typeof v === 'string' && v) {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return new Date();
}

class MilestoneService {
  milestonesPreview(max = 12): Source<Milestone[]> {
    if (AgentMode.demo) return just(dedupeMilestones(AgentFixtures.demoMilestones()).slice(0, max));
    const fetchLimit = Math.min(Math.max(max * 3, 24), 50);
    const q = query(collection(db, 'milestones'), orderBy('date', 'desc'), limit(fetchLimit));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, Milestone[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) =>
          dedupeMilestones(
            s.docs.map((d) => {
              const data = d.data();
              const rawUrls = Array.isArray(data.imageUrls)
                ? data.imageUrls.map((u) => repairLegacyMilestoneImageUrl(String(u)))
                : [];
              if (rawUrls.length === 0 && typeof data.imageUrl === 'string' && data.imageUrl) {
                rawUrls.push(repairLegacyMilestoneImageUrl(data.imageUrl));
              }
              return {
                id: d.id,
                title: String(data.title ?? ''),
                description: String(data.description ?? ''),
                date: parseMilestoneDate(data.date),
                author: String(data.author ?? ''),
                category: parseCategory(data.category),
                imageUrls: rawUrls.filter(Boolean),
              };
            }),
          ).slice(0, max),
      ),
      { label: 'milestones-preview' },
    );
  }
}

export const milestoneService = new MilestoneService();
