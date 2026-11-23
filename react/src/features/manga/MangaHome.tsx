import { useMemo, useState, type ReactNode } from 'react';
import { withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import {
  KatanaButton,
  KatanaCard,
  KatanaCompactCard,
  KatanaCoverBadges,
  KatanaCoverImage,
  KatanaEmptyState,
  KatanaErrorBanner,
  KatanaItemCard,
  KatanaPagination,
  KatanaPosterCard,
  KatanaSectionHeader,
  KatanaSkeletonGrid,
  KatanaSkeletonList,
} from './MangaUi';
import {
  chapterDisplayTitle,
  estimateUnreadCount,
  extractChapterNumber,
  formatCompactNumber,
  getPreferredMangaGenres,
  proxyKatanaImageUrl,
  setPreferredMangaGenres,
  type KatanaBookmark,
  type KatanaGenre,
  type KatanaHomeData,
  type KatanaManga,
} from './katanaService';
import { getKatanaGridColumns, KATANA_BREAKPOINTS, KatanaColors, KatanaType } from './katanaTokens';

export type MangaType = 'all' | 'manga' | 'manhwa' | 'manhua';
type FeedTab = 'latest' | 'new_hot' | 'updates';

const TYPE_META: Record<MangaType, { label: string; eyebrow: string; icon: string }> = {
  all: { label: 'All', eyebrow: 'Manga · Manhwa · Manhua', icon: 'apps' },
  manga: { label: 'Manga', eyebrow: 'Japanese', icon: 'auto_stories' },
  manhwa: { label: 'Manhwa', eyebrow: 'Korean Webtoon', icon: 'view_day' },
  manhua: { label: 'Manhua', eyebrow: 'Chinese', icon: 'history_edu' },
};

function TypeChip({
  label,
  icon,
  selected,
  compact,
  onClick,
}: {
  label: string;
  icon: string;
  selected: boolean;
  compact?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        flexShrink: 0,
        padding: compact ? '6px 9px' : '7px 13px',
        borderRadius: 99,
        background: selected ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
        border: `1px solid ${selected ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
        display: 'inline-flex',
        alignItems: 'center',
        gap: compact ? 4 : 6,
      }}
    >
      <Icon name={icon} size={compact ? 14 : 15} color={selected ? KatanaColors.accentSoft : KatanaColors.textMuted} />
      <span
        style={{
          fontFamily: Fonts.body,
          fontWeight: selected ? 700 : 600,
          fontSize: compact ? 12 : 13,
          lineHeight: lineHeight(compact ? 12 : 13, 1.2),
          color: selected ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
          whiteSpace: 'nowrap',
        }}
      >
        {label}
      </span>
    </button>
  );
}

function FeaturedHero({
  candidates,
  bookmarks,
  compact,
  desktop = false,
  onSelectManga,
  onOpenChapter,
  onSelectGenre,
}: {
  candidates: KatanaManga[];
  bookmarks: KatanaBookmark[];
  compact: boolean;
  desktop?: boolean;
  onSelectManga: (slug: string) => void;
  onOpenChapter: (manga: KatanaManga, chapterId: string) => void;
  onSelectGenre: (g: KatanaGenre) => void;
}) {
  const [index, setIndex] = useState(0);
  if (candidates.length === 0) return null;
  const featured = candidates[index % candidates.length];
  const bm = bookmarks.find((b) => b.slug === featured.slug);
  const completed = featured.status === 'completed';
  const backdropUrl = featured.coverUrl ? proxyKatanaImageUrl(featured.coverUrl) : '';

  return (
    <section
      aria-label="Featured title"
      style={{
        position: 'relative',
        borderRadius: 16,
        overflow: 'hidden',
        background: KatanaColors.surface,
        border: `1px solid ${KatanaColors.borderStrong}`,
        marginBottom: 14,
      }}
    >
      {/* Cover-derived atmospheric blurred backdrop */}
      {backdropUrl && (
        <img
          src={backdropUrl}
          alt=""
          aria-hidden="true"
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            filter: 'blur(28px) saturate(1.2) brightness(0.42)',
            transform: 'scale(1.18)',
            opacity: 0.72,
            pointerEvents: 'none',
          }}
        />
      )}
      <div
        aria-hidden="true"
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(100deg, rgba(11, 13, 18, 0.92) 0%, rgba(19, 22, 31, 0.80) 56%, rgba(11, 13, 18, 0.72) 100%)',
          pointerEvents: 'none',
        }}
      />

      <div
        style={{
          position: 'relative',
          padding: compact ? 14 : '16px 20px',
          display: 'flex',
          gap: compact ? 14 : 20,
          alignItems: 'center',
        }}
      >
        <button
          type="button"
          className="bare-button"
          aria-label={`Open ${featured.title}`}
          onClick={() => onSelectManga(featured.slug)}
          style={{
            position: 'relative',
            width: compact ? 96 : 122,
            height: compact ? 138 : 176,
            borderRadius: 10,
            overflow: 'hidden',
            flexShrink: 0,
            border: `1px solid ${KatanaColors.borderStrong}`,
            background: KatanaColors.surfaceAlt,
            boxShadow: '0 8px 24px rgba(0,0,0,0.45)',
          }}
        >
          <KatanaCoverImage url={featured.coverUrl} title={featured.title} iconSize={30} />
        </button>

        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: compact ? 6 : 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            <span
              style={{
                padding: '2px 8px',
                borderRadius: 6,
                background: KatanaColors.chipSelectedBg,
                border: `1px solid ${KatanaColors.chipSelectedBorder}`,
                fontFamily: Fonts.body,
                fontSize: 10.5,
                fontWeight: 700,
                color: KatanaColors.chipSelectedText,
                letterSpacing: 0.5,
              }}
            >
              SPOTLIGHT
            </span>
            <span
              style={{
                padding: '2px 8px',
                borderRadius: 6,
                background: withAlpha(completed ? KatanaColors.green : KatanaColors.teal, 0.16),
                fontFamily: Fonts.body,
                fontSize: 11,
                fontWeight: 600,
                color: completed ? KatanaColors.green : KatanaColors.teal,
              }}
            >
              {completed ? 'Completed' : 'Ongoing'}
            </span>
            {featured.rating != null && (
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>
                <Icon name="star" size={13} color={KatanaColors.accent} />
                <span style={{ fontFamily: Fonts.body, fontSize: 12, fontWeight: 700, color: KatanaColors.text }}>
                  {featured.rating.toFixed(1)}
                </span>
              </span>
            )}
            {featured.follows != null && featured.follows > 0 && (
              <span style={{ ...KatanaType.small, fontSize: 12 }}>
                {formatCompactNumber(featured.follows)} readers
              </span>
            )}
            {featured.latestChapter && (
              <span style={{ ...KatanaType.small, fontSize: 12, color: KatanaColors.link }}>
                {chapterDisplayTitle(featured.latestChapter)}
              </span>
            )}
          </div>

          <button
            type="button"
            className="bare-button"
            onClick={() => onSelectManga(featured.slug)}
            style={{ textAlign: 'left' }}
          >
            <h1
              className="clamp-2"
              style={{
                ...KatanaType.display,
                fontSize: compact ? 19 : 25,
                margin: 0,
              }}
            >
              {featured.title}
            </h1>
          </button>

          {featured.genres.length > 0 && (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {featured.genres.slice(0, compact ? 3 : 5).map((g) => (
                <button
                  key={g.slug}
                  type="button"
                  className="bare-button"
                  onClick={() => onSelectGenre(g)}
                  style={{
                    padding: '3px 9px',
                    borderRadius: 6,
                    background: 'rgba(27, 32, 44, 0.85)',
                    border: `1px solid ${KatanaColors.borderStrong}`,
                    fontFamily: Fonts.body,
                    fontSize: 11.5,
                    fontWeight: 600,
                    color: KatanaColors.textMuted,
                  }}
                >
                  {g.name}
                </button>
              ))}
            </div>
          )}

          {!compact && featured.summary && (
            <p className="clamp-2" style={{ ...KatanaType.body, fontSize: 13.5, margin: 0, maxWidth: 680 }}>
              {featured.summary}
            </p>
          )}

          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginTop: 2 }}>
            <KatanaButton
              label={bm?.lastReadChapterId ? `Continue ${bm.lastReadChapterTitle || ''}`.trim() : 'Start Reading'}
              icon="play_arrow"
              size="sm"
              onClick={() => {
                const target = bm?.lastReadChapterId || featured.chapters[featured.chapters.length - 1]?.id || 'fc';
                onOpenChapter(featured, target);
              }}
            />
            <KatanaButton
              label="Details"
              icon="info"
              filled={false}
              color={KatanaColors.text}
              size="sm"
              onClick={() => onSelectManga(featured.slug)}
            />
            {!desktop && candidates.length > 1 && (
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginLeft: 4 }}>
                {candidates.map((c, i) => (
                  <button
                    key={c.slug}
                    type="button"
                    className="bare-button"
                    aria-label={`Show featured title ${i + 1}: ${c.title}`}
                    onClick={() => setIndex(i)}
                    style={{
                      width: i === index ? 20 : 7,
                      height: 7,
                      borderRadius: 99,
                      background: i === index ? KatanaColors.accent : KatanaColors.borderStrong,
                      transition: 'width 180ms ease, background 180ms ease',
                    }}
                  />
                ))}
              </div>
            )}
          </div>
        </div>

        {desktop && candidates.length > 1 && (
          <div
            style={{
              width: 280,
              flexShrink: 0,
              borderLeft: `1px solid ${withAlpha(KatanaColors.borderStrong, 0.7)}`,
              paddingLeft: 16,
              display: 'flex',
              flexDirection: 'column',
              gap: 6,
            }}
          >
            <div style={{ ...KatanaType.small, fontSize: 11, fontWeight: 700, letterSpacing: 0.5, color: KatanaColors.textMuted }}>
              SPOTLIGHT QUEUE
            </div>
            {candidates.map((c, i) => {
              const active = i === index % candidates.length;
              return (
                <button
                  key={c.slug}
                  type="button"
                  className="bare-button"
                  onClick={() => setIndex(i)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 9,
                    padding: '5px 7px',
                    borderRadius: 8,
                    textAlign: 'left',
                    background: active ? 'rgba(37, 48, 71, 0.82)' : 'rgba(11, 13, 18, 0.42)',
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : 'transparent'}`,
                  }}
                >
                  <div
                    style={{
                      position: 'relative',
                      width: 28,
                      height: 40,
                      borderRadius: 5,
                      overflow: 'hidden',
                      flexShrink: 0,
                      background: KatanaColors.surfaceAlt,
                    }}
                  >
                    <KatanaCoverImage url={c.coverUrl} title={c.title} iconSize={14} />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div
                      className="ellipsis"
                      style={{
                        fontFamily: Fonts.body,
                        fontSize: 12.5,
                        fontWeight: active ? 700 : 600,
                        color: active ? KatanaColors.text : KatanaColors.textMuted,
                      }}
                    >
                      {c.title}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 1 }}>
                      {c.rating != null && (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 2, fontSize: 11, color: KatanaColors.accentSoft, fontWeight: 700 }}>
                          <Icon name="star" size={11} color={KatanaColors.accent} />
                          {c.rating.toFixed(1)}
                        </span>
                      )}
                      {c.latestChapter && (
                        <span className="ellipsis" style={{ ...KatanaType.small, fontSize: 11 }}>
                          {chapterDisplayTitle(c.latestChapter)}
                        </span>
                      )}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        )}
      </div>
    </section>
  );
}

