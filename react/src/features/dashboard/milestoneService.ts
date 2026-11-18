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
import { db } from '../../core/services/firebase';
import { just, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type Milestone = MilestoneFixture;

export const MILESTONE_META: Record<MilestoneCategory, { label: string; emoji: string }> = {
  firstDate: { label: 'First Date', emoji: '☕' },
  anniversary: { label: 'Anniversary', emoji: '💍' },
  trip: { label: 'Trip', emoji: '🚗' },
  memory: { label: 'Memory', emoji: '✨' },
  other: { label: 'Milestone', emoji: '🌸' },
};

function parseCategory(v: unknown): MilestoneCategory {
  if (v === 'firstDate' || v === 'anniversary' || v === 'trip' || v === 'memory') return v;
  return 'other';
}

class MilestoneService {
  milestonesPreview(max = 12): Source<Milestone[]> {
    if (AgentMode.demo) return just(AgentFixtures.demoMilestones());
    const q = query(collection(db, 'milestones'), orderBy('date', 'desc'), limit(max));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, Milestone[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) =>
          s.docs.map((d) => {
            const data = d.data();
            const rawUrls = Array.isArray(data.imageUrls) ? data.imageUrls.map(String) : [];
            if (rawUrls.length === 0 && typeof data.imageUrl === 'string' && data.imageUrl) {
              rawUrls.push(data.imageUrl);
            }
            return {
              id: d.id,
              title: String(data.title ?? ''),
              description: String(data.description ?? ''),
              date: (data.date as Timestamp | undefined)?.toDate() ?? new Date(),
              author: String(data.author ?? ''),
              category: parseCategory(data.category),
              imageUrls: rawUrls,
            };
          }),
      ),
      { label: 'milestones-preview' },
    );
  }
}

export const milestoneService = new MilestoneService();
