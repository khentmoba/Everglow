import { collection, getDocs, limit, query, serverTimestamp, setDoc, updateDoc, where, doc } from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { Changes, type Source } from '../../core/utils/liveSource';
import { catalogKeyOf, type MediaItem } from '../cinema/cinemaTypes';
import { fetchAniZipMappings } from '../../shared/utils/catalogProxy';
import { clearWatchProgress, saveWatchProgress, setListMembership, watchCinemaWatchlist } from '../cinema/tmdbService';

const ANILIST_ENDPOINT = 'https://graphql.anilist.co';
const JIKAN_PROXY = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyCatalog';
export const PROXY_ANIME_BASE = 'https://everglow-stream.khentplaysmoba.workers.dev/proxyAnime';

export type AnimexPageKind =
  | 'home'
  | 'browse'
  | 'schedule'
  | 'search'
  | 'history'
  | 'myList'
  | 'playlists'
  | 'seasonal'
  | 'downloads';

export interface AnimexMediaPage {
  items: MediaItem[];
  scores: number[];
  currentPage: number;
  lastPage?: number;
  hasNextPage: boolean;
}

export interface AnimexScheduleEntry {
  media: MediaItem;
  episode: number;
  airingAt: Date;
}

export interface AniListEpisode {
  number: number;
  title?: string;
  titleRomaji?: string;
  synopsis?: string;
  airedAt?: Date;
  duration?: number;
  thumbnail?: string;
}

export interface AniListCharacter {
  id: number;
  name: string;
  role: string;
  imageUrl: string;
  voiceActorName?: string;
  voiceActorImageUrl?: string;
}

export interface AniListStaff {
  id: number;
  name: string;
  role: string;
  imageUrl: string;
}

export interface AniListSeason {
  id: number;
  malId?: number;
  title: string;
  label: string;
  format: string;
  year?: number;
  episodeCount?: number;
  coverImageUrl: string;
  isMovie: boolean;
}

export interface AniListRecommended {
  id: number;
  malId?: number;
  title: string;
  coverImageUrl: string;
  rating?: number;
}

export interface AniListDetail {
  id: number;
  malId?: number;
  titleEnglish: string;
  titleRomaji: string;
  titleNative: string;
  synopsis: string;
  coverImageUrl: string;
  bannerImageUrl: string;
  siteUrl: string;
  episodeCount?: number;
  duration?: number;
  airingStatus: string;
  format: string;
  season?: string;
  seasonYear?: number;
  averageScore?: number;
  genres: string[];
  studios: string[];
  trailerYoutubeId?: string;
  characters: AniListCharacter[];
  staff: AniListStaff[];
  seasons: AniListSeason[];
  recommendations: AniListRecommended[];
  episodes: AniListEpisode[];
  nextAiringEpisode?: number;
  nextAiringAt?: number;
}

export interface AnimexPlaylist {
  id: string;
  name: string;
  emoji: string;
  items: MediaItem[];
  createdAt: Date;
}

export interface AnimexHistoryEntry {
  key: string;
  tmdbId: number;
  anilistId?: number;
  title: string;
  posterUrl: string;
  episode: number;
  totalEpisodes: number;
  audio: 'sub' | 'dub';
  progress?: number;
  resumeSeconds?: number;
  isMovie?: boolean;
  updatedAt: Date;
  savedItem?: MediaItem;
}

export interface AnimeServerOption {
  name: string;
  tag: string;
  available: boolean;
  supportsAudioSelection: boolean;
  supportsSeek: boolean;
  supportsResume: boolean;
  urlFor: (ep: number, audio: 'sub' | 'dub', startSeconds?: number) => string;
}

export interface AniSkipTime {
  skipType: string;
  startTime: number;
  endTime: number;
}

