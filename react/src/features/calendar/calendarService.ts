// Port of lib/features/calendar/data/services/calendar_service.dart + calendar_poll_service.dart + styles.
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  limit,
  onSnapshot,
  or,
  and,
  orderBy,
  query,
  runTransaction,
  Timestamp,
  updateDoc,
  where,
  type DocumentData,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type CalendarEventFixture, type CalendarEventType } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { AppColors } from '../../core/theme/colors';
import { Changes, just, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type CalendarEvent = CalendarEventFixture & {
  endDate?: Date;
  location?: string;
  attendees?: string[];
  isAllDay?: boolean;
  bucketItemId?: string;
};

export type PollOption = {
  id: string;
  date: Date;
  label: string;
};

export type DatePoll = {
  id: string;
  title: string;
  description: string;
  createdBy: string;
  createdAt: Date;
  status: 'open' | 'closed';
  options: PollOption[];
  votes: Record<string, string>;
  winningOptionId?: string;
};

export function calendarEventHue(type: CalendarEventType): string {
  switch (type) {
    case 'dateNight':
      return AppColors.auroraRose;
    case 'anniversary':
      return AppColors.blushGold;
    case 'reminder':
      return AppColors.auroraLilac;
    case 'custom':
      return AppColors.softLavender;
  }
}

export const CALENDAR_TYPE_INFO: Record<CalendarEventType, { emoji: string; label: string }> = {
  dateNight: { emoji: '💑', label: 'Date Night' },
  anniversary: { emoji: '💍', label: 'Anniversary' },
  reminder: { emoji: '⏰', label: 'Reminder' },
  custom: { emoji: '📌', label: 'Custom' },
};

export const CALENDAR_TYPE_EMOJI: Record<CalendarEventType, string> = {
  dateNight: '💕',
  anniversary: '🎉',
  reminder: '🔔',
  custom: '📌',
};

function parseType(v: unknown): CalendarEventType {
  if (v === 'dateNight' || v === 'anniversary' || v === 'reminder') return v;
  return 'custom';
}

function parseTs(v: unknown): Date {
  if (v && typeof (v as Timestamp).toDate === 'function') return (v as Timestamp).toDate();
  if (typeof v === 'number') return new Date(v);
  if (typeof v === 'string') {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return new Date();
}

function expandOccurrences(ev: CalendarEvent, start: Date, end: Date): CalendarEvent[] {
  if (ev.recurring !== 'monthly' && ev.recurring !== 'yearly') {
    return ev.date >= start && ev.date < end ? [ev] : [];
  }
  const out: CalendarEvent[] = [];
  const cursor = new Date(ev.date);
  for (let i = 0; i < 64 && cursor < end; i++) {
    if (cursor >= start) out.push({ ...ev, date: new Date(cursor) });
    if (ev.recurring === 'monthly') cursor.setMonth(cursor.getMonth() + 1);
    else if (ev.recurring === 'yearly') cursor.setFullYear(cursor.getFullYear() + 1);
    else break;
  }
  return out;
}

function mapSnapshot(snap: QuerySnapshot<DocumentData>, start: Date, end: Date): CalendarEvent[] {
  const out: CalendarEvent[] = [];
  for (const d of snap.docs) {
    const data = d.data();
    const ev: CalendarEvent = {
      id: d.id,
      bucketItemId: typeof data.bucketItemId === 'string' ? data.bucketItemId : undefined,
      title: String(data.title ?? ''),
      description: String(data.description ?? ''),
      date: parseTs(data.date),
      endDate: data.endDate != null ? parseTs(data.endDate) : undefined,
      type: parseType(data.type),
      createdBy: String(data.createdBy ?? ''),
      recurring: typeof data.recurring === 'string' ? data.recurring : undefined,
      location: typeof data.location === 'string' ? data.location : undefined,
      attendees: Array.isArray(data.attendees) ? data.attendees.map(String) : undefined,
      isAllDay: Boolean(data.isAllDay),
    };
    out.push(...expandOccurrences(ev, start, end));
  }
  return out.sort((a, b) => a.date.getTime() - b.date.getTime());
}

class CalendarService {
  cachedUpcoming: CalendarEvent[] | null = null;
  private demoEvents: CalendarEvent[] | null = null;
  private demoChanges = new Changes(() => [...this.ensureDemo()]);

  private ensureDemo(): CalendarEvent[] {
    if (!this.demoEvents) {
      this.demoEvents = AgentFixtures.demoEvents().map((e) => ({ ...e }));
    }
    return this.demoEvents;
  }

  getEventsForMonth(month: Date): Source<CalendarEvent[]> {
    if (AgentMode.demo) {
      return this.demoChanges.source;
    }
    const start = new Date(month.getFullYear(), month.getMonth(), 1);
    const end = new Date(month.getFullYear(), month.getMonth() + 1, 1);
    const q = query(
      collection(db, 'calendar_events'),
      or(
        and(where('date', '>=', Timestamp.fromDate(start)), where('date', '<', Timestamp.fromDate(end))),
        where('recurring', 'in', ['monthly', 'yearly']),
      ),
      orderBy('date'),
      limit(100),
    );
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, CalendarEvent[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) => mapSnapshot(s, start, end),
      ),
      { label: 'calendar-month' },
    );
  }

  getUpcomingEvents(days = 30): Source<CalendarEvent[]> {
    if (AgentMode.demo) return this.demoChanges.source;
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(start.getTime() + days * 86_400_000);
    const q = query(
      collection(db, 'calendar_events'),
      or(
        and(where('date', '>=', Timestamp.fromDate(start)), where('date', '<', Timestamp.fromDate(end))),
        where('recurring', 'in', ['monthly', 'yearly']),
      ),
      orderBy('date'),
      limit(100),
    );
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, CalendarEvent[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) => {
          const list = mapSnapshot(s, start, end).filter((e) => e.isAllDay || e.date >= now).slice(0, 20);
          this.cachedUpcoming = list;
          return list;
        },
      ),
      { label: 'calendar-upcoming' },
    );
  }

  async addEvent(ev: Omit<CalendarEvent, 'id'>): Promise<void> {
    if (AgentMode.demo) {
      this.demoEvents = [...this.ensureDemo(), { ...ev, id: `demo_ev_${Date.now()}` }].sort(
        (a, b) => a.date.getTime() - b.date.getTime(),
      );
      this.demoChanges.emit();
      return;
    }
    const payload: Record<string, unknown> = {
      title: ev.title,
      description: ev.description,
      date: Timestamp.fromDate(ev.date),
      type: ev.type,
      createdBy: ev.createdBy,
      recurring: ev.recurring ?? 'none',
      attendees: ev.attendees ?? [],
      isAllDay: ev.isAllDay ?? false,
    };
    if (ev.endDate) payload.endDate = Timestamp.fromDate(ev.endDate);
    if (ev.location) payload.location = ev.location;
    if (ev.bucketItemId) payload.bucketItemId = ev.bucketItemId;
    await addDoc(collection(db, 'calendar_events'), payload);
  }

  async updateEvent(id: string, data: Partial<CalendarEvent>): Promise<void> {
    if (AgentMode.demo) {
      this.demoEvents = this.ensureDemo().map((e) => (e.id === id ? { ...e, ...data } : e));
      this.demoChanges.emit();
      return;
    }
    const payload: Record<string, unknown> = { ...data };
    if (data.date instanceof Date) payload.date = Timestamp.fromDate(data.date);
    if (data.endDate instanceof Date) payload.endDate = Timestamp.fromDate(data.endDate);
    await updateDoc(doc(db, 'calendar_events', id), payload);
  }

  async deleteEvent(id: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoEvents = this.ensureDemo().filter((e) => e.id !== id);
      this.demoChanges.emit();
      return;
    }
    await deleteDoc(doc(db, 'calendar_events', id));
  }
}

