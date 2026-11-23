import { extractChapterNumber, type KatanaBookmark, type KatanaManga } from './katanaService';
import { inferSeriesReadingFormat } from './readerSpread';

export interface OfficialPublisherLink {
  id: string;
  name: string;
  badge: string;
  url: string;
  icon: string;
  category: 'publisher' | 'tracker' | 'registry';
  /** True only when `url` points directly to the exact series page (not a generic search query). */
  directLink: boolean;
  /** True only when the link is an established official publisher or licensed store URL (never true for trackers or search queries). */
  officialSimulpub: boolean;
}

export interface SourceBadgeInfo {
  id: NonNullable<KatanaManga['source']>;
  badge: 'MK' | 'MD' | 'CK' | 'BT';
  shortLabel: string;
  name: string;
  /** Small tie-breaker preference bonus (2–8 pts) used only after title match and metadata completeness signals. */
  searchPreferenceBonus: number;
  signals: {
    provenance: string;
    metadataQuality: string;
    specialty: string;
  };
  tooltip: string;
}

export const SOURCE_TRUST_META: Record<NonNullable<KatanaManga['source']>, SourceBadgeInfo> = {
  mangadex: {
    id: 'mangadex',
    badge: 'MD',
    shortLabel: 'MangaDex',
    name: 'MangaDex',
    searchPreferenceBonus: 8,
    signals: {
      provenance: 'Community scanlation index (unlicensed)',
      metadataQuality: 'Includes tracker IDs, publisher links & language tags',
      specialty: 'Multilingual chapters & group attribution',
    },
    tooltip:
      'MangaDex (MD) — Community scanlation index · Includes official publisher links, tracker IDs & group attribution',
  },
  mangakatana: {
    id: 'mangakatana',
    badge: 'MK',
    shortLabel: 'Katana',
    name: 'MangaKatana',
    searchPreferenceBonus: 6,
    signals: {
      provenance: 'Community chapter aggregator (unlicensed)',
      metadataQuality: 'Standard title, author, genre & chapter timestamps',
      specialty: 'Fast chapter feed & multi-CDN reader mirrors',
    },
    tooltip:
      'MangaKatana (MK) — Community chapter aggregator · Fast release feed & multi-CDN reader mirrors',
  },
  comick: {
    id: 'comick',
    badge: 'CK',
    shortLabel: 'ComicK',
    name: 'ComicK',
    searchPreferenceBonus: 4,
    signals: {
      provenance: 'Community chapter & volume index (unlicensed)',
      metadataQuality: 'Alt-title index & volume cover metadata',
      specialty: 'Tankobon releases & fallback chapter mirrors',
    },
    tooltip:
      'ComicK (CK) — Community chapter index · Alt-title catalog & volume chapters',
  },
  bato: {
    id: 'bato',
    badge: 'BT',
    shortLabel: 'Bato.to',
    name: 'Bato.to',
    searchPreferenceBonus: 2,
    signals: {
      provenance: 'Community mirror catalog (unlicensed)',
      metadataQuality: 'Basic series & chapter metadata',
      specialty: 'Full-color webtoon & long-strip series',
    },
    tooltip:
      'Bato.to (BT) — Community mirror catalog · Full-color webtoon & long-strip catalog',
  },
};

export function getSourceBadgeInfo(
  source?: KatanaManga['source'],
  slug?: string,
): SourceBadgeInfo {
  if (source && SOURCE_TRUST_META[source]) return SOURCE_TRUST_META[source];
  if (slug?.startsWith('md-')) return SOURCE_TRUST_META.mangadex;
  if (slug?.startsWith('ck-')) return SOURCE_TRUST_META.comick;
  if (slug?.startsWith('bt-')) return SOURCE_TRUST_META.bato;
  return SOURCE_TRUST_META.mangakatana;
}