function unescapeHtml(input: string): string {
  return input
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

const ANIMEX_PAGE_QUERY = `
query (
  $search: String
  $sort: [MediaSort]
  $status: MediaStatus
  $season: MediaSeason
  $seasonYear: Int
  $format: MediaFormat
  $genre: String
  $genre_in: [String]
  $tag: String
  $tag_in: [String]
  $page: Int
  $perPage: Int
) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      currentPage
      lastPage
      hasNextPage
    }
    media(
      search: $search
      type: ANIME
      sort: $sort
      status: $status
      season: $season
      seasonYear: $seasonYear
      format: $format
      genre: $genre
      genre_in: $genre_in
      tag: $tag
      tag_in: $tag_in
    ) {
      id
      idMal
      title { romaji english native }
      coverImage { extraLarge large medium }
      bannerImage
      description(asHtml: false)
      episodes
      duration
      status
      format
      season
      seasonYear
      averageScore
      genres
      studios(isMain: true) { nodes { id name } }
      nextAiringEpisode { airingAt episode }
      trailer { id site }
    }
  }
}
`;

const DETAILS_QUERY = `
query ($id: Int, $idMal: Int, $type: MediaType) {
  Media(id: $id, idMal: $idMal, type: $type) {
    id
    idMal
    title { romaji english native }
    description(asHtml: false)
    coverImage { extraLarge large medium color }
    bannerImage
    episodes
    duration
    status
    format
    season
    seasonYear
    averageScore
    genres
    studios(isMain: true) { nodes { id name } }
    trailer { id site thumbnail }
    siteUrl
    characters(perPage: 12, sort: ROLE) {
      edges {
        role
        node { id name { full native } image { large medium } }
        voiceActors(language: JAPANESE) { id name { full native } image { large medium } }
      }
    }
    staff(perPage: 8) {
      edges {
        role
        node { id name { full native } image { medium } }
      }
    }
    relations {
      edges {
        relationType
        node {
          id idMal title { romaji english } format type seasonYear
          startDate { year month day } episodes coverImage { large medium extraLarge }
        }
      }
    }
    recommendations(perPage: 10, sort: RATING_DESC) {
      nodes {
        rating
        mediaRecommendation {
          id idMal title { romaji english } coverImage { large medium }
        }
      }
    }
    streamingEpisodes { title url site thumbnail }
    nextAiringEpisode { airingAt episode }
  }
}
`;

const AIRING_SCHEDULE_QUERY = `
query ($airingAtGreater: Int, $airingAtLesser: Int, $page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { hasNextPage }
    airingSchedules(
      airingAt_greater: $airingAtGreater
      airingAt_lesser: $airingAtLesser
      sort: TIME
    ) {
      id
      airingAt
      episode
      media {
        id
        idMal
        title { romaji english native }
        coverImage { extraLarge large medium }
        bannerImage
        description(asHtml: false)
        episodes
        duration
        status
        format
        season
        seasonYear
        averageScore
        genres
        studios(isMain: true) { nodes { id name } }
        trailer { id site }
      }
    }
  }
}
`;

function mapAniListMedia(m: Record<string, unknown>, japaneseTitle = false): { item: MediaItem; score: number } | null {
  const id = Number(m.id ?? 0);
  if (!id) return null;
  const malId = typeof m.idMal === 'number' ? m.idMal : 0;
  const t = (m.title as Record<string, unknown> | undefined) ?? {};
  const en = typeof t.english === 'string' ? t.english.trim() : '';
  const rom = typeof t.romaji === 'string' ? t.romaji.trim() : '';
  const nat = typeof t.native === 'string' ? t.native.trim() : '';
  const title = japaneseTitle
    ? (rom || nat || en || 'Unknown Title')
    : (en || rom || 'Unknown Title');
  const cover = (m.coverImage as Record<string, unknown> | undefined) ?? {};
  const poster = String(cover.extraLarge ?? cover.large ?? cover.medium ?? '');
  const banner = String(m.bannerImage ?? '');
  const format = String(m.format ?? '');
  const episodes = typeof m.episodes === 'number' ? m.episodes : undefined;
  const duration = typeof m.duration === 'number' ? m.duration : undefined;
  const isMovie = format === 'MOVIE' || (episodes === 1 && (duration ?? 0) >= 40);
  const studioNodes = ((m.studios as Record<string, unknown> | undefined)?.nodes as Record<string, unknown>[] | undefined) ?? [];
  const studio = studioNodes.map((n) => String(n.name ?? '')).find(Boolean) ?? '';
  const avg = typeof m.averageScore === 'number' ? m.averageScore / 10 : undefined;
  const tr = m.trailer as Record<string, unknown> | undefined;
  const trailerYoutubeId = tr?.site === 'youtube' && typeof tr.id === 'string' ? tr.id : undefined;

  const item: MediaItem = {
    id: '',
    tmdbId: malId > 0 ? malId : id,
    anilistId: id,
    title,
    mediaType: isMovie ? 'movie' : 'tv',
    posterPath: poster,
    backdropPath: banner || poster,
    year: typeof m.seasonYear === 'number' ? String(m.seasonYear) : '',
    status: '',
    isAnime: true,
    userName: '',
    addedAt: new Date(),
    source: malId > 0 ? 'jikan' : 'anilist',
    synopsis: unescapeHtml(String(m.description ?? '')),
    episodeCount: episodes,
    airingStatus: String(m.status ?? ''),
    format,
    studio,
    genres: Array.isArray(m.genres) ? m.genres.map(String) : [],
    score: avg,
    remindMe: false,
    trailerYoutubeId,
  };
  return { item, score: avg ?? 0 };
}

const pageCache = new Map<string, { at: number; data: AnimexMediaPage }>();
const detailCache = new Map<number, { at: number; data: AniListDetail }>();
const scheduleCache = new Map<number, { at: number; data: AnimexScheduleEntry[] }>();
const CACHE_TTL = 10 * 60 * 1000;

async function postAniList(queryStr: string, variables: Record<string, unknown>): Promise<Record<string, unknown> | null> {
  try {
    const resp = await fetch(ANILIST_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ query: queryStr, variables }),
      signal: AbortSignal.timeout(15000),
    });
    if (!resp.ok) return null;
    const json = (await resp.json()) as { data?: Record<string, unknown>; errors?: unknown };
    if (json.errors) return null;
    return json.data ?? null;
  } catch (e) {
    Logger.w(`AniList request failed: ${String(e)}`);
    return null;
  }
}

