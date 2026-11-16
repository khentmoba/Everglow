// Port of lib/features/tonight/data/services/tonight_service.dart + models.
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
  type DocumentData,
  type DocumentSnapshot,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import {
  AgentFixtures,
  type CalendarEventFixture,
  type TonightDecisionFixture,
  type TonightOptionFixture,
  type TonightOptionType,
  type TonightStatus,
} from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type EveningEnergy = 'quiet' | 'playful' | 'adventurous';
export type TonightPreferences = {
  minutes: number | null;
  goingOut: boolean;
  energy: EveningEnergy;
};

export type TonightOption = TonightOptionFixture & { imageUrl?: string };
export type TonightDecision = TonightDecisionFixture & {
  preferences?: TonightPreferences;
  calendarEventId?: string;
};

export function winningOption(d: TonightDecision): TonightOption | null {
  if (!d.winnerOptionId) return null;
  return d.options.find((o) => o.id === d.winnerOptionId) ?? null;
}

export function isMatch(d: TonightDecision): boolean {
  const k = d.votes.khentsgdz;
  const c = d.votes.clairjassen;
  return k != null && c != null && k === c;
}

export function isTied(d: TonightDecision): boolean {
  const k = d.votes.khentsgdz;
  const c = d.votes.clairjassen;
  return k != null && c != null && k !== c;
}

const AVAILABLE_GAMES: TonightOption[] = [
  {
    id: 'game_scribble',
    type: 'game',
    title: 'Draw & Guess Together',
    subtitle: 'Play Zone Arcade',
    description: 'One draws, one guesses! Real-time canvas with secret words.',
    targetRoute: '/play-zone/scribble',
  },
  {
    id: 'game_table_tennis',
    type: 'game',
    title: 'Table Tennis Showdown',
    subtitle: 'Play Zone Arcade',
    description: 'Fast 1v1 rally battle or solo tournament bracket.',
    targetRoute: '/play-zone/tt',
  },
  {
    id: 'game_chess',
    type: 'game',
    title: 'Couple Chess',
    subtitle: 'Play Zone Classic',
    description: 'Cozy chess board for two with quiet, loving turns.',
    targetRoute: '/play-zone/chess',
  },
];

const QUIET_OPTIONS: TonightOption[] = [
  {
    id: 'quiet_chat',
    type: 'date',
    title: 'Tea and a little catch-up',
    subtitle: '20 minutes / Stay in',
    description: 'Make something warm and share the best part of your day.',
    targetRoute: '/sanctuary',
  },
  {
    id: 'quiet_draw',
    type: 'game',
    title: 'Draw a tiny memory together',
    subtitle: '20 minutes / Stay in',
    description: 'Take turns adding something to your shared canvas.',
    targetRoute: '/canvas',
  },
  {
    id: 'quiet_music',
    type: 'date',
    title: 'Trade three favorite songs',
    subtitle: '20 minutes / Stay in',
    description: 'Play a few songs and tell each other why you chose them.',
    targetRoute: '/jukebox',
  },
];

const FALLBACK_DATE_IDEAS = [
  'Cook homemade pasta together by candlelight',
  'Blanket fort movie marathon with warm popcorn',
  'Late night dessert run and sweet car talk',
  'Stargazing on the roof with our favorite songs',
  'Bake cookies together from scratch',
  'Cozy tea talk sharing our top 5 favorite memories',
];

