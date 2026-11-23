// Faithful port of the anime title data the watch page uses:
// lib/features/anime/data/models/anilist_detail.dart, the detail half of
// anilist_service.dart, aniskip_service.dart, tmdb_anime_details.dart and
// JikanService.fetchAnimeById.
import { clearOnLogout, setBoundedCache } from '../../core/utils/boundedCache';
import { Logger } from '../../core/system/logger';
import { catalogProxyGet } from '../../shared/utils/catalogProxy';
import { TmdbImages, type MediaItem } from '../cinema/cinemaTypes';

export interface AniListVoiceActor {
  id: number;
  name: string;
  imageUrl: string;
  language: string;
}

export interface AniListCharacter {
  id: number;
  name: string;
  imageUrl: string;
  role: string;
  voiceActors: AniListVoiceActor[];
}

export interface AniListStaffMember {
  id: number;
  name: string;
  imageUrl: string;
  role: string;
}

export interface AniListSeason {
  id: number;
  malId?: number;
  title: string;
  label: string;
  coverImageUrl: string;
  format: string;
  year?: number;
  month: number;
  day: number;
  episodeCount?: number;
  isCurrent: boolean;
}

export interface AniListRelated {
  id: number;
  malId?: number;
  title: string;
  coverImageUrl: string;
  relationType: string;
  format: string;
}

export interface AniListRecommended {
  id: number;
  malId?: number;
  title: string;
  coverImageUrl: string;
  rating?: number;
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
  staff: AniListStaffMember[];
  relations: AniListRelated[];
  recommendations: AniListRecommended[];
  episodes: AniListEpisode[];
  seasons: AniListSeason[];
  nextAiringAt?: number;
  nextAiringEpisode?: number;
}

export function emptyDetail(fields: Partial<AniListDetail> & Pick<AniListDetail, 'id' | 'titleEnglish'>): AniListDetail {
  return {
    titleRomaji: '',
    titleNative: '',
    synopsis: '',
    coverImageUrl: '',
    bannerImageUrl: '',
    siteUrl: '',
    airingStatus: '',
    format: '',
    genres: [],
    studios: [],
    characters: [],
    staff: [],
    relations: [],
    recommendations: [],
    episodes: [],
    seasons: [],
    ...fields,
  };
}

type Json = Record<string, unknown>;
const obj = (v: unknown): Json | undefined => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Json) : undefined);
const list = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const maps = (v: unknown): Json[] => list(v).filter((e): e is Json => !!obj(e));
const str = (v: unknown): string | undefined => (typeof v === 'string' ? v : undefined);
const int = (v: unknown): number | undefined => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : undefined);

export function unescapeHtmlEntities(input: string): string {
  return input
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#039;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ');
}

function stripHtml(html: string): string {
  if (!html) return '';
  return unescapeHtmlEntities(html.replace(/<[^>]*>/g, ''));
}

// ---------- AniList GraphQL ----------

const ANILIST_ENDPOINT = 'https://graphql.anilist.co';

async function postGraphQL(query: string, variables: Json): Promise<Json | null> {
  await new Promise((r) => setTimeout(r, 50));
  try {
    const resp = await fetch(ANILIST_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ query, variables }),
      signal: AbortSignal.timeout(20000),
    });
    if (resp.status === 200) {
      const body = (await resp.json()) as Json;
      if (body.errors != null) {
        Logger.e(`AniList GraphQL errors: ${JSON.stringify(body.errors)}`);
        return null;
      }
      return obj(body.data) ?? null;
    }
    Logger.e(`AniList HTTP ${resp.status}: ${await resp.text().catch(() => '')}`);
    return null;
  } catch (e) {
    Logger.e('AniList request error', e);
    return null;
  }
}