async function jikanFallback(opts: {
  search?: string;
  sort?: string;
  status?: string;
  season?: string;
  seasonYear?: number;
  page?: number;
  perPage?: number;
}): Promise<AnimexMediaPage | null> {
  const token = auth.currentUser ? await auth.currentUser.getIdToken().catch(() => null) : null;
  const headers: Record<string, string> = token ? { Authorization: `Bearer ${token}` } : {};
  let path = `top/anime?type=tv&filter=bypopularity&page=${opts.page ?? 1}&limit=${opts.perPage ?? 18}`;
  if (opts.search?.trim()) {
    path = `anime?q=${encodeURIComponent(opts.search.trim())}&page=${opts.page ?? 1}&limit=${opts.perPage ?? 18}`;
  } else if (opts.season && opts.seasonYear) {
    path = `seasons/${opts.seasonYear}/${opts.season.toLowerCase()}?page=${opts.page ?? 1}&limit=${opts.perPage ?? 18}`;
  } else if (opts.status === 'RELEASING') {
    path = `top/anime?filter=airing&page=${opts.page ?? 1}&limit=${opts.perPage ?? 18}`;
  }
  try {
    const resp = await fetch(`${JIKAN_PROXY}?${new URLSearchParams({ base: 'jikan', path }).toString()}`, {
      headers,
      signal: AbortSignal.timeout(12000),
    });
    if (!resp.ok) return null;
    const json = (await resp.json()) as { data?: Record<string, unknown>[] };
    const list = json.data ?? [];
    const items: MediaItem[] = list.map((j) => {
      const images = (j.images as Record<string, unknown> | undefined)?.jpg as Record<string, unknown> | undefined;
      const poster = String(images?.large_image_url ?? images?.image_url ?? '');
      const titles = Array.isArray(j.titles) ? (j.titles as { type: string; title: string }[]) : [];
      const en = titles.find((x) => x.type === 'English')?.title;
      const airedFrom = String(((j.aired as Record<string, unknown> | undefined)?.from) ?? '');
      const typ = String(j.type ?? 'TV');
      return {
        id: '',
        tmdbId: Number(j.mal_id ?? 0),
        title: en || String(j.title ?? 'Unknown Title'),
        mediaType: typ === 'Movie' ? 'movie' : 'tv',
        posterPath: poster,
        backdropPath: poster,
        year: airedFrom.length >= 4 ? airedFrom.slice(0, 4) : '',
        status: '',
        isAnime: true,
        userName: '',
        addedAt: new Date(),
        source: 'jikan',
        synopsis: String(j.synopsis ?? ''),
        episodeCount: typeof j.episodes === 'number' ? j.episodes : undefined,
        airingStatus: String(j.status ?? ''),
        format: typ.toUpperCase(),
        studio: '',
        genres: Array.isArray(j.genres) ? (j.genres as { name: string }[]).map((g) => g.name) : [],
        score: typeof j.score === 'number' ? j.score : undefined,
        remindMe: false,
      };
    });
    return {
      items,
      scores: items.map((x) => x.score ?? 0),
      currentPage: opts.page ?? 1,
      hasNextPage: false,
    };
  } catch {
    return null;
  }
}

