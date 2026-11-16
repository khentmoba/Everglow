// Port of lib/features/bucket_list/data/services/bucket_list_service.dart + bucket_item.dart + bucket_ui.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  deleteField,
  doc,
  limit,
  onSnapshot,
  orderBy,
  query,
  Timestamp,
  updateDoc,
  type DocumentData,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type BucketItemFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { AppColors } from '../../core/theme/colors';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type BucketStatus = 'wish' | 'planned' | 'completed';
export type BucketPriority = 'low' | 'medium' | 'high' | 'urgent';
export type BucketCategory = 'travel' | 'experience' | 'food' | 'adventure' | 'milestone' | 'other';

export type BucketItem = Omit<BucketItemFixture, 'priority'> & {
  priority: BucketPriority;
  notes?: string;
  assignedTo?: string;
  dueDate?: Date;
  calendarEventId?: string;
  imageUrl?: string;
};

export const BUCKET_CATEGORIES: Array<{ id: BucketCategory; label: string; emoji: string; hue: string }> = [
  { id: 'travel', label: 'Travel', emoji: '✈️', hue: AppColors.auroraTeal },
  { id: 'experience', label: 'Experience', emoji: '🎭', hue: AppColors.softLavender },
  { id: 'food', label: 'Food & Drink', emoji: '🍽️', hue: AppColors.warmAmber },
  { id: 'adventure', label: 'Adventure', emoji: '🏔️', hue: AppColors.success },
  { id: 'milestone', label: 'Milestone', emoji: '🏆', hue: AppColors.blushGold },
  { id: 'other', label: 'Other', emoji: '💫', hue: AppColors.roseQuartz },
];

export const BUCKET_STATUS_META: Record<BucketStatus, { label: string; shortLabel: string; emoji: string; hue: string; icon: string }> = {
  wish: { label: 'Wished', shortLabel: 'Wished', emoji: '🌟', hue: AppColors.blushGold, icon: 'auto_awesome' },
  planned: { label: 'Planned', shortLabel: 'Planned', emoji: '📋', hue: AppColors.auroraTeal, icon: 'map' },
  completed: { label: 'Fulfilled', shortLabel: 'Done', emoji: '✅', hue: AppColors.success, icon: 'check_circle' },
};

export const BUCKET_PRIORITY_META: Record<BucketPriority, { label: string; shortLabel: string; emoji: string; rank: number; hue: string }> = {
  low: { label: 'Low', shortLabel: 'Low', emoji: '⬇️', rank: 0, hue: AppColors.softLavender },
  medium: { label: 'Medium', shortLabel: 'Med', emoji: '➡️', rank: 1, hue: AppColors.blushGold },
  high: { label: 'High', shortLabel: 'High', emoji: '⬆️', rank: 2, hue: AppColors.warmAmber },
  urgent: { label: 'Urgent', shortLabel: 'Urgent', emoji: '🔥', rank: 3, hue: AppColors.error },
};

export function bucketCategoryMeta(cat: string) {
  return BUCKET_CATEGORIES.find((c) => c.id === cat) ?? BUCKET_CATEGORIES[5];
}

export function bucketAssigneeLabel(username?: string): string {
  if (username === 'khentsgdz') return 'Khent';
  if (username === 'clairjassen') return 'Clair';
  return username || 'Unassigned';
}

export function bucketAssigneeHue(username?: string): string {
  if (username === 'khentsgdz') return AppColors.auroraTeal;
  if (username === 'clairjassen') return AppColors.auroraRose;
  return AppColors.mutedPurple;
}

export function isBucketOverdue(item: BucketItem): boolean {
  if (!item.dueDate || item.status === 'completed') return false;
  const endOfDue = new Date(item.dueDate.getFullYear(), item.dueDate.getMonth(), item.dueDate.getDate(), 23, 59, 59);
  return Date.now() > endOfDue.getTime();
}

export function isBucketDueSoon(item: BucketItem): boolean {
  if (!item.dueDate || item.status === 'completed') return false;
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const due = new Date(item.dueDate.getFullYear(), item.dueDate.getMonth(), item.dueDate.getDate()).getTime();
  const diff = Math.round((due - today) / 86_400_000);
  return diff >= 0 && diff <= 2;
}

function parseTs(v: unknown): Date | undefined {
  if (v && typeof (v as Timestamp).toDate === 'function') return (v as Timestamp).toDate();
  return undefined;
}

function mapDocs(s: QuerySnapshot<DocumentData>): BucketItem[] {
  return s.docs.map((d) => {
    const data = d.data();
    const status: BucketStatus = data.status === 'planned' || data.status === 'completed' ? data.status : 'wish';
    const priority: BucketPriority =
      data.priority === 'low' || data.priority === 'high' || data.priority === 'urgent' ? data.priority : 'medium';
    return {
      id: d.id,
      calendarEventId: typeof data.calendarEventId === 'string' ? data.calendarEventId : undefined,
      title: String(data.title ?? ''),
      description: String(data.description ?? ''),
      category: String(data.category ?? 'other'),
      status,
      createdBy: String(data.createdBy ?? ''),
      createdAt: parseTs(data.createdAt) ?? new Date(),
      completedAt: parseTs(data.completedAt),
      completedBy: typeof data.completedBy === 'string' ? data.completedBy : undefined,
      imageUrl: typeof data.imageUrl === 'string' ? data.imageUrl : undefined,
      notes: typeof data.notes === 'string' ? data.notes : '',
      priority,
      assignedTo: typeof data.assignedTo === 'string' ? data.assignedTo : undefined,
      dueDate: parseTs(data.dueDate),
    };
  });
}

