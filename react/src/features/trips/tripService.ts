// Port of lib/features/trip_kit/data: models/trip.dart and
// services/trip_kit_service.dart.
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
  runTransaction,
  Timestamp,
  updateDoc,
  type DocumentData,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { just, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type TripPackItem = { id: string; label: string; packed: boolean; packedBy: string | null };
export type TripExpense = { id: string; label: string; amount: number; paidBy: string | null };
export type TripPlace = {
  id: string;
  name: string;
  note: string;
  done: boolean;
  lat: number | null;
  lng: number | null;
  category: string | null;
};

export type Trip = {
  id: string;
  title: string;
  destination: string;
  startDate: Date | null;
  endDate: Date | null;
  notes: string;
  budgetTotal: number;
  packing: TripPackItem[];
  expenses: TripExpense[];
  places: TripPlace[];
  createdBy: string;
  createdAt: Date;
};

export const newTripItemId = () =>
  `${Date.now() * 1000 + Math.floor(Math.random() * 1000)}${Math.floor(Math.random() * (1 << 20))}`;

const str = (v: unknown, fallback = '') => (typeof v === 'string' ? v : fallback);
const asDate = (v: unknown) => (v instanceof Timestamp ? v.toDate() : null);
const asMoney = (v: unknown) => {
  if (typeof v === 'number') return v;
  const n = Number.parseFloat(`${v}`);
  return Number.isFinite(n) ? n : 0;
};

function asList<T>(v: unknown, parse: (m: Record<string, unknown>) => T): T[] {
  if (!Array.isArray(v)) return [];
  const out: T[] = [];
  for (const e of v) {
    if (e && typeof e === 'object') {
      try {
        out.push(parse(e as Record<string, unknown>));
      } catch {
        // Skip one bad sub-item; keep the rest of the trip readable.
      }
    }
  }
  return out;
}

const packFromMap = (d: Record<string, unknown>): TripPackItem => ({
  id: str(d.id) || newTripItemId(),
  label: str(d.label),
  packed: d.packed === true,
  packedBy: typeof d.packedBy === 'string' ? d.packedBy : null,
});
const expenseFromMap = (d: Record<string, unknown>): TripExpense => ({
  id: str(d.id) || newTripItemId(),
  label: str(d.label),
  amount: asMoney(d.amount),
  paidBy: typeof d.paidBy === 'string' ? d.paidBy : null,
});
const placeFromMap = (d: Record<string, unknown>): TripPlace => ({
  id: str(d.id) || newTripItemId(),
  name: str(d.name),
  note: str(d.note),
  done: d.done === true,
  lat: typeof d.lat === 'number' ? d.lat : null,
  lng: typeof d.lng === 'number' ? d.lng : null,
  category: typeof d.category === 'string' ? d.category : null,
});

const packToMap = (i: TripPackItem) => ({
  id: i.id,
  label: i.label,
  packed: i.packed,
  ...(i.packedBy != null ? { packedBy: i.packedBy } : {}),
});
const expenseToMap = (e: TripExpense) => ({
  id: e.id,
  label: e.label,
  amount: e.amount,
  ...(e.paidBy != null ? { paidBy: e.paidBy } : {}),
});
const placeToMap = (p: TripPlace) => ({
  id: p.id,
  name: p.name,
  note: p.note,
  done: p.done,
  ...(p.lat != null ? { lat: p.lat } : {}),
  ...(p.lng != null ? { lng: p.lng } : {}),
  ...(p.category != null ? { category: p.category } : {}),
});

export function tripFromMap(data: DocumentData, id: string): Trip {
  const notes = data.notes ?? data.description;
  return {
    id,
    title: str(data.title),
    destination: str(data.destination),
    startDate: asDate(data.startDate),
    endDate: asDate(data.endDate),
    notes: typeof notes === 'string' ? notes : '',
    budgetTotal: asMoney(data.budgetTotal ?? data.budgetEstimate),
    packing: asList(data.packing, packFromMap),
    expenses: asList(data.expenses, expenseFromMap),
    places: asList(data.places, placeFromMap),
    createdBy: str(data.createdBy),
    createdAt: asDate(data.createdAt) ?? new Date(),
  };
}

function tripToMap(t: Trip) {
  return {
    title: t.title,
    destination: t.destination,
    ...(t.startDate ? { startDate: Timestamp.fromDate(t.startDate) } : {}),
    ...(t.endDate ? { endDate: Timestamp.fromDate(t.endDate) } : {}),
    notes: t.notes,
    budgetTotal: t.budgetTotal,
    packing: t.packing.map(packToMap),
    expenses: t.expenses.map(expenseToMap),
    places: t.places.map(placeToMap),
    createdBy: t.createdBy,
    createdAt: Timestamp.fromDate(t.createdAt),
  };
}

export const packedCount = (t: Trip) => t.packing.filter((e) => e.packed).length;
export const spentTotal = (t: Trip) => t.expenses.reduce((sum, e) => sum + e.amount, 0);
export const remaining = (t: Trip) => t.budgetTotal - spentTotal(t);
export const budgetProgress = (t: Trip) => (t.budgetTotal <= 0 ? 0 : Math.min(1, Math.max(0, spentTotal(t) / t.budgetTotal)));
export const overBudget = (t: Trip) => t.budgetTotal > 0 && spentTotal(t) > t.budgetTotal;
export const visitedCount = (t: Trip) => t.places.filter((e) => e.done).length;

export const demoTrips: Trip[] = [
  {
    id: 'demo_trip',
    title: 'Fictional seaside weekend',
    destination: 'Demo beach',
    startDate: null,
    endDate: null,
    notes: '',
    budgetTotal: 3000,
    packing: [],
    expenses: [],
    places: [],
    createdBy: 'khentsgdz',
    createdAt: new Date(2026, 1, 14),
  },
];

const COLLECTION = 'travel_trips';

type ListField = 'packing' | 'expenses' | 'places';

class TripService {
  watchAll(): Source<Trip[]> {
    if (AgentMode.demo) return just(demoTrips);
    const subscribe: Source<Trip[]> = (l) =>
      onSnapshot(
        query(collection(db, COLLECTION), orderBy('createdAt', 'desc'), limit(50)),
        (snap) => {
          const out: Trip[] = [];
          for (const d of snap.docs) {
            try {
              out.push(tripFromMap(d.data(), d.id));
            } catch (e) {
              Logger.e(`TripKit: skipping malformed trip ${d.id}`, e);
            }
          }
          l.data(out);
        },
        (e) => l.error?.(e),
      );
    return withFirestoreTimeout(subscribe, { label: 'trip-kit-all', maxAttempts: 3, resubscribe: () => subscribe });
  }

  watchOne(id: string): Source<Trip | null> {
    if (AgentMode.demo) return just(demoTrips.find((t) => t.id === id) ?? null);
    const src: Source<Trip | null> = (l) =>
      onSnapshot(
        doc(db, COLLECTION, id),
        (snap) => {
          if (!snap.exists()) return l.data(null);
          try {
            l.data(tripFromMap(snap.data(), snap.id));
          } catch (e) {
            Logger.e(`TripKit: malformed trip ${id}`, e);
            l.data(null);
          }
        },
        (e) => l.error?.(e),
      );
    return withFirestoreTimeout(src, { label: 'trip-kit-one' });
  }

  async create(trip: Trip): Promise<string> {
    if (AgentMode.demo) return demoTrips[0].id;
    try {
      const ref = await addDoc(collection(db, COLLECTION), tripToMap(trip));
      return ref.id;
    } catch (e) {
      Logger.e('TripKit: error creating trip', e);
      throw e;
    }
  }

  async updateDetails(trip: Trip): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await updateDoc(doc(db, COLLECTION, trip.id), {
        title: trip.title,
        destination: trip.destination,
        startDate: trip.startDate ? Timestamp.fromDate(trip.startDate) : deleteField(),
        endDate: trip.endDate ? Timestamp.fromDate(trip.endDate) : deleteField(),
        notes: trip.notes,
        budgetTotal: trip.budgetTotal,
      });
    } catch (e) {
      Logger.e('TripKit: error updating details', e);
      throw e;
    }
  }

  addPackingItem = (tripId: string, item: TripPackItem) =>
    this.updateList(tripId, 'packing', (t) =>
      (t.packing.some((e) => e.id === item.id) ? t.packing : [...t.packing, item]).map(packToMap),
    );

  setPackingItemPacked = (tripId: string, itemId: string, packed: boolean, packedBy: string | null) =>
    this.updateList(tripId, 'packing', (t) =>
      t.packing
        .map((i) => (i.id === itemId ? { ...i, packed, packedBy: packed ? (packedBy ?? i.packedBy) : null } : i))
        .map(packToMap),
    );

  removePackingItem = (tripId: string, itemId: string) =>
    this.updateList(tripId, 'packing', (t) => t.packing.filter((i) => i.id !== itemId).map(packToMap));

  addExpense = (tripId: string, expense: TripExpense) =>
    this.updateList(tripId, 'expenses', (t) =>
      (t.expenses.some((e) => e.id === expense.id) ? t.expenses : [...t.expenses, expense]).map(expenseToMap),
    );

  removeExpense = (tripId: string, expenseId: string) =>
    this.updateList(tripId, 'expenses', (t) => t.expenses.filter((e) => e.id !== expenseId).map(expenseToMap));

  addPlace = (tripId: string, place: TripPlace) =>
    this.updateList(tripId, 'places', (t) =>
      (t.places.some((e) => e.id === place.id) ? t.places : [...t.places, place]).map(placeToMap),
    );

  setPlaceDone = (tripId: string, placeId: string, done: boolean) =>
    this.updateList(tripId, 'places', (t) => t.places.map((p) => (p.id === placeId ? { ...p, done } : p)).map(placeToMap));

  removePlace = (tripId: string, placeId: string) =>
    this.updateList(tripId, 'places', (t) => t.places.filter((p) => p.id !== placeId).map(placeToMap));

  private async updateList(id: string, field: ListField, change: (t: Trip) => unknown[]): Promise<void> {
    if (AgentMode.demo) return;
    try {
      const ref = doc(db, COLLECTION, id);
      await runTransaction(db, async (tx) => {
        const snap = await tx.get(ref);
        const data = snap.data();
        if (!snap.exists() || !data) throw new Error(`Trip ${id} no longer exists`);
        tx.update(ref, { [field]: change(tripFromMap(data, id)) });
      });
    } catch (e) {
      Logger.e(`TripKit: error updating ${field} for ${id}`, e);
      throw e;
    }
  }

  async delete(id: string): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await deleteDoc(doc(db, COLLECTION, id));
    } catch (e) {
      Logger.e('TripKit: error deleting trip', e);
      throw e;
    }
  }
}

export const tripService = new TripService();

const monthDay = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' });
const grouped = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });

export const tripPeso = (amount: number) => `₱${grouped.format(Math.sign(amount) * Math.round(Math.abs(amount)))}`;
export const formatMonthDay = (d: Date) => monthDay.format(d);

export function tripDateRange(t: Trip) {
  if (t.startDate == null && t.endDate == null) return 'Dates TBD';
  if (t.startDate != null && t.endDate != null) return `${monthDay.format(t.startDate)} – ${monthDay.format(t.endDate)}`;
  return monthDay.format((t.startDate ?? t.endDate)!);
}