export async function fetchAnimexPage(opts: {
  search?: string;
  sort?: string;
  status?: string;
  season?: string;
  seasonYear?: number;
  format?: string;
  genres?: string[];
  page?: number;
  perPage?: number;
  japaneseTitle?: boolean;
}): Promise<AnimexMediaPage> {
  const key = JSON.stringify(opts);
  const cached = pageCache.get(key);
  if (cached && Date.now() - cached.at < CACHE_TTL) {
    return cached.data;
  }

  const knownTags = new Set(['Isekai', 'Reincarnation', 'Reverse Isekai']);
  const genres = opts.genres ?? [];
  const tags = genres.filter((g) => knownTags.has(g));
  const stdGenres = genres.filter((g) => !knownTags.has(g));

  const variables: Record<string, unknown> = {
    page: opts.page ?? 1,
    perPage: opts.perPage ?? 24,
  };
  if (opts.search?.trim()) variables.search = opts.search.trim();
  if (opts.sort) variables.sort = [opts.sort];
  if (opts.status) variables.status = opts.status;
  if (opts.season) variables.season = opts.season;
  if (opts.seasonYear) variables.seasonYear = opts.seasonYear;
  if (opts.format) variables.format = opts.format;
  if (stdGenres.length === 1) variables.genre = stdGenres[0];
  else if (stdGenres.length > 1) variables.genre_in = stdGenres;
  if (tags.length === 1) variables.tag = tags[0];
  else if (tags.length > 1) variables.tag_in = tags;

  const data = await postAniList(ANIMEX_PAGE_QUERY, variables);
  const pageData = data?.Page as Record<string, unknown> | undefined;
  if (!pageData) {
    const fb = await jikanFallback(opts);
    if (fb) return fb;
    return { items: [], scores: [], currentPage: opts.page ?? 1, hasNextPage: false };
  }

  const pageInfo = (pageData.pageInfo as Record<string, unknown> | undefined) ?? {};
  const media = Array.isArray(pageData.media) ? (pageData.media as Record<string, unknown>[]) : [];
  const items: MediaItem[] = [];
  const scores: number[] = [];
  for (const m of media) {
    const mapped = mapAniListMedia(m, opts.japaneseTitle);
    if (mapped) {
      items.push(mapped.item);
      scores.push(mapped.score);
    }
  }
  const result: AnimexMediaPage = {
    items,
    scores,
    currentPage: Number(pageInfo.currentPage ?? opts.page ?? 1),
    lastPage: typeof pageInfo.lastPage === 'number' ? pageInfo.lastPage : undefined,
    hasNextPage: pageInfo.hasNextPage === true,
  };
  pageCache.set(key, { at: Date.now(), data: result });
  return result;
}