const RELATION_NODE = `
          id
          idMal
          title { romaji english }
          format
          type
          seasonYear
          startDate { year month day }
          episodes
          coverImage { large medium extraLarge }`;

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
    startDate { year month day }
    endDate { year month day }
    averageScore
    meanScore
    popularity
    genres
    studios(isMain: true) { nodes { id name } }
    trailer { id site thumbnail }
    siteUrl

    characters(perPage: 12, sort: ROLE) {
      edges {
        role
        node {
          id
          name { full native }
          image { large medium }
        }
        voiceActors(language: JAPANESE) {
          id
          name { full native }
          image { large medium }
        }
      }
    }

    staff(perPage: 8) {
      edges {
        role
        node {
          id
          name { full native }
          image { medium }
        }
      }
    }

    relations {
      edges {
        relationType
        node {${RELATION_NODE}
          relations {
            edges {
              relationType
              node {${RELATION_NODE}
              }
            }
          }
        }
      }
    }

    recommendations(perPage: 10, sort: RATING_DESC) {
      nodes {
        rating
        mediaRecommendation {
          id
          idMal
          title { romaji english }
          coverImage { large medium }
        }
      }
    }

    streamingEpisodes {
      title
      url
      site
      thumbnail
    }

    nextAiringEpisode {
      airingAt
      episode
    }
  }
}
`;

const DETAIL_TTL = 10 * 60 * 1000;
const DETAIL_CACHE_MAX = 40;
const detailCache = new Map<number, { at: number; detail: AniListDetail }>();

export async function fetchDetails({ anilistId, malId }: { anilistId?: number; malId?: number }): Promise<AniListDetail | null> {
  if (anilistId == null && malId == null) return null;
  const cacheKey = anilistId ?? -malId!;
  const cached = detailCache.get(cacheKey);
  if (cached && Date.now() - cached.at < DETAIL_TTL) return cached.detail;
  const variables: Json = { type: 'ANIME' };
  if (anilistId != null) variables.id = anilistId;
  if (anilistId == null && malId != null) variables.idMal = malId;
  const data = await postGraphQL(DETAILS_QUERY, variables);
  const media = obj(data?.Media);
  if (!media) return null;
  const detail = mapDetail(media);
  setBoundedCache(detailCache, cacheKey, { at: Date.now(), detail }, DETAIL_CACHE_MAX);
  return detail;
}

export async function fetchDetailsFresh(opts: { anilistId?: number; malId?: number }): Promise<AniListDetail | null> {
  if (opts.anilistId != null) detailCache.delete(opts.anilistId);
  if (opts.malId != null) detailCache.delete(-opts.malId);
  return fetchDetails(opts);
}

export async function fetchDetailsWithFallback(opts: { anilistId?: number; malId?: number }): Promise<AniListDetail | null> {
  if (opts.anilistId == null && opts.malId == null) return null;
  const primary = await fetchDetails(opts);
  if (primary) return primary;
  if (opts.malId == null) return null;
  const jikan = await fetchJikanAnimeById(opts.malId);
  if (!jikan) return null;
  return mapJikanDetail(jikan, opts.malId);
}

function mapDetail(m: Json): AniListDetail {
  const title = obj(m.title);
  const cover = obj(m.coverImage);
  const trailer = obj(m.trailer);
  const studioNodes = maps(obj(m.studios)?.nodes);
  const episodes = int(m.episodes);
  return {
    id: int(m.id) ?? 0,
    malId: int(m.idMal),
    titleEnglish: str(title?.english) ?? '',
    titleRomaji: str(title?.romaji) ?? '',
    titleNative: str(title?.native) ?? '',
    synopsis: stripHtml(str(m.description) ?? ''),
    coverImageUrl: str(cover?.extraLarge) ?? str(cover?.large) ?? str(cover?.medium) ?? '',
    bannerImageUrl: str(m.bannerImage) ?? '',
    siteUrl: str(m.siteUrl) ?? '',
    episodeCount: episodes,
    duration: int(m.duration),
    airingStatus: str(m.status) ?? '',
    format: str(m.format) ?? '',
    season: str(m.season),
    seasonYear: int(m.seasonYear),
    averageScore: typeof m.averageScore === 'number' ? m.averageScore / 10 : undefined,
    genres: list(m.genres).filter((g): g is string => typeof g === 'string'),
    studios: studioNodes.map((s) => str(s.name) ?? '').filter((n) => n),
    trailerYoutubeId: trailer && trailer.site === 'youtube' ? str(trailer.id) : undefined,
    characters: mapCharacters(obj(m.characters)),
    staff: mapStaff(obj(m.staff)),
    relations: mapRelations(obj(m.relations)),
    seasons: mapSeasons(m),
    recommendations: mapRecommendations(obj(m.recommendations)),
    episodes: mapEpisodes(m.streamingEpisodes, episodes),
    nextAiringAt: int(obj(m.nextAiringEpisode)?.airingAt),
    nextAiringEpisode: int(obj(m.nextAiringEpisode)?.episode),
  };
}

function mapCharacters(c?: Json): AniListCharacter[] {
  if (!c) return [];
  return maps(c.edges).map((e) => {
    const node = obj(e.node) ?? {};
    const name = obj(node.name) ?? {};
    const image = obj(node.image) ?? {};
    return {
      id: int(node.id) ?? 0,
      name: str(name.full) ?? str(name.native) ?? str(name.first) ?? '',
      imageUrl: str(image.large) ?? str(image.medium) ?? '',
      role: str(e.role) ?? 'SUPPORTING',
      voiceActors: maps(e.voiceActors).map((v) => {
        const vname = obj(v.name) ?? {};
        const vimage = obj(v.image) ?? {};
        return {
          id: int(v.id) ?? 0,
          name: str(vname.full) ?? str(vname.native) ?? '',
          imageUrl: str(vimage.large) ?? str(vimage.medium) ?? '',
          language: 'JAPANESE',
        };
      }),
    };
  });
}

function mapStaff(s?: Json): AniListStaffMember[] {
  if (!s) return [];
  return maps(s.edges).map((e) => {
    const node = obj(e.node) ?? {};
    const name = obj(node.name) ?? {};
    return {
      id: int(node.id) ?? 0,
      name: str(name.full) ?? str(name.native) ?? str(name.first) ?? '',
      imageUrl: str(obj(node.image)?.medium) ?? '',
      role: str(e.role) ?? '',
    };
  });
}

const VALID_FORMATS = new Set(['TV', 'TV_SHORT', 'MOVIE', 'OVA', 'ONA', 'SPECIAL']);

function mapRelations(r?: Json): AniListRelated[] {
  if (!r) return [];
  return maps(r.edges)
    .filter((e) => {
      const node = obj(e.node) ?? {};
      const format = (str(node.format) ?? '').toUpperCase().trim();
      const type = str(node.type) ?? '';
      if (type && type !== 'ANIME') return false;
      if (format && !VALID_FORMATS.has(format)) return false;
      return true;
    })
    .map((e) => {
      const node = obj(e.node) ?? {};
      const title = obj(node.title) ?? {};
      const cover = obj(node.coverImage) ?? {};
      return {
        id: int(node.id) ?? 0,
        malId: int(node.idMal),
        title: str(title.english) ?? str(title.romaji) ?? '',
        coverImageUrl: str(cover.large) ?? str(cover.medium) ?? '',
        relationType: str(e.relationType) ?? '',
        format: str(node.format) ?? '',
      };
    });
}

const ALLOWED_RELATIONS = new Set(['SEQUEL', 'PREQUEL', 'PARENT', 'SIDE_STORY', 'SPIN_OFF', 'ALTERNATIVE', 'ADAPTATION']);

function mapSeasons(m: Json): AniListSeason[] {
  const currentId = int(m.id) ?? 0;
  const seasons = new Map<number, AniListSeason>();
  const addNode = (node: Json | undefined, relType?: string, isCurrent = false) => {
    if (!node) return;
    const id = int(node.id) ?? 0;
    if (id <= 0) return;
    const format = (str(node.format) ?? '').toUpperCase().trim();
    if (!VALID_FORMATS.has(format)) return;
    if (relType === 'SUMMARY' || relType === 'CHARACTER' || relType === 'OTHER') return;
    const t = obj(node.title);
    const english = str(t?.english);
    const title = english ? english : (str(t?.romaji) ?? '');
    if (!title) return;
    const cover = obj(node.coverImage);
    const start = obj(node.startDate);
    if (seasons.has(id)) return;
    seasons.set(id, {
      id,
      malId: int(node.idMal),
      title,
      label: title,
      coverImageUrl: str(cover?.large) ?? str(cover?.extraLarge) ?? str(cover?.medium) ?? '',
      format,
      year: int(start?.year) ?? int(node.seasonYear),
      month: int(start?.month) ?? 0,
      day: int(start?.day) ?? 0,
      episodeCount: int(node.episodes),
      isCurrent: isCurrent || id === currentId,
    });
  };
  addNode(m, undefined, true);
  for (const edge of maps(obj(m.relations)?.edges)) {
    const relType = str(edge.relationType) ?? '';
    if (!ALLOWED_RELATIONS.has(relType)) continue;
    const node = obj(edge.node);
    if (!node) continue;
    if ((str(node.type) ?? '') === 'ANIME') addNode(node, relType);
    if (relType === 'ADAPTATION' || relType === 'SEQUEL' || relType === 'PREQUEL') {
      for (const nEdge of maps(obj(node.relations)?.edges)) {
        const nRelType = str(nEdge.relationType) ?? '';
        if (!ALLOWED_RELATIONS.has(nRelType)) continue;
        const nNode = obj(nEdge.node);
        if (!nNode) continue;
        if ((str(nNode.type) ?? '') === 'ANIME') addNode(nNode, nRelType);
      }
    }
  }
  const sorted = [...seasons.values()].sort((a, b) => {
    const yA = a.year ?? 9999;
    const yB = b.year ?? 9999;
    if (yA !== yB) return yA - yB;
    if (a.month !== b.month) return a.month - b.month;
    return a.day - b.day;
  });
  return assignSeasonLabels(sorted);
}

function parseSeasonNumber(title: string): number | undefined {
  if (/\bFinal\s+Season\b/i.test(title)) return 999;
  const s = /\b(?:Season|Series)\s*(\d+)\b/i.exec(title);
  if (s) return Number.parseInt(s[1], 10);
  const ord = /\b(\d+)(?:st|nd|rd|th)\s+(?:Season|Stage)\b/i.exec(title);
  if (ord) return Number.parseInt(ord[1], 10);
  const words: Record<string, number> = { first: 1, second: 2, third: 3, fourth: 4, fifth: 5, sixth: 6 };
  const w = /\b(First|Second|Third|Fourth|Fifth|Sixth)\s+(?:Season|Stage)\b/i.exec(title);
  if (w && words[w[1].toLowerCase()] != null) return words[w[1].toLowerCase()];
  const roman = /\b(?:Season\s+)?(II|III|IV|VI|VII|VIII|IX)\b/.exec(title);
  if (roman) {
    const romans: Record<string, number> = { II: 2, III: 3, IV: 4, VI: 6, VII: 7, VIII: 8, IX: 9 };
    const val = romans[roman[1]];
    if (val != null) return val;
  }
  if (/\bSeason\s+V\b/i.test(title)) return 5;
  const end = /(?<!(?:Part|Cour|Ep|Episode|Movie|OVA|ONA|Vol|Volume)\s*)(?:^|\s+)(\d{1,2})(?:\s*[:\-—]|\s*$)/i.exec(title);
  if (end) {
    const n = Number.parseInt(end[1], 10);
    if (n >= 2 && n <= 20) return n;
  }
  return undefined;
}

function parsePartNumber(title: string): number | undefined {
  const p = /\b(?:Part|Cour)\s*(\d+)\b/i.exec(title);
  if (p) return Number.parseInt(p[1], 10);
  const ord = /\b(\d+)(?:st|nd|rd|th)\s+Cour\b/i.exec(title);
  if (ord) return Number.parseInt(ord[1], 10);
  const roman = /\bPart\s+(II|III|IV|V)\b/i.exec(title);
  if (roman) return ({ II: 2, III: 3, IV: 4, V: 5 } as Record<string, number>)[roman[1].toUpperCase()];
  return undefined;
}

export function assignSeasonLabels(seasons: AniListSeason[]): AniListSeason[] {
  if (!seasons.length) return seasons;
  const formatCounts = new Map<string, number>();
  for (const s of seasons) {
    const fmt = s.format.toUpperCase().trim();
    formatCounts.set(fmt, (formatCounts.get(fmt) ?? 0) + 1);
  }
  const hasTv = (formatCounts.get('TV') ?? 0) > 0 || (formatCounts.get('TV_SHORT') ?? 0) > 0;
  const formatIndices = new Map<string, number>();
  let currentSeasonNum = 0;
  return seasons.map((s) => {
    const fmt = s.format.toUpperCase().trim();
    const indexInFormat = (formatIndices.get(fmt) ?? 0) + 1;
    formatIndices.set(fmt, indexInFormat);
    const totalInFormat = formatCounts.get(fmt) ?? 0;
    let label: string;
    const isEpisodic = fmt === 'TV' || fmt === 'TV_SHORT' || (!hasTv && fmt === 'ONA');
    if (isEpisodic) {
      const explicitSeason = parseSeasonNumber(s.title);
      const explicitPart = parsePartNumber(s.title);
      const partSuffix = explicitPart != null && explicitPart > 1 ? ` Part ${explicitPart}` : '';
      if (explicitSeason === 999) {
        label = `Final Season${partSuffix}`;
      } else if (explicitSeason != null) {
        currentSeasonNum = explicitSeason;
        label = `Season ${explicitSeason}${partSuffix}`;
      } else if (explicitPart != null && explicitPart > 1 && currentSeasonNum > 0) {
        label = `Season ${currentSeasonNum} Part ${explicitPart}`;
      } else {
        currentSeasonNum = currentSeasonNum === 0 ? 1 : currentSeasonNum + 1;
        label = `Season ${currentSeasonNum}${partSuffix}`;
      }
    } else if (fmt === 'OVA') {
      label = totalInFormat > 1 ? `OVA ${indexInFormat}` : 'OVA';
    } else if (fmt === 'ONA') {
      label = totalInFormat > 1 ? `ONA ${indexInFormat}` : 'ONA';
    } else if (fmt === 'MOVIE') {
      label = totalInFormat > 1 ? `Movie ${indexInFormat}` : 'Movie';
    } else if (fmt === 'SPECIAL') {
      label = totalInFormat > 1 ? `Special ${indexInFormat}` : 'Special';
    } else {
      label = s.title;
    }
    return { ...s, label };
  });
}

function mapRecommendations(r?: Json): AniListRecommended[] {
  if (!r) return [];
  return maps(r.nodes).map((n) => {
    const media = obj(n.mediaRecommendation) ?? {};
    const title = obj(media.title) ?? {};
    const cover = obj(media.coverImage) ?? {};
    return {
      id: int(media.id) ?? 0,
      malId: int(media.idMal),
      title: str(title.english) ?? str(title.romaji) ?? '',
      coverImageUrl: str(cover.large) ?? str(cover.medium) ?? '',
      rating: int(n.rating),
    };
  });
}

export function mapEpisodes(streaming: unknown, episodeCount?: number): AniListEpisode[] {
  const byNum = new Map<number, AniListEpisode>();
  let autoIndex = 1;
  for (const e of maps(streaming)) {
    const rawTitle = str(e.title);
    const thumb = str(e.thumbnail);
    let epNum = int(e.number) ?? 0;
    let cleanTitle = rawTitle;
    if (rawTitle != null) {
      const m = /^Episode\s+(\d+)\s*(?:-\s*(.*))?$/i.exec(rawTitle.trim());
      if (m) {
        if (epNum === 0) epNum = Number.parseInt(m[1] ?? '', 10) || 0;
        const rest = m[2]?.trim();
        if (rest) cleanTitle = rest;
      }
    }
    if (epNum <= 0) epNum = autoIndex;
    autoIndex = epNum + 1;
    byNum.set(epNum, {
      number: epNum,
      title: cleanTitle,
      airedAt: typeof e.airingAt === 'number' ? new Date(Math.trunc(e.airingAt) * 1000) : undefined,
      thumbnail: thumb ? thumb : undefined,
    });
  }
  const maxAnilistEp = byNum.size ? Math.max(...byNum.keys()) : undefined;
  const maxEp = episodeCount != null && episodeCount > 0 ? episodeCount : (maxAnilistEp ?? 0);
  const out: AniListEpisode[] = [];
  for (let i = 1; i <= maxEp; i++) out.push(byNum.get(i) ?? { number: i });
  return out;
}

// ---------- Jikan (through proxyCatalog) ----------

export async function fetchJikanAnimeById(malId: number): Promise<Json | null> {
  for (let attempt = 0; ; attempt++) {
    try {
      const resp = await catalogProxyGet('jikan', `anime/${malId}`, { timeoutMs: 20000 });
      if (resp.status === 200) return obj(await resp.json()) ?? null;
      if (resp.status === 429 && attempt < 3) {
        const retryAfter = Number(resp.headers.get('retry-after'));
        const wait = Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : Math.min(1000 * 2 ** attempt, 8000);
        await new Promise((r) => setTimeout(r, Math.min(wait, 8000)));
        continue;
      }
      Logger.e(`[Jikan] /anime/${malId} failed (${resp.status})`);
      return null;
    } catch (e) {
      Logger.e(`[Jikan] /anime/${malId} error`, e);
      return null;
    }
  }
}

// Same as Flutter: it maps the raw response, so most fields come back empty.
function mapJikanDetail(j: Json, fallbackMalId: number): AniListDetail {
  const jpg = obj(obj(j.images)?.jpg);
  const pickImage = (size: string) => str(jpg?.[size]) ?? '';
  const trailer = obj(j.trailer);
  const ytId = str(trailer?.youtube_id) ?? (str(trailer?.url)?.split('v=').pop() ?? '');
  const malId = int(j.mal_id) ?? fallbackMalId;
  const episodeCount = int(j.episodes);
  const durationDigits = (str(j.duration) ?? '').replace(/[^0-9]/g, '');
  return emptyDetail({
    id: 0,
    malId,
    titleEnglish: str(j.title_english) ?? str(j.title) ?? '',
    titleRomaji: str(j.title_japanese) ?? '',
    synopsis: stripHtml(str(j.synopsis) ?? ''),
    coverImageUrl: pickImage('large_image_url') || pickImage('image_url'),
    bannerImageUrl: pickImage('extra_large_image_url'),
    episodeCount,
    duration: durationDigits ? Number.parseInt(durationDigits, 10) : undefined,
    airingStatus: str(j.status) ?? '',
    format: str(j.type) ?? '',
    season: str(j.season),
    seasonYear: int(j.year),
    averageScore: typeof j.score === 'number' ? j.score : undefined,
    genres: maps(j.genres)
      .map((g) => str(g.name) ?? '')
      .filter((n) => n),
    studios: maps(j.studios)
      .map((s) => str(s.name) ?? '')
      .filter((n) => n),
    trailerYoutubeId: ytId && ytId !== 'null' ? ytId : undefined,
    episodes: episodeCount && episodeCount > 0 ? Array.from({ length: episodeCount }, (_, i) => ({ number: i + 1 })) : [],
  });
}

// ---------- AniSkip (through proxyCatalog) ----------

export interface AniSkipTime {
  start: number;
  end: number;
}

export interface AniSkipTimes {
  opening?: AniSkipTime;
  ending?: AniSkipTime;
}

export function skipEndLabel(time: AniSkipTime): string {
  const total = Math.round(time.end);
  return `${Math.trunc(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

export const skipVisibleAt = (time: AniSkipTime, position: number) => position >= time.start && position <= time.end;

export function parseAniSkipTimes(json: Json): AniSkipTimes {
  const out: AniSkipTimes = {};
  for (const r of maps(json.results)) {
    const interval = obj(r.interval);
    if (!interval) continue;
    const start = typeof interval.start_time === 'number' ? interval.start_time : undefined;
    const end = typeof interval.end_time === 'number' ? interval.end_time : undefined;
    if (start == null || end == null || end <= start || start < 0) continue;
    const type = String(r.skip_type ?? '');
    if (type === 'op') out.opening ??= { start, end };
    else if (type === 'ed') out.ending ??= { start, end };
  }
  return out;
}

const SKIP_CACHE_MAX = 200;
const skipCache = new Map<string, AniSkipTimes>();

clearOnLogout(detailCache, skipCache);

export async function fetchSkipTimes(malId: number, episode: number): Promise<AniSkipTimes | null> {
  if (malId <= 0 || episode <= 0) return null;
  const key = `${malId}:${episode}`;
  if (skipCache.has(key)) return skipCache.get(key)!;
  try {
    const resp = await catalogProxyGet('aniskip', `v1/skip-times/${malId}/${episode}?types[]=op&types[]=ed`);
    if (resp.status === 404) {
      setBoundedCache(skipCache, key, {}, SKIP_CACHE_MAX);
      return {};
    }
    if (resp.status !== 200) {
      Logger.e(`[AniSkip] ${key} failed (${resp.status})`);
      return null;
    }
    const json = obj(await resp.json());
    if (!json) return null;
    const times = parseAniSkipTimes(json);
    setBoundedCache(skipCache, key, times, SKIP_CACHE_MAX);
    return times;
  } catch (e) {
    Logger.e(`[AniSkip] ${key} error`, e);
    return null;
  }
}

// ---------- TMDB-sourced anime (tmdb_anime_details.dart) ----------

export type EpisodeSlots = Map<number, { season: number; episode: number }>;

export const mediaIsMovie = (item: MediaItem) =>
  item.mediaType.trim().toLowerCase() !== 'tv' || item.format.trim().toLowerCase() === 'movie';

export const mediaPosterUrl = (item: MediaItem) => TmdbImages.posterFor(item.posterPath);

export function mapTmdbAnimeDetails(item: MediaItem, data: Json): { detail: AniListDetail; slots: EpisodeSlots } {
  const slots: EpisodeSlots = new Map();
  const seasons = maps(data.seasons)
    .filter((s) => (typeof s.season_number === 'number' ? s.season_number : 0) > 0)
    .sort((a, b) => (a.season_number as number) - (b.season_number as number));
  for (const season of seasons.slice(0, 30)) {
    const number = Math.trunc(season.season_number as number);
    const count = Math.min(Math.max(int(season.episode_count) ?? 0, 0), 500);
    for (let episode = 1; episode <= count && slots.size < 2000; episode++) {
      slots.set(slots.size + 1, { season: number, episode });
    }
  }
  const isMovie = mediaIsMovie(item);
  return {
    detail: emptyDetail({
      id: 0,
      titleEnglish: String(data.name ?? data.title ?? item.title),
      synopsis: str(data.overview) ?? item.synopsis,
      coverImageUrl: mediaPosterUrl(item),
      bannerImageUrl: item.backdropPath,
      episodeCount: isMovie ? 1 : slots.size,
      duration: int(data.runtime),
      airingStatus: str(data.status) ?? '',
      format: isMovie ? 'MOVIE' : 'TV',
      genres: maps(data.genres).map((g) => String(g.name)),
    }),
    slots,
  };
}
