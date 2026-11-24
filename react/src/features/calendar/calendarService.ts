// Port of lib/features/calendar/data/services/calendar_service.dart, calendar_poll_service.dart,
// data/models/date_poll.dart, domain/models/calendar_event.dart and widgets/calendar_event_style.dart.
import {
  addDoc,
  and,
  collection,
  deleteDoc,
  deleteField,
  doc,
  limit,
  onSnapshot,
  or,
  orderBy,
  query,
  runTransaction,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
  type DocumentData,
  type DocumentSnapshot,
  type QuerySnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type CalendarEventFixture, type CalendarEventType } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { AppColors } from '../../core/theme/colors';
import { Logger } from '../../core/system/logger';
import { Changes, just, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type { CalendarEventType };

export type CalendarEvent = CalendarEventFixture & {
  endDate?: Date;
  location?: string;
  attendees?: string[];
  isAllDay?: boolean;
  bucketItemId?: string;
  color?: string | null;
};

export type PollOption = { id: string; date: Date; label: string };

export type DatePoll = {
  id: string;
  title: string;
  description: string;
  createdBy: string;
  createdAt: Date;
  status: 'open' | 'closed';
  options: PollOption[];
  votes: Record<string, string>;
  decidedOptionId?: string;
};

export const CALENDAR_EVENT_TYPES: CalendarEventType[] = ['dateNight', 'anniversary', 'reminder', 'custom'];

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

/** calendarEventTypeInfo. */
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

/** DatePoll.tally. */
export function pollTally(poll: DatePoll): Record<string, number> {
  const m: Record<string, number> = {};
  for (const v of Object.values(poll.votes)) m[v] = (m[v] ?? 0) + 1;
  return m;
}

/** DatePoll.winningOptionId: the most votes, the later entry on a tie (Dart's reduce with >=). */
export function pollWinningOptionId(poll: DatePoll): string | undefined {
  const entries = Object.entries(pollTally(poll));
  if (entries.length === 0) return undefined;
  return entries.reduce((a, b) => (a[1] >= b[1] ? a : b))[0];
}

function parseType(v: unknown): CalendarEventType {
  if (v === 'dateNight' || v === 'anniversary' || v === 'reminder' || v === 'custom') return v;
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

/** CalendarEvent.occurrencesBetween: a repeat lands on the same day, clamped to the month's last day. */
export function occurrencesBetween(ev: CalendarEvent, start: Date, end: Date): CalendarEvent[] {
  if (end <= start) return [];
  if (ev.recurring !== 'monthly' && ev.recurring !== 'yearly') {
    return ev.date >= start && ev.date < end ? [ev] : [];
  }
  const date = ev.date;
  const out: CalendarEvent[] = [];
  let year = start.getFullYear() < date.getFullYear() ? date.getFullYear() : start.getFullYear();
  let month = ev.recurring === 'yearly' ? date.getMonth() : start < date ? date.getMonth() : start.getMonth();
  while (new Date(year, month, 1) < end) {
    const lastDay = new Date(year, month + 1, 0).getDate();
    const occ = new Date(
      year,
      month,
      Math.min(date.getDate(), lastDay),
      date.getHours(),
      date.getMinutes(),
      date.getSeconds(),
      date.getMilliseconds(),
    );
    if (occ >= date && occ >= start && occ < end) {
      out.push({
        ...ev,
        date: occ,
        endDate: ev.endDate ? new Date(occ.getTime() + (ev.endDate.getTime() - date.getTime())) : undefined,
      });
    }
    if (ev.recurring === 'yearly') year++;
    else if (month === 11) {
      month = 0;
      year++;
    } else month++;
  }
  return out;
}

function mapEvent(d: DocumentSnapshot<DocumentData>): CalendarEvent {
  const data = d.data() ?? {};
  return {
    id: d.id,
    bucketItemId: typeof data.bucketItemId === 'string' ? data.bucketItemId : undefined,
    title: String(data.title ?? ''),
    description: String(data.description ?? ''),
    date: parseTs(data.date),
    endDate: data.endDate != null ? parseTs(data.endDate) : undefined,
    type: parseType(data.type),
    createdBy: String(data.createdBy ?? ''),
    color: typeof data.color === 'string' ? data.color : null,
    recurring: typeof data.recurring === 'string' ? data.recurring : 'none',
    location: typeof data.location === 'string' ? data.location : undefined,
    attendees: Array.isArray(data.attendees) ? data.attendees.map(String) : [],
    isAllDay: data.isAllDay === true,
  };
}

/** CalendarEvent.toFirestore. */
function eventPayload(ev: Omit<CalendarEvent, 'id'>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  if (ev.bucketItemId != null) out.bucketItemId = ev.bucketItemId;
  out.title = ev.title;
  out.description = ev.description;
  out.date = Timestamp.fromDate(ev.date);
  if (ev.endDate) out.endDate = Timestamp.fromDate(ev.endDate);
  out.type = ev.type;
  out.createdBy = ev.createdBy;
  out.color = ev.color ?? null;
  out.recurring = ev.recurring ?? 'none';
  if (ev.location) out.location = ev.location;
  out.attendees = ev.attendees ?? [];
  out.isAllDay = ev.isAllDay ?? false;
  return out;
}

function expand(snap: QuerySnapshot<DocumentData>, start: Date, end: Date): CalendarEvent[] {
  const out: CalendarEvent[] = [];
  for (const d of snap.docs) out.push(...occurrencesBetween(mapEvent(d), start, end));
  return out.sort((a, b) => a.date.getTime() - b.date.getTime());
}

function eventsQuery(start: Date, end: Date) {
  return query(
    collection(db, 'calendar_events'),
    or(
      and(where('date', '>=', Timestamp.fromDate(start)), where('date', '<', Timestamp.fromDate(end))),
      where('recurring', 'in', ['monthly', 'yearly']),
    ),
    orderBy('date'),
    limit(100),
  );
}

class CalendarService {
  cachedUpcoming: CalendarEvent[] | null = null;
  // Flutter's agent mode streams the fixtures and ignores writes; React keeps writes in memory so demos react.
  private demoEvents: CalendarEvent[] | null = null;
  private demoChanges = new Changes(() => [...this.ensureDemo()]);

  private ensureDemo(): CalendarEvent[] {
    if (!this.demoEvents) this.demoEvents = AgentFixtures.demoEvents().map((e) => ({ ...e }));
    return this.demoEvents;
  }

  watchEvent(id: string): Source<CalendarEvent | null> {
    if (AgentMode.isActive.value) return just(this.ensureDemo().find((e) => e.id === id) ?? null);
    return snapshots<DocumentSnapshot<DocumentData>, CalendarEvent | null>(
      (next, error) => onSnapshot(doc(db, 'calendar_events', id), next, error),
      (d) => (d.exists() ? mapEvent(d) : null),
    );
  }

  getEventsForMonth(month: Date): Source<CalendarEvent[]> {
    if (AgentMode.demo) return this.demoChanges.source;
    const start = new Date(month.getFullYear(), month.getMonth(), 1);
    const end = new Date(month.getFullYear(), month.getMonth() + 1, 1);
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, CalendarEvent[]>(
        (next, error) => onSnapshot(eventsQuery(start, end), next, error),
        (s) => expand(s, start, end),
      ),
      { label: 'calendar-month' },
    );
  }

  getUpcomingEvents(days = 30): Source<CalendarEvent[]> {
    if (AgentMode.demo) return this.demoChanges.source;
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(now.getTime() + days * 86_400_000);
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, CalendarEvent[]>(
        (next, error) => onSnapshot(eventsQuery(start, end), next, error),
        (s) => {
          const list = expand(s, start, end)
            .filter((e) => e.isAllDay || e.date >= now)
            .slice(0, 20);
          this.cachedUpcoming = list;
          return list;
        },
      ),
      { label: 'calendar-upcoming', maxAttempts: 3 },
    );
  }

  /** A wish plan gets the id `bucket_<wishId>` and marks the wish planned in the same transaction. */
  async addEvent(ev: Omit<CalendarEvent, 'id'>): Promise<void> {
    if (AgentMode.demo) {
      this.demoEvents = [...this.ensureDemo(), { ...ev, id: `demo_ev_${Date.now()}` }];
      this.demoChanges.emit();
      return;
    }
    try {
      if (ev.bucketItemId == null) {
        await addDoc(collection(db, 'calendar_events'), eventPayload(ev));
      } else {
        const bucket = doc(db, 'bucket_list', ev.bucketItemId);
        const eventRef = doc(db, 'calendar_events', `bucket_${ev.bucketItemId}`);
        await runTransaction(db, async (tx) => {
          const wish = await tx.get(bucket);
          const existing = await tx.get(eventRef);
          if (!wish.exists()) throw new Error('This wish no longer exists');
          if (existing.exists()) throw new Error('This wish already has a calendar plan');
          tx.set(eventRef, eventPayload(ev));
          tx.update(bucket, { calendarEventId: eventRef.id, status: 'planned', dueDate: Timestamp.fromDate(ev.date) });
        });
      }
    } catch (e) {
      Logger.e('Error adding calendar event', e);
      throw e;
    }
  }

  async updateEvent(id: string, data: Record<string, unknown>): Promise<void> {
    if (AgentMode.demo) {
      this.demoEvents = this.ensureDemo().map((e) => (e.id === id ? { ...e, ...data } : e));
      this.demoChanges.emit();
      return;
    }
    try {
      await updateDoc(doc(db, 'calendar_events', id), data);
    } catch (e) {
      Logger.e('Error updating calendar event', e);
      throw e;
    }
  }

  async deleteEvent(id: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoEvents = this.ensureDemo().filter((e) => e.id !== id);
      this.demoChanges.emit();
      return;
    }
    try {
      await deleteDoc(doc(db, 'calendar_events', id));
    } catch (e) {
      Logger.e('Error deleting calendar event', e);
      throw e;
    }
  }
}