export async function fetchAniListDetails(opts: { anilistId?: number; malId?: number }): Promise<AniListDetail | null> {
  const key = opts.anilistId ?? -(opts.malId ?? 0);
  if (!key) return null;
  const cached = detailCache.get(key);
  if (cached && Date.now() - cached.at < CACHE_TTL) return cached.data;

  const variables: Record<string, unknown> = { type: 'ANIME' };
  if (opts.anilistId) variables.id = opts.anilistId;
  else if (opts.malId) variables.idMal = opts.malId;

  const data = await postAniList(DETAILS_QUERY, variables);
  const m = data?.Media as Record<string, unknown> | undefined;
  if (!m) return null;

  const title = (m.title as Record<string, unknown> | undefined) ?? {};
  const cover = (m.coverImage as Record<string, unknown> | undefined) ?? {};
  const trailer = m.trailer as Record<string, unknown> | undefined;
  const studioNodes = ((m.studios as Record<string, unknown> | undefined)?.nodes as Record<string, unknown>[] | undefined) ?? [];

  const charEdges = ((m.characters as Record<string, unknown> | undefined)?.edges as Record<string, unknown>[] | undefined) ?? [];
  const characters: AniListCharacter[] = charEdges.map((e) => {
    const node = (e.node as Record<string, unknown> | undefined) ?? {};
    const nName = (node.name as Record<string, unknown> | undefined) ?? {};
    const nImg = (node.image as Record<string, unknown> | undefined) ?? {};
    const vas = Array.isArray(e.voiceActors) ? (e.voiceActors as Record<string, unknown>[]) : [];
    const va = vas[0];
    const vaName = (va?.name as Record<string, unknown> | undefined)?.full as string | undefined;
    const vaImg = ((va?.image as Record<string, unknown> | undefined)?.large ??
      (va?.image as Record<string, unknown> | undefined)?.medium) as string | undefined;
    return {
      id: Number(node.id ?? 0),
      name: String(nName.full ?? ''),
      role: String(e.role ?? ''),
      imageUrl: String(nImg.large ?? nImg.medium ?? ''),
      voiceActorName: vaName,
      voiceActorImageUrl: vaImg,
    };
  });

  const staffEdges = ((m.staff as Record<string, unknown> | undefined)?.edges as Record<string, unknown>[] | undefined) ?? [];
  const staff: AniListStaff[] = staffEdges.map((e) => {
    const node = (e.node as Record<string, unknown> | undefined) ?? {};
    const nName = (node.name as Record<string, unknown> | undefined) ?? {};
    const nImg = (node.image as Record<string, unknown> | undefined) ?? {};
    return {
      id: Number(node.id ?? 0),
      name: String(nName.full ?? ''),
      role: String(e.role ?? ''),
      imageUrl: String(nImg.medium ?? ''),
    };
  });

  const relEdges = ((m.relations as Record<string, unknown> | undefined)?.edges as Record<string, unknown>[] | undefined) ?? [];
  const seasons: AniListSeason[] = relEdges
    .filter((e) => ['SEQUEL', 'PREQUEL', 'PARENT', 'SIDE_STORY'].includes(String(e.relationType ?? '')))
    .map((e) => {
      const n = (e.node as Record<string, unknown> | undefined) ?? {};
      const nt = (n.title as Record<string, unknown> | undefined) ?? {};
      const nc = (n.coverImage as Record<string, unknown> | undefined) ?? {};
      const fmt = String(n.format ?? '');
      return {
        id: Number(n.id ?? 0),
        malId: typeof n.idMal === 'number' ? n.idMal : undefined,
        title: String(nt.english ?? nt.romaji ?? ''),
        label: String(e.relationType ?? '').replace(/_/g, ' '),
        format: fmt,
        year: typeof n.seasonYear === 'number' ? n.seasonYear : undefined,
        episodeCount: typeof n.episodes === 'number' ? n.episodes : undefined,
        coverImageUrl: String(nc.large ?? nc.medium ?? nc.extraLarge ?? ''),
        isMovie: fmt === 'MOVIE',
      };
    })
    .filter((s) => s.id > 0);

  const recNodes = ((m.recommendations as Record<string, unknown> | undefined)?.nodes as Record<string, unknown>[] | undefined) ?? [];
  const recommendations: AniListRecommended[] = recNodes
    .map((n) => {
      const mr = (n.mediaRecommendation as Record<string, unknown> | undefined) ?? {};
      const mt = (mr.title as Record<string, unknown> | undefined) ?? {};
      const mc = (mr.coverImage as Record<string, unknown> | undefined) ?? {};
      return {
        id: Number(mr.id ?? 0),
        malId: typeof mr.idMal === 'number' ? mr.idMal : undefined,
        title: String(mt.english ?? mt.romaji ?? ''),
        coverImageUrl: String(mc.large ?? mc.medium ?? ''),
        rating: typeof n.rating === 'number' ? n.rating : undefined,
      };
    })
    .filter((r) => r.id > 0);

  const epCount = typeof m.episodes === 'number' ? m.episodes : undefined;
  const streaming = Array.isArray(m.streamingEpisodes) ? (m.streamingEpisodes as Record<string, unknown>[]) : [];
  const epByNum = new Map<number, AniListEpisode>();
  streaming.forEach((s, idx) => {
    const raw = String(s.title ?? '');
    const match = /^Episode\s+(\d+)\s*(?:-\s*(.*))?$/i.exec(raw.trim());
    const num = match ? Number(match[1]) : idx + 1;
    epByNum.set(num, {
      number: num,
      title: match?.[2]?.trim() || raw || `Episode ${num}`,
      thumbnail: typeof s.thumbnail === 'string' && s.thumbnail ? s.thumbnail : undefined,
    });
  });
  const totalEps = epCount && epCount > 0 ? epCount : Math.max(0, ...Array.from(epByNum.keys()));
  const episodes: AniListEpisode[] = [];
  for (let i = 1; i <= totalEps; i++) {
    episodes.push(epByNum.get(i) ?? { number: i, title: `Episode ${i}` });
  }

  const nextAiring = m.nextAiringEpisode as Record<string, unknown> | undefined;
  const detail: AniListDetail = {
    id: Number(m.id ?? 0),
    malId: typeof m.idMal === 'number' ? m.idMal : undefined,
    titleEnglish: String(title.english ?? ''),
    titleRomaji: String(title.romaji ?? ''),
    titleNative: String(title.native ?? ''),
    synopsis: unescapeHtml(String(m.description ?? '')),
    coverImageUrl: String(cover.extraLarge ?? cover.large ?? cover.medium ?? ''),
    bannerImageUrl: String(m.bannerImage ?? ''),
    siteUrl: String(m.siteUrl ?? ''),
    episodeCount: epCount,
    duration: typeof m.duration === 'number' ? m.duration : undefined,
    airingStatus: String(m.status ?? ''),
    format: String(m.format ?? ''),
    season: typeof m.season === 'string' ? m.season : undefined,
    seasonYear: typeof m.seasonYear === 'number' ? m.seasonYear : undefined,
    averageScore: typeof m.averageScore === 'number' ? m.averageScore / 10 : undefined,
    genres: Array.isArray(m.genres) ? m.genres.map(String) : [],
    studios: studioNodes.map((s) => String(s.name ?? '')).filter(Boolean),
    trailerYoutubeId: trailer?.site === 'youtube' && typeof trailer.id === 'string' ? trailer.id : undefined,
    characters,
    staff,
    seasons,
    recommendations,
    episodes,
    nextAiringAt: typeof nextAiring?.airingAt === 'number' ? nextAiring.airingAt : undefined,
    nextAiringEpisode: typeof nextAiring?.episode === 'number' ? nextAiring.episode : undefined,
  };
  detailCache.set(key, { at: Date.now(), data: detail });
  return detail;
}