function CurrentlyReadingShelf({
  items,
  catalog,
  downloadedCounts,
  compact,
  onSelectManga,
  onResumeBookmark,
  onViewAll,
}: {
  items: KatanaBookmark[];
  catalog: KatanaManga[];
  downloadedCounts?: Record<string, number>;
  compact: boolean;
  onSelectManga: (slug: string) => void;
  onResumeBookmark?: (bm: KatanaBookmark) => void;
  onViewAll: () => void;
}) {
  if (items.length === 0) return null;
  const catalogMap = new Map(catalog.map((m) => [m.slug, m]));

  return (
    <section style={{ marginBottom: 14 }}>
      <KatanaSectionHeader
        title="Currently Reading"
        badge={String(items.length)}
        trailing={
          <button
            type="button"
            className="bare-button"
            onClick={onViewAll}
            style={{
              padding: '4px 10px',
              borderRadius: 99,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.border}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 3,
            }}
          >
            <span style={{ ...KatanaType.link, fontSize: 12 }}>View all</span>
            <Icon name="chevron_right" size={15} color={KatanaColors.link} />
          </button>
        }
      />
      <div style={{ height: 8 }} />
      <div className="no-scrollbar" style={{ display: 'flex', gap: 10, overflowX: 'auto', paddingBottom: 2 }}>
        {items.slice(0, 10).map((bm) => {
          const matched = catalogMap.get(bm.slug);
          const currentNum = extractChapterNumber(bm.lastReadChapterTitle || bm.lastReadChapterId);
          const latestNum = extractChapterNumber(
            bm.latestChapterTitle || matched?.latestChapter?.title || matched?.latestChapter?.num || '',
          );
          const pct = latestNum > 0 && currentNum > 0 ? Math.min(100, Math.round((currentNum / latestNum) * 100)) : 0;
          const unread = estimateUnreadCount(bm, latestNum || undefined);
          const dlCount = downloadedCounts?.[bm.slug] ?? 0;

          return (
            <div
              key={bm.slug}
              style={{
                width: compact ? 248 : 296,
                flexShrink: 0,
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                padding: 8,
                borderRadius: 11,
                background: KatanaColors.surface,
                border: `1px solid ${KatanaColors.border}`,
              }}
            >
              <button
                type="button"
                className="bare-button"
                onClick={() => onSelectManga(bm.slug)}
                style={{
                  flex: 1,
                  minWidth: 0,
                  textAlign: 'left',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                }}
              >
                <div
                  style={{
                    position: 'relative',
                    width: 48,
                    height: 68,
                    borderRadius: 7,
                    overflow: 'hidden',
                    flexShrink: 0,
                    border: `1px solid ${KatanaColors.borderStrong}`,
                    background: KatanaColors.surfaceAlt,
                  }}
                >
                  <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={18} />
                  <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="ellipsis" style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 700, color: KatanaColors.text }}>
                    {bm.title}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
                    <span className="ellipsis" style={{ ...KatanaType.link, fontSize: 11.5 }}>
                      {bm.lastReadChapterTitle || 'Resume'}
                    </span>
                    {unread > 0 && (
                      <span
                        style={{
                          padding: '1px 5px',
                          borderRadius: 4,
                          background: withAlpha(KatanaColors.accent, 0.18),
                          fontFamily: Fonts.body,
                          fontSize: 10,
                          fontWeight: 700,
                          color: KatanaColors.accentSoft,
                          flexShrink: 0,
                        }}
                      >
                        +{unread} new
                      </span>
                    )}
                  </div>
                  {pct > 0 && (
                    <div style={{ height: 3, borderRadius: 99, background: KatanaColors.surfaceAlt, overflow: 'hidden', marginTop: 7 }}>
                      <div
                        style={{
                          width: `${pct}%`,
                          height: '100%',
                          background: KatanaColors.accent,
                        }}
                      />
                    </div>
                  )}
                </div>
              </button>
              {onResumeBookmark && bm.lastReadChapterId && (
                <button
                  type="button"
                  className="bare-button"
                  aria-label={`Resume ${bm.title}`}
                  title={`Resume ${bm.lastReadChapterTitle || bm.title}`}
                  onClick={() => onResumeBookmark(bm)}
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: 99,
                    flexShrink: 0,
                    background: KatanaColors.accent,
                    display: 'grid',
                    placeItems: 'center',
                  }}
                >
                  <Icon name="play_arrow" size={20} color={KatanaColors.accentInk} />
                </button>
              )}
            </div>
          );
        })}
      </div>
    </section>
  );
}

