// Port of lib/features/subs/data/models/subscription.dart and
// lib/features/subs/data/services/subs_service.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  limit,
  onSnapshot,
  orderBy,
  query,
  Timestamp,
  updateDoc,
  type DocumentData,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { just, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type SubCycle = 'monthly' | 'yearly';
export type SubPayer = 'khent' | 'clair' | 'shared';

export const SubCycles: { id: SubCycle; displayName: string; suffix: string }[] = [
  { id: 'monthly', displayName: 'Monthly', suffix: '/mo' },
  { id: 'yearly', displayName: 'Yearly', suffix: '/yr' },
];
export const SubPayers: { id: SubPayer; displayName: string }[] = [
  { id: 'khent', displayName: 'Khent' },
  { id: 'clair', displayName: 'Clair' },
  { id: 'shared', displayName: 'Shared' },
];

export type Subscription = {
  id: string;
  name: string;
  price: number;
  renewalDate: Date;
  cycle: SubCycle;
  payer: SubPayer;
  createdBy: string;
  createdAt: Date;
};

export const cycleSuffix = (s: Subscription) => (s.cycle === 'monthly' ? '/mo' : '/yr');
export const payerName = (p: SubPayer) => SubPayers.find((x) => x.id === p)!.displayName;
export const monthlyCost = (s: Subscription) => (s.cycle === 'monthly' ? s.price : s.price / 12);

export { daysUntilRenewal } from './renewalPure';

function fromMap(data: DocumentData, id: string): Subscription {
  const asDate = (v: unknown) => (v instanceof Timestamp ? v.toDate() : null);
  const price = data.price;
  return {
    id,
    name: typeof data.name === 'string' ? data.name : '',
    price: typeof price === 'number' ? price : typeof price === 'string' ? Number.parseFloat(price.trim()) || 0 : 0,
    renewalDate: asDate(data.renewalDate) ?? new Date(),
    cycle: data.cycle === 'yearly' ? 'yearly' : 'monthly',
    payer: data.payer === 'khent' || data.payer === 'clair' ? data.payer : 'shared',
    createdBy: typeof data.createdBy === 'string' ? data.createdBy : '',
    createdAt: asDate(data.createdAt) ?? new Date(),
  };
}

function demoSubscriptions(): Subscription[] {
  const now = new Date();
  return [
    {
      id: 'demo_sub',
      name: 'Demo movie nights',
      price: 300,
      renewalDate: new Date(now.getTime() + 7 * 86_400_000),
      cycle: 'monthly',
      payer: 'shared',
      createdBy: 'khentsgdz',
      createdAt: new Date(2026, 1, 14),
    },
  ];
}

const COLLECTION = 'subscriptions';

class SubsService {
  watchAll(): Source<Subscription[]> {
    if (AgentMode.demo) return just(demoSubscriptions());
    const subscribe: Source<Subscription[]> = (l) =>
      onSnapshot(
        query(collection(db, COLLECTION), orderBy('createdAt', 'desc'), limit(50)),
        (snap) => l.data(snap.docs.map((d) => fromMap(d.data(), d.id))),
        (e) => l.error?.(e),
      );
    return withFirestoreTimeout(subscribe, { label: 'subs-all', maxAttempts: 3, resubscribe: () => subscribe });
  }

  async add(sub: Omit<Subscription, 'id'>): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await addDoc(collection(db, COLLECTION), {
        name: sub.name,
        price: sub.price,
        renewalDate: Timestamp.fromDate(sub.renewalDate),
        cycle: sub.cycle,
        payer: sub.payer,
        createdBy: sub.createdBy,
        createdAt: Timestamp.fromDate(sub.createdAt),
      });
      Logger.i(`Added subscription: ${sub.name}`);
    } catch (e) {
      Logger.e('Error adding subscription', e);
      throw e;
    }
  }

  async update(sub: Subscription, original: Subscription): Promise<void> {
    if (AgentMode.demo) return;
    const changes: Record<string, unknown> = {};
    if (sub.name !== original.name) changes.name = sub.name;
    if (sub.price !== original.price) changes.price = sub.price;
    if (sub.renewalDate.getTime() !== original.renewalDate.getTime()) changes.renewalDate = Timestamp.fromDate(sub.renewalDate);
    if (sub.cycle !== original.cycle) changes.cycle = sub.cycle;
    if (sub.payer !== original.payer) changes.payer = sub.payer;
    if (Object.keys(changes).length === 0) return;
    try {
      await updateDoc(doc(db, COLLECTION, sub.id), changes);
      Logger.i(`Updated subscription: ${sub.id}`);
    } catch (e) {
      Logger.e('Error updating subscription', e);
      throw e;
    }
  }

  async delete(id: string): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await deleteDoc(doc(db, COLLECTION, id));
      Logger.i(`Deleted subscription: ${id}`);
    } catch (e) {
      Logger.e('Error deleting subscription', e);
      throw e;
    }
  }
}

export const subsService = new SubsService();