export async function fetchAiringSchedule(weekday: number): Promise<AnimexScheduleEntry[]> {
  const cached = scheduleCache.get(weekday);
  if (cached && Date.now() - cached.at < CACHE_TTL) return cached.data;

  const now = new Date();
  const mondayOffset = (now.getDay() + 6) % 7; // 0 = Monday .. 6 = Sunday
  const target = new Date(now.getFullYear(), now.getMonth(), now.getDate() - mondayOffset + weekday);
  const startSec = Math.floor(target.getTime() / 1000);
  const endSec = startSec + 86400;

  const data = await postAniList(AIRING_SCHEDULE_QUERY, {
    airingAtGreater: startSec,
    airingAtLesser: endSec,
    page: 1,
    perPage: 50,
  });
  const pageData = data?.Page as Record<string, unknown> | undefined;
  const rows = Array.isArray(pageData?.airingSchedules) ? (pageData.airingSchedules as Record<string, unknown>[]) : [];
  const entries: AnimexScheduleEntry[] = [];
  for (const r of rows) {
    const mediaRaw = r.media as Record<string, unknown> | undefined;
    if (!mediaRaw) continue;
    const mapped = mapAniListMedia(mediaRaw);
    if (!mapped) continue;
    entries.push({
      media: mapped.item,
      episode: Number(r.episode ?? 1),
      airingAt: new Date(Number(r.airingAt ?? startSec) * 1000),
    });
  }
  entries.sort((a, b) => a.airingAt.getTime() - b.airingAt.getTime());
  scheduleCache.set(weekday, { at: Date.now(), data: entries });
  return entries;
}

export async function fetchAniZipEpisodes(opts: { anilistId?: number; malId?: number }): Promise<Record<number, { title?: string; overview?: string; image?: string; airdate?: string; runtime?: number }>> {
  try {
    const json = (await fetchAniZipMappings(opts)) as { episodes?: Record<string, Record<string, unknown>> } | null;
    if (!json) return {};
    const out: Record<number, { title?: string; overview?: string; image?: string; airdate?: string; runtime?: number }> = {};
    for (const [k, v] of Object.entries(json.episodes ?? {})) {
      const num = Number(k);
      if (!Number.isFinite(num) || num <= 0) continue;
      const titles = v.title as Record<string, string> | undefined;
      out[num] = {
        title: titles?.en ?? titles?.['x-jat'] ?? titles?.ja,
        overview: (v.overview as string | undefined) || (v.summary as string | undefined),
        image: v.image as string | undefined,
        airdate: (v.airDate as string | undefined) ?? (v.airdate as string | undefined),
        runtime: typeof v.runtime === 'number' ? v.runtime : typeof v.length === 'number' ? v.length : undefined,
      };
    }
    return out;
  } catch {
    return {};
  }
}

export async function fetchAniSkip(malId: number, episode: number): Promise<AniSkipTime[]> {
  if (!malId || episode <= 0) return [];
  try {
    const resp = await fetch(
      `https://api.aniskip.com/v2/skip-times/${malId}/${episode}?types=op&types=ed&episodeLength=0`,
      { signal: AbortSignal.timeout(6000) },
    );
    if (!resp.ok) return [];
    const json = (await resp.json()) as { results?: { skipType: string; interval?: { startTime: number; endTime: number } }[] };
    return (json.results ?? [])
      .filter((r) => r.interval)
      .map((r) => ({ skipType: r.skipType, startTime: r.interval!.startTime, endTime: r.interval!.endTime }));
  } catch {
    return [];
  }
}