const SOURCE_PREFERENCE_BONUS: Record<NonNullable<KatanaManga['source']>, number> = {
  mangadex: SOURCE_TRUST_META.mangadex.searchPreferenceBonus,
  mangakatana: SOURCE_TRUST_META.mangakatana.searchPreferenceBonus,
  comick: SOURCE_TRUST_META.comick.searchPreferenceBonus,
  bato: SOURCE_TRUST_META.bato.searchPreferenceBonus,
};

export function normalizeCanonicalTitle(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/\b(the|a|an)\b/g, ' ')
    .replace(/[^a-z0-9\u3040-\u30ff\u4e00-\u9faf\uac00-\ud7af]+/g, '')
    .trim();
}

function tokenizeQuery(raw: string): string[] {
  return raw
    .toLowerCase()
    .split(/[^a-z0-9\u3040-\u30ff\u4e00-\u9faf\uac00-\ud7af]+/)
    .map((s) => s.trim())
    .filter((s) => s.length >= 2);
}

/**
 * Scores a catalog item by explainable signals: query match accuracy, metadata completeness
 * (linked tracker IDs, alt titles, author/genre presence, chapter count), reader rating/popularity,
 * and a small catalog search preference tie-breaker.
 */
export function computeMangaSearchRelevance(
  item: KatanaManga,
  query: string,
  orderBy = 'popular',
): number {
  let score = SOURCE_PREFERENCE_BONUS[item.source ?? 'mangakatana'] ?? 4;
  // Explainable metadata completeness & official link availability signals
  if (
    item.externalLinks?.officialEnglishUrl ||
    item.externalLinks?.rawOfficialUrl ||
    item.externalLinks?.bookwalkerPath
  ) {
    score += 14;
  }
  if (
    item.externalLinks?.anilistId ||
    item.externalLinks?.malId ||
    item.externalLinks?.kitsuId ||
    item.externalLinks?.mangaUpdatesId
  ) {
    score += 10;
  }
  if ((item.altNames?.length ?? 0) > 0) score += 6;
  if ((item.authors?.length ?? 0) > 0 && item.genres.length > 0) score += 6;
  const qClean = query.trim().toLowerCase();
  const qNorm = normalizeCanonicalTitle(query);
  const titleLower = item.title.trim().toLowerCase();
  const titleNorm = normalizeCanonicalTitle(item.title);
  const altNorms = (item.altNames ?? []).map(normalizeCanonicalTitle).filter(Boolean);

  if (qNorm.length > 0) {
    if (titleNorm === qNorm || titleLower === qClean) {
      score += 1000;
    } else if (altNorms.includes(qNorm)) {
      score += 880;
    } else if (titleNorm.startsWith(qNorm) || titleLower.startsWith(qClean)) {
      score += 620;
    } else if (altNorms.some((a) => a.startsWith(qNorm))) {
      score += 520;
    } else if (titleNorm.includes(qNorm)) {
      score += 380;
    } else if (altNorms.some((a) => a.includes(qNorm))) {
      score += 310;
    }

    const tokens = tokenizeQuery(query);
    if (tokens.length > 0) {
      const hayTitle = [item.title, ...(item.altNames ?? [])].join(' ').toLowerCase();
      const hayMeta = [...(item.authors ?? []), item.summary ?? ''].join(' ').toLowerCase();
      let titleHits = 0;
      let metaHits = 0;
      for (const tok of tokens) {
        if (hayTitle.includes(tok)) titleHits += 1;
        else if (hayMeta.includes(tok)) metaHits += 1;
      }
      if (titleHits === tokens.length) score += 320;
      score += Math.round((titleHits / tokens.length) * 200);
      score += Math.round((metaHits / tokens.length) * 70);
    }

    // Penalize overly long peripheral titles when query is short
    const lenDiff = Math.max(0, titleNorm.length - qNorm.length);
    score -= Math.min(80, Math.floor(lenDiff * 1.5));
  }

  // Quality & popularity signals
  if (typeof item.rating === 'number' && item.rating > 0) {
    score += Math.min(120, Math.round(item.rating * 12));
  }
  if (typeof item.follows === 'number' && item.follows > 0) {
    score += Math.min(85, Math.round(Math.log10(item.follows + 1) * 18));
  }
  const chCount =
    item.chapterCount ??
    extractChapterNumber(item.latestChapter?.num || item.latestChapter?.title || '');
  if (chCount > 0) {
    score += Math.min(55, Math.round(Math.sqrt(chCount) * 3.5));
  }
  if (item.coverUrl && !item.coverUrl.startsWith('data:')) {
    score += 10;
  }

  // Respect explicit sort mode when browsing without a text query
  if (!qNorm) {
    if (orderBy === 'az') {
      return -item.title.toLowerCase().charCodeAt(0) * 100 + score;
    }
    if (orderBy === 'numc') {
      return chCount * 20 + score;
    }
  }

  return score;
}

