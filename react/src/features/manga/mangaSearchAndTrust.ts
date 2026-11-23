import { extractChapterNumber, type KatanaBookmark, type KatanaManga } from './katanaService';
import { inferSeriesReadingFormat } from './readerSpread';

export interface OfficialPublisherLink {
  id: string;
  name: string;
  badge: string;
  url: string;
  icon: string;
  /** True only when `url` points directly to the exact series page (not a generic search query). */
  directLink: boolean;
  officialSimulpub: boolean;
}

export interface SourceBadgeInfo {
  id: NonNullable<KatanaManga['source']>;
  badge: 'MK' | 'MD' | 'CK' | 'BT';
  name: string;
  trustScore: number;
  tooltip: string;
}

export const SOURCE_TRUST_META: Record<NonNullable<KatanaManga['source']>, SourceBadgeInfo> = {
  mangadex: {
    id: 'mangadex',
    badge: 'MD',
    name: 'MangaDex',
    trustScore: 28,
    tooltip: 'MD · MangaDex — Primary multilingual scanlation & official-link registry (Trust rank #1)',
  },
  mangakatana: {
    id: 'mangakatana',
    badge: 'MK',
    name: 'MangaKatana',
    trustScore: 25,
    tooltip: 'MK · MangaKatana — Fast chapter feed & multi-CDN reader mirrors (Trust rank #2)',
  },
  comick: {
    id: 'comick',
    badge: 'CK',
    name: 'ComicK',
    trustScore: 20,
    tooltip: 'CK · ComicK — High-resolution tankobon & community chapter index (Trust rank #3)',
  },
  bato: {
    id: 'bato',
    badge: 'BT',
    name: 'Bato.to',
    trustScore: 16,
    tooltip: 'BT · Bato.to — Full-color webtoon & community mirror catalog (Trust rank #4)',
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

const SOURCE_TRUST_SCORE: Record<NonNullable<KatanaManga['source']>, number> = {
  mangadex: SOURCE_TRUST_META.mangadex.trustScore,
  mangakatana: SOURCE_TRUST_META.mangakatana.trustScore,
  comick: SOURCE_TRUST_META.comick.trustScore,
  bato: SOURCE_TRUST_META.bato.trustScore,
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
 * Scores a catalog item by relevance to the search query, rating/popularity, chapter completeness,
 * and source reliability so exact matches on trusted sources always outrank weak partial matches.
 */
export function computeMangaSearchRelevance(
  item: KatanaManga,
  query: string,
  orderBy = 'popular',
): number {
  let score = SOURCE_TRUST_SCORE[item.source ?? 'mangakatana'] ?? 15;
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

/**
 * Merges and deduplicates multi-source search results (`mangakatana`, `mangadex`, `comick`, `bato`)
 * using tracker IDs (when bookmarked) and canonical titles/altNames, preserving the freshest
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

  const trackerKeyByNormTitle = new Map<string, string>();
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
    const norm = normalizeCanonicalTitle(bm.title);
    if (norm) trackerKeyByNormTitle.set(norm, tKey);
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

    const normTitle = normalizeCanonicalTitle(item.title);
    const trackerKey =
      trackerKeyBySlug.get(item.slug) ||
      (normTitle ? trackerKeyByNormTitle.get(normTitle) : undefined);
    const canonicalKey = trackerKey || normTitle || item.slug;

    const existing = byCanonicalKey.get(canonicalKey);
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

/**
 * Resolves verified direct series deep links (when an exact official English URL, BookWalker path,
 * AniList ID, MyAnimeList ID, Kitsu ID, or MangaUpdates ID is known) alongside clearly labeled
 * publisher catalog search links (MANGA Plus, VIZ, WEBTOON, Tapas, BookWalker).
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

  if (ext?.officialEnglishUrl && /^https?:\/\//i.test(ext.officialEnglishUrl)) {
    links.push({
      id: 'official-en',
      name: 'Official English Page',
      badge: 'Verified Direct Link',
      url: ext.officialEnglishUrl,
      icon: 'verified',
      directLink: true,
      officialSimulpub: true,
    });
  }
  if (ext?.rawOfficialUrl && /^https?:\/\//i.test(ext.rawOfficialUrl)) {
    links.push({
      id: 'official-raw',
      name: 'Original Publisher',
      badge: 'Verified Direct Link',
      url: ext.rawOfficialUrl,
      icon: 'verified',
      directLink: true,
      officialSimulpub: true,
    });
  }
  if (anilistId) {
    links.push({
      id: 'anilist-direct',
      name: `AniList #${anilistId}`,
      badge: 'Direct Series Page',
      url: `https://anilist.co/manga/${encodeURIComponent(anilistId)}`,
      icon: 'verified',
      directLink: true,
      officialSimulpub: true,
    });
  }
  if (malId) {
    links.push({
      id: 'mal-direct',
      name: `MAL #${malId}`,
      badge: 'Direct Series Page',
      url: `https://myanimelist.net/manga/${encodeURIComponent(malId)}`,
      icon: 'verified',
      directLink: true,
      officialSimulpub: true,
    });
  }
  if (kitsuId) {
    links.push({
      id: 'kitsu-direct',
      name: `Kitsu #${kitsuId}`,
      badge: 'Direct Series Page',
      url: `https://kitsu.app/manga/${encodeURIComponent(kitsuId)}`,
      icon: 'verified',
      directLink: true,
      officialSimulpub: true,
    });
  }
  if (muId) {
    links.push({
      id: 'mangaupdates',
      name: 'MangaUpdates',
      badge: 'Direct License Registry',
      url: `https://www.mangaupdates.com/series/${encodeURIComponent(muId)}`,
      icon: 'fact_check',
      directLink: true,
      officialSimulpub: true,
    });
  }

  if (format === 'webtoon') {
    links.push(
      {
        id: 'webtoon',
        name: 'Find on WEBTOON',
        badge: 'Publisher Lookup',
        url: `https://www.webtoons.com/en/search?keyword=${q}`,
        icon: 'search',
        directLink: false,
        officialSimulpub: false,
      },
      {
        id: 'tapas',
        name: 'Find on Tapas',
        badge: 'Publisher Lookup',
        url: `https://tapas.io/search?q=${q}`,
        icon: 'search',
        directLink: false,
        officialSimulpub: false,
      },
    );
  } else {
    links.push(
      {
        id: 'mangaplus',
        name: 'Find on MANGA Plus',
        badge: 'Publisher Lookup',
        url: `https://mangaplus.shueisha.co.jp/search_result?keyword=${q}`,
        icon: 'search',
        directLink: false,
        officialSimulpub: false,
      },
      {
        id: 'viz',
        name: 'Find on VIZ',
        badge: 'Publisher Lookup',
        url: `https://www.viz.com/search?search=${q}`,
        icon: 'search',
        directLink: false,
        officialSimulpub: false,
      },
    );
  }

  const bwPath = ext?.bookwalkerPath?.replace(/^\/+/, '');
  links.push({
    id: 'bookwalker',
    name: bwPath ? 'BookWalker' : 'Find on BookWalker',
    badge: bwPath ? 'Direct Store Page' : 'Publisher Lookup',
    url: bwPath ? `https://bookwalker.jp/${bwPath}` : `https://global.bookwalker.jp/search/?word=${q}`,
    icon: bwPath ? 'collections_bookmark' : 'search',
    directLink: Boolean(bwPath),
    officialSimulpub: Boolean(bwPath),
  });

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
