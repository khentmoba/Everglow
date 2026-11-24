// Faithful port of lib/features/anime/data/services/animex_stores.dart and
// the history/playlist models in animex_models.dart. Same storage keys and
// JSON shape as Flutter, so Clair's watch history and playlists carry over.
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { ValueNotifier, useValue } from '../../core/system/store';
import { isWatchedItem } from '../cinema/tmdbService';
import type { MediaItem } from '../cinema/cinemaTypes';
import { mediaIsMovie, mediaPosterUrl } from './animexData';

export interface AnimexHistoryEntry {
  key: string;
  anilistId?: number;
  malId: number;
  title: string;
  coverUrl: string;
  episode: number;
  totalEpisodes: number;
  updatedAt: Date;
  savedItem?: MediaItem;
}

export function historyResumeSeconds(e: AnimexHistoryEntry): number | undefined {
  const item = e.savedItem;
  if (!item) return undefined;
  return mediaResumeSeconds(item);
}

/** `MediaItem.resumeSeconds`. */
export function mediaResumeSeconds(item: MediaItem): number | undefined {
  const at = item.currentTimestamp ?? 0;
  if (at <= 0 || isWatchedItem(item)) return undefined;
  const total = item.durationSeconds ?? 0;
  if (total > 0 && at >= total * 0.95) return undefined;
  return at;
}

export const historyIsMovie = (e: AnimexHistoryEntry) => (e.savedItem ? mediaIsMovie(e.savedItem) : e.totalEpisodes === 1);
export const historyResumeLabel = (e: AnimexHistoryEntry) => (historyIsMovie(e) ? 'Resume movie' : `Resume Episode ${e.episode}`);

export function historySeriesProgress(e: AnimexHistoryEntry): number | undefined {
  if (e.totalEpisodes <= 1 || e.episode <= 0) return undefined;
  return Math.min(Math.max((e.episode - 1) / e.totalEpisodes, 0), 1);
}

export function historyFromMediaItem(item: MediaItem): AnimexHistoryEntry {
  const isMovie = mediaIsMovie(item);
  return {
    key: item.source === 'tmdb' ? `animex-tmdb-${item.mediaType}-${item.tmdbId}` : `animex-${item.anilistId ?? item.tmdbId}`,
    anilistId: item.anilistId,
    malId: item.tmdbId,
    title: item.title,
    coverUrl: mediaPosterUrl(item),
    episode: item.currentEpisode ?? 1,
    totalEpisodes: isMovie ? 1 : (item.episodeCount ?? 0),
    updatedAt: item.progressUpdatedAt ?? item.addedAt,
    savedItem: item,
  };
}

function historyToJson(e: AnimexHistoryEntry) {
  return {
    key: e.key,
    ...(e.anilistId != null ? { anilistId: e.anilistId } : {}),
    malId: e.malId,
    title: e.title,
    coverUrl: e.coverUrl,
    episode: e.episode,
    totalEpisodes: e.totalEpisodes,
    updatedAt: e.updatedAt.getTime(),
  };
}

const num = (v: unknown, fallback: number) => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : fallback);
const optInt = (v: unknown) => (typeof v === 'number' && Number.isInteger(v) ? v : undefined);
const s = (v: unknown, fallback = '') => (typeof v === 'string' ? v : fallback);

function historyFromJson(j: Record<string, unknown>): AnimexHistoryEntry {
  return {
    key: s(j.key),
    anilistId: optInt(j.anilistId),
    malId: num(j.malId, 0),
    title: s(j.title),
    coverUrl: s(j.coverUrl),
    episode: num(j.episode, 1),
    totalEpisodes: num(j.totalEpisodes, 0),
    updatedAt: new Date(num(j.updatedAt, 0)),
  };
}

export function mediaItemFromHistory(e: AnimexHistoryEntry): MediaItem {
  if (e.savedItem) return e.savedItem;
  return {
    id: '',
    tmdbId: e.malId,
    title: e.title,
    mediaType: 'tv',
    posterPath: e.coverUrl,
    backdropPath: '',
    year: '',
    status: '',
    isAnime: true,
    userName: '',
    addedAt: new Date(),
    source: 'jikan',
    anilistId: e.anilistId,
    synopsis: '',
    airingStatus: '',
    format: '',
    studio: '',
    genres: [],
    currentEpisode: e.episode,
    remindMe: false,
  };
}

export interface AnimexPlaylistItem {
  source: string;
  anilistId?: number;
  malId: number;
  title: string;
  coverUrl: string;
  year: string;
  format: string;
}

export const playlistItemKey = (i: AnimexPlaylistItem) => (i.anilistId != null ? `anilist:${i.anilistId}` : `${i.source}:${i.malId}`);
export const playlistItemMatches = (i: AnimexPlaylistItem, item: MediaItem) =>
  playlistItemKey(i) === (item.anilistId != null ? `anilist:${item.anilistId}` : `${item.source}:${item.tmdbId}`);