function mapPoll(d: DocumentSnapshot<DocumentData>): DatePoll {
  const data = d.data() ?? {};
  const str = (v: unknown) => (typeof v === 'string' ? v : '');
  const votes: Record<string, string> = {};
  if (data.votes && typeof data.votes === 'object') {
    for (const [k, v] of Object.entries(data.votes as Record<string, unknown>)) if (typeof v === 'string') votes[k] = v;
  }
  const rawOpts: unknown[] = Array.isArray(data.options) ? data.options : [];
  return {
    id: d.id,
    title: str(data.title),
    description: str(data.description),
    createdBy: str(data.createdBy),
    createdAt: parseTs(data.createdAt),
    status: data.status === 'closed' ? 'closed' : 'open',
    options: rawOpts
      .filter((o): o is Record<string, unknown> => !!o && typeof o === 'object')
      .map((o) => ({ id: str(o.id), date: parseTs(o.date), label: str(o.label) })),
    votes,
    decidedOptionId: typeof data.decidedOptionId === 'string' ? data.decidedOptionId : undefined,
  };
}

const POLLS = 'calendar_polls';

class CalendarPollService {
  // Flutter has no agent-mode polls (it queries Firestore and shows the error state); React shows one demo poll.
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

  private demoUpdate(id: string, fn: (p: DatePoll) => DatePoll) {
    this.demoPolls = this.demoPolls.map((p) => (p.id === id ? fn(p) : p));
    this.demoChanges.emit();
  }

