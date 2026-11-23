import { extractChapterNumber, type KatanaBookmark, type KatanaManga } from './katanaService';
import { inferSeriesReadingFormat } from './readerSpread';

export interface OfficialPublisherLink {
  id: string;
  name: string;
  badge: string;
  url: string;
  icon: string;
  officialSimulpub: boolean;
}

const SOURCE_TRUST_SCORE: Record<NonNullable<KatanaManga['source']>, number> = {
  mangadex: 28,
  mangakatana: 25,
  comick: 20,
  bato: 12,
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
    };
  }

  return Array.from(byCanonicalKey.values())
    .sort((a, b) => b.score - a.score)
    .map((e) => e.item);
}

/**
 * Returns direct official simulpub and licensed digital publisher links for a series
 * (MANGA Plus by SHUEISHA, VIZ Shonen Jump, WEBTOON, Tapas, BookWalker, MangaUpdates)
 * so readers can always access or verify official licensed releases alongside community mirrors.
 */
export function resolveOfficialPublisherLinks(
  manga: Pick<KatanaManga, 'slug' | 'title' | 'genres' | 'demographic' | 'altNames'>,
  bookmark?: Pick<KatanaBookmark, 'malId' | 'anilistId' | 'mangaUpdatesId'> | null,
): OfficialPublisherLink[] {
  const q = encodeURIComponent(manga.title.trim());
  const format = inferSeriesReadingFormat(
    manga.genres.map((g) => g.name),
    manga.title,
    manga.demographic,
    manga.altNames,
    manga.slug,
  );
  const links: OfficialPublisherLink[] = [];

  if (format === 'webtoon') {
    links.push(
      {
        id: 'webtoon',
        name: 'WEBTOON',
        badge: 'Official Simulpub',
        url: `https://www.webtoons.com/en/search?keyword=${q}`,
        icon: 'verified',
        officialSimulpub: true,
      },
      {
        id: 'tapas',
        name: 'Tapas',
        badge: 'Licensed Webtoon',
        url: `https://tapas.io/search?q=${q}`,
        icon: 'menu_book',
        officialSimulpub: true,
      },
    );
  } else {
    links.push(
      {
        id: 'mangaplus',
        name: 'MANGA Plus',
        badge: 'SHUEISHA Simulpub',
        url: `https://mangaplus.shueisha.co.jp/search_result?keyword=${q}`,
        icon: 'verified',
        officialSimulpub: true,
      },
      {
        id: 'viz',
        name: 'VIZ / Shonen Jump',
        badge: 'Official English',
        url: `https://www.viz.com/search?search=${q}`,
        icon: 'auto_stories',
        officialSimulpub: true,
      },
    );
  }

  links.push({
    id: 'bookwalker',
    name: 'BookWalker',
    badge: 'Licensed Volumes',
    url: `https://global.bookwalker.jp/search/?word=${q}`,
    icon: 'LocalLibrary' in {} ? 'local_library' : 'collections_bookmark',
    officialSimulpub: false,
  });

  if (bookmark?.mangaUpdatesId) {
    links.push({
      id: 'mangaupdates',
      name: 'MangaUpdates',
      badge: 'License Registry',
      url: `https://www.mangaupdates.com/series/${encodeURIComponent(bookmark.mangaUpdatesId)}`,
      icon: 'fact_check',
      officialSimulpub: false,
    });
  }

  return links;
}
