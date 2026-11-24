// Port of lib/features/money/data/models/money_entry.dart and
// lib/features/money/data/services/money_service.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  limit as qLimit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
  type DocumentData,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { just, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type MoneyType = 'expense' | 'income';

export const MoneyCategories = {
  expense: ['Food', 'Transport', 'Shopping', 'Bills', 'Dates', 'Fun', 'Health', 'Other'],
  income: ['Allowance', 'Salary', 'Gift', 'Other'],
  emoji: {
    Food: '🍽️',
    Transport: '🛵',
    Shopping: '🛍️',
    Bills: '🧾',
    Dates: '💕',
    Fun: '🎮',
    Health: '💊',
    Allowance: '💌',
    Salary: '💼',
    Gift: '🎁',
    Other: '✨',
  } as Record<string, string>,
  iconFor(category: string): string {
    return this.emoji[category] ?? '✨';
  },
};

const pesoFormat = new Intl.NumberFormat('en-PH', { maximumFractionDigits: 0 });
export const formatPeso = (amount: number) => `₱${pesoFormat.format(amount)}`;

export type MoneyEntry = {
  id: string;
  type: MoneyType;
  amount: number;
  category: string;
  note: string;
  author: string;
  createdAt: Date;
};

export type BudgetLimit = { category: string; amount: number };

export type MonthlyTotal = { income: number; expense: number; balance: number };

function parseAmount(v: unknown): number {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return Number.parseFloat(v) || 0;
  return 0;
}

function parseTimestamp(v: unknown): Date {
  if (v instanceof Timestamp) return v.toDate();
  if (typeof v === 'number') return new Date(v);
  if (typeof v === 'string') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? new Date() : d;
  }
  return new Date();
}

function entryFromMap(data: DocumentData, id: string): MoneyEntry {
  return {
    id,
    type: String(data.type ?? '').toLowerCase() === 'income' ? 'income' : 'expense',
    amount: parseAmount(data.amount),
    category: data.category != null ? String(data.category) : 'Other',
    note: data.note != null ? String(data.note) : '',
    author: data.author != null ? String(data.author) : '',
    createdAt: parseTimestamp(data.createdAt),
  };
}

const sameMonth = (d: Date, month: Date) => d.getFullYear() === month.getFullYear() && d.getMonth() === month.getMonth();

export function summarizeMonth(entries: MoneyEntry[], month: Date): MonthlyTotal {
  let income = 0;
  let expense = 0;
  for (const e of entries) {
    if (!sameMonth(e.createdAt, month)) continue;
    if (e.type === 'income') income += e.amount;
    else expense += e.amount;
  }
  return { income, expense, balance: income - expense };
}

export function spentByCategory(entries: MoneyEntry[], month: Date): Record<string, number> {
  const out: Record<string, number> = {};
  for (const e of entries) {
    if (e.type !== 'expense' || !sameMonth(e.createdAt, month)) continue;
    out[e.category] = (out[e.category] ?? 0) + e.amount;
  }
  return out;
}

const monthKey = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;

function demoMoney(month: Date): MoneyEntry[] {
  return [
    {
      id: 'demo_income',
      type: 'income',
      amount: 2000,
      category: 'Allowance',
      note: '',
      author: 'khentsgdz',
      createdAt: new Date(month.getFullYear(), month.getMonth(), 1),
    },
    {
      id: 'demo_expense',
      type: 'expense',
      amount: 250,
      category: 'Dates',
      note: 'Fictional coffee date',
      author: 'clairjassen',
      createdAt: new Date(month.getFullYear(), month.getMonth(), 2),
    },
  ];
}

const demoBudgets: BudgetLimit[] = [{ category: 'Dates', amount: 1000 }];

class MoneyService {
  watchMonth(month: Date): Source<MoneyEntry[]> {
    if (AgentMode.demo) return just(demoMoney(month));
    const subscribe: Source<MoneyEntry[]> = (l) => {
      const MAX_MONTH_LIMIT = 1600;
      let active = true;
      let limit = 200;
      let unsub = () => {};
      const listen = () => {
        if (!active) return;
        const q = query(
          collection(db, 'budget_transactions'),
          where('createdAt', '>=', Timestamp.fromDate(new Date(month.getFullYear(), month.getMonth()))),
          where('createdAt', '<', Timestamp.fromDate(new Date(month.getFullYear(), month.getMonth() + 1))),
          orderBy('createdAt', 'desc'),
          qLimit(limit),
        );
        unsub = onSnapshot(
          q,
          (snap) => {
            if (!active) return;
            if (snap.docs.length === limit && limit < MAX_MONTH_LIMIT) {
              limit = Math.min(limit * 2, MAX_MONTH_LIMIT);
              unsub();
              listen();
              return;
            }
            const out: MoneyEntry[] = [];
            for (const d of snap.docs) {
              try {
                out.push(entryFromMap(d.data(), d.id));
              } catch (e) {
                Logger.e(`Money: skipping malformed entry ${d.id}`, e);
              }
            }
            l.data(out);
          },
          (e) => {
            if (active) l.error?.(e);
          },
        );
      };
      listen();
      return () => {
        active = false;
        unsub();
      };
    };
    return withFirestoreTimeout(subscribe, { label: 'money-recent', maxAttempts: 3, resubscribe: () => subscribe });
  }

  watchLimits(): Source<BudgetLimit[]> {
    if (AgentMode.demo) return just(demoBudgets);
    const src: Source<BudgetLimit[]> = (l) =>
      onSnapshot(
        query(collection(db, 'budget_limits'), qLimit(30)),
        (snap) =>
          l.data(
            snap.docs.map((d) => {
              const data = d.data();
              const amount = data.amount;
              return {
                category: data.category != null ? String(data.category) : d.id,
                amount: typeof amount === 'number' ? amount : Number.parseFloat(String(amount ?? '')) || 0,
              };
            }),
          ),
        (e) => l.error?.(e),
      );
    return withFirestoreTimeout(src, { label: 'money-limits' });
  }

  async add(entry: Omit<MoneyEntry, 'id' | 'createdAt'>): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await addDoc(collection(db, 'budget_transactions'), {
        type: entry.type,
        amount: entry.amount,
        category: entry.category,
        note: entry.note,
        author: entry.author.toLowerCase(),
        createdAt: serverTimestamp(),
        monthKey: monthKey(new Date()),
      });
      Logger.i(`Money added: ${entry.type} ${entry.amount}`);
    } catch (e) {
      Logger.e('Error adding money entry', e);
      throw e;
    }
  }

  async delete(id: string): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await deleteDoc(doc(db, 'budget_transactions', id));
      Logger.i(`Money deleted: ${id}`);
    } catch (e) {
      Logger.e('Error deleting money entry', e);
      throw e;
    }
  }

  async setLimit(category: string, amount: number): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await setDoc(doc(db, 'budget_limits', category), { category, amount, updatedAt: serverTimestamp() });
      Logger.i(`Money budget set: ${category} -> ${amount}`);
    } catch (e) {
      Logger.e('Error setting budget limit', e);
      throw e;
    }
  }

  async removeLimit(category: string): Promise<void> {
    if (AgentMode.demo) return;
    try {
      await deleteDoc(doc(db, 'budget_limits', category));
      Logger.i(`Money budget removed: ${category}`);
    } catch (e) {
      Logger.e('Error removing budget limit', e);
      throw e;
    }
  }
}

export const moneyService = new MoneyService();