export function buildAnimeServers(opts: {
  anilistId?: number;
  malId?: number;
  tmdbId?: number;
  isMovie?: boolean;
}): AnimeServerOption[] {
  const aniId = opts.anilistId && opts.anilistId > 0 ? opts.anilistId : 0;
  const malId = opts.malId && opts.malId > 0 ? opts.malId : 0;
  const tmdbId = opts.tmdbId && opts.tmdbId > 0 ? opts.tmdbId : 0;
  const hasAni = aniId > 0;
  const hasSource = hasAni || malId > 0;
  const appendStart = (base: string, start?: number) => (start && start > 0 ? `${base}${base.includes('?') ? '&' : '?'}start=${start}` : base);

  return [
    {
      name: 'Everglow',
      tag: 'Ad-free',
      available: hasSource,
      supportsAudioSelection: true,
      supportsSeek: true,
      supportsResume: true,
      urlFor: (ep, audio, start) =>
        appendStart(`${PROXY_ANIME_BASE}?source=everglow&anilistId=${aniId}&malId=${malId}&ep=${ep}&audio=${audio}`, start),
    },
    {
      name: 'CineSrc',
      tag: 'Ad-free',
      available: tmdbId > 0,
      supportsAudioSelection: false,
      supportsSeek: false,
      supportsResume: true,
      urlFor: (ep, _audio, start) =>
        appendStart(
          opts.isMovie
            ? `https://everglow-1c6db.web.app/embed.html?tmdbId=${tmdbId}&type=movie`
            : `https://everglow-1c6db.web.app/embed.html?tmdbId=${tmdbId}&type=tv&s=1&e=${ep}`,
          start,
        ),
    },
    {
      name: 'TryEmbed',
      tag: 'Embed',
      available: hasSource,
      supportsAudioSelection: true,
      supportsSeek: false,
      supportsResume: false,
      urlFor: (ep, audio) =>
        hasAni
          ? `https://tryembed.us.cc/embed/anime/${aniId}/${ep}/${audio}`
          : `https://tryembed.us.cc/embed/anime/${malId}/${ep}/${audio}?type=mal`,
    },
    {
      name: 'VidCore',
      tag: 'Embed',
      available: tmdbId > 0,
      supportsAudioSelection: false,
      supportsSeek: false,
      supportsResume: false,
      urlFor: (ep) =>
        opts.isMovie
          ? `https://vidcore.org/embed/movie/${tmdbId}`
          : `https://vidcore.org/embed/tv/${tmdbId}/1/${ep}`,
    },
    {
      name: 'Rive',
      tag: 'Embed',
      available: tmdbId > 0,
      supportsAudioSelection: false,
      supportsSeek: false,
      supportsResume: false,
      urlFor: (ep) =>
        opts.isMovie
          ? `https://rivestream.us/embed?type=movie&id=${tmdbId}`
          : `https://rivestream.us/embed?type=tv&id=${tmdbId}&season=1&episode=${ep}`,
    },
    {
      name: 'Fmov',
      tag: 'Embed',
      available: tmdbId > 0,
      supportsAudioSelection: false,
      supportsSeek: false,
      supportsResume: false,
      urlFor: (ep) =>
        opts.isMovie
          ? `https://fmov.my/embed/movie/${tmdbId}`
          : `https://fmov.my/embed/anime/${tmdbId}/1/${ep}`,
    },
  ];
}

// ---------- Local Preferences & Playlists Store (mirrors AnimexStores) ----------

interface AnimexStoreState {
  titleJapanese: boolean;
  hideSpoilers: boolean;
  autoNext: boolean;
  skipIntro: boolean;
  playlists: AnimexPlaylist[];
}

const storeState: AnimexStoreState = {
  titleJapanese: false,
  hideSpoilers: true,
  autoNext: true,
  skipIntro: true,
  playlists: [],
};

let storeUser = '';
const storeChanges = new Changes<AnimexStoreState>(() => ({ ...storeState, playlists: [...storeState.playlists] }));

function persistPrefs(user: string) {
  if (!user || AgentMode.demo) return;
  try {
    localStorage.setItem(
      `animex_prefs_v1_${user}`,
      JSON.stringify({
        titleJapanese: storeState.titleJapanese,
        hideSpoilers: storeState.hideSpoilers,
        autoNext: storeState.autoNext,
        skipIntro: storeState.skipIntro,
      }),
    );
    localStorage.setItem(`animex_playlists_v1_${user}`, JSON.stringify(storeState.playlists));
  } catch {
    // ignore storage errors
  }
}

export function loadAnimexStoreForUser(user: string): void {
  if (storeUser === user) return;
  storeUser = user;
  storeState.playlists = [];
  if (!user || AgentMode.demo) {
    storeChanges.emit();
    return;
  }
  try {
    const pRaw = localStorage.getItem(`animex_prefs_v1_${user}`);
    if (pRaw) {
      const p = JSON.parse(pRaw) as Partial<AnimexStoreState>;
      storeState.titleJapanese = p.titleJapanese ?? false;
      storeState.hideSpoilers = p.hideSpoilers ?? true;
      storeState.autoNext = p.autoNext ?? true;
      storeState.skipIntro = p.skipIntro ?? true;
    }
    const plRaw = localStorage.getItem(`animex_playlists_v1_${user}`);
    if (plRaw) {
      const parsed = JSON.parse(plRaw) as AnimexPlaylist[];
      storeState.playlists = parsed.map((pl) => ({ ...pl, createdAt: new Date(pl.createdAt) }));
    }
  } catch {
    // ignore corrupt JSON
  }
  storeChanges.emit();
}