function localSuggestions(prefs: TonightPreferences): TonightOption[] {
  if (prefs.goingOut) {
    const adventurous = prefs.energy === 'adventurous';
    return [
      {
        id: 'out_walk',
        type: 'date',
        title: adventurous ? 'Take a new route together' : 'A gentle evening walk',
        subtitle: '20 minutes / Go out',
        description: 'Choose somewhere nearby and enjoy a little time outside.',
        targetRoute: '/calendar',
      },
      {
        id: 'out_treat',
        type: 'date',
        title: 'Share a nearby treat',
        subtitle: '30 minutes / Go out',
        description: 'Pick a nearby spot for a snack or a drink.',
        targetRoute: '/calendar',
      },
      {
        id: 'out_photo',
        type: 'date',
        title: adventurous ? 'A little photo scavenger hunt' : 'Find a quiet spot to sit',
        subtitle: '20 minutes / Go out',
        description: 'Keep it nearby, with no big plan needed.',
        targetRoute: '/calendar',
      },
    ];
  }
  if (prefs.energy === 'quiet') return QUIET_OPTIONS;
  return [AVAILABLE_GAMES[0], AVAILABLE_GAMES[1], AVAILABLE_GAMES[2]];
}

function parseDate(v: unknown): Date | undefined {
  if (!v) return undefined;
  if (typeof (v as Timestamp).toDate === 'function') return (v as Timestamp).toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'string') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? undefined : d;
  }
  if (typeof v === 'number') return new Date(v);
  return undefined;
}

function parseStatus(v: unknown): TonightStatus {
  if (v === 'decided' || v === 'planned') return v;
  return 'voting';
}

function parseOptionType(v: unknown): TonightOptionType {
  if (v === 'date' || v === 'game') return v;
  return 'movie';
}

function parsePrefs(v: unknown): TonightPreferences {
  const p = v && typeof v === 'object' ? (v as Record<string, unknown>) : {};
  const mins = typeof p.minutes === 'number' && [30, 45, 90, 180].includes(p.minutes) ? p.minutes : null;
  const energy =
    p.energy === 'playful' || p.energy === 'adventurous' ? p.energy : 'quiet';
  return {
    minutes: mins,
    goingOut: p.goingOut === true,
    energy,
  };
}

function fromMap(data: Record<string, unknown>, id: string): TonightDecision {
  const rawOptions = Array.isArray(data.options) ? data.options : [];
  const options: TonightOption[] = rawOptions
    .filter((o): o is Record<string, unknown> => o != null && typeof o === 'object')
    .map((o) => ({
      id: String(o.id ?? ''),
      type: parseOptionType(o.type),
      title: String(o.title ?? ''),
      subtitle: String(o.subtitle ?? ''),
      description: String(o.description ?? ''),
      imageUrl: typeof o.imageUrl === 'string' ? o.imageUrl : undefined,
      targetRoute: typeof o.targetRoute === 'string' ? o.targetRoute : undefined,
    }));
  const votes: Record<string, string> = {};
  if (data.votes && typeof data.votes === 'object') {
    for (const [k, v] of Object.entries(data.votes as Record<string, unknown>)) {
      if (typeof v === 'string') votes[k] = v;
    }
  }
  return {
    id,
    status: parseStatus(data.status),
    preferences: parsePrefs(data.preferences),
    options,
    votes,
    winnerOptionId: typeof data.winnerOptionId === 'string' && data.winnerOptionId ? data.winnerOptionId : undefined,
    calendarEventId: typeof data.calendarEventId === 'string' ? data.calendarEventId : undefined,
    planTime: parseDate(data.planTime),
    createdAt: parseDate(data.createdAt) ?? new Date(),
    updatedAt: parseDate(data.updatedAt) ?? new Date(),
  };
}

export function activeTonightDocId(): string {
  const now = new Date();
  const y = String(now.getFullYear()).padStart(4, '0');
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `day_${y}${m}${d}`;
}

class TonightService {
  private demoDecision: TonightDecision | null = null;
  private demoChanges = new Changes(() => this.ensureDemo());

  private ensureDemo(): TonightDecision {
    if (!this.demoDecision) {
      this.demoDecision = AgentFixtures.demoDecision();
    }
    return this.demoDecision;
  }

