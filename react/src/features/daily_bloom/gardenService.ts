// Port of lib/features/daily_bloom/data/models/plant_type.dart + garden_stats.dart
// and garden_provider.dart.
import { doc, onSnapshot, runTransaction, Timestamp, type DocumentData, type DocumentSnapshot } from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type GardenStatsFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { ValueNotifier } from '../../core/system/store';
import { Logger } from '../../core/system/logger';
import { snapshots, withFirestoreTimeout } from '../../core/utils/liveSource';
import { awardDaily, type XpAward } from '../xp/xpService';

export type GardenStats = GardenStatsFixture;

export type PlantType = {
  id: string;
  displayName: string;
  emoji: string;
  stageDescriptions: string[];
  seasonalBonusMonth?: number;
  seasonalBonusName?: string;
};

export const PLANT_TYPES: PlantType[] = [
  {
    id: 'lily',
    displayName: 'Lily',
    emoji: '🌸',
    stageDescriptions: ['Empty pot', 'A tiny sprout', 'Growing bud', 'Opening bloom', 'Half bloom', 'Full bloom'],
  },
  {
    id: 'rose',
    displayName: 'Rose',
    emoji: '🌹',
    stageDescriptions: ['Empty pot', 'A tiny sprout', 'Thorny stem', 'Rose bud', 'Opening rose', 'Full rose'],
    seasonalBonusMonth: 2,
    seasonalBonusName: "Valentine's Bloom",
  },
  {
    id: 'sunflower',
    displayName: 'Sunflower',
    emoji: '🌻',
    stageDescriptions: ['Empty pot', 'A tiny sprout', 'Tall stem', 'Budding head', 'Opening petals', 'Full sunflower'],
    seasonalBonusMonth: 7,
    seasonalBonusName: 'Summer Radiance',
  },
  {
    id: 'tulip',
    displayName: 'Tulip',
    emoji: '🌷',
    stageDescriptions: ['Empty pot', 'A tiny sprout', 'Slender stem', 'Tulip bud', 'Opening tulip', 'Full tulip'],
    seasonalBonusMonth: 4,
    seasonalBonusName: 'Spring Awakening',
  },
  {
    id: 'sakura',
    displayName: 'Sakura',
    emoji: '🌸',
    stageDescriptions: ['Empty pot', 'A tiny sprout', 'Branching tree', 'Cherry buds', 'Opening blossoms', 'Full sakura'],
    seasonalBonusMonth: 3,
    seasonalBonusName: 'Hanami Season',
  },
];

export function plantFromId(id: string): PlantType {
  return PLANT_TYPES.find((p) => p.id === id) ?? PLANT_TYPES[0];
}

export function effectiveStage(p: PlantType, baseStage: number): number {
  const month = new Date().getMonth() + 1;
  if (p.seasonalBonusMonth === month) return Math.min(5, Math.max(0, baseStage + 1));
  return baseStage;
}

export function isPlantInSeason(p: PlantType): boolean {
  return p.seasonalBonusMonth != null && p.seasonalBonusMonth === new Date().getMonth() + 1;
}

function parseTimestamp(value: unknown): Date {
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === 'number') return new Date(value);
  if (typeof value === 'string') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? new Date() : d;
  }
  return new Date();
}

const toInt = (v: unknown) => (typeof v === 'number' ? Math.trunc(v) : 0);

/** `GardenStats.fromMap`. */
function fromMap(data: Record<string, unknown>): GardenStats {
  return {
    currentStage: toInt(data.currentStage),
    lastVisit: parseTimestamp(data.lastVisit),
    streakCount: toInt(data.streakCount),
    totalInteractions: toInt(data.totalInteractions),
    plantType: typeof data.plantType === 'string' ? data.plantType : 'lily',
  };
}

/** `GardenStats.initial()`. */
const initialStats = (): GardenStats => ({
  currentStage: 0,
  lastVisit: new Date(),
  streakCount: 0,
  totalInteractions: 0,
  plantType: 'lily',
});

const toFirestore = (s: GardenStats) => ({
  currentStage: s.currentStage,
  lastVisit: Timestamp.fromDate(s.lastVisit),
  streakCount: s.streakCount,
  totalInteractions: s.totalInteractions,
  plantType: s.plantType,
});

/** `GardenStats.calculateStage`. */
export function calculateStage(interactions: number): number {
  if (interactions >= 30) return 5;
  if (interactions >= 20) return 4;
  if (interactions >= 10) return 3;
  if (interactions >= 5) return 2;
  if (interactions >= 1) return 1;
  return 0;
}

const sameDay = (a: Date, b: Date) =>
  a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

const gardenAward: XpAward = { amount: 10, dailyCap: 1 };
const statsRef = (uid: string) => doc(db, 'users', uid, 'garden_stats', 'stats');