export interface AnimexPlaylist {
  id: string;
  name: string;
  emoji: string;
  createdAt: Date;
  items: AnimexPlaylistItem[];
}

function playlistItemFromJson(j: Record<string, unknown>): AnimexPlaylistItem {
  return {
    source: s(j.source, 'jikan'),
    anilistId: optInt(j.anilistId),
    malId: num(j.malId, 0),
    title: s(j.title),
    coverUrl: s(j.coverUrl),
    year: s(j.year),
    format: s(j.format),
  };
}

const playlistItemToJson = (i: AnimexPlaylistItem) => ({
  source: i.source,
  ...(i.anilistId != null ? { anilistId: i.anilistId } : {}),
  malId: i.malId,
  title: i.title,
  coverUrl: i.coverUrl,
  year: i.year,
  format: i.format,
});

const isMap = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);

const HISTORY_KEY = 'animex_watch_history_v1';
const PLAYLISTS_KEY = 'animex_playlists_v1';
const PREFS_KEY = 'animex_prefs_v1';
const keyFor = (base: string, user: string) => (user ? `${base}_${user}` : base);
const isCoupleUser = (user: string) => user === 'khentsgdz' || user === 'clairjassen';

class AnimexStoresImpl {
  history: AnimexHistoryEntry[] = [];
  playlists: AnimexPlaylist[] = [];
  titleJapanese = false;
  hideSpoilers = true;
  autoNext = true;
  skipIntro = true;
  private scheduleAlerts = new Map<string, boolean>();
  private loaded = false;
  private generation = 0;
  currentUser = '';
  /** Bumps on every change, like notifyListeners(). */
  readonly version = new ValueNotifier(0);

  private notify() {
    this.version.value = this.version.value + 1;
  }

  load(username?: string | null): void {
    const user = username ?? '';
    if (this.loaded && user === this.currentUser) return;
    const generation = ++this.generation;
    this.currentUser = user;
    this.history = [];
    this.playlists = [];
    this.titleJapanese = false;
    this.hideSpoilers = true;
    this.autoNext = true;
    this.skipIntro = true;
    this.scheduleAlerts.clear();
    this.loaded = false;
    this.notify();
    if (!user) {
      this.loaded = true;
      return;
    }
    try {
      this.readInto(
        Prefs.getString(keyFor(HISTORY_KEY, user)),
        Prefs.getString(keyFor(PLAYLISTS_KEY, user)),
        Prefs.getString(keyFor(PREFS_KEY, user)),
      );
      if (!this.history.length && !this.playlists.length && isCoupleUser(user)) {
        const legacyHistory = Prefs.getString(HISTORY_KEY);
        const legacyPlaylists = Prefs.getString(PLAYLISTS_KEY);
        if (legacyHistory || legacyPlaylists) {
          this.readInto(legacyHistory, legacyPlaylists, Prefs.getString(PREFS_KEY));
          this.persist();
          for (const key of [HISTORY_KEY, PLAYLISTS_KEY, PREFS_KEY]) {
            if (generation !== this.generation) return;
            Prefs.remove(key);
          }
        }
      }
      if (generation !== this.generation) return;
      this.loaded = true;
      this.notify();
    } catch (e) {
      Logger.w(`[AnimexStores] load failed: ${String(e)}`);
    }
  }

  private readInto(historyRaw: string | null, playlistsRaw: string | null, prefsRaw: string | null) {
    if (historyRaw) {
      try {
        const raw: unknown = JSON.parse(historyRaw);
        if (Array.isArray(raw)) {
          this.history = raw
            .filter(isMap)
            .map(historyFromJson)
            .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
        }
      } catch (e) {
        Logger.w(`[AnimexStores] malformed history ignored: ${String(e)}`);
      }
    }
    if (playlistsRaw) {
      try {
        const raw: unknown = JSON.parse(playlistsRaw);
        if (Array.isArray(raw)) {
          this.playlists = raw.filter(isMap).map((j) => ({
            id: s(j.id),
            name: s(j.name),
            emoji: s(j.emoji, 'star'),
            createdAt: new Date(num(j.createdAt, 0)),
            items: (Array.isArray(j.items) ? j.items : []).filter(isMap).map(playlistItemFromJson),
          }));
        }
      } catch (e) {
        Logger.w(`[AnimexStores] malformed playlists ignored: ${String(e)}`);
      }
    }
    if (prefsRaw) {
      try {
        const data: unknown = JSON.parse(prefsRaw);
        if (isMap(data)) {
          this.titleJapanese = data.titleJapanese === true;
          this.hideSpoilers = data.hideSpoilers !== false;
          this.autoNext = data.autoNext !== false;
          this.skipIntro = data.skipIntro !== false;
          if (isMap(data.scheduleAlerts)) {
            for (const [k, v] of Object.entries(data.scheduleAlerts)) this.scheduleAlerts.set(k, v === true);
          }
        }
      } catch (e) {
        Logger.w(`[AnimexStores] malformed prefs ignored: ${String(e)}`);
      }
    }
  }