  watchActiveDecision(): Source<TonightDecision | null> {
    if (AgentMode.demo) {
      this.ensureDemo();
      return this.demoChanges.source;
    }
    const ref = doc(db, 'tonight_decisions', activeTonightDocId());
    return withFirestoreTimeout(
      snapshots<DocumentSnapshot<DocumentData>, TonightDecision | null>(
        (next, error) => onSnapshot(ref, next, error),
        (s) => (s.exists() ? fromMap(s.data(), s.id) : null),
      ),
      { label: 'tonight-active' },
    );
  }

  private async fetchMovieSuggestion(maxMinutes: number | null): Promise<TonightOption> {
    try {
      const snap = await getDocs(
        query(collection(db, 'watch_list'), where('userName', 'in', ['khentsgdz', 'clairjassen']), limit(25)),
      );
      const movies = snap.docs.filter((d) => {
        const data = d.data();
        const mediaType = String(data.mediaType ?? 'movie').toLowerCase();
        const dur = data.durationSeconds;
        const tmdbId = Number(data.tmdbId);
        const fits = maxMinutes == null || (typeof dur === 'number' && dur > 0 && dur <= maxMinutes * 60);
        return mediaType === 'movie' && (data.source ?? 'tmdb') === 'tmdb' && tmdbId > 0 && fits;
      });
      if (movies.length > 0) {
        const picked = movies[Math.floor(Math.random() * movies.length)];
        const data = picked.data();
        const poster = typeof data.posterPath === 'string' && data.posterPath.startsWith('/') ? `https://image.tmdb.org/t/p/w500${data.posterPath}` : undefined;
        return {
          id: `opt_movie_${picked.id}`,
          type: 'movie',
          title: String(data.title ?? 'Watchlist Movie'),
          subtitle: 'From Cinema Watchlist',
          description: String(data.overview ?? data.synopsis ?? 'From your saved Cinema watchlist.'),
          imageUrl: poster,
          targetRoute: `/cinema/video/${data.tmdbId}?type=movie&title=${encodeURIComponent(String(data.title ?? ''))}`,
        };
      }
    } catch {
      // fall through
    }
    return QUIET_OPTIONS[0];
  }

  private async fetchDateIdeaSuggestion(): Promise<TonightOption> {
    try {
      const snap = await getDocs(query(collection(db, 'date_ideas'), limit(25)));
      if (!snap.empty) {
        const picked = snap.docs[Math.floor(Math.random() * snap.docs.length)];
        return {
          id: `opt_date_${picked.id}`,
          type: 'date',
          title: String(picked.data().title ?? 'Cozy Date Night'),
          subtitle: 'Saved Date Idea',
          description: 'A romantic, special idea to experience together tonight.',
          targetRoute: '/calendar',
        };
      }
    } catch {
      // fall through
    }
    const title = FALLBACK_DATE_IDEAS[Math.floor(Math.random() * FALLBACK_DATE_IDEAS.length)];
    return {
      id: `opt_date_fallback_${Date.now()}`,
      type: 'date',
      title,
      subtitle: 'Everglow Date Idea',
      description: 'A cozy, loving plan made for just the two of you.',
      targetRoute: '/calendar',
    };
  }

  private async generateSuggestions(prefs: TonightPreferences): Promise<TonightOption[]> {
    const local = localSuggestions(prefs);
    if (prefs.goingOut || (prefs.minutes != null && prefs.minutes < 90)) {
      return local;
    }
    const movie = await this.fetchMovieSuggestion(prefs.minutes);
    if (prefs.minutes == null && prefs.energy !== 'quiet') {
      return [movie, await this.fetchDateIdeaSuggestion(), local[2]];
    }
    return [movie, ...local.filter((o) => o.id !== movie.id).slice(0, 2)];
  }