export function MangaHome({
  width,
  data,
  currentlyReading = [],
  libraryBookmarks = [],
  extraCatalog = [],
  downloadedCounts = {},
  type,
  typeItems,
  typeLoading,
  typePage,
  typeHasNext,
  typeTotalPages,
  typeTotalResults,
  onSelectType,
  onTypePage,
  onSelectManga,
  onSelectGenre,
  onOpenChapter,
  onResumeBookmark,
  onViewAllReading,
  onRetryHome,
}: {
  width: number;
  data: KatanaHomeData;
  currentlyReading?: KatanaBookmark[];
  libraryBookmarks?: KatanaBookmark[];
  extraCatalog?: KatanaManga[];
  downloadedCounts?: Record<string, number>;
  type: MangaType;
  typeItems: KatanaManga[];
  typeLoading: boolean;
  typePage: number;
  typeHasNext: boolean;
  typeTotalPages?: number;
  typeTotalResults?: number;
  onSelectType: (t: MangaType) => void;
  onTypePage: (page: number) => void;
  onSelectManga: (slug: string) => void;
  onSelectGenre: (g: KatanaGenre) => void;
  onOpenChapter: (manga: KatanaManga, chapterId: string) => void;
  onResumeBookmark?: (bm: KatanaBookmark) => void;
  onViewAllReading?: () => void;
  onRetryHome?: () => void;
}) {
  const desktop = width >= KATANA_BREAKPOINTS.desktop;
  const tablet = width >= KATANA_BREAKPOINTS.tablet;
  const compact = width < KATANA_BREAKPOINTS.tablet;
  const homeGridCols = desktop ? 4 : getKatanaGridColumns(width);
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
  const [feedTab, setFeedTab] = useState<FeedTab>('latest');
  const [tasteGenres, setTasteGenres] = useState<string[]>(() => getPreferredMangaGenres());
  const [tasteEditorOpen, setTasteEditorOpen] = useState(false);

  const effectiveView = viewMode;
  const allCatalog = useMemo(() => {
    const seen = new Map<string, KatanaManga>();
    for (const m of [...data.hotUpdates, ...data.hot, ...data.latest, ...extraCatalog]) {
      if (!seen.has(m.slug)) seen.set(m.slug, m);
    }
    return [...seen.values()];
  }, [data.hotUpdates, data.hot, data.latest, extraCatalog]);

  const featuredCandidates = useMemo(() => {
    const pool = data.hot.length > 0 ? data.hot : data.latest;
    return pool.slice(0, 4);
  }, [data.hot, data.latest]);

  const toggleTasteGenre = (slug: string) => {
    setTasteGenres((prev) => {
      const next = prev.includes(slug) ? prev.filter((s) => s !== slug) : [...prev, slug];
      return setPreferredMangaGenres(next);
    });
  };

  // Explainable recommendations: every card carries a concrete "why" label.
  const recommended = useMemo(() => {
    if (allCatalog.length === 0) return [];
    const readingSlugs = new Set(currentlyReading.map((b) => b.slug));
    const readingGenreSource = new Map<string, string>();
    for (const bm of currentlyReading) {
      const m = allCatalog.find((x) => x.slug === bm.slug);
      m?.genres.forEach((g) => {
        if (!readingGenreSource.has(g.slug)) readingGenreSource.set(g.slug, bm.title);
      });
    }
    const explicitSet = new Set(tasteGenres);
    const candidates = allCatalog.filter((m) => !readingSlugs.has(m.slug));

    const scored = candidates.map((m) => {
      const explicitMatches = m.genres.filter((g) => explicitSet.has(g.slug));
      const historyMatch = m.genres.find((g) => readingGenreSource.has(g.slug));
      const score = explicitMatches.length * 3 + (historyMatch ? 2 : 0) + (m.rating ? m.rating / 5 : 0);
      let reason = '';
      if (explicitMatches.length > 0) {
        reason = `Matches ${explicitMatches.slice(0, 2).map((g) => g.name).join(' · ')}`;
      } else if (historyMatch) {
        const src = readingGenreSource.get(historyMatch.slug)!;
        reason = `Because you read ${src}`;
      } else if (m.rating != null) {
        reason = `Top rated · ${m.rating.toFixed(1)}`;
      }
      return { manga: m, score, reason };
    });

    return scored.sort((a, b) => b.score - a.score).slice(0, 8);
  }, [allCatalog, currentlyReading, tasteGenres]);

  const newAndHotItems = useMemo(() => {
    const seen = new Set<string>();
    const combined = [...data.hotUpdates, ...data.hot].filter((m) => {
      if (seen.has(m.slug)) return false;
      seen.add(m.slug);
      return true;
    });
    return combined.sort((a, b) => (b.rating ?? 0) - (a.rating ?? 0));
  }, [data.hotUpdates, data.hot]);

  const libraryUpdates = useMemo(() => {
    const catalogMap = new Map(allCatalog.map((m) => [m.slug, m]));
    const activeLibrary = libraryBookmarks.filter((b) => b.bookmarked || Boolean(b.lastReadChapterId));
    return activeLibrary
      .map((bm) => {
        const matched = catalogMap.get(bm.slug);
        const unread = estimateUnreadCount(bm, matched?.chapterCount);
        const manga: KatanaManga = matched ?? {
          slug: bm.slug,
          id: bm.slug,
          title: bm.title,
          coverUrl: bm.coverUrl,
          status: 'ongoing',
          updateText: '',
          summary: '',
          genres: [],
          altNames: [],
          authors: [],
          artists: [],
          chapters: [],
          recentChapters: [],
          latestChapter: bm.latestChapterTitle
            ? { id: bm.lastReadChapterId || 'fc', num: '', title: bm.latestChapterTitle }
            : undefined,
        };
        return { manga, unread, updatedAt: (bm.lastReadAt ?? bm.addedAt).getTime() };
      })
      .filter((x) => x.unread > 0 || Boolean(x.manga.latestChapter))
      .sort((a, b) => b.unread - a.unread || b.updatedAt - a.updatedAt)
      .map((x) => x.manga);
  }, [allCatalog, libraryBookmarks]);

  const libraryUnreadTotal = useMemo(() => {
    return libraryBookmarks.reduce((acc, bm) => acc + estimateUnreadCount(bm), 0);
  }, [libraryBookmarks]);

  const openRandomPick = () => {
    if (allCatalog.length === 0) return;
    const pick = allCatalog[Math.floor(Math.random() * allCatalog.length)];
    onSelectManga(pick.slug);
  };

  const unreadBySlug = useMemo(() => {
    const map: Record<string, number> = {};
    for (const bm of currentlyReading) {
      map[bm.slug] = estimateUnreadCount(bm);
    }
    return map;
  }, [currentlyReading]);

  const renderFeedItems = (items: KatanaManga[]) => {
    if (effectiveView === 'grid') {
      return (
        <div style={{ display: 'grid', gridTemplateColumns: `repeat(${homeGridCols}, minmax(0, 1fr))`, gap: 12 }}>
          {items.map((m) => (
            <KatanaPosterCard
              key={m.slug}
              manga={m}
              unreadCount={unreadBySlug[m.slug]}
              downloadedCount={downloadedCounts[m.slug]}
              onSelect={() => onSelectManga(m.slug)}
              onOpenChapter={onOpenChapter}
            />
          ))}
        </div>
      );
    }
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {items.map((m) => (
          <KatanaItemCard
            key={m.slug}
            manga={m}
            compact={compact}
            unreadCount={unreadBySlug[m.slug]}
            downloadedCount={downloadedCounts[m.slug]}
            onSelectManga={onSelectManga}
            onSelectGenre={onSelectGenre}
            onOpenChapter={onOpenChapter}
          />
        ))}
      </div>
    );
  };

  const viewToggle = (
    <div
      style={{
        display: 'inline-flex',
        padding: 3,
        borderRadius: 8,
        background: KatanaColors.surfaceAlt,
        border: `1px solid ${KatanaColors.border}`,
      }}
    >
      {(['grid', 'list'] as const).map((mode) => {
        const active = effectiveView === mode;
        return (
          <button
            key={mode}
            type="button"
            className="bare-button"
            aria-label={mode === 'grid' ? 'Grid view' : 'List view'}
            onClick={() => setViewMode(mode)}
            style={{
              width: 32,
              height: 28,
              borderRadius: 6,
              background: active ? KatanaColors.chipSelectedBg : 'transparent',
              border: active ? `1px solid ${KatanaColors.chipSelectedBorder}` : '1px solid transparent',
              display: 'grid',
              placeItems: 'center',
            }}
          >
            <Icon name={mode === 'grid' ? 'grid_view' : 'view_agenda'} size={16} color={active ? KatanaColors.chipSelectedText : KatanaColors.textMuted} />
          </button>
        );
      })}
    </div>
  );

  const typeChips = (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: compact ? 6 : 8 }}>
      <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex', gap: compact ? 5 : 8, flex: 1, minWidth: 0 }}>
        {(['all', 'manga', 'manhwa', 'manhua'] as const).map((t) => (
          <TypeChip
            key={t}
            label={TYPE_META[t].label}
            icon={TYPE_META[t].icon}
            selected={type === t}
            compact={compact}
            onClick={() => onSelectType(t)}
          />
        ))}
      </div>
      {allCatalog.length > 0 && (
        <button
          type="button"
          className="bare-button"
          onClick={openRandomPick}
          aria-label="Pick a random title"
          title="Pick a random title"
          style={{
            flexShrink: 0,
            padding: compact ? '6px 9px' : '7px 12px',
            minWidth: compact ? 34 : undefined,
            height: compact ? 32 : undefined,
            borderRadius: 99,
            background: KatanaColors.surfaceAlt,
            border: `1px solid ${KatanaColors.borderStrong}`,
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 5,
          }}
        >
          <Icon name="casino" size={16} color={KatanaColors.textMuted} />
          {!compact && <span style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 600, color: KatanaColors.text }}>Random</span>}
        </button>
      )}
    </div>
  );

  const hasPersonalizedSignal = recommended.some((r) => r.reason.startsWith('Matches ') || r.reason.startsWith('Because you read '));
  const recommendedRail =
    type === 'all' && recommended.length > 0 ? (
      <section style={{ marginTop: 22 }}>
        <KatanaSectionHeader
          title={hasPersonalizedSignal ? 'Picked for You' : 'Top Rated Picks'}
          badge={tasteGenres.length > 0 ? `${tasteGenres.length} tastes` : undefined}
          trailing={
            <button
              type="button"
              className="bare-button"
              onClick={() => setTasteEditorOpen((v) => !v)}
              style={{
                padding: '4px 10px',
                borderRadius: 99,
                background: tasteEditorOpen ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                border: `1px solid ${tasteEditorOpen ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 5,
              }}
            >
              <Icon name="tune" size={14} color={KatanaColors.textMuted} />
              <span style={{ fontFamily: Fonts.body, fontSize: 12, fontWeight: 600, color: KatanaColors.text }}>
                Personalize
              </span>
            </button>
          }
        />
        {tasteEditorOpen && data.genres.length > 0 && (
          <KatanaCard padding={12} radius={10} style={{ marginTop: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
              <span style={{ ...KatanaType.small, color: KatanaColors.textMuted }}>
                Pick genres you enjoy — recommendations update immediately:
              </span>
              {tasteGenres.length > 0 && (
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => setTasteGenres(setPreferredMangaGenres([]))}
                  style={{ ...KatanaType.small, color: KatanaColors.link }}
                >
                  Reset
                </button>
              )}
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {data.genres.slice(0, 14).map((g) => {
                const picked = tasteGenres.includes(g.slug);
                return (
                  <button
                    key={g.slug}
                    type="button"
                    className="bare-button"
                    onClick={() => toggleTasteGenre(g.slug)}
                    style={{
                      padding: '4px 10px',
                      borderRadius: 99,
                      background: picked ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                      border: `1px solid ${picked ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: picked ? 700 : 500,
                      color: picked ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                    }}
                  >
                    {picked ? `✓ ${g.name}` : g.name}
                  </button>
                );
              })}
            </div>
          </KatanaCard>
        )}
        <div style={{ height: 10 }} />
        <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex', gap: 14, paddingBottom: 4 }}>
          {recommended.map(({ manga, reason }) => (
            <KatanaCompactCard
              key={manga.slug}
              manga={manga}
              width={tablet ? 156 : 124}
              reason={reason}
              onSelect={() => onSelectManga(manga.slug)}
              onOpenChapter={onOpenChapter}
            />
          ))}
        </div>
      </section>
    ) : null;

  const hotCard =
    data.hot.length > 0 ? (
      <KatanaCard padding={14}>
        <KatanaSectionHeader title="Hot Manga" trailing={<Icon name="local_fire_department" size={20} color={KatanaColors.orange} />} />
        <div style={{ height: 12 }} />
        {desktop ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {data.hot.slice(0, 6).map((m, i) => (
              <button
                key={m.slug}
                type="button"
                className="bare-button"
                onClick={() => onSelectManga(m.slug)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  textAlign: 'left',
                  padding: 6,
                  borderRadius: 8,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                }}
              >
                <span
                  style={{
                    width: 24,
                    textAlign: 'center',
                    fontFamily: Fonts.body,
                    fontSize: 16,
                    fontWeight: 800,
                    color: i < 3 ? KatanaColors.accent : KatanaColors.textLight,
                    flexShrink: 0,
                  }}
                >
                  {i + 1}
                </span>
                <div style={{ position: 'relative', width: 42, height: 60, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surface }}>
                  <KatanaCoverImage url={m.coverUrl} title={m.title} iconSize={16} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
                    {m.title}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 2 }}>
                    {m.rating != null && (
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 2, fontFamily: Fonts.body, fontSize: 11, fontWeight: 700, color: KatanaColors.textMuted }}>
                        <Icon name="star" size={11} color={KatanaColors.accent} />
                        {m.rating.toFixed(1)}
                      </span>
                    )}
                    {m.latestChapter && (
                      <span className="ellipsis" style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.link }}>
                        {chapterDisplayTitle(m.latestChapter)}
                      </span>
                    )}
                  </div>
                </div>
              </button>
            ))}
          </div>
        ) : (
          <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex', gap: 12, paddingBottom: 4 }}>
            {data.hot.map((m) => (
              <KatanaCompactCard key={m.slug} manga={m} width={124} onSelect={() => onSelectManga(m.slug)} onOpenChapter={onOpenChapter} />
            ))}
          </div>
        )}
      </KatanaCard>
    ) : null;

  const genresCard =
    data.genres.length > 0 ? (
      <KatanaCard padding={14}>
        <KatanaSectionHeader title="Genres" />
        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 7 }}>
          {data.genres.map((g) => (
            <button
              key={g.slug}
              type="button"
              className="bare-button"
              onClick={() => onSelectGenre(g)}
              style={{
                padding: '6px 10px',
                borderRadius: 7,
                background: KatanaColors.surfaceAlt,
                border: `1px solid ${KatanaColors.border}`,
                whiteSpace: 'nowrap',
              }}
            >
              <span style={{ fontFamily: Fonts.body, fontWeight: 600, fontSize: 12.5, color: KatanaColors.text }}>{g.name}</span>
              {g.count > 0 && <span style={{ ...KatanaType.small, fontSize: 11 }}> ({g.count})</span>}
            </button>
          ))}
        </div>
      </KatanaCard>
    ) : null;

  const activeFeedItems =
    type !== 'all'
      ? typeItems
      : feedTab === 'new_hot'
        ? newAndHotItems
        : feedTab === 'updates'
          ? libraryUpdates
          : data.latest;

  const feedTitle =
    type !== 'all'
      ? TYPE_META[type].label
      : feedTab === 'new_hot'
        ? 'New & Hot'
        : feedTab === 'updates'
          ? 'My Library Updates'
          : 'Latest Updates';

  const feedSection = (
    <section>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
        <KatanaSectionHeader title={feedTitle} badge={feedTab === 'updates' && libraryUnreadTotal > 0 ? `${libraryUnreadTotal} unread` : undefined} />
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          {type === 'all' && (
            <div
              role="tablist"
              aria-label="Discovery feed"
              style={{
                display: 'inline-flex',
                padding: 3,
                borderRadius: 9,
                background: KatanaColors.surfaceAlt,
                border: `1px solid ${KatanaColors.border}`,
              }}
            >
              {([
                { key: 'latest', label: 'Latest' },
                { key: 'new_hot', label: 'New & Hot' },
                { key: 'updates', label: 'My Updates' },
              ] as const).map((t) => {
                const active = feedTab === t.key;
                return (
                  <button
                    key={t.key}
                    type="button"
                    role="tab"
                    aria-selected={active}
                    className="bare-button"
                    onClick={() => setFeedTab(t.key)}
                    style={{
                      padding: '4px 10px',
                      borderRadius: 6,
                      background: active ? KatanaColors.chipSelectedBg : 'transparent',
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: active ? 700 : 500,
                      color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                    }}
                  >
                    {t.label}
                  </button>
                );
              })}
            </div>
          )}
          {type !== 'all' && <span style={KatanaType.small}>{TYPE_META[type].eyebrow}</span>}
          {viewToggle}
        </div>
      </div>

      <div style={{ height: 12 }} />
      {type !== 'all' && typeLoading && typeItems.length === 0 ? (
        effectiveView === 'grid' ? <KatanaSkeletonGrid count={homeGridCols * 2} columns={homeGridCols} /> : <KatanaSkeletonList count={4} />
      ) : activeFeedItems.length === 0 ? (
        feedTab === 'updates' && type === 'all' ? (
          <KatanaEmptyState
            icon="notifications_none"
            title="No library updates yet"
            subtitle="Add series to your Library to track new chapters here as they arrive."
            actionLabel="Browse Latest"
            actionIcon="schedule"
            onAction={() => setFeedTab('latest')}
          />
        ) : (
          <KatanaEmptyState
            icon="menu_book"
            title={type === 'all' ? 'Catalog unavailable right now' : `No ${TYPE_META[type].label} titles found`}
            subtitle={
              data.error
                ? data.error
                : 'Pull fresh updates or try another format filter to explore available series.'
            }
            actionLabel={onRetryHome ? 'Try Again' : undefined}
            actionIcon="refresh"
            onAction={onRetryHome}
          />
        )
      ) : (
        renderFeedItems(activeFeedItems)
      )}
      {type !== 'all' && activeFeedItems.length > 0 && (
        <div style={{ marginTop: 16 }}>
          <KatanaPagination
            page={typePage}
            hasPrev={typePage > 1}
            hasNext={typeHasNext}
            totalPages={typeTotalPages}
            totalResults={typeTotalResults}
            onPageChange={onTypePage}
          />
        </div>
      )}
    </section>
  );

  const center = (child: ReactNode) => <div style={{ maxWidth: 1240, margin: '0 auto' }}>{child}</div>;

  if (!desktop) {
    return (
      <div style={{ padding: '14px 16px 32px' }}>
        {center(
          <>
            {data.error && <KatanaErrorBanner message={data.error} onRetry={onRetryHome} />}
            {type === 'all' && (
              <FeaturedHero
                candidates={featuredCandidates}
                bookmarks={currentlyReading}
                compact={compact}
                onSelectManga={onSelectManga}
                onOpenChapter={onOpenChapter}
                onSelectGenre={onSelectGenre}
              />
            )}
            <CurrentlyReadingShelf
              items={currentlyReading}
              catalog={allCatalog}
              downloadedCounts={downloadedCounts}
              compact={compact}
              onSelectManga={onSelectManga}
              onResumeBookmark={onResumeBookmark}
              onViewAll={() => onViewAllReading?.()}
            />
            {typeChips}
            <div style={{ height: 14 }} />
            {feedSection}
            {recommendedRail}
            {type === 'all' && hotCard && <div style={{ marginTop: 20 }}>{hotCard}</div>}
            {genresCard && <div style={{ marginTop: 18 }}>{genresCard}</div>}
          </>,
        )}
      </div>
    );
  }

  return (
    <div style={{ padding: '16px 16px 48px' }}>
      {center(
        <>
          {data.error && <KatanaErrorBanner message={data.error} onRetry={onRetryHome} />}
          {type === 'all' && (
            <FeaturedHero
              candidates={featuredCandidates}
              bookmarks={currentlyReading}
              compact={false}
              desktop
              onSelectManga={onSelectManga}
              onOpenChapter={onOpenChapter}
              onSelectGenre={onSelectGenre}
            />
          )}
          <CurrentlyReadingShelf
            items={currentlyReading}
            catalog={allCatalog}
            downloadedCounts={downloadedCounts}
            compact={false}
            onSelectManga={onSelectManga}
            onResumeBookmark={onResumeBookmark}
            onViewAll={() => onViewAllReading?.()}
          />
          {typeChips}
          <div style={{ height: 14 }} />
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 18 }}>
            <div style={{ flex: 7, minWidth: 0 }}>
              {feedSection}
              {recommendedRail}
            </div>
            <aside style={{ width: 320, flexShrink: 0, display: 'flex', flexDirection: 'column', gap: 16 }}>
              {type === 'all' && hotCard}
              {genresCard}
            </aside>
          </div>
        </>,
      )}
    </div>
  );
}