function extractYearQualifier(title: string, slug = ''): string {
  const m = /\b(19[7-9]\d|20[0-3]\d)\b/.exec(`${title} ${slug}`);
  return m ? m[1] : '';
}

function normalizeAuthorToken(authors?: string[]): string {
  if (!authors || authors.length === 0) return '';
  return authors[0]
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '')
    .trim();
}

function hasConflictingMetadata(a: KatanaManga, b: KatanaManga): boolean {
  const authorA = normalizeAuthorToken(a.authors);
  const authorB = normalizeAuthorToken(b.authors);
  if (authorA && authorB && authorA !== authorB && !authorA.includes(authorB) && !authorB.includes(authorA)) {
    return true;
  }
  const demoA = (a.demographic ?? '').trim().toLowerCase();
  const demoB = (b.demographic ?? '').trim().toLowerCase();
  if (demoA && demoB && demoA !== demoB) {
    return true;
  }
  const yearA = extractYearQualifier(a.title, a.slug);
  const yearB = extractYearQualifier(b.title, b.slug);
  if (yearA && yearB && yearA !== yearB) {
    return true;
  }
  return false;
}

/**
 * Merges and deduplicates multi-source search results (`mangakatana`, `mangadex`, `comick`, `bato`)
 * using tracker IDs and author/year/demographic-aware canonical titles/altNames, preserving the freshest
 * latest-chapter metadata and sorting by relevance score instead of naive round-robin.
 */