  private persist() {
    const user = this.currentUser;
    if (!user) return;
    Prefs.set(keyFor(HISTORY_KEY, user), JSON.stringify(this.history.map(historyToJson)));
    Prefs.set(
      keyFor(PLAYLISTS_KEY, user),
      JSON.stringify(
        this.playlists.map((p) => ({
          id: p.id,
          name: p.name,
          emoji: p.emoji,
          createdAt: p.createdAt.getTime(),
          items: p.items.map(playlistItemToJson),
        })),
      ),
    );
    Prefs.set(
      keyFor(PREFS_KEY, user),
      JSON.stringify({
        titleJapanese: this.titleJapanese,
        hideSpoilers: this.hideSpoilers,
        autoNext: this.autoNext,
        skipIntro: this.skipIntro,
        scheduleAlerts: Object.fromEntries(this.scheduleAlerts),
      }),
    );
  }

  private changed() {
    this.notify();
    this.persist();
  }

  findHistory(key: string): AnimexHistoryEntry | undefined {
    return this.history.find((e) => e.key === key);
  }

  recordWatch(e: Omit<AnimexHistoryEntry, 'updatedAt' | 'savedItem' | 'totalEpisodes'> & { totalEpisodes?: number }) {
    this.history = this.history.filter((h) => h.key !== e.key);
    this.history.unshift({ ...e, totalEpisodes: e.totalEpisodes ?? 0, updatedAt: new Date() });
    if (this.history.length > 60) this.history.length = 60;
    this.changed();
  }

  clearHistory() {
    this.history = [];
    this.changed();
  }

  removeHistoryEntry(key: string) {
    this.history = this.history.filter((e) => e.key !== key);
    this.changed();
  }

  playlistById(id: string) {
    return this.playlists.find((p) => p.id === id);
  }

  isInAnyPlaylist(anilistId: number) {
    return this.playlists.some((p) => p.items.some((i) => i.anilistId === anilistId));
  }

  createPlaylist(name: string, emoji: string): AnimexPlaylist {
    const playlist: AnimexPlaylist = { id: `custom-${Date.now()}`, name, emoji, createdAt: new Date(), items: [] };
    this.playlists = [playlist, ...this.playlists];
    this.changed();
    return playlist;
  }

  private replacePlaylist(id: string, update: (p: AnimexPlaylist) => AnimexPlaylist | null) {
    const index = this.playlists.findIndex((p) => p.id === id);
    if (index < 0) return;
    const next = update(this.playlists[index]);
    if (!next) return;
    this.playlists = this.playlists.map((p, i) => (i === index ? next : p));
    this.changed();
  }

  updatePlaylist(id: string, { name, emoji }: { name?: string; emoji?: string }) {
    this.replacePlaylist(id, (p) => ({ ...p, name: name ?? p.name, emoji: emoji ?? p.emoji }));
  }

  deletePlaylist(id: string) {
    this.playlists = this.playlists.filter((p) => p.id !== id);
    this.changed();
  }

  addToPlaylist(id: string, item: AnimexPlaylistItem) {
    this.replacePlaylist(id, (p) =>
      p.items.some((i) => playlistItemKey(i) === playlistItemKey(item)) ? null : { ...p, items: [...p.items, item] },
    );
  }

  removeFromPlaylist(id: string, anilistId: number) {
    this.replacePlaylist(id, (p) => ({ ...p, items: p.items.filter((i) => i.anilistId !== anilistId) }));
  }

  removePlaylistEntry(id: string, item: AnimexPlaylistItem) {
    this.replacePlaylist(id, (p) => ({ ...p, items: p.items.filter((i) => playlistItemKey(i) !== playlistItemKey(item)) }));
  }

  setHideSpoilers(value: boolean) {
    if (this.hideSpoilers === value) return;
    this.hideSpoilers = value;
    this.changed();
  }

  setAutoNext(value: boolean) {
    if (this.autoNext === value) return;
    this.autoNext = value;
    this.changed();
  }

  setSkipIntro(value: boolean) {
    if (this.skipIntro === value) return;
    this.skipIntro = value;
    this.changed();
  }

  setTitleJapanese(value: boolean) {
    this.titleJapanese = value;
    this.changed();
  }

  isAlertEnabled(key: string) {
    return this.scheduleAlerts.get(key) ?? false;
  }

  toggleAlert(key: string) {
    this.scheduleAlerts.set(key, !(this.scheduleAlerts.get(key) ?? false));
    this.changed();
  }
}

export const AnimexStores = new AnimexStoresImpl();

/** Re-renders on every store change (Flutter's ListenableBuilder on AnimexStores). */
export function useAnimexStores(): AnimexStoresImpl {
  useValue(AnimexStores.version);
  return AnimexStores;
}