class CalendarPollService {
  private demoPolls: DatePoll[] = [
    {
      id: 'demo_poll_1',
      title: 'Weekend Anniversary Dinner',
      description: 'Which evening works best for both of us?',
      createdBy: 'khentsgdz',
      createdAt: new Date(Date.now() - 86_400_000),
      status: 'open',
      options: [
        { id: 'opt_1', date: new Date(Date.now() + 3 * 86_400_000), label: 'Friday 7:30 PM' },
        { id: 'opt_2', date: new Date(Date.now() + 4 * 86_400_000), label: 'Saturday 7:00 PM' },
      ],
      votes: { khentsgdz: 'opt_2' },
    },
  ];
  private demoChanges = new Changes(() => [...this.demoPolls]);

  watchAll(): Source<DatePoll[]> {
    if (AgentMode.demo) return this.demoChanges.source;
    const q = query(collection(db, 'date_polls'), orderBy('createdAt', 'desc'), limit(50));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, DatePoll[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) =>
          s.docs.map((d) => {
            const data = d.data();
            const rawOpts = Array.isArray(data.options) ? data.options : [];
            const rawVotes = (data.votes as Record<string, unknown>) ?? {};
            const votes: Record<string, string> = {};
            for (const [k, v] of Object.entries(rawVotes)) {
              if (typeof v === 'string') votes[k] = v;
            }
            return {
              id: d.id,
              title: String(data.title ?? ''),
              description: String(data.description ?? ''),
              createdBy: String(data.createdBy ?? ''),
              createdAt: parseTs(data.createdAt),
              status: data.status === 'closed' ? 'closed' : 'open',
              options: rawOpts.map((o: Record<string, unknown>, i: number) => ({
                id: String(o.id ?? `opt_${i}`),
                date: parseTs(o.date),
                label: String(o.label ?? ''),
              })),
              votes,
              winningOptionId: typeof data.winningOptionId === 'string' ? data.winningOptionId : undefined,
            };
          }),
      ),
      { label: 'calendar-polls' },
    );
  }

  async create(poll: Omit<DatePoll, 'id'>): Promise<void> {
    if (AgentMode.demo) {
      this.demoPolls = [{ ...poll, id: `demo_poll_${Date.now()}` }, ...this.demoPolls];
      this.demoChanges.emit();
      return;
    }
    await addDoc(collection(db, 'date_polls'), {
      title: poll.title,
      description: poll.description,
      createdBy: poll.createdBy,
      createdAt: Timestamp.fromDate(poll.createdAt),
      status: poll.status,
      options: poll.options.map((o) => ({ id: o.id, date: Timestamp.fromDate(o.date), label: o.label })),
      votes: poll.votes,
    });
  }

  async vote(pollId: string, username: string, optionId: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoPolls = this.demoPolls.map((p) =>
        p.id === pollId ? { ...p, votes: { ...p.votes, [username]: optionId } } : p,
      );
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'date_polls', pollId), { [`votes.${username}`]: optionId });
  }

  async finalize(pollId: string, winningOptionId: string, event: Omit<CalendarEvent, 'id'>): Promise<void> {
    if (AgentMode.demo) {
      this.demoPolls = this.demoPolls.map((p) =>
        p.id === pollId ? { ...p, status: 'closed', winningOptionId } : p,
      );
      this.demoChanges.emit();
      await calendarService.addEvent(event);
      return;
    }
    const pollRef = doc(db, 'date_polls', pollId);
    const eventRef = doc(collection(db, 'calendar_events'));
    await runTransaction(db, async (tx) => {
      tx.update(pollRef, { status: 'closed', winningOptionId });
      tx.set(eventRef, {
        title: event.title,
        description: event.description,
        date: Timestamp.fromDate(event.date),
        type: event.type,
        createdBy: event.createdBy,
        recurring: 'none',
        attendees: event.attendees ?? [],
        isAllDay: false,
      });
    });
  }

  async reopen(pollId: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoPolls = this.demoPolls.map((p) =>
        p.id === pollId ? { ...p, status: 'open', winningOptionId: undefined } : p,
      );
      this.demoChanges.emit();
      return;
    }
    await updateDoc(doc(db, 'date_polls', pollId), { status: 'open', winningOptionId: null });
  }

  async delete(pollId: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoPolls = this.demoPolls.filter((p) => p.id !== pollId);
      this.demoChanges.emit();
      return;
    }
    await deleteDoc(doc(db, 'date_polls', pollId));
  }
}

export const calendarService = new CalendarService();
export const calendarPollService = new CalendarPollService();
export { just };