export function rankAndMergeMultiSourceCatalog(args: {
  query: string;
  orderBy?: string;
  katanaItems: KatanaManga[];
  mangadexItems: KatanaManga[];
  comickItems: KatanaManga[];
  batoItems: KatanaManga[];
  bookmarks?: KatanaBookmark[];
}): KatanaManga[] {
  const {
    query,
    orderBy = 'popular',
    katanaItems,
    mangadexItems,
    comickItems,
    batoItems,
    bookmarks = [],
  } = args;

  const trackerKeyBySlug = new Map<string, string>();
  for (const bm of bookmarks) {
    const tKey =
      (bm.anilistId && `al:${bm.anilistId}`) ||
      (bm.malId && `mal:${bm.malId}`) ||
      (bm.kitsuId && `kt:${bm.kitsuId}`) ||
      (bm.mangaUpdatesId && `mu:${bm.mangaUpdatesId}`) ||
      '';
    if (!tKey) continue;
    trackerKeyBySlug.set(bm.slug, tKey);
  }

  const allCandidates = [...katanaItems, ...mangadexItems, ...comickItems, ...batoItems];
  const scored = allCandidates.map((item, idx) => ({
    item,
    score: computeMangaSearchRelevance(item, query, orderBy),
    idx,
  }));

  // Sort highest relevance first before deduplicating so the best-matching source wins the canonical slot
  scored.sort((a, b) => b.score - a.score || a.idx - b.idx);

  const byCanonicalKey = new Map<string, { item: KatanaManga; score: number }>();
  const slugSeen = new Set<string>();

  for (const entry of scored) {
    const { item, score } = entry;
    if (slugSeen.has(item.slug)) continue;
    slugSeen.add(item.slug);

    const ext = item.externalLinks;
    const itemTrackerKey =
      trackerKeyBySlug.get(item.slug) ||
      (ext?.anilistId && `al:${ext.anilistId}`) ||
      (ext?.malId && `mal:${ext.malId}`) ||
      (ext?.kitsuId && `kt:${ext.kitsuId}`) ||
      (ext?.mangaUpdatesId && `mu:${ext.mangaUpdatesId}`) ||
      '';

    const normTitle = normalizeCanonicalTitle(item.title);
    const yearQual = extractYearQualifier(item.title, item.slug);
    const baseTitleKey = normTitle ? (yearQual ? `${normTitle}:${yearQual}` : normTitle) : item.slug;
    let canonicalKey = itemTrackerKey || baseTitleKey;

    let existing = byCanonicalKey.get(canonicalKey);
    if (existing && !itemTrackerKey && hasConflictingMetadata(existing.item, item)) {
      const disambiguator =
        normalizeAuthorToken(item.authors) ||
        (item.demographic ?? '').trim().toLowerCase() ||
        extractYearQualifier(item.title, item.slug) ||
        item.slug;
      canonicalKey = `${baseTitleKey}|${disambiguator}`;
      existing = byCanonicalKey.get(canonicalKey);
    }

    if (!existing) {
      byCanonicalKey.set(canonicalKey, { item, score });
      continue;
    }

    // Merge richest metadata & freshest chapter across duplicate source hits
    const prev = existing.item;
    const prevChNum = extractChapterNumber(prev.latestChapter?.num || prev.latestChapter?.title || '');
    const nextChNum = extractChapterNumber(item.latestChapter?.num || item.latestChapter?.title || '');
    const fresherLatest = nextChNum > prevChNum ? item.latestChapter : prev.latestChapter ?? item.latestChapter;
    const mergedGenres =
      prev.genres.length >= item.genres.length
        ? prev.genres
        : item.genres;
    const mergedAltNames = Array.from(new Set([...(prev.altNames ?? []), ...(item.altNames ?? [])])).slice(0, 8);

    existing.item = {
      ...prev,
      coverUrl: prev.coverUrl || item.coverUrl,
      summary: (prev.summary?.length ?? 0) >= (item.summary?.length ?? 0) ? prev.summary : item.summary,
      rating: prev.rating ?? item.rating,
      follows: Math.max(prev.follows ?? 0, item.follows ?? 0) || prev.follows || item.follows,
      chapterCount: Math.max(prev.chapterCount ?? 0, item.chapterCount ?? 0, Math.floor(Math.max(prevChNum, nextChNum))) || undefined,
      latestChapter: fresherLatest,
      genres: mergedGenres,
      altNames: mergedAltNames,
      releaseDay: prev.releaseDay ?? item.releaseDay,
      externalLinks: {
        ...(item.externalLinks ?? {}),
        ...(prev.externalLinks ?? {}),
      },
    };
  }

  return Array.from(byCanonicalKey.values())
    .sort((a, b) => b.score - a.score)
    .map((e) => e.item);
}