/** `GardenService.watchStats` / `watchPartnerStats`: a missing doc reads as the initial stats. */
function watchStats(uid: string, label: string) {
  return withFirestoreTimeout(
    snapshots<DocumentSnapshot<DocumentData>, GardenStats>(
      (next, error) => onSnapshot(statsRef(uid), next, error),
      (s) => (s.exists() ? fromMap(s.data()) : initialStats()),
    ),
    { label },
  );
}

/** `GardenProvider` + `GardenService`. */
class GardenStore {
  stats = new ValueNotifier<GardenStats | null>(null);
  partnerStats = new ValueNotifier<GardenStats | null>(null);
  hasError = new ValueNotifier(false);
  hasPartnerError = new ValueNotifier(false);
  private uid: string | null = null;
  private partnerUid: string | null = null;
  private unsub: (() => void) | null = null;
  private partnerUnsub: (() => void) | null = null;

  updateUserId(uid: string | null) {
    if (this.uid === uid) return;
    this.unsub?.();
    this.unsub = null;
    this.hasError.value = false;
    this.uid = uid;
    if (!uid) {
      this.stats.value = null;
      return;
    }
    if (AgentMode.demo) {
      this.stats.value = AgentFixtures.demoGardenStats();
      return;
    }
    this.unsub = watchStats(uid, 'garden-stats')({
      data: (v) => {
        this.stats.value = v;
        this.hasError.value = false;
      },
      error: () => {
        this.hasError.value = true;
      },
    });
  }

  watchPartner(partnerUid: string | null) {
    if (this.partnerUid === partnerUid && (this.partnerUnsub || this.partnerStats.value)) return;
    this.partnerUnsub?.();
    this.partnerUnsub = null;
    this.hasPartnerError.value = false;
    this.partnerUid = partnerUid;
    if (!partnerUid) {
      this.partnerStats.value = null;
      return;
    }
    if (AgentMode.demo) {
      this.partnerStats.value = AgentFixtures.demoGardenStats();
      return;
    }
    this.partnerUnsub = watchStats(partnerUid, 'garden-partner-stats')({
      data: (v) => {
        this.partnerStats.value = v;
        this.hasPartnerError.value = false;
      },
      error: () => {
        this.hasPartnerError.value = true;
      },
    });
  }

  stopWatchingPartner() {
    this.partnerUnsub?.();
    this.partnerUnsub = null;
    this.partnerUid = null;
    this.hasPartnerError.value = false;
    this.partnerStats.value = null;
  }

  /** `GardenProvider.recordInteraction`: the daily visit that grows the plant. */
  async recordInteraction() {
    const uid = this.uid;
    if (!uid) return;
    const previous = this.stats.value;
    if (previous) {
      const total = previous.totalInteractions + 1;
      this.stats.value = { ...previous, totalInteractions: total, currentStage: calculateStage(total), lastVisit: new Date() };
    }
    if (AgentMode.demo) return;
    try {
      await runTransaction(db, async (txn) => {
        const ref = statsRef(uid);
        const snap = await txn.get(ref);
        const now = new Date();
        if (!snap.exists()) {
          txn.set(ref, toFirestore({ currentStage: 1, lastVisit: now, streakCount: 1, totalInteractions: 1, plantType: 'lily' }));
          return;
        }
        const current = fromMap(snap.data());
        let streak = current.streakCount;
        const yesterday = new Date(now.getTime() - 86400000);
        if (sameDay(current.lastVisit, yesterday)) streak += 1;
        else if (!sameDay(current.lastVisit, now)) streak = 1;
        const total = current.totalInteractions + 1;
        txn.update(ref, {
          currentStage: calculateStage(total),
          lastVisit: Timestamp.fromDate(now),
          streakCount: streak,
          totalInteractions: total,
        });
      });
      try {
        await awardDaily(uid, 'garden', gardenAward);
      } catch (e) {
        Logger.e('Garden: XP award failed', e);
      }
    } catch (e) {
      Logger.e('Optimistic action failed', e);
      this.stats.value = previous;
    }
  }

  /** `GardenProvider.setPlantType`. */
  async setPlantType(typeId: string) {
    const uid = this.uid;
    if (!uid) return;
    const previous = this.stats.value;
    if (previous) this.stats.value = { ...previous, plantType: typeId };
    if (AgentMode.demo) return;
    try {
      await runTransaction(db, async (txn) => {
        const ref = statsRef(uid);
        const snap = await txn.get(ref);
        if (snap.exists()) txn.update(ref, { plantType: typeId });
        else txn.set(ref, toFirestore({ ...initialStats(), plantType: typeId }));
      });
      Logger.i(`Plant type set to ${typeId} for user ${uid}`);
    } catch (e) {
      Logger.e('Optimistic action failed', e);
      this.stats.value = previous;
    }
  }
}

export const gardenStore = new GardenStore();