export const animexStoreSource: Source<AnimexStoreState> = (l) => storeChanges.source(l);

export const animexStoreActions = {
  setTitleJapanese(v: boolean) {
    storeState.titleJapanese = v;
    persistPrefs(storeUser);
    storeChanges.emit();
  },
  setHideSpoilers(v: boolean) {
    storeState.hideSpoilers = v;
    persistPrefs(storeUser);
    storeChanges.emit();
  },
  setAutoNext(v: boolean) {
    storeState.autoNext = v;
    persistPrefs(storeUser);
    storeChanges.emit();
  },
  setSkipIntro(v: boolean) {
    storeState.skipIntro = v;
    persistPrefs(storeUser);
    storeChanges.emit();
  },
  createPlaylist(name: string, emoji: string) {
    const id = `pl_${Date.now()}`;
    storeState.playlists = [
      { id, name: name.trim(), emoji: emoji || 'sparkles', items: [], createdAt: new Date() },
      ...storeState.playlists,
    ];
    persistPrefs(storeUser);
    storeChanges.emit();
    return id;
  },
  deletePlaylist(id: string) {
    storeState.playlists = storeState.playlists.filter((p) => p.id !== id);
    persistPrefs(storeUser);
    storeChanges.emit();
  },
  addToPlaylist(playlistId: string, item: MediaItem) {
    const key = catalogKeyOf(item);
    storeState.playlists = storeState.playlists.map((p) =>
      p.id === playlistId && !p.items.some((x) => catalogKeyOf(x) === key)
        ? { ...p, items: [item, ...p.items] }
        : p,
    );
    persistPrefs(storeUser);
    storeChanges.emit();
  },
  removeFromPlaylist(playlistId: string, item: MediaItem) {
    const key = catalogKeyOf(item);
    storeState.playlists = storeState.playlists.map((p) =>
      p.id === playlistId ? { ...p, items: p.items.filter((x) => catalogKeyOf(x) !== key) } : p,
    );
    persistPrefs(storeUser);
    storeChanges.emit();
  },
};

export function watchAnimeWatchlist(userName: string): Source<MediaItem[]> {
  const base = watchCinemaWatchlist(userName);
  return (l) =>
    base({
      data: (all) => l.data(all.filter((x) => x.isAnime)),
      error: l.error,
    });
}

export async function toggleAnimeList(item: MediaItem, userName: string, add: boolean): Promise<void> {
  await setListMembership({ ...item, isAnime: true }, userName, add);
  if (add && !AgentMode.demo && item.anilistId) {
    const snap = await getDocs(query(collection(db, 'watch_list'), where('userName', '==', userName), limit(500)));
    const existing = snap.docs.find((d) => Number(d.data().tmdbId ?? 0) === item.tmdbId);
    if (existing) {
      await updateDoc(existing.ref, {
        anilistId: item.anilistId,
        episodeCount: item.episodeCount ?? null,
        airingStatus: item.airingStatus,
        format: item.format,
        studio: item.studio,
        synopsis: item.synopsis,
      });
    } else {
      await setDoc(doc(collection(db, 'watch_list')), {
        tmdbId: item.tmdbId,
        anilistId: item.anilistId,
        title: item.title,
        mediaType: item.mediaType,
        posterPath: item.posterPath,
        backdropPath: item.backdropPath,
        year: item.year,
        status: 'to-watch',
        isAnime: true,
        userName,
        source: item.source || 'jikan',
        episodeCount: item.episodeCount ?? null,
        airingStatus: item.airingStatus,
        format: item.format,
        studio: item.studio,
        genres: item.genres,
        score: item.score ?? null,
        synopsis: item.synopsis,
        addedAt: serverTimestamp(),
      });
    }
  }
}

export async function saveAnimeWatchProgress(
  item: MediaItem,
  userName: string,
  episode: number,
  timestamp?: number,
  durationSeconds?: number,
): Promise<void> {
  await saveWatchProgress({ ...item, isAnime: true }, userName, {
    episode,
    season: 1,
    timestamp,
    durationSeconds,
    status: 'watching-self',
  });
}

export { clearWatchProgress as clearAnimeWatchProgress };

export function currentAnimeSeason(): { season: 'WINTER' | 'SPRING' | 'SUMMER' | 'FALL'; year: number } {
  const now = new Date();
  const m = now.getMonth() + 1;
  const season = m <= 3 ? 'WINTER' : m <= 6 ? 'SPRING' : m <= 9 ? 'SUMMER' : 'FALL';
  return { season, year: now.getFullYear() };
}