function describeOfficialPublisherUrl(
  url: string,
  kind: 'english' | 'raw',
): { name: string; platformKey?: 'mangaplus' | 'viz' | 'webtoon' | 'tapas' | 'bookwalker' } {
  const lower = url.toLowerCase();
  if (lower.includes('mangaplus.shueisha.co.jp')) {
    return { name: 'Read on MANGA Plus (Official)', platformKey: 'mangaplus' };
  }
  if (lower.includes('viz.com')) {
    return { name: 'Read on VIZ / Shonen Jump (Official)', platformKey: 'viz' };
  }
  if (lower.includes('webtoons.com')) {
    return { name: 'Read on WEBTOON (Official)', platformKey: 'webtoon' };
  }
  if (lower.includes('tapas.io')) {
    return { name: 'Read on Tapas (Official)', platformKey: 'tapas' };
  }
  if (lower.includes('bookwalker.jp')) {
    return { name: 'Read on BookWalker (Official)', platformKey: 'bookwalker' };
  }
  if (lower.includes('kodansha.us')) {
    return { name: 'Read on Kodansha (Official)' };
  }
  if (lower.includes('yenpress.com')) {
    return { name: 'Read on Yen Press (Official)' };
  }
  if (lower.includes('sevenseasentertainment.com')) {
    return { name: 'Read on Seven Seas (Official)' };
  }
  if (lower.includes('j-novel.club')) {
    return { name: 'Read on J-Novel Club (Official)' };
  }
  if (lower.includes('shonenjumpplus.com')) {
    return { name: 'Shonen Jump+ (Original Official)' };
  }
  if (lower.includes('kadocomi.jp') || lower.includes('comic-walker.com')) {
    return { name: 'KadoComi (Original Official)' };
  }
  if (lower.includes('pocket.shonenmagazine.com')) {
    return { name: 'Magazine Pocket (Original Official)' };
  }
  return {
    name: kind === 'english' ? 'Read on Official English Publisher' : 'Original Publisher Page (Official)',
  };
}

export function getPrimaryVerifiedOfficialLink(
  manga: Pick<KatanaManga, 'slug' | 'title' | 'genres' | 'demographic' | 'altNames' | 'externalLinks'>,
  bookmark?: Pick<KatanaBookmark, 'malId' | 'anilistId' | 'kitsuId' | 'mangaUpdatesId'> | null,
): OfficialPublisherLink | null {
  const all = resolveOfficialPublisherLinks(manga, bookmark);
  return all.find((l) => l.category === 'publisher' && l.directLink && l.officialSimulpub) ?? null;
}

/**
 * Resolves verified direct series deep links (when an exact official English URL, raw publisher URL,
 * BookWalker path, AniList ID, MyAnimeList ID, Kitsu ID, or MangaUpdates ID is known) FIRST,
 * followed by clearly separated and labeled publisher catalog search queries (MANGA Plus, VIZ,
 * WEBTOON, Tapas, BookWalker).
 */
