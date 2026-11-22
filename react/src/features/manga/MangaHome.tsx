import { useMemo, useState, type ReactNode } from 'react';
import { withAlpha } from '../../core/theme/colors';
import { Align, linear, lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import {
  KatanaButton,
  KatanaCard,
  KatanaCompactCard,
  KatanaCoverImage,
  KatanaEmptyState,
  KatanaErrorBanner,
  KatanaItemCard,
  KatanaPagination,
  KatanaPosterCard,
  KatanaSectionHeader,
} from './MangaUi';
import { chapterDisplayTitle, type KatanaBookmark, type KatanaGenre, type KatanaHomeData, type KatanaManga } from './katanaService';
import { KATANA_BREAKPOINTS, KatanaColors, KatanaType } from './katanaTokens';

export type MangaType = 'all' | 'manga' | 'manhwa' | 'manhua';

const TYPE_META: Record<MangaType, { label: string; eyebrow: string; icon: string }> = {
  all: { label: 'All', eyebrow: 'Manga · Manhwa · Manhua', icon: 'apps' },
  manga: { label: 'Manga', eyebrow: 'Japanese', icon: 'auto_stories' },
  manhwa: { label: 'Manhwa', eyebrow: 'Korean Webtoon', icon: 'view_day' },
  manhua: { label: 'Manhua', eyebrow: 'Chinese', icon: 'history_edu' },
};

function parseChapterNumber(raw: string): number {
  const m = /(\d+(?:\.\d+)?)/.exec(raw);
  return m ? Number(m[1]) : 0;
}

function TypeChip({ label, icon, selected, onClick }: { label: string; icon: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        flexShrink: 0,
        padding: '8px 14px',
        borderRadius: 99,
        background: selected
          ? linear([KatanaColors.accentSoft, KatanaColors.accent], { begin: Align.topLeft, end: Align.bottomRight })
          : KatanaColors.surfaceAlt,
        border: `1px solid ${selected ? KatanaColors.accent : KatanaColors.border}`,
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
      }}
    >
      <Icon name={icon} size={15} color={selected ? KatanaColors.accentInk : KatanaColors.textMuted} />
      <span
        style={{
          fontFamily: Fonts.body,
          fontWeight: 700,
          fontSize: 13,
          lineHeight: lineHeight(13, 1.2),
          color: selected ? KatanaColors.accentInk : KatanaColors.text,
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
  onSelectManga,
  onOpenChapter,
  onSelectGenre,
}: {
  candidates: KatanaManga[];
  bookmarks: KatanaBookmark[];
  compact: boolean;
  onSelectManga: (slug: string) => void;
  onOpenChapter: (manga: KatanaManga, chapterId: string) => void;
  onSelectGenre: (g: KatanaGenre) => void;
}) {
  const [index, setIndex] = useState(0);
  if (candidates.length === 0) return null;
  const featured = candidates[index % candidates.length];
  const bm = bookmarks.find((b) => b.slug === featured.slug);
  const completed = featured.status === 'completed';

  return (
    <section
      aria-label="Featured title"
      style={{
        position: 'relative',
        borderRadius: 16,
        overflow: 'hidden',
        background: linear([KatanaColors.surfaceGlow, KatanaColors.surface], { begin: Align.topLeft, end: Align.bottomRight }),
        border: `1px solid ${KatanaColors.borderStrong}`,
        marginBottom: 18,
      }}
    >
      <div
        style={{
          position: 'relative',
          padding: compact ? 14 : 22,
          display: 'flex',
          gap: compact ? 14 : 22,
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
            width: compact ? 104 : 148,
            height: compact ? 150 : 212,
            borderRadius: 10,
            overflow: 'hidden',
            flexShrink: 0,
            border: `1px solid ${KatanaColors.borderStrong}`,
            background: KatanaColors.surfaceAlt,
          }}
        >
          <KatanaCoverImage url={featured.coverUrl} iconSize={32} />
        </button>

        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: compact ? 6 : 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            <span
              style={{
                padding: '2px 9px',
                borderRadius: 99,
                background: withAlpha(KatanaColors.accent, 0.16),
                border: `1px solid ${withAlpha(KatanaColors.accent, 0.4)}`,
                fontFamily: Fonts.body,
                fontSize: 11,
                fontWeight: 700,
                color: KatanaColors.accentSoft,
                letterSpacing: 0.4,
              }}
            >
              FEATURED
            </span>
            <span
              style={{
                padding: '2px 8px',
                borderRadius: 99,
                background: withAlpha(completed ? KatanaColors.green : KatanaColors.teal, 0.14),
                fontFamily: Fonts.body,
                fontSize: 11,
                fontWeight: 600,
                color: completed ? KatanaColors.green : KatanaColors.teal,
              }}
            >
              {completed ? 'Completed' : 'Ongoing'}
            </span>
            {featured.latestChapter && (
              <span style={{ ...KatanaType.small, fontSize: 12 }}>
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
                fontSize: compact ? 20 : 28,
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
                    background: KatanaColors.surfaceAlt,
                    border: `1px solid ${KatanaColors.border}`,
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
            <p className="clamp-2" style={{ ...KatanaType.body, margin: 0, maxWidth: 640 }}>
              {featured.summary}
            </p>
          )}

          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginTop: 2 }}>
            <KatanaButton
              label={bm?.lastReadChapterId ? `Continue ${bm.lastReadChapterTitle || ''}`.trim() : 'Start Reading'}
              icon="play_arrow"
              size={compact ? 'sm' : 'md'}
              onClick={() => {
                const target = bm?.lastReadChapterId || featured.chapters[featured.chapters.length - 1]?.id || 'fc';
                onOpenChapter(featured, target);
              }}
            />
            <KatanaButton
              label="Details"
              icon="info"
              filled={false}
              color={KatanaColors.textMuted}
              size={compact ? 'sm' : 'md'}
              onClick={() => onSelectManga(featured.slug)}
            />
            {candidates.length > 1 && (
              <div style={{ marginLeft: 'auto', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
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
      </div>
    </section>
  );
}

function CurrentlyReadingShelf({
  items,
  catalog,
  onSelectManga,
  onViewAll,
}: {
  items: KatanaBookmark[];
  catalog: KatanaManga[];
  onSelectManga: (slug: string) => void;
  onViewAll: () => void;
}) {
  if (items.length === 0) return null;
  const catalogMap = new Map(catalog.map((m) => [m.slug, m]));

  return (
    <section style={{ marginBottom: 18 }}>
      <KatanaSectionHeader
        title="Currently Reading"
        badge={String(items.length)}
        trailing={
          <button
            type="button"
            className="bare-button"
            onClick={onViewAll}
            style={{
              padding: '5px 11px',
              borderRadius: 99,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.borderStrong}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 3,
            }}
          >
            <span style={KatanaType.accent}>View all</span>
            <Icon name="chevron_right" size={16} color={KatanaColors.accentSoft} />
          </button>
        }
      />
      <div style={{ height: 10 }} />
      <div className="no-scrollbar" style={{ display: 'flex', gap: 12, overflowX: 'auto', paddingBottom: 4 }}>
        {items.slice(0, 10).map((bm) => {
          const matched = catalogMap.get(bm.slug);
          const currentNum = parseChapterNumber(bm.lastReadChapterTitle || bm.lastReadChapterId);
          const latestNum = parseChapterNumber(
            bm.latestChapterTitle || matched?.latestChapter?.title || matched?.latestChapter?.num || '',
          );
          const pct = latestNum > 0 && currentNum > 0 ? Math.min(100, Math.round((currentNum / latestNum) * 100)) : 0;
          const unread = latestNum > currentNum ? Math.max(0, Math.floor(latestNum - currentNum)) : 0;

          return (
            <button
              key={bm.slug}
              type="button"
              className="bare-button"
              onClick={() => onSelectManga(bm.slug)}
              style={{
                width: 124,
                flexShrink: 0,
                textAlign: 'left',
                display: 'flex',
                flexDirection: 'column',
              }}
            >
              <div
                style={{
                  position: 'relative',
                  width: 124,
                  height: 174,
                  borderRadius: 10,
                  overflow: 'hidden',
                  border: `1px solid ${KatanaColors.borderStrong}`,
                  background: KatanaColors.surfaceAlt,
                }}
              >
                <KatanaCoverImage url={bm.coverUrl} iconSize={24} />
                {unread > 0 && (
                  <span
                    style={{
                      position: 'absolute',
                      top: 6,
                      right: 6,
                      padding: '2px 6px',
                      borderRadius: 6,
                      background: KatanaColors.crimson,
                      color: '#FFFFFF',
                      fontFamily: Fonts.body,
                      fontSize: 10,
                      fontWeight: 800,
                    }}
                  >
                    +{unread} new
                  </span>
                )}
                <div
                  style={{
                    position: 'absolute',
                    left: 0,
                    right: 0,
                    bottom: 0,
                    padding: '18px 8px 8px',
                    background: 'linear-gradient(to top, rgba(11, 13, 18, 0.94), transparent)',
                  }}
                >
                  {bm.lastReadChapterTitle && (
                    <div
                      className="ellipsis"
                      style={{
                        fontFamily: Fonts.body,
                        fontSize: 11,
                        fontWeight: 700,
                        color: KatanaColors.accentSoft,
                      }}
                    >
                      {bm.lastReadChapterTitle}
                      {latestNum > 0 ? ` / ${latestNum}` : ''}
                    </div>
                  )}
                  {pct > 0 && (
                    <div
                      style={{
                        height: 4,
                        borderRadius: 99,
                        background: 'rgba(255,255,255,0.18)',
                        marginTop: 5,
                        overflow: 'hidden',
                      }}
                    >
                      <div style={{ width: `${pct}%`, height: '100%', background: KatanaColors.accent, borderRadius: 99 }} />
                    </div>
                  )}
                </div>
              </div>
              <div style={{ height: 7 }} />
              <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
                {bm.title || bm.slug.replace(/-/g, ' ')}
              </div>
            </button>
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
  type,
  typeItems,
  typeLoading,
  typePage,
  typeHasNext,
  onSelectType,
  onTypePage,
  onSelectManga,
  onSelectGenre,
  onOpenChapter,
  onViewAllReading,
  onRetryHome,
}: {
  width: number;
  data: KatanaHomeData;
  currentlyReading?: KatanaBookmark[];
  type: MangaType;
  typeItems: KatanaManga[];
  typeLoading: boolean;
  typePage: number;
  typeHasNext: boolean;
  onSelectType: (t: MangaType) => void;
  onTypePage: (page: number) => void;
  onSelectManga: (slug: string) => void;
  onSelectGenre: (g: KatanaGenre) => void;
  onOpenChapter: (manga: KatanaManga, chapterId: string) => void;
  onViewAllReading?: () => void;
  onRetryHome?: () => void;
}) {
  const desktop = width >= KATANA_BREAKPOINTS.desktop;
  const tablet = width >= KATANA_BREAKPOINTS.tablet;
  const compact = width < KATANA_BREAKPOINTS.tablet;
  const [viewMode, setViewMode] = useState<'grid' | 'list'>(() => (width >= KATANA_BREAKPOINTS.tablet ? 'grid' : 'list'));

  const effectiveView = compact ? 'list' : viewMode;
  const allCatalog = useMemo(() => {
    const seen = new Map<string, KatanaManga>();
    for (const m of [...data.hotUpdates, ...data.hot, ...data.latest]) {
      if (!seen.has(m.slug)) seen.set(m.slug, m);
    }
    return [...seen.values()];
  }, [data.hotUpdates, data.hot, data.latest]);

  const featuredCandidates = useMemo(() => {
    const pool = data.hot.length > 0 ? data.hot : data.latest;
    return pool.slice(0, 4);
  }, [data.hot, data.latest]);

  const recommended = useMemo(() => {
    if (allCatalog.length === 0) return [];
    const readingSlugs = new Set(currentlyReading.map((b) => b.slug));
    const preferredGenres = new Set<string>();
    for (const bm of currentlyReading) {
      const m = allCatalog.find((x) => x.slug === bm.slug);
      m?.genres.forEach((g) => preferredGenres.add(g.slug));
    }
    const candidates = allCatalog.filter((m) => !readingSlugs.has(m.slug));
    if (preferredGenres.size === 0) return candidates.slice(0, 8);
    return [...candidates]
      .sort((a, b) => {
        const aScore = a.genres.filter((g) => preferredGenres.has(g.slug)).length;
        const bScore = b.genres.filter((g) => preferredGenres.has(g.slug)).length;
        return bScore - aScore;
      })
      .slice(0, 8);
  }, [allCatalog, currentlyReading]);

  const openRandomPick = () => {
    if (allCatalog.length === 0) return;
    const pick = allCatalog[Math.floor(Math.random() * allCatalog.length)];
    onSelectManga(pick.slug);
  };

  const renderFeedItems = (items: KatanaManga[]) => {
    if (effectiveView === 'grid') {
      const cols = desktop ? 4 : 3;
      return (
        <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 12 }}>
          {items.map((m) => (
            <KatanaPosterCard
              key={m.slug}
              manga={m}
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
            onSelectManga={onSelectManga}
            onSelectGenre={onSelectGenre}
            onOpenChapter={onOpenChapter}
          />
        ))}
      </div>
    );
  };

  const viewToggle = !compact && (
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
              width: 30,
              height: 26,
              borderRadius: 6,
              background: active ? KatanaColors.accent : 'transparent',
              display: 'grid',
              placeItems: 'center',
            }}
          >
            <Icon name={mode === 'grid' ? 'grid_view' : 'view_agenda'} size={16} color={active ? KatanaColors.accentInk : KatanaColors.textMuted} />
          </button>
        );
      })}
    </div>
  );

  const typeChips = (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
      <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex', gap: 8, flex: 1, minWidth: 0 }}>
        {(['all', 'manga', 'manhwa', 'manhua'] as const).map((t) => (
          <TypeChip
            key={t}
            label={TYPE_META[t].label}
            icon={TYPE_META[t].icon}
            selected={type === t}
            onClick={() => onSelectType(t)}
          />
        ))}
      </div>
      {allCatalog.length > 0 && (
        <button
          type="button"
          className="bare-button"
          onClick={openRandomPick}
          title="Pick a random title"
          style={{
            flexShrink: 0,
            padding: '7px 12px',
            borderRadius: 99,
            background: KatanaColors.surfaceAlt,
            border: `1px solid ${KatanaColors.borderStrong}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
          }}
        >
          <Icon name="casino" size={15} color={KatanaColors.accentSoft} />
          <span style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 600, color: KatanaColors.text }}>Random</span>
        </button>
      )}
    </div>
  );

  const recommendedRail =
    type === 'all' && recommended.length > 0 ? (
      <section style={{ marginBottom: 18 }}>
        <KatanaSectionHeader
          title={currentlyReading.length > 0 ? 'Recommended for You' : 'Trending Now'}
          trailing={<Icon name="auto_awesome" size={18} color={KatanaColors.accentSoft} />}
        />
        <div style={{ height: 10 }} />
        <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex', gap: 12, paddingBottom: 4 }}>
          {recommended.map((m) => (
            <KatanaCompactCard key={m.slug} manga={m} width={tablet ? 124 : 108} onSelect={() => onSelectManga(m.slug)} onOpenChapter={onOpenChapter} />
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
                    fontFamily: Fonts.display,
                    fontSize: 17,
                    fontWeight: 700,
                    color: i < 3 ? KatanaColors.accent : KatanaColors.textLight,
                    flexShrink: 0,
                  }}
                >
                  {i + 1}
                </span>
                <div style={{ position: 'relative', width: 42, height: 60, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surface }}>
                  <KatanaCoverImage url={m.coverUrl} iconSize={16} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
                    {m.title}
                  </div>
                  {m.latestChapter && (
                    <div className="ellipsis" style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.link, marginTop: 2 }}>
                      {chapterDisplayTitle(m.latestChapter)}
                    </div>
                  )}
                </div>
              </button>
            ))}
          </div>
        ) : (
          <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex', gap: 12, paddingBottom: 4 }}>
            {data.hot.map((m) => (
              <KatanaCompactCard key={m.slug} manga={m} width={104} onSelect={() => onSelectManga(m.slug)} onOpenChapter={onOpenChapter} />
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

  const feedItems = type === 'all' ? data.latest : typeItems;
  const feedSection = (
    <section>
      <KatanaSectionHeader
        title={type === 'all' ? 'Latest Updates' : TYPE_META[type].label}
        trailing={
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 10 }}>
            {type !== 'all' && <span style={KatanaType.small}>{TYPE_META[type].eyebrow}</span>}
            {viewToggle}
          </div>
        }
      />
      <div style={{ height: 12 }} />
      {type !== 'all' && typeLoading && typeItems.length === 0 ? (
        <div style={{ padding: '48px 0', display: 'grid', placeItems: 'center' }}>
          <div className="spin" style={{ width: 34, height: 34, borderRadius: '50%', border: `3px solid ${KatanaColors.accent}`, borderRightColor: 'transparent', boxSizing: 'border-box' }} />
        </div>
      ) : feedItems.length === 0 ? (
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
      ) : (
        renderFeedItems(feedItems)
      )}
      {type !== 'all' && feedItems.length > 0 && (
        <div style={{ marginTop: 16 }}>
          <KatanaPagination page={typePage} hasPrev={typePage > 1} hasNext={typeHasNext} onPageChange={onTypePage} />
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
            <CurrentlyReadingShelf items={currentlyReading} catalog={allCatalog} onSelectManga={onSelectManga} onViewAll={() => onViewAllReading?.()} />
            {typeChips}
            <div style={{ height: 16 }} />
            {recommendedRail}
            {feedSection}
            {type === 'all' && hotCard && <div style={{ marginTop: 20 }}>{hotCard}</div>}
            {genresCard && <div style={{ marginTop: 18 }}>{genresCard}</div>}
          </>,
        )}
      </div>
    );
  }

  return (
    <div style={{ padding: '18px 16px 48px' }}>
      {center(
        <>
          {data.error && <KatanaErrorBanner message={data.error} onRetry={onRetryHome} />}
          {type === 'all' && (
            <FeaturedHero
              candidates={featuredCandidates}
              bookmarks={currentlyReading}
              compact={false}
              onSelectManga={onSelectManga}
              onOpenChapter={onOpenChapter}
              onSelectGenre={onSelectGenre}
            />
          )}
          <CurrentlyReadingShelf items={currentlyReading} catalog={allCatalog} onSelectManga={onSelectManga} onViewAll={() => onViewAllReading?.()} />
          {typeChips}
          <div style={{ height: 16 }} />
          {recommendedRail}
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 18 }}>
            <div style={{ flex: 7, minWidth: 0 }}>{feedSection}</div>
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
