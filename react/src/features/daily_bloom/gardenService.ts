// Port of lib/features/daily_bloom/data/models/plant_type.dart + garden_stats.dart
// and garden_provider.dart.
import { doc, onSnapshot, setDoc, type DocumentData, type DocumentSnapshot, type Timestamp } from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type GardenStatsFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { ValueNotifier } from '../../core/system/store';
import { snapshots, withFirestoreTimeout } from '../../core/utils/liveSource';

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

function fromFirestore(data: Record<string, unknown>): GardenStats {
  return {
    currentStage: Math.trunc(Number(data.currentStage ?? 0)),
    lastVisit: (data.lastVisit as Timestamp | undefined)?.toDate() ?? new Date(),
    streakCount: Math.trunc(Number(data.streakCount ?? 0)),
    totalInteractions: Math.trunc(Number(data.totalInteractions ?? 0)),
    plantType: String(data.plantType ?? 'lily'),
  };
}

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
    this.uid = uid;
    this.unsub?.();
    this.unsub = null;
    if (!uid) {
      this.stats.value = null;
      return;
    }
    if (AgentMode.demo) {
      this.stats.value = AgentFixtures.demoGardenStats();
      this.hasError.value = false;
      return;
    }
    const ref = doc(db, 'users', uid, 'garden', 'stats');
    this.unsub = withFirestoreTimeout(
      snapshots<DocumentSnapshot<DocumentData>, GardenStats | null>(
        (next, error) => onSnapshot(ref, next, error),
        (s) => (s.exists() ? fromFirestore(s.data()) : { currentStage: 1, lastVisit: new Date(), streakCount: 1, totalInteractions: 1, plantType: 'lily' }),
      ),
      { label: 'garden-stats' },
    )({
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
    if (this.partnerUid === partnerUid) return;
    this.partnerUid = partnerUid;
    this.partnerUnsub?.();
    this.partnerUnsub = null;
    if (!partnerUid) {
      this.partnerStats.value = null;
      return;
    }
    if (AgentMode.demo) {
      this.partnerStats.value = {
        ...AgentFixtures.demoGardenStats(),
        plantType: 'rose',
        currentStage: 4,
      };
      this.hasPartnerError.value = false;
      return;
    }
    const ref = doc(db, 'users', partnerUid, 'garden', 'stats');
    this.partnerUnsub = withFirestoreTimeout(
      snapshots<DocumentSnapshot<DocumentData>, GardenStats | null>(
        (next, error) => onSnapshot(ref, next, error),
        (s) => (s.exists() ? fromFirestore(s.data()) : null),
      ),
      { label: 'garden-partner-stats' },
    )({
      data: (v) => {
        this.partnerStats.value = v;
        this.hasPartnerError.value = false;
      },
      error: () => {
        this.hasPartnerError.value = true;
      },
    });
  }

  async setPlantType(typeId: string) {
    if (this.stats.value) {
      this.stats.value = { ...this.stats.value, plantType: typeId };
    }
    if (AgentMode.demo || !this.uid) return;
    await setDoc(doc(db, 'users', this.uid, 'garden', 'stats'), { plantType: typeId }, { merge: true });
  }
}

export const gardenStore = new GardenStore();