export function resolveOfficialPublisherLinks(
  manga: Pick<KatanaManga, 'slug' | 'title' | 'genres' | 'demographic' | 'altNames' | 'externalLinks'>,
  bookmark?: Pick<KatanaBookmark, 'malId' | 'anilistId' | 'kitsuId' | 'mangaUpdatesId'> | null,
): OfficialPublisherLink[] {
  const q = encodeURIComponent(manga.title.trim());
  const format = inferSeriesReadingFormat(
    manga.genres.map((g) => g.name),
    manga.title,
    manga.demographic,
    manga.altNames,
    manga.slug,
  );
  const ext = manga.externalLinks;
  const anilistId = bookmark?.anilistId || ext?.anilistId;
  const malId = bookmark?.malId || ext?.malId;
  const kitsuId = bookmark?.kitsuId || ext?.kitsuId;
  const muId = bookmark?.mangaUpdatesId || ext?.mangaUpdatesId;

  const links: OfficialPublisherLink[] = [];
  const coveredPlatforms = new Set<string>();

  if (ext?.officialEnglishUrl && /^https?:\/\//i.test(ext.officialEnglishUrl)) {
    const desc = describeOfficialPublisherUrl(ext.officialEnglishUrl, 'english');
    if (desc.platformKey) coveredPlatforms.add(desc.platformKey);
    links.push({
      id: 'official-en',
      name: desc.name,
      badge: 'Verified Official Series Link',
      url: ext.officialEnglishUrl,
      icon: 'verified',
      category: 'publisher',
      directLink: true,
      officialSimulpub: true,
    });
  }
  if (ext?.rawOfficialUrl && /^https?:\/\//i.test(ext.rawOfficialUrl)) {
    const desc = describeOfficialPublisherUrl(ext.rawOfficialUrl, 'raw');
    if (desc.platformKey) coveredPlatforms.add(desc.platformKey);
    links.push({
      id: 'official-raw',
      name: desc.name,
      badge: 'Verified Official Publisher Page',
      url: ext.rawOfficialUrl,
      icon: 'verified',
      category: 'publisher',
      directLink: true,
      officialSimulpub: true,
    });
  }

  const bwPath = ext?.bookwalkerPath?.replace(/^\/+/, '');
  if (bwPath) {
    coveredPlatforms.add('bookwalker');
    links.push({
      id: 'bookwalker',
      name: 'BookWalker Official Store',
      badge: 'Verified Direct Store Page',
      url: `https://bookwalker.jp/${bwPath}`,
      icon: 'collections_bookmark',
      category: 'publisher',
      directLink: true,
      officialSimulpub: true,
    });
  }

  if (format === 'webtoon') {
    if (!coveredPlatforms.has('webtoon')) {
      links.push({
        id: 'webtoon',
        name: 'WEBTOON Catalog Search',
        badge: 'Catalog search query only — not a verified official chapter',
        url: `https://www.webtoons.com/en/search?keyword=${q}`,
        icon: 'search',
        category: 'publisher',
        directLink: false,
        officialSimulpub: false,
      });
    }
    if (!coveredPlatforms.has('tapas')) {
      links.push({
        id: 'tapas',
        name: 'Tapas Catalog Search',
        badge: 'Catalog search query only — not a verified official chapter',
        url: `https://tapas.io/search?q=${q}`,
        icon: 'search',
        category: 'publisher',
        directLink: false,
        officialSimulpub: false,
      });
    }
  } else {
    if (!coveredPlatforms.has('mangaplus')) {
      links.push({
        id: 'mangaplus',
        name: 'MANGA Plus Catalog Search',
        badge: 'Catalog search query only — not a verified official chapter',
        url: `https://mangaplus.shueisha.co.jp/search_result?keyword=${q}`,
        icon: 'search',
        category: 'publisher',
        directLink: false,
        officialSimulpub: false,
      });
    }
    if (!coveredPlatforms.has('viz')) {
      links.push({
        id: 'viz',
        name: 'VIZ Catalog Search',
        badge: 'Catalog search query only — not a verified official chapter',
        url: `https://www.viz.com/search?search=${q}`,
        icon: 'search',
        category: 'publisher',
        directLink: false,
        officialSimulpub: false,
      });
    }
  }

  if (!coveredPlatforms.has('bookwalker')) {
    links.push({
      id: 'bookwalker',
      name: 'BookWalker Catalog Search',
      badge: 'Catalog search query only — not a verified official chapter',
      url: `https://global.bookwalker.jp/search/?word=${q}`,
      icon: 'search',
      category: 'publisher',
      directLink: false,
      officialSimulpub: false,
    });
  }

  if (anilistId) {
    links.push({
      id: 'anilist-direct',
      name: `AniList #${anilistId}`,
      badge: 'Tracker Entry (Matched ID)',
      url: `https://anilist.co/manga/${encodeURIComponent(anilistId)}`,
      icon: 'query_stats',
      category: 'tracker',
      directLink: true,
      officialSimulpub: false,
    });
  }
  if (malId) {
    links.push({
      id: 'mal-direct',
      name: `MyAnimeList #${malId}`,
      badge: 'Tracker Entry (Matched ID)',
      url: `https://myanimelist.net/manga/${encodeURIComponent(malId)}`,
      icon: 'query_stats',
      category: 'tracker',
      directLink: true,
      officialSimulpub: false,
    });
  }
  if (kitsuId) {
    links.push({
      id: 'kitsu-direct',
      name: `Kitsu #${kitsuId}`,
      badge: 'Tracker Entry (Matched ID)',
      url: `https://kitsu.app/manga/${encodeURIComponent(kitsuId)}`,
      icon: 'query_stats',
      category: 'tracker',
      directLink: true,
      officialSimulpub: false,
    });
  }
  if (muId) {
    links.push({
      id: 'mangaupdates',
      name: 'MangaUpdates',
      badge: 'Release & License Database',
      url: `https://www.mangaupdates.com/series/${encodeURIComponent(muId)}`,
      icon: 'fact_check',
      category: 'registry',
      directLink: true,
      officialSimulpub: false,
    });
  }

  return links;
}