  watchAll(): Source<DatePoll[]> {
    if (AgentMode.demo) return this.demoChanges.source;
    const q = query(collection(db, POLLS), orderBy('createdAt', 'desc'), limit(50));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, DatePoll[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) => s.docs.map(mapPoll),
      ),
      { label: 'polls-all' },
    );
  }

  async create(poll: Omit<DatePoll, 'id'>): Promise<void> {
    if (AgentMode.demo) {
      this.demoPolls = [{ ...poll, id: `demo_poll_${Date.now()}` }, ...this.demoPolls];
      this.demoChanges.emit();
      return;
    }
    try {
      const payload: Record<string, unknown> = {
        title: poll.title,
        description: poll.description,
        createdBy: poll.createdBy,
        createdAt: Timestamp.fromDate(poll.createdAt),
        options: poll.options.map((o) => ({ id: o.id, date: Timestamp.fromDate(o.date), label: o.label })),
        votes: poll.votes,
        status: poll.status,
      };
      if (poll.decidedOptionId != null) payload.decidedOptionId = poll.decidedOptionId;
      await addDoc(collection(db, POLLS), payload);
    } catch (e) {
      Logger.e('Error creating poll', e);
      throw e;
    }
  }

  async vote(pollId: string, username: string, optionId: string): Promise<void> {
    if (AgentMode.demo) return this.demoUpdate(pollId, (p) => ({ ...p, votes: { ...p.votes, [username]: optionId } }));
    try {
      await updateDoc(doc(db, POLLS, pollId), { [`votes.${username}`]: optionId });
    } catch (e) {
      Logger.e('Error voting', e);
    }
  }

  /** Closes the poll and writes the plan as `poll_<pollId>` in one batch. */
  async finalize(pollId: string, winning: string, event: Omit<CalendarEvent, 'id'>): Promise<void> {
    if (AgentMode.demo) {
      this.demoUpdate(pollId, (p) => ({ ...p, status: 'closed', decidedOptionId: winning }));
      await calendarService.addEvent(event);
      return;
    }
    try {
      const batch = writeBatch(db);
      batch.set(doc(db, 'calendar_events', `poll_${pollId}`), eventPayload(event));
      batch.update(doc(db, POLLS, pollId), { status: 'closed', decidedOptionId: winning });
      await batch.commit();
    } catch (e) {
      Logger.e('Error finalizing calendar poll', e);
      throw e;
    }
  }

  async reopen(pollId: string): Promise<void> {
    if (AgentMode.demo) return this.demoUpdate(pollId, (p) => ({ ...p, status: 'open', decidedOptionId: undefined }));
    try {
      await updateDoc(doc(db, POLLS, pollId), { status: 'open', decidedOptionId: deleteField() });
    } catch (e) {
      Logger.e('Error reopening poll', e);
    }
  }

  async delete(pollId: string): Promise<void> {
    if (AgentMode.demo) {
      this.demoPolls = this.demoPolls.filter((p) => p.id !== pollId);
      this.demoChanges.emit();
      return;
    }
    try {
      await deleteDoc(doc(db, POLLS, pollId));
    } catch (e) {
      Logger.e('Error deleting poll', e);
    }
  }
}

export const calendarService = new CalendarService();
if (typeof window !== 'undefined') {
  window.addEventListener('everglow:logout', () => {
    calendarService.cachedUpcoming = null;
  });
}
export const calendarPollService = new CalendarPollService();
export { just };