  async createOrShuffle(prefs: TonightPreferences, force = false): Promise<void> {
    if (AgentMode.demo) {
      this.demoDecision = {
        id: activeTonightDocId(),
        status: 'voting',
        preferences: prefs,
        options: localSuggestions(prefs),
        votes: {},
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      this.demoChanges.emit();
      return;
    }
    const ref = doc(db, 'tonight_decisions', activeTonightDocId());
    if (!force) {
      const existing = await getDoc(ref);
      if (existing.exists() && fromMap(existing.data(), existing.id).status !== 'planned') {
        return;
      }
    }
    const options = await this.generateSuggestions(prefs);
    await setDoc(ref, {
      status: 'voting',
      preferences: prefs,
      options,
      votes: {},
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  async castVote(username: string, optionId: string): Promise<void> {
    if (AgentMode.demo) {
      const current = this.ensureDemo();
      const votes = { ...current.votes, [username]: optionId };
      const match = votes.khentsgdz != null && votes.khentsgdz === votes.clairjassen;
      this.demoDecision = {
        ...current,
        votes,
        status: match ? 'decided' : current.status,
        winnerOptionId: match ? optionId : current.winnerOptionId,
        updatedAt: new Date(),
      };
      this.demoChanges.emit();
      return;
    }
    const ref = doc(db, 'tonight_decisions', activeTonightDocId());
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists()) return;
      const current = fromMap(snap.data(), snap.id);
      if (current.status !== 'voting' || !current.options.some((o) => o.id === optionId)) return;
      const votes = { ...current.votes, [username]: optionId };
      const match = votes.khentsgdz != null && votes.khentsgdz === votes.clairjassen;
      tx.update(ref, {
        votes,
        status: match ? 'decided' : current.status,
        ...(match ? { winnerOptionId: optionId } : {}),
        updatedAt: serverTimestamp(),
      });
    });
  }

  async decideWinner(optionId: string): Promise<void> {
    if (AgentMode.demo) {
      const current = this.ensureDemo();
      this.demoDecision = { ...current, status: 'decided', winnerOptionId: optionId, updatedAt: new Date() };
      this.demoChanges.emit();
      return;
    }
    const ref = doc(db, 'tonight_decisions', activeTonightDocId());
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists()) return;
      const current = fromMap(snap.data(), snap.id);
      if (current.status !== 'voting') return;
      tx.update(ref, { winnerOptionId: optionId, status: 'decided', updatedAt: serverTimestamp() });
    });
  }

  async makePlan(option: TonightOption, planTime: Date, createdBy: string): Promise<CalendarEventFixture | null> {
    if (AgentMode.demo) {
      const current = this.ensureDemo();
      this.demoDecision = { ...current, status: 'planned', planTime, updatedAt: new Date() };
      this.demoChanges.emit();
      return {
        id: 'agent_event',
        title: `Plan: ${option.title}`,
        description: 'Decided together in Agent Mode session.',
        date: planTime,
        type: 'dateNight',
        createdBy,
      };
    }
    const prefix = option.type === 'movie' ? '🎬 Movie Night' : option.type === 'date' ? '🌹 Date' : '🎮 Game';
    const eventRef = doc(collection(db, 'calendar_events'));
    const decisionRef = doc(db, 'tonight_decisions', activeTonightDocId());
    const event: CalendarEventFixture = {
      id: eventRef.id,
      title: `${prefix}: ${option.title}`,
      description: `Decided together on Tonight ✨\n${option.description || option.subtitle}`,
      date: planTime,
      type: 'dateNight',
      createdBy,
    };
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(decisionRef);
      if (!snap.exists()) throw new Error('Tonight decision missing');
      tx.set(eventRef, {
        title: event.title,
        description: event.description,
        date: Timestamp.fromDate(planTime),
        type: 'dateNight',
        createdBy,
        attendees: ['khentsgdz', 'clairjassen'],
      });
      tx.update(decisionRef, {
        status: 'planned',
        calendarEventId: eventRef.id,
        planTime: Timestamp.fromDate(planTime),
        updatedAt: serverTimestamp(),
      });
    });
    return event;
  }

  async resetSession(): Promise<void> {
    if (AgentMode.demo) return;
    await deleteDoc(doc(db, 'tonight_decisions', activeTonightDocId()));
  }
}

export const tonightService = new TonightService();