/**
 * Estimates offline download size (in MB) before queuing 1 or more chapters, using observed
 * average chapter size on this device when available, or realistic format-specific defaults
 * (~4.2 MB/ch for paged manga, ~6.4 MB/ch for long-strip webtoons).
 */
export function estimateMangaBatchMegabytes(
  chaptersCount: number,
  isWebtoon = false,
  downloadedItems?: ReadonlyArray<{ downloadedBytes?: number; totalBytes?: number }>,
): { megabytes: number; perChapterMb: number; label: string } {
  const count = Math.max(0, Math.floor(chaptersCount));
  let avgBytes = isWebtoon ? 6.4 * 1024 * 1024 : 4.2 * 1024 * 1024;
  if (downloadedItems && downloadedItems.length > 0) {
    const valid = downloadedItems
      .map((it) => (it.downloadedBytes && it.downloadedBytes > 100_000 ? it.downloadedBytes : it.totalBytes || 0))
      .filter((b) => b > 100_000);
    if (valid.length >= 2) {
      const sum = valid.reduce((a, b) => a + b, 0);
      avgBytes = Math.min(18 * 1024 * 1024, Math.max(1.5 * 1024 * 1024, sum / valid.length));
    }
  }
  const perChapterMb = Number((avgBytes / (1024 * 1024)).toFixed(1));
  const megabytes = Number(((avgBytes * count) / (1024 * 1024)).toFixed(count <= 2 ? 1 : 0));
  const label =
    count <= 0
      ? '0 MB'
      : megabytes >= 1000
        ? `~${(megabytes / 1024).toFixed(1)} GB`
        : `~${megabytes} MB`;
  return { megabytes, perChapterMb, label };
}

export interface ChapterGapSegment {
  afterNum: number;
  beforeNum: number;
  missingNums: number[];
  label: string;
  beforeChapterId: string;
  afterChapterId: string;
}

/**
 * Uchiyomi-style Chapter Health scan: inspects a series' chapter list for missing integer chapter
 * numbers so the detail page can list exact gaps and offer one-tap jump or cross-source repair.
 */
export function detectSeriesMissingChapters(
  chapters: ReadonlyArray<{ id: string; num: string; title: string }>,
): { missingNumbers: number[]; segments: ChapterGapSegment[] } {
  if (!chapters || chapters.length < 2) return { missingNumbers: [], segments: [] };
  const byIntNum = new Map<number, string>();
  for (const ch of chapters) {
    const n = extractChapterNumber(ch.num || ch.title || ch.id);
    if (Number.isFinite(n) && n >= 1 && n <= 5000 && Number.isInteger(n)) {
      if (!byIntNum.has(n)) byIntNum.set(n, ch.id);
    }
  }
  const nums = Array.from(byIntNum.keys()).sort((a, b) => a - b);
  if (nums.length < 2) return { missingNumbers: [], segments: [] };

  const missingNumbers: number[] = [];
  const segments: ChapterGapSegment[] = [];
  for (let i = 0; i < nums.length - 1; i++) {
    const low = nums[i];
    const high = nums[i + 1];
    const gap = high - low - 1;
    if (gap >= 1 && gap <= 25) {
      const segMissing: number[] = [];
      for (let m = low + 1; m < high && missingNumbers.length < 60; m++) {
        segMissing.push(m);
        missingNumbers.push(m);
      }
      if (segMissing.length > 0) {
        const label =
          segMissing.length === 1
            ? `Ch. ${segMissing[0]}`
            : `Ch. ${segMissing[0]}–${segMissing[segMissing.length - 1]} (${segMissing.length})`;
        segments.push({
          afterNum: low,
          beforeNum: high,
          missingNums: segMissing,
          label,
          afterChapterId: byIntNum.get(low) ?? '',
          beforeChapterId: byIntNum.get(high) ?? '',
        });
      }
    }
  }
  return { missingNumbers, segments };
}