class BucketListService {
  private demoItems: BucketItem[] | null = null;
  private demoChanges = new Changes(() => [...this.ensureDemo()]);

  private ensureDemo(): BucketItem[] {
    if (!this.demoItems) {
      this.demoItems = AgentFixtures.demoBucketList().map((i) => ({ ...i }));
    }
    return this.demoItems;
  }

  watchPreview(max = 12): Source<BucketItem[]> {
    if (AgentMode.demo) return this.demoChanges.source;
    const q = query(collection(db, 'bucket_list'), orderBy('createdAt', 'desc'), limit(max));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, BucketItem[]>(
        (next, error) => onSnapshot(q, next, error),
        mapDocs,
      ),
      { label: 'bucket-list-preview' },
    );
  }

  watchAll(): Source<BucketItem[]> {
    if (AgentMode.demo) return this.demoChanges.source;
    const q = query(collection(db, 'bucket_list'), orderBy('createdAt', 'desc'), limit(100));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, BucketItem[]>(
        (next, error) => onSnapshot(q, next, error),
        mapDocs,
      ),
      { label: 'bucket-list-all' },
    );
  }

  async add(item: Omit<BucketItem, 'id'>): Promise<void> {
    if (AgentMode.demo) {
      this.demoItems = [{ ...item, id: `demo_bucket_${Date.now()}` }, ...this.ensureDemo()];
      this.demoChanges.emit();
      return;
    }
    const payload: Record<string, unknown> = {
      title: item.title,
      description: item.description,
      category: item.category,
      status: item.status,
      createdBy: item.createdBy,
      createdAt: Timestamp.fromDate(item.createdAt),
      notes: item.notes ?? '',
      priority: item.priority,
    };
    if (item.assignedTo) payload.assignedTo = item.assignedTo;
    if (item.dueDate) payload.dueDate = Timestamp.fromDate(item.dueDate);
    await addDoc(collection(db, 'bucket_list'), payload);
  }

  async update(id: string, patch: Partial<BucketItem>): Promise<void> {
    if (AgentMode.demo) {
      this.demoItems = this.ensureDemo().map((i) => (i.id === id ? { ...i, ...patch } : i));
      this.demoChanges.emit();
      return;
    }
    const payload: Record<string, unknown> = { ...patch };
    if (patch.dueDate instanceof Date) payload.dueDate = Timestamp.fromDate(patch.dueDate);
    if (patch.completedAt instanceof Date) payload.completedAt = Timestamp.fromDate(patch.completedAt);
    await updateDoc(doc(db, 'bucket_list', id), payload);
  }

  async delete(id: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoItems = this.ensureDemo().filter((i) => i.id !== id);
      this.demoChanges.emit();
      return;
    }
    await deleteDoc(doc(db, 'bucket_list', id));
  }

  async markComplete(id: string, completedBy: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoItems = this.ensureDemo().map((i) =>
        i.id === id ? { ...i, status: 'completed', completedAt: new Date(), completedBy } : i,
      );
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'bucket_list', id), {
      status: 'completed',
      completedAt: Timestamp.now(),
      completedBy,
    });
  }

  async markUncomplete(id: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoItems = this.ensureDemo().map((i) =>
        i.id === id ? { ...i, status: 'wish', completedAt: undefined, completedBy: undefined } : i,
      );
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'bucket_list', id), {
      status: 'wish',
      completedAt: deleteField(),
      completedBy: deleteField(),
    });
  }

  async moveStatus(id: string, status: BucketStatus, completedBy?: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoItems = this.ensureDemo().map((i) =>
        i.id === id
          ? {
              ...i,
              status,
              completedAt: status === 'completed' ? new Date() : undefined,
              completedBy: status === 'completed' ? completedBy : undefined,
            }
          : i,
      );
      this.demoChanges.emit();
      return;
    }
    const data: Record<string, unknown> = { status };
    if (status === 'completed') {
      data.completedAt = Timestamp.now();
      if (completedBy) data.completedBy = completedBy;
    } else {
      data.completedAt = deleteField();
      data.completedBy = deleteField();
    }
    await updateDoc(doc(db, 'bucket_list', id), data);
  }

  async assign(id: string, username?: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoItems = this.ensureDemo().map((i) => (i.id === id ? { ...i, assignedTo: username } : i));
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'bucket_list', id), {
      assignedTo: username ?? deleteField(),
    });
  }

  async setPriority(id: string, priority: BucketPriority): Promise<void> {
    if (AgentMode.demo) {
      this.demoItems = this.ensureDemo().map((i) => (i.id === id ? { ...i, priority } : i));
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'bucket_list', id), { priority });
  }

  async setDueDate(id: string, dueDate?: Date): Promise<void> {
    if (AgentMode.demo) {
      this.demoItems = this.ensureDemo().map((i) => (i.id === id ? { ...i, dueDate } : i));
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'bucket_list', id), {
      dueDate: dueDate ? Timestamp.fromDate(dueDate) : deleteField(),
    });
  }
}

export const bucketListService = new BucketListService();