export interface HeatmapDayCell {
  dateKey: string;
  shortLabel: string;
  count: number;
}

/**
 * Computes truthful reading statistics from library bookmarks and history entries:
 * never fabricates minimums when 0 chapters have been read, computes a real consecutive-day
 * streak ending today or yesterday, and builds a 28-day Wrapped-style reading activity heatmap.
 */
export function computeTruthfulReadingStats(
  bookmarks: ReadonlyArray<Pick<KatanaBookmark, 'readChapterIds'>>,
  historyEntries: ReadonlyArray<{ readAt: number }>,
  nowMs = Date.now(),
): {
  totalChaptersRead: number;
  estHours: number;
  estTimeLabel: string;
  weekChapters: number;
  streakDays: number;
  activeDaysTotal: number;
  heatmapDays: HeatmapDayCell[];
} {
  const totalChaptersRead = bookmarks.reduce((acc, b) => acc + (b.readChapterIds?.length ?? 0), 0);
  const totalSeconds = totalChaptersRead * 18 * 25;
  const estHours = totalChaptersRead === 0 ? 0 : Math.round(totalSeconds / 360) / 10;
  const estTimeLabel =
    totalChaptersRead === 0
      ? '0h'
      : totalSeconds < 3600
        ? `${Math.max(1, Math.round(totalSeconds / 60))}m`
        : `${estHours}h`;

  const sevenDaysAgo = nowMs - 7 * 86_400_000;
  const weekChapters = historyEntries.filter((h) => Number.isFinite(h.readAt) && h.readAt >= sevenDaysAgo).length;

  const toLocalDayKey = (ms: number): string => {
    const d = new Date(ms);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  };

  const countsByDay = new Map<string, number>();
  for (const h of historyEntries) {
    if (!Number.isFinite(h.readAt) || h.readAt <= 0) continue;
    const key = toLocalDayKey(h.readAt);
    countsByDay.set(key, (countsByDay.get(key) ?? 0) + 1);
  }

  const activeDaysTotal = countsByDay.size;

  // Consecutive-day streak must include today or yesterday; otherwise current streak is 0.
  let streakDays = 0;
  const todayKey = toLocalDayKey(nowMs);
  const yesterdayKey = toLocalDayKey(nowMs - 86_400_000);
  if (countsByDay.has(todayKey) || countsByDay.has(yesterdayKey)) {
    let cursorMs = countsByDay.has(todayKey) ? nowMs : nowMs - 86_400_000;
    while (countsByDay.has(toLocalDayKey(cursorMs))) {
      streakDays += 1;
      cursorMs -= 86_400_000;
    }
  }

  // Build 28-day (4-week) Wrapped-style activity heatmap oldest -> newest (ending today)
  const heatmapDays: HeatmapDayCell[] = [];
  for (let offset = 27; offset >= 0; offset--) {
    const dayMs = nowMs - offset * 86_400_000;
    const dateKey = toLocalDayKey(dayMs);
    const d = new Date(dayMs);
    const shortLabel = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    heatmapDays.push({
      dateKey,
      shortLabel,
      count: countsByDay.get(dateKey) ?? 0,
    });
  }

  return {
    totalChaptersRead,
    estHours,
    estTimeLabel,
    weekChapters,
    streakDays,
    activeDaysTotal,
    heatmapDays,
  };
}

