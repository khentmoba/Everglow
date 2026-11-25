import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { reduceAmbientMotion } from '../../core/system/device';
import { withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { KatanaFonts as Fonts } from './katanaTokens';
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
  KatanaSkeletonGrid,
  KatanaSkeletonList,
} from './MangaUi';
import {
  chapterDisplayTitle,
  computeSeriesReleaseSchedule,
  estimateUnreadCount,
  extractChapterNumber,
  fetchKatanaCatalog,
  formatKatanaTime,
  getPreferredMangaGenres,
  proxyKatanaImageUrl,
  setPreferredMangaGenres,
  type KatanaBookmark,
  type KatanaGenre,
  type KatanaHomeData,
  type KatanaManga,
  type KatanaSourceHealth,
  type KatanaWeekday,
} from './katanaService';
import { getKatanaGridColumns, KATANA_BREAKPOINTS, KatanaColors, KatanaType, useCoverDominantAccent } from './katanaTokens';

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
  selected,
  compact,
  onClick,
}: {
  label: string;
  icon?: string;
  selected: boolean;
  compact?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={selected}
      className="bare-button"
      onClick={onClick}
      style={{
        flex: compact ? 1 : undefined,
        minWidth: 0,
        minHeight: 44,
        padding: compact ? '0 4px' : '0 14px',
        position: 'relative',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        borderBottom: selected ? `2px solid ${KatanaColors.accent}` : '2px solid transparent',
        marginBottom: -1,
        transition: 'color 150ms ease, border-color 150ms ease',
      }}
    >
      <span
        style={{
          fontFamily: Fonts.body,
          fontWeight: selected ? 700 : 500,
          fontSize: compact ? 13.5 : 14,
          lineHeight: lineHeight(compact ? 13.5 : 14, 1.2),
          color: selected ? KatanaColors.text : KatanaColors.textLight,
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
  const featured = candidates.length > 0 ? candidates[index % candidates.length] : null;
  const backdropUrl = featured?.coverUrl ? proxyKatanaImageUrl(featured.coverUrl) : '';
  const heroAccent = useCoverDominantAccent(
    backdropUrl,
    featured?.title ?? '',
    featured?.genres.map((g) => g.name),
  );
  const swipeStartRef = useRef<{ x: number; y: number } | null>(null);
  if (!featured) return null;
  const bm = bookmarks.find((b) => b.slug === featured.slug);
  const completed = featured.status === 'completed';
  const allowBlur = !reduceAmbientMotion({
    width: typeof window !== 'undefined' ? window.innerWidth : 1024,
    height: typeof window !== 'undefined' ? window.innerHeight : 800,
  });

  const handleTouchStart = (e: React.TouchEvent) => {
    if (candidates.length <= 1 || e.touches.length !== 1) return;
    swipeStartRef.current = { x: e.touches[0].clientX, y: e.touches[0].clientY };
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    const start = swipeStartRef.current;
    swipeStartRef.current = null;
    if (!start || candidates.length <= 1 || e.changedTouches.length === 0) return;
    const dx = e.changedTouches[0].clientX - start.x;
    const dy = e.changedTouches[0].clientY - start.y;
    if (Math.abs(dx) < 42 || Math.abs(dx) < Math.abs(dy) * 1.2) return;
    setIndex((prev) => (dx < 0 ? (prev + 1) % candidates.length : (prev - 1 + candidates.length) % candidates.length));
  };

  return (
    <section
      aria-label="Featured title"
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
      style={{
        position: 'relative',
        margin: desktop ? '0 0 24px' : '-14px -16px 18px',
        borderRadius: desktop ? 10 : 0,
        overflow: 'hidden',
        background: KatanaColors.background,
        minHeight: compact ? 376 : desktop ? 360 : 340,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'flex-end',
      }}
    >
      {/* Full-bleed cover artwork stage */}
      {backdropUrl ? (
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
            objectPosition: compact ? 'center 18%' : 'center 24%',
            filter: !compact && allowBlur ? 'blur(18px) saturate(1.1) brightness(0.45)' : 'brightness(0.76)',
            transform: !compact && allowBlur ? 'scale(1.12)' : undefined,
            pointerEvents: 'none',
          }}
        />
      ) : (
        <div
          aria-hidden="true"
          style={{
            position: 'absolute',
            inset: 0,
            background: `radial-gradient(circle at 25% 20%, ${withAlpha(heroAccent.accent, 0.28)} 0%, ${KatanaColors.background} 85%)`,
            pointerEvents: 'none',
          }}
        />
      )}
      <div
        aria-hidden="true"
        style={{
          position: 'absolute',
          inset: 0,
          background: compact
            ? `linear-gradient(180deg, ${withAlpha(KatanaColors.background, 0.14)} 0%, ${withAlpha(KatanaColors.background, 0.45)} 44%, ${withAlpha(KatanaColors.background, 0.94)} 78%, ${KatanaColors.background} 100%)`
            : `linear-gradient(180deg, ${withAlpha(KatanaColors.background, 0.22)} 0%, ${withAlpha(KatanaColors.background, 0.64)} 58%, ${KatanaColors.background} 100%)`,
          pointerEvents: 'none',
        }}
      />

      <div
        style={{
          position: 'relative',
          padding: compact ? '140px 18px 18px' : desktop ? '28px 30px' : '26px 24px 22px',
          display: 'flex',
          gap: desktop ? 28 : 22,
          alignItems: 'flex-end',
        }}
      >
        {!compact && (
          <button
            type="button"
            className="bare-button"
            aria-label={`Open ${featured.title}`}
            onClick={() => onSelectManga(featured.slug)}
            style={{
              position: 'relative',
              width: desktop ? 176 : 148,
              height: desktop ? 258 : 216,
              borderRadius: 7,
              overflow: 'hidden',
              flexShrink: 0,
              background: KatanaColors.surfaceAlt,
              boxShadow: '0 18px 42px rgba(0,0,0,0.68)',
            }}
          >
            <KatanaCoverImage url={featured.coverUrl} title={featured.title} iconSize={34} priority />
          </button>
        )}

        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: compact ? 8 : 10 }}>
          <div
            className="katana-tabular"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              flexWrap: 'wrap',
              fontFamily: Fonts.body,
              fontSize: 12.5,
              fontWeight: 600,
              color: KatanaColors.textMuted,
            }}
          >
            <span style={{ color: completed ? KatanaColors.green : KatanaColors.teal }}>
              {completed ? 'Completed' : 'Ongoing'}
            </span>
            {featured.rating != null && (
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, color: KatanaColors.text }}>
                <Icon name="star" size={13} color={KatanaColors.accent} />
                {featured.rating.toFixed(1)}
              </span>
            )}
            {featured.latestChapter && (
              <span className="ellipsis">
                {featured.latestChapter.num
                  ? `Ch. ${featured.latestChapter.num}`
                  : chapterDisplayTitle(featured.latestChapter)}
              </span>
            )}
            {featured.genres.slice(0, compact ? 2 : 3).map((g) => (
              <button
                key={g.slug}
                type="button"
                className="bare-button"
                onClick={() => onSelectGenre(g)}
                style={{
                  fontFamily: Fonts.body,
                  fontSize: 12.5,
                  fontWeight: 500,
                  color: KatanaColors.textMuted,
                }}
              >
                {g.name}
              </button>
            ))}
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
                fontFamily: Fonts.heading,
                fontWeight: 700,
                color: KatanaColors.text,
                fontSize: compact ? 28 : desktop ? 36 : 32,
                letterSpacing: -0.9,
                lineHeight: 1.08,
                margin: 0,
              }}
            >
              {featured.title}
            </h1>
          </button>

          {featured.summary && (
            <p
              className={compact ? 'clamp-2' : 'clamp-3'}
              style={{
                ...KatanaType.body,
                fontSize: compact ? 13.5 : 14,
                margin: 0,
                maxWidth: 560,
                lineHeight: 1.5,
                color: withAlpha(KatanaColors.text, 0.78),
              }}
            >
              {featured.summary}
            </p>
          )}

          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginTop: 4 }}>
            <KatanaButton
              label={
                bm?.status === 'completed'
                  ? 'Read Again'
                  : bm?.lastReadChapterId
                    ? `Continue ${bm.lastReadChapterTitle || ''}`.trim()
                    : 'Start Reading'
              }
              icon="play_arrow"
              size="md"
              onClick={() => {
                const first = featured.chapters[featured.chapters.length - 1]?.id || 'fc';
                const target = bm?.status === 'completed' ? first : bm?.lastReadChapterId || first;
                onOpenChapter(featured, target);
              }}
            />
            <button
              type="button"
              className="bare-button"
              onClick={() => onSelectManga(featured.slug)}
              style={{
                minHeight: 46,
                padding: '0 14px',
                borderRadius: 7,
                background: 'rgba(255, 255, 255, 0.08)',
                fontFamily: Fonts.body,
                fontSize: 13.5,
                fontWeight: 600,
                color: KatanaColors.text,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 4,
              }}
            >
              <span>Details</span>
              <Icon name="chevron_right" size={17} color={KatanaColors.textMuted} />
            </button>
            {!desktop && candidates.length > 1 && (
              <div style={{ display: 'inline-flex', alignItems: 'center', marginLeft: 'auto' }}>
                {candidates.map((c, i) => (
                  <button
                    key={c.slug}
                    type="button"
                    className="bare-button"
                    aria-label={`Show featured title ${i + 1}: ${c.title}`}
                    aria-pressed={i === index}
                    onClick={() => setIndex(i)}
                    style={{
                      minWidth: 26,
                      minHeight: 36,
                      padding: 0,
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <span
                      style={{
                        width: i === index ? 18 : 6,
                        height: 3,
                        borderRadius: 2,
                        background: i === index ? KatanaColors.accent : withAlpha(KatanaColors.text, 0.3),
                        transition: 'width 180ms ease, background 180ms ease',
                      }}
                    />
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {desktop && candidates.length > 1 && (
          <div
            style={{
              width: 340,
              flexShrink: 0,
              borderLeft: `1px solid ${withAlpha(KatanaColors.borderStrong, 0.7)}`,
              paddingLeft: 18,
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
                    background: active ? withAlpha(KatanaColors.surfaceGlow, 0.86) : withAlpha(KatanaColors.background, 0.45),
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
    <section style={{ marginBottom: 24 }}>
      <KatanaSectionHeader
        title="Currently Reading"
        badge={`${items.length}`}
        trailing={
          <button
            type="button"
            className="bare-button"
            onClick={onViewAll}
            style={{
              minHeight: 36,
              padding: '4px 2px',
              display: 'inline-flex',
              alignItems: 'center',
              gap: 2,
            }}
          >
            <span style={{ ...KatanaType.link, fontSize: 13 }}>View all</span>
            <Icon name="chevron_right" size={16} color={KatanaColors.link} />
          </button>
        }
      />
      <div style={{ height: 12 }} />
      <div
        className="no-scrollbar"
        style={{
          display: 'flex',
          gap: compact ? 12 : 16,
          overflowX: 'auto',
          paddingBottom: 2,
          scrollSnapType: 'x mandatory',
          WebkitOverflowScrolling: 'touch',
        }}
      >
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
                width: compact ? 116 : 134,
                flexShrink: 0,
                scrollSnapAlign: 'start',
                display: 'flex',
                flexDirection: 'column',
              }}
            >
              <button
                type="button"
                className="bare-button"
                onClick={() => {
                  if (onResumeBookmark && bm.lastReadChapterId) onResumeBookmark(bm);
                  else onSelectManga(bm.slug);
                }}
                aria-label={
                  onResumeBookmark && bm.lastReadChapterId ? `Continue ${bm.title}` : `Open ${bm.title}`
                }
                style={{
                  position: 'relative',
                  width: '100%',
                  aspectRatio: '2 / 3',
                  borderRadius: 6,
                  overflow: 'hidden',
                  background: KatanaColors.surfaceAlt,
                  boxShadow: '0 6px 18px rgba(0,0,0,0.4)',
                }}
              >
                <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={24} priority />
                <div
                  aria-hidden="true"
                  style={{
                    position: 'absolute',
                    inset: 'auto 0 0 0',
                    height: '38%',
                    background: 'linear-gradient(to top, rgba(8,8,10,0.88) 0%, transparent 100%)',
                    pointerEvents: 'none',
                  }}
                />
                {unread > 0 && (
                  <span
                    className="katana-tabular"
                    style={{
                      position: 'absolute',
                      top: 6,
                      right: 6,
                      padding: '2px 6px',
                      borderRadius: 4,
                      background: KatanaColors.accent,
                      color: KatanaColors.accentInk,
                      fontFamily: Fonts.body,
                      fontSize: 10.5,
                      fontWeight: 800,
                      lineHeight: 1.2,
                    }}
                  >
                    +{unread}
                  </span>
                )}
                {dlCount > 0 && (
                  <span
                    title={`${dlCount} ${dlCount === 1 ? 'chapter' : 'chapters'} ready offline`}
                    style={{
                      position: 'absolute',
                      bottom: 9,
                      left: 7,
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 2,
                      padding: '2px 5px',
                      borderRadius: 4,
                      background: 'rgba(8,8,10,0.78)',
                      fontFamily: Fonts.body,
                      fontSize: 10.5,
                      fontWeight: 700,
                      color: KatanaColors.green,
                    }}
                  >
                    <Icon name="download_done" size={11} color={KatanaColors.green} />
                    {dlCount}
                  </span>
                )}
                {onResumeBookmark && bm.lastReadChapterId && (
                  <span
                    aria-hidden="true"
                    style={{
                      position: 'absolute',
                      bottom: 8,
                      right: 7,
                      width: 28,
                      height: 28,
                      borderRadius: 99,
                      background: 'rgba(8,8,10,0.8)',
                      display: 'grid',
                      placeItems: 'center',
                    }}
                  >
                    <Icon name="play_arrow" size={16} color="#FFFFFF" />
                  </span>
                )}
                {pct > 0 && (
                  <div
                    aria-hidden="true"
                    style={{
                      position: 'absolute',
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 3,
                      background: 'rgba(255,255,255,0.16)',
                    }}
                  >
                    <div style={{ width: `${pct}%`, height: '100%', background: KatanaColors.accent }} />
                  </div>
                )}
              </button>
              <button
                type="button"
                className="bare-button"
                onClick={() => onSelectManga(bm.slug)}
                style={{ textAlign: 'left', paddingTop: 7, display: 'flex', flexDirection: 'column', gap: 2 }}
              >
                <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
                  {bm.title}
                </div>
                <span className="ellipsis katana-tabular" style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textLight }}>
                  {bm.lastReadChapterTitle || 'Resume'}
                  {(bm.lastReadPage ?? 0) > 1 ? ` · p.${bm.lastReadPage}` : ''}
                </span>
              </button>
            </div>
          );
        })}
      </div>
    </section>
  );
}

const WEEKDAYS: KatanaWeekday[] = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

function todayWeekday(): KatanaWeekday {
  const jsDay = new Date().getDay(); // 0=Sun..6=Sat
  return WEEKDAYS[(jsDay + 6) % 7];
}

type ScheduledCalendarEntry = {
  manga: KatanaManga;
  releaseDay: KatanaWeekday;
  verified: boolean;
  followed: boolean;
  nextReleaseAt?: number;
  intervalDays?: number;
};

function ReleaseCalendarRail({
  catalog,
  bookmarks = [],
  unreadBySlug,
  downloadedCounts,
  compact,
  onSelectManga,
}: {
  catalog: KatanaManga[];
  bookmarks?: KatanaBookmark[];
  unreadBySlug: Record<string, number>;
  downloadedCounts: Record<string, number>;
  compact: boolean;
  onSelectManga: (slug: string) => void;
}) {
  const today = useMemo(() => todayWeekday(), []);
  const todayIdx = WEEKDAYS.indexOf(today);
  const [calendarMode, setCalendarMode] = useState<'upcoming' | 'followed' | 'recent'>('upcoming');

  const allEntries = useMemo((): ScheduledCalendarEntry[] => {
    const bmBySlug = new Map(bookmarks.filter((b) => b.bookmarked).map((b) => [b.slug, b]));
    const out: ScheduledCalendarEntry[] = [];
    const seen = new Set<string>();

    for (const m of catalog) {
      const bm = bmBySlug.get(m.slug);
      const sched = computeSeriesReleaseSchedule(m.recentChapters.length > 0 ? m.recentChapters : m.chapters, m.updateText, bm);
      const day = sched.releaseDay ?? m.releaseDay;
      if (!day) continue;
      seen.add(m.slug);
      out.push({
        manga: { ...m, releaseDay: day },
        releaseDay: day,
        verified: sched.verified,
        followed: Boolean(bm),
        nextReleaseAt: sched.nextReleaseAt,
        intervalDays: sched.releaseIntervalMs ? Math.max(1, Math.round(sched.releaseIntervalMs / 86_400_000)) : undefined,
      });
    }

    // Also include followed ongoing bookmarks with stored schedule telemetry that aren't in the current catalog slice.
    for (const bm of bmBySlug.values()) {
      if (seen.has(bm.slug)) continue;
      const sched = computeSeriesReleaseSchedule(undefined, undefined, bm);
      if (!sched.releaseDay) continue;
      seen.add(bm.slug);
      out.push({
        manga: {
          slug: bm.slug,
          id: bm.slug,
          title: bm.title,
          coverUrl: bm.coverUrl,
          status: bm.status || 'ongoing',
          updateText: bm.cadenceHours ? `Every ${Math.max(1, Math.round(bm.cadenceHours / 24))}d` : 'Tracked schedule',
          summary: '',
          genres: [],
          latestChapter: bm.latestChapterTitle
            ? { id: bm.latestChapterId || 'c1', num: String(bm.latestChapterNum || ''), title: bm.latestChapterTitle }
            : undefined,
          recentChapters: [],
          altNames: [],
          authors: [],
          artists: [],
          chapters: [],
          releaseDay: sched.releaseDay,
        },
        releaseDay: sched.releaseDay,
        verified: sched.verified,
        followed: true,
        nextReleaseAt: sched.nextReleaseAt,
        intervalDays: sched.releaseIntervalMs ? Math.max(1, Math.round(sched.releaseIntervalMs / 86_400_000)) : 7,
      });
    }
    return out;
  }, [catalog, bookmarks]);

  const scheduled = useMemo(() => {
    if (calendarMode === 'followed') {
      const followed = allEntries.filter((e) => e.followed && e.manga.status.toLowerCase() !== 'completed');
      return followed.length > 0 ? followed : allEntries.filter((e) => e.manga.status.toLowerCase() !== 'completed');
    }
    if (calendarMode === 'upcoming') {
      return allEntries.filter((e) => e.manga.status.toLowerCase() !== 'completed');
    }
    return allEntries;
  }, [allEntries, calendarMode]);

  const byDay = useMemo(() => {
    const map: Record<KatanaWeekday, ScheduledCalendarEntry[]> = {
      Mon: [], Tue: [], Wed: [], Thu: [], Fri: [], Sat: [], Sun: [],
    };
    for (const entry of scheduled) {
      map[entry.releaseDay].push(entry);
    }
    for (const day of WEEKDAYS) {
      map[day].sort((a, b) => Number(b.followed) - Number(a.followed) || Number(b.verified) - Number(a.verified));
    }
    return map;
  }, [scheduled]);

  const [selectedDay, setSelectedDay] = useState<KatanaWeekday>(() => {
    if (catalog.some((m) => m.releaseDay === today) || bookmarks.some((b) => b.releaseDay === today)) return today;
    return catalog.find((m) => m.releaseDay)?.releaseDay ?? today;
  });

  if (allEntries.length === 0) return null;

  const activeItems = byDay[selectedDay] ?? [];
  const selectedIdx = WEEKDAYS.indexOf(selectedDay);
  const daysAhead = (selectedIdx - todayIdx + 7) % 7;
  const dueTodayCount = byDay[today]?.length ?? 0;
  const upcomingEtaLabel =
    daysAhead === 0
      ? `${activeItems.length} series expected today`
      : daysAhead === 1
        ? 'Expected tomorrow'
        : `Expected in ${daysAhead}d`;

  return (
    <section aria-label="Release calendar" style={{ marginTop: 22 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
        <KatanaSectionHeader
          title={
            calendarMode === 'followed'
              ? 'My Release Schedule'
              : calendarMode === 'upcoming'
                ? 'Daily Release Schedule'
                : 'Recently Updated by Day'
          }
          badge={selectedDay === today ? `Today · ${activeItems.length}` : `${selectedDay} · ${activeItems.length}`}
        />
        <div
          role="tablist"
          aria-label="Calendar view"
          style={{
            display: 'inline-flex',
            gap: 14,
          }}
        >
          {([
            { key: 'upcoming', label: 'Daily Schedule' },
            { key: 'followed', label: 'Following' },
            { key: 'recent', label: 'Recent' },
          ] as const).map((m) => {
            const active = calendarMode === m.key;
            return (
              <button
                key={m.key}
                type="button"
                role="tab"
                aria-selected={active}
                className="bare-button"
                onClick={() => setCalendarMode(m.key)}
                style={{
                  minHeight: 36,
                  padding: '4px 0',
                  borderBottom: `2px solid ${active ? KatanaColors.accent : 'transparent'}`,
                  fontFamily: Fonts.body,
                  fontSize: 12.5,
                  fontWeight: active ? 700 : 500,
                  color: active ? KatanaColors.text : KatanaColors.textMuted,
                }}
              >
                {m.label}
              </button>
            );
          })}
        </div>
      </div>
      <div style={{ ...KatanaType.small, fontSize: 12, marginTop: 4 }}>
        {calendarMode === 'recent'
          ? 'Grouped by each series’ newest chapter.'
          : `${upcomingEtaLabel}${dueTodayCount > 0 && selectedDay !== today ? ` · ${dueTodayCount} due today` : ''}`}
      </div>
      <div style={{ height: 10 }} />
      <div
        className="no-scrollbar"
        role="tablist"
        aria-label="Update day"
        style={{
          display: 'flex',
          gap: 16,
          overflowX: 'auto',
          marginBottom: 12,
          borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.8)}`,
          maskImage: 'linear-gradient(to right, black 92%, transparent 100%)',
          WebkitMaskImage: 'linear-gradient(to right, black 92%, transparent 100%)',
        }}
      >
        {WEEKDAYS.map((day) => {
          const active = selectedDay === day;
          const count = byDay[day].length;
          const isToday = day === today;
          return (
            <button
              key={day}
              type="button"
              role="tab"
              aria-selected={active}
              className="bare-button"
              onClick={() => setSelectedDay(day)}
              style={{
                flexShrink: 0,
                minHeight: 40,
                padding: '6px 2px',
                borderBottom: `2px solid ${active ? KatanaColors.accent : 'transparent'}`,
                marginBottom: -1,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 5,
              }}
            >
              <span
                style={{
                  fontFamily: Fonts.body,
                  fontSize: 13,
                  fontWeight: active ? 700 : 500,
                  color: active ? KatanaColors.text : KatanaColors.textMuted,
                }}
              >
                {day}
              </span>
              {isToday && (
                <span
                  aria-label="Today"
                  style={{
                    width: 5,
                    height: 5,
                    borderRadius: 99,
                    background: KatanaColors.accent,
                  }}
                />
              )}
              {count > 0 && (
                <span
                  className="katana-tabular"
                  style={{
                    ...KatanaType.small,
                    fontSize: 11,
                    fontWeight: 600,
                    color: active ? KatanaColors.accentSoft : KatanaColors.textLight,
                  }}
                >
                  {count}
                </span>
              )}
            </button>
          );
        })}
      </div>
      {activeItems.length === 0 ? (
        <div
          style={{
            padding: '14px 0',
            ...KatanaType.small,
            color: KatanaColors.textMuted,
          }}
        >
          No series updated on {selectedDay} recently. Tap another day to see recent drops.
        </div>
      ) : (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: compact ? '1fr' : 'repeat(2, minmax(0, 1fr))',
            columnGap: 20,
          }}
        >
          {activeItems.slice(0, 6).map((entry) => {
            const m = entry.manga;
            const unread = unreadBySlug[m.slug] ?? 0;
            const dl = downloadedCounts[m.slug] ?? 0;
            const isDueToday = selectedDay === today && calendarMode !== 'recent';
            return (
              <button
                key={m.slug}
                type="button"
                className="bare-button"
                onClick={() => onSelectManga(m.slug)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  padding: '10px 0',
                  borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.72)}`,
                  textAlign: 'left',
                  minHeight: 68,
                }}
              >
                <div style={{ position: 'relative', width: 42, height: 60, borderRadius: 5, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                  <KatanaCoverImage url={m.coverUrl} title={m.title} iconSize={16} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 13.5, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
                    {m.title}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 6, marginTop: 4 }}>
                    {isDueToday && (
                      <span
                        style={{
                          fontFamily: Fonts.body,
                          fontSize: 11,
                          fontWeight: 700,
                          color: KatanaColors.green,
                        }}
                      >
                        Expected today
                      </span>
                    )}
                    {entry.followed && (
                      <span
                        style={{
                          fontFamily: Fonts.body,
                          fontSize: 11,
                          fontWeight: 600,
                          color: KatanaColors.accentSoft,
                        }}
                      >
                        {entry.intervalDays ? `Every ${entry.intervalDays}d` : 'Following'}
                      </span>
                    )}
                    {m.latestChapter && (
                      <span style={{ ...KatanaType.small, fontSize: 12, color: KatanaColors.textMuted }}>
                        {chapterDisplayTitle(m.latestChapter)}
                      </span>
                    )}
                    {m.updateText && !isDueToday && (
                      <span style={{ ...KatanaType.small, fontSize: 11.5 }}>{m.updateText}</span>
                    )}
                  </div>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 3, flexShrink: 0 }}>
                  {unread > 0 && (
                    <span
                      className="katana-tabular"
                      style={{
                        padding: '2px 6px',
                        borderRadius: 4,
                        background: KatanaColors.accent,
                        color: KatanaColors.accentInk,
                        fontFamily: Fonts.body,
                        fontSize: 10.5,
                        fontWeight: 800,
                      }}
                    >
                      +{unread}
                    </span>
                  )}
                  {dl > 0 && (
                    <span style={{ ...KatanaType.small, fontSize: 11, color: KatanaColors.green, fontWeight: 600 }}>
                      {dl} offline
                    </span>
                  )}
                </div>
              </button>
            );
          })}
        </div>
      )}
    </section>
  );
}

export function MangaHome({
  width,
  userName,
  syncedPreferredGenres,
  data,
  currentlyReading = [],
  libraryBookmarks = [],
  extraCatalog = [],
  downloadedCounts = {},
  sourceHealth,
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
  scrollContainerRef,
}: {
  width: number;
  userName?: string;
  syncedPreferredGenres?: string[];
  data: KatanaHomeData;
  currentlyReading?: KatanaBookmark[];
  libraryBookmarks?: KatanaBookmark[];
  extraCatalog?: KatanaManga[];
  downloadedCounts?: Record<string, number>;
  sourceHealth?: KatanaSourceHealth;
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
  scrollContainerRef?: React.RefObject<HTMLDivElement | null>;
}) {
  const desktop = width >= KATANA_BREAKPOINTS.desktop;
  const tablet = width >= KATANA_BREAKPOINTS.tablet;
  const compact = width < KATANA_BREAKPOINTS.tablet;
  const homeGridCols = desktop ? 4 : getKatanaGridColumns(width);
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
  const [feedTab, setFeedTab] = useState<FeedTab>('latest');
  const [tasteGenres, setTasteGenres] = useState<string[]>(() => getPreferredMangaGenres());
  const [tasteEditorOpen, setTasteEditorOpen] = useState(false);

  useEffect(() => {
    if (Array.isArray(syncedPreferredGenres) && syncedPreferredGenres.length > 0) {
      setTasteGenres((prev) => {
        if (prev.length === syncedPreferredGenres.length && prev.every((g, i) => g === syncedPreferredGenres[i])) {
          return prev;
        }
        return syncedPreferredGenres;
      });
    }
  }, [syncedPreferredGenres]);

  const effectiveView = viewMode;
  const [genreRecPool, setGenreRecPool] = useState<KatanaManga[]>([]);
  const topActiveGenresKey = useMemo(() => {
    const counts = new Map<string, number>();
    for (const g of tasteGenres) counts.set(g, (counts.get(g) ?? 0) + 3);
    for (const bm of libraryBookmarks) {
      if (bm.libraryStatus === 'dropped') continue;
      const w = bm.userScore != null && bm.userScore >= 8 ? 3 : 1;
      for (const g of bm.genres ?? []) counts.set(g, (counts.get(g) ?? 0) + w);
    }
    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map((e) => e[0])
      .join(',');
  }, [tasteGenres, libraryBookmarks]);

  useEffect(() => {
    if (!topActiveGenresKey) return;
    let alive = true;
    const slugs = topActiveGenresKey.split(',').filter(Boolean);
    void Promise.all(
      slugs.map((gSlug) => fetchKatanaCatalog({ mode: 'genre', key: gSlug, page: 1 }).catch(() => ({ items: [] as KatanaManga[] }))),
    ).then((results) => {
      if (!alive) return;
      const merged: KatanaManga[] = [];
      const seen = new Set<string>();
      for (const r of results) {
        for (const m of r.items) {
          if (!seen.has(m.slug)) {
            seen.add(m.slug);
            merged.push(m);
          }
        }
      }
      if (merged.length > 0) setGenreRecPool(merged);
    });
    return () => {
      alive = false;
    };
  }, [topActiveGenresKey]);

  const allCatalog = useMemo(() => {
    const seen = new Map<string, KatanaManga>();
    for (const m of [...data.hotUpdates, ...data.hot, ...data.latest, ...extraCatalog, ...genreRecPool]) {
      if (!seen.has(m.slug)) seen.set(m.slug, m);
    }
    return [...seen.values()];
  }, [data.hotUpdates, data.hot, data.latest, extraCatalog, genreRecPool]);

  const featuredCandidates = useMemo(() => {
    const pool = data.hot.length > 0 ? data.hot : data.latest;
    const readingSet = new Set(currentlyReading.map((b) => b.slug));
    const droppedSet = new Set(
      libraryBookmarks.filter((b) => b.libraryStatus === 'dropped').map((b) => b.slug),
    );
    const discoveryPool = pool.filter((m) => !readingSet.has(m.slug) && !droppedSet.has(m.slug));
    const candidates = discoveryPool.length >= 2 ? discoveryPool : pool;
    // Prioritize ongoing discovery titles before completed titles so the Hero Spotlight feels fresh and never duplicates Currently Reading.
    const sorted = [...candidates].sort((a, b) => {
      const aOngoing = a.status.toLowerCase() !== 'completed' ? 1 : 0;
      const bOngoing = b.status.toLowerCase() !== 'completed' ? 1 : 0;
      if (bOngoing !== aOngoing) return bOngoing - aOngoing;
      return (b.follows ?? 0) - (a.follows ?? 0) || (b.rating ?? 0) - (a.rating ?? 0);
    });
    return sorted.slice(0, 4);
  }, [data.hot, data.latest, currentlyReading, libraryBookmarks]);

  const [tasteOnboardDismissed, setTasteOnboardDismissed] = useState<boolean>(() => {
    try {
      return localStorage.getItem('katana_taste_onboarded_v1') === '1';
    } catch {
      return false;
    }
  });
  const [feedUnreadOnly, setFeedUnreadOnly] = useState(false);
  const [feedAlertsOnly, setFeedAlertsOnly] = useState(false);
  const [phoneControlsOpen, setPhoneControlsOpen] = useState(false);
  const [alertBannerDismissed, setAlertBannerDismissed] = useState(false);

  const dismissTasteOnboarding = () => {
    setTasteOnboardDismissed(true);
    try {
      localStorage.setItem('katana_taste_onboarded_v1', '1');
    } catch {
      // ignore storage errors
    }
  };

  const toggleTasteGenre = (slug: string) => {
    setTasteGenres((prev) => {
      const next = prev.includes(slug) ? prev.filter((s) => s !== slug) : [...prev, slug];
      return setPreferredMangaGenres(next, userName);
    });
  };

  const latestLeadSlugs = useMemo(() => new Set(data.latest.slice(0, 6).map((m) => m.slug)), [data.latest]);

  // Explainable recommendations: score-weighted, penalizing dropped genres, cross-rail deduped.
  const recommended = useMemo(() => {
    if (allCatalog.length === 0) return [];
    const readingSlugs = new Set(currentlyReading.map((b) => b.slug));
    const droppedSlugs = new Set(
      libraryBookmarks.filter((b) => b.libraryStatus === 'dropped').map((b) => b.slug),
    );
    const droppedGenres = new Set<string>();
    const ratedGenreSource = new Map<string, { title: string; score: number }>();
    const readingGenreSource = new Map<string, string>();
    const trackerGenreSource = new Map<string, string>();

    for (const bm of libraryBookmarks) {
      const m = allCatalog.find((x) => x.slug === bm.slug);
      const bmGenreSlugs =
        m && m.genres.length > 0
          ? m.genres.map((g) => g.slug)
          : Array.isArray(bm.genres) && bm.genres.length > 0
            ? bm.genres
            : [];
      if (bmGenreSlugs.length === 0) continue;
      if (bm.libraryStatus === 'dropped') {
        bmGenreSlugs.forEach((gSlug) => droppedGenres.add(gSlug));
        continue;
      }
      if (bm.anilistId || bm.malId || bm.kitsuId || bm.mangaUpdatesId || bm.shikimoriId || bm.bangumiId) {
        bmGenreSlugs.forEach((gSlug) => {
          if (!trackerGenreSource.has(gSlug)) trackerGenreSource.set(gSlug, bm.title);
        });
      }
      if (bm.userScore != null && bm.userScore >= 8) {
        for (const gSlug of bmGenreSlugs) {
          const prev = ratedGenreSource.get(gSlug);
          if (!prev || bm.userScore > prev.score) {
            ratedGenreSource.set(gSlug, { title: bm.title, score: bm.userScore });
          }
        }
      }
      if (bm.libraryStatus === 'completed' || readingSlugs.has(bm.slug)) {
        bmGenreSlugs.forEach((gSlug) => {
          if (!readingGenreSource.has(gSlug)) readingGenreSource.set(gSlug, bm.title);
        });
      }
    }

    const explicitSet = new Set(tasteGenres);
    const spotlightSlugs = new Set(featuredCandidates.map((m) => m.slug));
    const candidates = allCatalog.filter(
      (m) => !readingSlugs.has(m.slug) && !droppedSlugs.has(m.slug) && !spotlightSlugs.has(m.slug),
    );
    const nonDuplicate = candidates.filter((m) => !latestLeadSlugs.has(m.slug));
    const pool = nonDuplicate.length >= 4 ? nonDuplicate : candidates;

    const usedBecauseTitles = new Map<string, number>();
    const scored = pool.map((m) => {
      const explicitMatches = m.genres.filter((g) => explicitSet.has(g.slug));
      const ratedMatch = m.genres.find((g) => ratedGenreSource.has(g.slug));
      const trackerMatch = m.genres.find((g) => trackerGenreSource.has(g.slug));
      const historyMatch = m.genres.find((g) => readingGenreSource.has(g.slug));
      const droppedPenalty = m.genres.filter((g) => droppedGenres.has(g.slug)).length * 1.5;
      const novelBonus = latestLeadSlugs.has(m.slug) ? 0 : 1.5;
      const ratedBonus = ratedMatch ? (ratedGenreSource.get(ratedMatch.slug)!.score / 10) * 3.5 : 0;
      const trackerBonus = trackerMatch ? 2.4 : 0;
      const popularityBonus = m.follows && m.follows > 0 ? Math.min(2.2, Math.log10(m.follows + 1) * 0.42) : 0;
      const score =
        explicitMatches.length * 3 +
        ratedBonus +
        trackerBonus +
        (historyMatch ? 2 : 0) +
        (m.rating ? m.rating / 5 : 0) +
        popularityBonus +
        novelBonus -
        droppedPenalty;

      let reason = '';
      if (ratedMatch) {
        const fav = ratedGenreSource.get(ratedMatch.slug)!;
        const count = usedBecauseTitles.get(fav.title) ?? 0;
        if (count < 1) {
          usedBecauseTitles.set(fav.title, count + 1);
          reason = `Because you rated ${fav.title} ${fav.score}/10`;
        } else {
          reason = `Matches your ${ratedMatch.name} favorites`;
        }
      } else if (trackerMatch) {
        reason = `From your AniList & tracker watchlist (${trackerMatch.name})`;
      } else if (explicitMatches.length > 0) {
        reason = `Matches ${explicitMatches.slice(0, 2).map((g) => g.name).join(' · ')}`;
      } else if (historyMatch) {
        const src = readingGenreSource.get(historyMatch.slug)!;
        const count = usedBecauseTitles.get(src) ?? 0;
        if (count < 1) {
          usedBecauseTitles.set(src, count + 1);
          reason = `Because you read ${src}`;
        } else if (m.genres.length > 0) {
          reason = `More ${m.genres[0].name} for you`;
        } else if (m.rating != null) {
          reason = `Top rated · ${m.rating.toFixed(1)}`;
        }
      } else if (m.rating != null && m.rating >= 8.0) {
        reason = `Top rated · ${m.rating.toFixed(1)}`;
      } else if (m.follows != null && m.follows > 0) {
        reason = `Trending · ${m.follows.toLocaleString()} readers`;
      } else if (m.genres.length > 0) {
        reason = `Popular in ${m.genres[0].name}`;
      }
      return { manga: m, score, reason };
    });

    return scored.sort((a, b) => b.score - a.score).slice(0, 8);
  }, [allCatalog, currentlyReading, libraryBookmarks, tasteGenres, latestLeadSlugs, featuredCandidates]);

  const distinctHot = useMemo(() => {
    const recSlugs = new Set(recommended.slice(0, 6).map((r) => r.manga.slug));
    const ranked = [...data.hot].sort(
      (a, b) => (b.follows ?? 0) - (a.follows ?? 0) || (b.rating ?? 0) - (a.rating ?? 0),
    );
    const fresh = ranked.filter((m) => !recSlugs.has(m.slug));
    return fresh.length >= 4 ? fresh : ranked;
  }, [data.hot, recommended]);

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

  const liveLatestBySlug = useMemo(() => {
    const map: Record<string, number> = {};
    for (const m of allCatalog) {
      const n = extractChapterNumber(m.latestChapter?.title || m.latestChapter?.num || m.latestChapter?.id);
      if (n > 0) map[m.slug] = Math.max(map[m.slug] ?? 0, n);
    }
    return map;
  }, [allCatalog]);

  const libraryUnreadTotal = useMemo(() => {
    return libraryBookmarks.reduce((acc, bm) => acc + estimateUnreadCount(bm, liveLatestBySlug[bm.slug]), 0);
  }, [libraryBookmarks, liveLatestBySlug]);

  const openRandomPick = () => {
    if (allCatalog.length === 0) return;
    const pick = allCatalog[Math.floor(Math.random() * allCatalog.length)];
    onSelectManga(pick.slug);
  };

  const unreadBySlug = useMemo(() => {
    const map: Record<string, number> = {};
    for (const bm of currentlyReading) {
      map[bm.slug] = estimateUnreadCount(bm, liveLatestBySlug[bm.slug]);
    }
    return map;
  }, [currentlyReading, liveLatestBySlug]);

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
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2 }}>
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
              width: 44,
              height: 44,
              display: 'grid',
              placeItems: 'center',
            }}
          >
            <Icon name={mode === 'grid' ? 'grid_view' : 'view_agenda'} size={18} color={active ? KatanaColors.accent : KatanaColors.textLight} />
          </button>
        );
      })}
    </div>
  );

  const [railEditorOpen, setRailEditorOpen] = useState(false);
  type HomeRailId = 'reading' | 'feed' | 'pick_back_up' | 'trending' | 'calendar' | 'recommended' | 'hidden_gems';
  const DEFAULT_HOME_RAIL_ORDER: HomeRailId[] = [
    'reading',
    'feed',
    'trending',
    'calendar',
    'recommended',
    'hidden_gems',
  ];
  const HOME_RAIL_LABELS: Record<HomeRailId, string> = {
    reading: 'Currently Reading',
    feed: 'Catalog Updates Feed',
    pick_back_up: 'Pick Back Up',
    trending: 'Top 10 & Trending',
    calendar: 'Release Schedule',
    recommended: 'Picked for You',
    hidden_gems: 'Hidden Gems',
  };
  const [homeRailOrder, setHomeRailOrder] = useState<HomeRailId[]>(() => {
    try {
      const raw = localStorage.getItem('katana_home_rail_order_v1');
      if (raw) {
        const parsed = JSON.parse(raw) as HomeRailId[];
        if (Array.isArray(parsed) && parsed.length > 0) {
          const valid = parsed.filter((k) => DEFAULT_HOME_RAIL_ORDER.includes(k));
          const missing = DEFAULT_HOME_RAIL_ORDER.filter((k) => !valid.includes(k));
          return [...valid, ...missing];
        }
      }
    } catch {
      // ignore
    }
    return DEFAULT_HOME_RAIL_ORDER;
  });
  const [hiddenHomeRails, setHiddenHomeRails] = useState<HomeRailId[]>(() => {
    try {
      const raw = localStorage.getItem('katana_home_rails_hidden_v1');
      if (raw) {
        const parsed = JSON.parse(raw) as HomeRailId[];
        if (Array.isArray(parsed)) return parsed.filter((k) => DEFAULT_HOME_RAIL_ORDER.includes(k));
      }
    } catch {
      // ignore
    }
    return [];
  });

  const moveHomeRail = (railId: HomeRailId, delta: -1 | 1) => {
    setHomeRailOrder((prev) => {
      const idx = prev.indexOf(railId);
      const nextIdx = idx + delta;
      if (idx < 0 || nextIdx < 0 || nextIdx >= prev.length) return prev;
      const next = [...prev];
      const [item] = next.splice(idx, 1);
      next.splice(nextIdx, 0, item);
      try {
        localStorage.setItem('katana_home_rail_order_v1', JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
  };

  const toggleHomeRailVisible = (railId: HomeRailId) => {
    setHiddenHomeRails((prev) => {
      const next = prev.includes(railId) ? prev.filter((k) => k !== railId) : [...prev, railId];
      try {
        localStorage.setItem('katana_home_rails_hidden_v1', JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
  };

  const pickBackUpItems = useMemo(() => {
    if (type !== 'all') return [];
    const nowMs = Date.now();
    return libraryBookmarks
      .filter((bm) => {
        if (!bm.bookmarked && !bm.lastReadChapterId) return false;
        if (bm.libraryStatus === 'completed' || bm.libraryStatus === 'dropped') return false;
        if (bm.libraryStatus === 'on_hold') return true;
        const unread = estimateUnreadCount(bm, liveLatestBySlug[bm.slug]);
        const ageDays = bm.lastReadAt ? (nowMs - bm.lastReadAt.getTime()) / 86_400_000 : 14;
        return unread >= 2 || (unread >= 1 && ageDays >= 3);
      })
      .slice(0, 8);
  }, [libraryBookmarks, liveLatestBySlug, type]);

  const pickBackUpRail =
    type === 'all' && pickBackUpItems.length > 0 ? (
      <section aria-label="Pick back up" style={{ marginTop: 20 }}>
        <KatanaSectionHeader title="Pick Back Up" badge={`${pickBackUpItems.length} waiting`} />
        <div style={{ height: 10 }} />
        <div
          className="no-scrollbar"
          style={{
            display: 'flex',
            gap: 12,
            overflowX: 'auto',
            paddingBottom: 4,
            scrollSnapType: 'x mandatory',
          }}
        >
          {pickBackUpItems.map((bm) => {
            const unread = estimateUnreadCount(bm, liveLatestBySlug[bm.slug]);
            const reason =
              bm.libraryStatus === 'on_hold'
                ? unread > 0
                  ? `On Hold · +${unread} new`
                  : 'On Hold · Tap to resume'
                : unread > 0
                  ? `+${unread} unread since ${bm.lastReadChapterTitle || 'last read'}`
                  : `Continue ${bm.lastReadChapterTitle || 'reading'}`;
            return (
              <div
                key={`pickup-${bm.slug}`}
                style={{
                  width: compact ? 236 : 264,
                  flexShrink: 0,
                  scrollSnapAlign: 'start',
                  padding: '8px 0',
                  borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.72)}`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                }}
              >
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => onSelectManga(bm.slug)}
                  style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 10, textAlign: 'left' }}
                >
                  <div style={{ position: 'relative', width: 44, height: 64, borderRadius: 5, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                    <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={16} />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
                      {bm.title}
                    </div>
                    <div className="ellipsis" style={{ marginTop: 3, fontFamily: Fonts.body, fontSize: 11.5, fontWeight: 500, color: KatanaColors.accentSoft }}>
                      {reason}
                    </div>
                  </div>
                </button>
                <button
                  type="button"
                  className="bare-button"
                  aria-label={`Resume ${bm.title}`}
                  onClick={() => onResumeBookmark?.(bm)}
                  style={{
                    width: 40,
                    height: 40,
                    borderRadius: 99,
                    background: withAlpha(KatanaColors.accent, 0.14),
                    color: KatanaColors.accent,
                    display: 'grid',
                    placeItems: 'center',
                    flexShrink: 0,
                  }}
                >
                  <Icon name="play_arrow" size={20} color={KatanaColors.accent} />
                </button>
              </div>
            );
          })}
        </div>
      </section>
    ) : null;

  const hiddenGemsRail = useMemo(() => {
    if (type !== 'all' || allCatalog.length < 5) return null;
    const spotlightSet = new Set(featuredCandidates.map((m) => m.slug));
    const readingSet = new Set(currentlyReading.map((b) => b.slug));
    const recSet = new Set(recommended.slice(0, 4).map((r) => r.manga.slug));
    const gems = allCatalog
      .filter((m) => !spotlightSet.has(m.slug) && !readingSet.has(m.slug) && !recSet.has(m.slug))
      .sort((a, b) => (b.rating ?? 8.2) - (a.rating ?? 8.2) || (a.follows ?? 9999) - (b.follows ?? 9999))
      .slice(0, 8);
    if (gems.length < 3) return null;
    return (
      <section aria-label="Hidden gems" style={{ marginTop: 20 }}>
        <KatanaSectionHeader title="Hidden Gems" badge="High-Rated & Underrated" />
        <div style={{ height: 10 }} />
        <div className="no-scrollbar" style={{ display: 'flex', gap: 14, overflowX: 'auto', paddingBottom: 4 }}>
          {gems.map((m) => (
            <KatanaCompactCard
              key={`gem-${m.slug}`}
              manga={m}
              width={tablet ? 156 : 124}
              reason={
                m.rating != null
                  ? `★ ${m.rating.toFixed(1)} · Cult favorite`
                  : m.genres[0]
                    ? `Hidden ${m.genres[0].name} gem`
                    : 'Underrated pick'
              }
              onSelect={() => onSelectManga(m.slug)}
              onOpenChapter={onOpenChapter}
            />
          ))}
        </div>
      </section>
    );
  }, [type, allCatalog, featuredCandidates, currentlyReading, recommended, tablet, onSelectManga, onOpenChapter]);

  const typeStripRef = useRef<HTMLDivElement | null>(null);
  const typeChips = (
    <>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: compact ? 8 : 8 }}>
      <div
        ref={typeStripRef}
        role="tablist"
        aria-label="Format filter"
        style={{
          display: 'flex',
          gap: compact ? 0 : 8,
          borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.85)}`,
          flex: compact ? '1 1 100%' : '0 1 auto',
          minWidth: 0,
        }}
      >
        {(['all', 'manga', 'manhwa', 'manhua'] as const).map((t) => (
          <TypeChip
            key={t}
            label={TYPE_META[t].label}
            selected={type === t}
            compact={compact}
            onClick={() => onSelectType(t)}
          />
        ))}
      </div>
      {!compact && (
      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 10, flexShrink: 0, marginLeft: 'auto' }}>
        {type === 'all' && (
          <button
            type="button"
            className="bare-button"
            onClick={() => setRailEditorOpen((v) => !v)}
            aria-expanded={railEditorOpen}
            aria-label="Choose what shows on Home"
            title="Choose what shows on Home"
            style={{
              padding: '0 8px',
              minHeight: 40,
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 5,
            }}
          >
            <Icon name="reorder" size={16} color={railEditorOpen ? KatanaColors.accent : KatanaColors.textMuted} />
            <span style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 600, color: railEditorOpen ? KatanaColors.text : KatanaColors.textMuted }}>
              Arrange
            </span>
          </button>
        )}
        {allCatalog.length > 0 && (
          <button
            type="button"
            className="bare-button"
            onClick={openRandomPick}
            aria-label="Pick a random title"
            title="Pick a random title"
            style={{
              flexShrink: 0,
              padding: '0 8px',
              minHeight: 40,
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 5,
            }}
          >
            <Icon name="casino" size={16} color={KatanaColors.accent} />
            <span style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 600, color: KatanaColors.textMuted }}>Random</span>
          </button>
        )}
      </div>
      )}
    </div>
    {railEditorOpen && type === 'all' && (
      <KatanaCard padding={12} radius={10} style={{ marginTop: 10 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
          <span style={{ fontFamily: Fonts.body, fontSize: 12.5, fontWeight: 700, color: KatanaColors.text }}>
            Choose what shows on Home
          </span>
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              setHomeRailOrder(DEFAULT_HOME_RAIL_ORDER);
              setHiddenHomeRails([]);
              try {
                localStorage.removeItem('katana_home_rail_order_v1');
                localStorage.removeItem('katana_home_rails_hidden_v1');
              } catch {
                // ignore
              }
            }}
            style={{ ...KatanaType.link, fontSize: 12, minHeight: 36, padding: '0 8px' }}
          >
            Reset Default
          </button>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {homeRailOrder.map((railId, idx) => {
            const visible = !hiddenHomeRails.includes(railId);
            return (
              <div
                key={railId}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '4px 8px',
                  borderRadius: 8,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                }}
              >
                <button
                  type="button"
                  className="bare-button"
                  aria-pressed={visible}
                  onClick={() => toggleHomeRailVisible(railId)}
                  style={{
                    flex: 1,
                    minHeight: 40,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    textAlign: 'left',
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
                    fontWeight: 600,
                    color: visible ? KatanaColors.text : KatanaColors.textLight,
                  }}
                >
                  <Icon
                    name={visible ? 'visibility' : 'visibility_off'}
                    size={16}
                    color={visible ? KatanaColors.accent : KatanaColors.textLight}
                  />
                  <span>{HOME_RAIL_LABELS[railId]}</span>
                </button>
                <button
                  type="button"
                  className="bare-button"
                  aria-label={`Move ${HOME_RAIL_LABELS[railId]} up`}
                  disabled={idx === 0}
                  onClick={() => moveHomeRail(railId, -1)}
                  style={{ width: 40, height: 40, display: 'grid', placeItems: 'center', opacity: idx === 0 ? 0.35 : 1 }}
                >
                  <Icon name="arrow_upward" size={16} color={KatanaColors.textMuted} />
                </button>
                <button
                  type="button"
                  className="bare-button"
                  aria-label={`Move ${HOME_RAIL_LABELS[railId]} down`}
                  disabled={idx === homeRailOrder.length - 1}
                  onClick={() => moveHomeRail(railId, 1)}
                  style={{ width: 40, height: 40, display: 'grid', placeItems: 'center', opacity: idx === homeRailOrder.length - 1 ? 0.35 : 1 }}
                >
                  <Icon name="arrow_downward" size={16} color={KatanaColors.textMuted} />
                </button>
              </div>
            );
          })}
        </div>
      </KatanaCard>
    )}
    </>
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
                  onClick={() => setTasteGenres(setPreferredMangaGenres([], userName))}
                  style={{ ...KatanaType.small, color: KatanaColors.link, minHeight: 44 }}
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
      <section style={{ paddingTop: 18, borderTop: `1px solid ${withAlpha(KatanaColors.border, 0.75)}` }}>
        <KatanaSectionHeader title="Hot Manga" />
        <div style={{ height: 12 }} />
        {desktop ? (
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {distinctHot.slice(0, 6).map((m, i) => (
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
                  padding: '9px 0',
                  borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.7)}`,
                }}
              >
                <span
                  style={{
                    width: 24,
                    textAlign: 'center',
                    fontFamily: Fonts.display,
                    fontSize: 20,
                    fontWeight: 400,
                    color: i < 3 ? KatanaColors.accent : KatanaColors.textLight,
                    flexShrink: 0,
                  }}
                >
                  {i + 1}
                </span>
                <div style={{ position: 'relative', width: 42, height: 60, borderRadius: 5, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
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
                      <span className="ellipsis" style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textMuted }}>
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
            {distinctHot.map((m) => (
              <KatanaCompactCard key={m.slug} manga={m} width={124} onSelect={() => onSelectManga(m.slug)} onOpenChapter={onOpenChapter} />
            ))}
          </div>
        )}
      </section>
    ) : null;

  const genresCard =
    data.genres.length > 0 ? (
      <section style={{ paddingTop: 18, borderTop: `1px solid ${withAlpha(KatanaColors.border, 0.75)}` }}>
        <KatanaSectionHeader title="Genres" />
        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px 14px' }}>
          {data.genres.map((g) => (
            <button
              key={g.slug}
              type="button"
              className="bare-button"
              onClick={() => onSelectGenre(g)}
              style={{
                padding: '4px 0',
                whiteSpace: 'nowrap',
              }}
            >
              <span style={{ fontFamily: Fonts.body, fontWeight: 600, fontSize: 13.5, color: KatanaColors.textMuted }}>{g.name}</span>
              {g.count > 0 && <span className="katana-tabular" style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textLight }}> {g.count}</span>}
            </button>
          ))}
        </div>
      </section>
    ) : null;

  const alertsBySlug = useMemo(() => {
    const map: Record<string, boolean> = {};
    for (const bm of libraryBookmarks) {
      map[bm.slug] = bm.notifyOnUpdate !== false;
    }
    return map;
  }, [libraryBookmarks]);

  const alertUnreadSeriesCount = useMemo(() => {
    return libraryBookmarks.filter((bm) => bm.notifyOnUpdate !== false && estimateUnreadCount(bm) > 0).length;
  }, [libraryBookmarks]);

  const baseFeedItems =
    type !== 'all'
      ? typeItems
      : feedTab === 'new_hot'
        ? newAndHotItems
        : feedTab === 'updates'
          ? libraryUpdates
          : data.latest;

  const activeFeedItems = useMemo(() => {
    return baseFeedItems.filter((m) => {
      if (feedUnreadOnly && (unreadBySlug[m.slug] ?? 0) <= 0) return false;
      if (feedAlertsOnly && !alertsBySlug[m.slug]) return false;
      return true;
    });
  }, [baseFeedItems, feedUnreadOnly, feedAlertsOnly, unreadBySlug, alertsBySlug]);

  const showTasteOnboarding = !tasteOnboardDismissed && tasteGenres.length === 0 && type === 'all' && data.genres.length > 0;

  const tasteOnboardingBanner = showTasteOnboarding ? (
    <KatanaCard padding={compact ? 10 : 12} radius={12} style={{ marginTop: 12, borderColor: withAlpha(KatanaColors.accent, 0.35) }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, minWidth: 0 }}>
          <Icon name="auto_awesome" size={16} color={KatanaColors.accent} />
          <span style={{ fontFamily: Fonts.body, fontSize: 13.5, fontWeight: 700, color: KatanaColors.text }}>
            Pick a genre to personalize your feed
          </span>
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={dismissTasteOnboarding}
          style={{ ...KatanaType.small, padding: '4px 8px', minHeight: 44, flexShrink: 0 }}
        >
          Skip
        </button>
      </div>
      <div
        className="no-scrollbar"
        style={{ display: 'flex', flexWrap: compact ? 'nowrap' : 'wrap', overflowX: compact ? 'auto' : 'visible', gap: 6, marginTop: 8, paddingBottom: 2 }}
      >
        {data.genres.slice(0, 8).map((g) => {
          const picked = tasteGenres.includes(g.slug);
          return (
            <button
              key={g.slug}
              type="button"
              className="bare-button"
              aria-pressed={picked}
              onClick={() => {
                toggleTasteGenre(g.slug);
                dismissTasteOnboarding();
              }}
              style={{
                minHeight: 44,
                padding: '6px 12px',
                borderRadius: 99,
                flexShrink: 0,
                background: picked ? KatanaColors.accent : KatanaColors.surfaceAlt,
                border: `1px solid ${picked ? KatanaColors.accent : KatanaColors.borderStrong}`,
                fontFamily: Fonts.body,
                fontSize: 12,
                fontWeight: 600,
                color: picked ? KatanaColors.accentInk : KatanaColors.text,
                whiteSpace: 'nowrap',
              }}
            >
              + {g.name}
            </button>
          );
        })}
      </div>
    </KatanaCard>
  ) : null;

  const isSourceHealthDegraded = Boolean(
    sourceHealth &&
      (sourceHealth.fallbackActive ||
        sourceHealth.mangadexBatchOk === false ||
        sourceHealth.comickOk === false ||
        sourceHealth.batoOk === false),
  );

  const newChapterAlertBanner =
    (!alertBannerDismissed && alertUnreadSeriesCount > 0 && type === 'all' && feedTab !== 'updates') || isSourceHealthDegraded ? (
      <div
        role="status"
        style={{
          marginBottom: 18,
          padding: '8px 0',
          borderTop: `1px solid ${withAlpha(KatanaColors.border, 0.72)}`,
          borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.72)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 10,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0, flex: 1 }}>
          <span
            aria-hidden="true"
            style={{
              width: 7,
              height: 7,
              borderRadius: '50%',
              flexShrink: 0,
              background: isSourceHealthDegraded ? KatanaColors.orange : KatanaColors.accent,
            }}
          />
          <span className="ellipsis" style={{ fontFamily: Fonts.body, fontSize: 13, fontWeight: 500, color: KatanaColors.textMuted }}>
            {isSourceHealthDegraded
              ? 'Update checks degraded — fallback active'
              : `${alertUnreadSeriesCount} followed ${alertUnreadSeriesCount === 1 ? 'series has' : 'series have'} new chapters`}
          </span>
        </div>
        {alertUnreadSeriesCount > 0 && feedTab !== 'updates' && (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, flexShrink: 0 }}>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setAlertBannerDismissed(true);
                setFeedTab('updates');
              }}
              style={{
                minHeight: 32,
                padding: '0 4px',
                color: KatanaColors.accentSoft,
                fontFamily: Fonts.body,
                fontSize: 13,
                fontWeight: 700,
                whiteSpace: 'nowrap',
              }}
            >
              View
            </button>
            <button
              type="button"
              className="bare-button"
              aria-label="Dismiss chapter alerts banner"
              onClick={() => setAlertBannerDismissed(true)}
              style={{ width: 30, height: 30, display: 'grid', placeItems: 'center' }}
            >
              <Icon name="close" size={15} color={KatanaColors.textLight} />
            </button>
          </div>
        )}
      </div>
    ) : null;

  const [rankMode, setRankMode] = useState<'trending' | 'top'>('trending');
  const trendingRankedRail = useMemo(() => {
    const trendingSource = data.hotUpdates.length >= 4 ? data.hotUpdates : data.hot;
    const topRated = allCatalog
      .filter((m) => typeof m.rating === 'number' && m.rating > 0)
      .sort((a, b) => (b.rating ?? 0) - (a.rating ?? 0) || (b.follows ?? 0) - (a.follows ?? 0));
    const canRankTop = topRated.length >= 3;
    const mode = rankMode === 'top' && canRankTop ? 'top' : 'trending';
    const items = (mode === 'top' ? topRated : trendingSource).slice(0, 10);
    if (type !== 'all' || items.length < 3) return null;
    const modeButton = (key: 'trending' | 'top', label: string) => (
      <button
        key={key}
        type="button"
        className="bare-button"
        aria-pressed={mode === key}
        onClick={() => setRankMode(key)}
        style={{
          minHeight: 36,
          padding: '4px 0',
          borderBottom: `2px solid ${mode === key ? KatanaColors.accent : 'transparent'}`,
          fontFamily: Fonts.body,
          fontSize: 12.5,
          fontWeight: mode === key ? 700 : 500,
          color: mode === key ? KatanaColors.text : KatanaColors.textMuted,
        }}
      >
        {label}
      </button>
    );
    return (
      <section aria-label={mode === 'top' ? 'Top rated' : 'Trending this week'} style={{ marginTop: 20 }}>
        <KatanaSectionHeader
          title={mode === 'top' ? 'Top Rated' : 'Trending This Week'}
          badge={`Top ${items.length}`}
          trailing={
            canRankTop ? (
              <div role="group" aria-label="Ranking" style={{ display: 'inline-flex', gap: 14 }}>
                {modeButton('trending', 'Trending')}
                {modeButton('top', 'Top Rated')}
              </div>
            ) : undefined
          }
        />
        <div
          className="no-scrollbar"
          style={{
            display: 'flex',
            gap: 12,
            overflowX: 'auto',
            paddingTop: 10,
            paddingBottom: 4,
          }}
        >
          {items.map((m, idx) => {
            const rank = idx + 1;
            const rankBg =
              rank === 1
                ? KatanaColors.accent
                : rank === 2
                  ? '#CBD5E1'
                  : rank === 3
                    ? '#D97706'
                    : withAlpha(KatanaColors.background, 0.88);
            const rankFg = rank <= 3 ? KatanaColors.accentInk : KatanaColors.text;
            return (
              <button
                key={`rank-${m.slug}`}
                type="button"
                className="bare-button katana-card-hover"
                onClick={() => onSelectManga(m.slug)}
                style={{
                  width: compact ? 118 : 138,
                  flexShrink: 0,
                  textAlign: 'left',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 6,
                }}
              >
                <div style={{ position: 'relative', width: '100%', aspectRatio: '2 / 3', borderRadius: 10, overflow: 'hidden', background: KatanaColors.surfaceAlt }}>
                  <KatanaCoverImage url={m.coverUrl} title={m.title} />
                  <span
                    style={{
                      position: 'absolute',
                      top: 6,
                      left: 6,
                      minWidth: 26,
                      height: 24,
                      padding: '0 7px',
                      borderRadius: 7,
                      background: rankBg,
                      color: rankFg,
                      fontFamily: Fonts.display,
                      fontSize: 17,
                      fontWeight: 400,
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      boxShadow: '0 2px 8px rgba(0,0,0,0.45)',
                    }}
                  >
                    #{rank}
                  </span>
                  {unreadBySlug[m.slug] > 0 && (
                    <span
                      style={{
                        position: 'absolute',
                        top: 6,
                        right: 6,
                        padding: '2px 6px',
                        borderRadius: 6,
                        background: KatanaColors.accent,
                        color: KatanaColors.accentInk,
                        fontFamily: Fonts.body,
                        fontSize: 10.5,
                        fontWeight: 800,
                      }}
                    >
                      +{unreadBySlug[m.slug]}
                    </span>
                  )}
                </div>
                <div
                  style={{
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
                    fontWeight: 700,
                    color: KatanaColors.text,
                    lineHeight: 1.25,
                    display: '-webkit-box',
                    WebkitLineClamp: 2,
                    WebkitBoxOrient: 'vertical',
                    overflow: 'hidden',
                  }}
                >
                  {m.title}
                </div>
                {m.latestChapter && (
                  <div className="ellipsis" style={{ ...KatanaType.small, fontSize: 11, color: KatanaColors.textMuted }}>
                    {m.latestChapter.title || `Ch. ${m.latestChapter.num}`}
                    {m.latestChapter.updateAt ? ` · ${formatKatanaTime(m.latestChapter.updateAt)}` : ''}
                  </div>
                )}
              </button>
            );
          })}
        </div>
      </section>
    );
  }, [data.hotUpdates, data.hot, allCatalog, rankMode, type, compact, onSelectManga, unreadBySlug]);

  const feedTitle =
    type !== 'all'
      ? TYPE_META[type].label
      : feedTab === 'new_hot'
        ? 'New & Hot'
        : feedTab === 'updates'
          ? 'My Library Updates'
          : 'Latest Updates';

  const freshnessLabel = data.fetchedAt
    ? `${data.fromCache ? 'Saved copy' : 'Live'} · Updated ${formatKatanaTime(new Date(data.fetchedAt))}`
    : undefined;

  const phoneFilterActiveCount =
    (type !== 'all' ? 1 : 0) +
    (feedTab !== 'latest' ? 1 : 0) +
    (feedUnreadOnly ? 1 : 0) +
    (feedAlertsOnly ? 1 : 0);

  const feedSection = (
    <section aria-label="Manga catalog feed">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
        <div style={{ minWidth: 0 }}>
          <KatanaSectionHeader
            title={feedTitle}
            badge={
              type !== 'all' && typeLoading && typeItems.length > 0
                ? 'Updating…'
                : feedTab === 'updates' && libraryUnreadTotal > 0
                  ? `${libraryUnreadTotal} unread`
                  : undefined
            }
          />
          {freshnessLabel && type === 'all' && !compact && (
            <div style={{ ...KatanaType.small, fontSize: 11.5, marginTop: 2 }}>{freshnessLabel}</div>
          )}
        </div>
        {compact ? (
          <button
            type="button"
            className="bare-button"
            aria-expanded={phoneControlsOpen}
            onClick={() => setPhoneControlsOpen((v) => !v)}
            style={{
              minHeight: 36,
              padding: '0 4px',
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
              fontFamily: Fonts.body,
              fontSize: 13,
              fontWeight: 600,
              color: phoneControlsOpen || phoneFilterActiveCount > 0 ? KatanaColors.accentSoft : KatanaColors.textMuted,
              flexShrink: 0,
            }}
          >
            <Icon name="tune" size={15} color={phoneControlsOpen || phoneFilterActiveCount > 0 ? KatanaColors.accent : KatanaColors.textMuted} />
            <span>Sort & Filter{phoneFilterActiveCount > 0 ? ` (${phoneFilterActiveCount})` : ''}</span>
          </button>
        ) : (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 14, flexWrap: 'wrap' }}>
            {type === 'all' && (
              <div
                role="tablist"
                aria-label="Discovery feed"
                style={{
                  display: 'inline-flex',
                  gap: 14,
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
                        minHeight: 36,
                        padding: '4px 0',
                        borderBottom: `2px solid ${active ? KatanaColors.accent : 'transparent'}`,
                        fontFamily: Fonts.body,
                        fontSize: 13,
                        fontWeight: active ? 700 : 500,
                        color: active ? KatanaColors.text : KatanaColors.textMuted,
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
        )}
      </div>

      {compact && phoneControlsOpen && (
        <div
          style={{
            marginTop: 10,
            padding: 12,
            borderRadius: 12,
            background: KatanaColors.surface,
            border: `1px solid ${withAlpha(KatanaColors.borderStrong, 0.7)}`,
            display: 'flex',
            flexDirection: 'column',
            gap: 10,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
            <span style={{ ...KatanaType.small, fontWeight: 700 }}>Feed & View</span>
            {viewToggle}
          </div>
          {type === 'all' && (
            <div role="tablist" aria-label="Discovery feed" style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
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
                      minHeight: 40,
                      padding: '4px 12px',
                      borderRadius: 99,
                      background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                      border: `1px solid ${active ? KatanaColors.chipSelectedBorder : 'transparent'}`,
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
          {type === 'all' && libraryBookmarks.length > 0 && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
              <button
                type="button"
                className="bare-button"
                aria-pressed={feedUnreadOnly}
                onClick={() => setFeedUnreadOnly((v) => !v)}
                style={{
                  minHeight: 44,
                  padding: '4px 11px',
                  borderRadius: 99,
                  background: feedUnreadOnly ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                  border: `1px solid ${feedUnreadOnly ? KatanaColors.chipSelectedBorder : 'transparent'}`,
                  fontFamily: Fonts.body,
                  fontSize: 12,
                  fontWeight: 600,
                  color: feedUnreadOnly ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 5,
                }}
              >
                <Icon name="mark_chat_unread" size={14} color={feedUnreadOnly ? KatanaColors.accent : KatanaColors.textLight} />
                Unread only
              </button>
              <button
                type="button"
                className="bare-button"
                aria-pressed={feedAlertsOnly}
                onClick={() => setFeedAlertsOnly((v) => !v)}
                style={{
                  minHeight: 44,
                  padding: '4px 11px',
                  borderRadius: 99,
                  background: feedAlertsOnly ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                  border: `1px solid ${feedAlertsOnly ? KatanaColors.chipSelectedBorder : 'transparent'}`,
                  fontFamily: Fonts.body,
                  fontSize: 12,
                  fontWeight: 600,
                  color: feedAlertsOnly ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 5,
                }}
              >
                <Icon name="notifications_active" size={14} color={feedAlertsOnly ? KatanaColors.accent : KatanaColors.textLight} />
                Alerts on
              </button>
            </div>
          )}
        </div>
      )}

      {!compact && type === 'all' && libraryBookmarks.length > 0 && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, flexWrap: 'wrap', marginTop: 8 }}>
          <button
            type="button"
            className="bare-button"
            aria-pressed={feedUnreadOnly}
            onClick={() => setFeedUnreadOnly((v) => !v)}
            style={{
              minHeight: 34,
              padding: '0 2px',
              fontFamily: Fonts.body,
              fontSize: 12.5,
              fontWeight: feedUnreadOnly ? 700 : 500,
              color: feedUnreadOnly ? KatanaColors.accentSoft : KatanaColors.textMuted,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
            }}
          >
            <Icon name="mark_chat_unread" size={14} color={feedUnreadOnly ? KatanaColors.accent : KatanaColors.textLight} />
            Unread only
          </button>
          <button
            type="button"
            className="bare-button"
            aria-pressed={feedAlertsOnly}
            onClick={() => setFeedAlertsOnly((v) => !v)}
            style={{
              minHeight: 34,
              padding: '0 2px',
              fontFamily: Fonts.body,
              fontSize: 12.5,
              fontWeight: feedAlertsOnly ? 700 : 500,
              color: feedAlertsOnly ? KatanaColors.accentSoft : KatanaColors.textMuted,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
            }}
          >
            <Icon name="notifications_active" size={14} color={feedAlertsOnly ? KatanaColors.accent : KatanaColors.textLight} />
            Alerts on
          </button>
        </div>
      )}

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

  const center = (child: ReactNode) => <div style={{ maxWidth: 1380, margin: '0 auto' }}>{child}</div>;

  const [pullDistance, setPullDistance] = useState(0);
  const pullStartYRef = useRef<number | null>(null);
  const handlePullStart = (e: React.TouchEvent) => {
    if (!onRetryHome || e.touches.length !== 1) return;
    const containerTop = scrollContainerRef?.current?.scrollTop ?? (typeof window !== 'undefined' ? window.scrollY : 0);
    if (containerTop > 2) return;
    pullStartYRef.current = e.touches[0].clientY;
  };
  const handlePullMove = (e: React.TouchEvent) => {
    if (pullStartYRef.current === null || e.touches.length !== 1) return;
    const dy = e.touches[0].clientY - pullStartYRef.current;
    if (dy > 10 && dy < 120) setPullDistance(Math.round(dy));
    else if (dy <= 0) setPullDistance(0);
  };
  const handlePullEnd = () => {
    if (pullDistance >= 64 && onRetryHome) onRetryHome();
    pullStartYRef.current = null;
    setPullDistance(0);
  };

  const pullBanner =
    pullDistance > 14 ? (
      <div
        role="status"
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 6,
          padding: '6px 12px',
          marginBottom: 10,
          borderRadius: 99,
          background: KatanaColors.surfaceAlt,
          border: `1px solid ${pullDistance >= 64 ? KatanaColors.accent : KatanaColors.border}`,
          ...KatanaType.small,
          color: pullDistance >= 64 ? KatanaColors.accentSoft : KatanaColors.textMuted,
          fontWeight: 600,
        }}
      >
        <Icon name="refresh" size={14} color={pullDistance >= 64 ? KatanaColors.accent : KatanaColors.textMuted} />
        {pullDistance >= 64 ? 'Release to refresh' : 'Pull down to refresh'}
      </div>
    ) : null;

  const renderOrderedHomeRails = (isCompactLayout: boolean) => {
    const visibleOrder = homeRailOrder.filter((id) => !hiddenHomeRails.includes(id));
    return visibleOrder.map((railId) => {
      switch (railId) {
        case 'reading':
          return null; // Rendered directly below hero above typeChips unless reordered below
        case 'feed':
          return <div key="rail-feed">{feedSection}</div>;
        case 'pick_back_up':
          return <div key="rail-pickup">{pickBackUpRail}</div>;
        case 'trending':
          return <div key="rail-trending">{trendingRankedRail}</div>;
        case 'calendar':
          return type === 'all' ? (
            <div key="rail-calendar">
              <ReleaseCalendarRail
                catalog={allCatalog}
                bookmarks={libraryBookmarks}
                unreadBySlug={unreadBySlug}
                downloadedCounts={downloadedCounts}
                compact={isCompactLayout}
                onSelectManga={onSelectManga}
              />
            </div>
          ) : null;
        case 'recommended':
          return <div key="rail-recommended">{recommendedRail}</div>;
        case 'hidden_gems':
          return <div key="rail-gems">{hiddenGemsRail}</div>;
        default:
          return null;
      }
    });
  };

  if (!desktop) {
    return (
      <div
        onTouchStart={handlePullStart}
        onTouchMove={handlePullMove}
        onTouchEnd={handlePullEnd}
        style={{ padding: '14px 16px 32px' }}
      >
        {center(
          <>
            {pullBanner}
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
            <div style={{ marginBottom: 18 }}>{typeChips}</div>
            {type === 'all' && !hiddenHomeRails.includes('reading') && (
              <CurrentlyReadingShelf
                items={currentlyReading}
                catalog={allCatalog}
                downloadedCounts={downloadedCounts}
                compact={compact}
                onSelectManga={onSelectManga}
                onResumeBookmark={onResumeBookmark}
                onViewAll={() => onViewAllReading?.()}
              />
            )}
            {newChapterAlertBanner ?? tasteOnboardingBanner}
            {renderOrderedHomeRails(compact)}
            {type === 'all' && hotCard && <div style={{ marginTop: 26 }}>{hotCard}</div>}
            {genresCard && <div style={{ marginTop: 26 }}>{genresCard}</div>}
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
          {!hiddenHomeRails.includes('reading') && (
            <CurrentlyReadingShelf
              items={currentlyReading}
              catalog={allCatalog}
              downloadedCounts={downloadedCounts}
              compact={false}
              onSelectManga={onSelectManga}
              onResumeBookmark={onResumeBookmark}
              onViewAll={() => onViewAllReading?.()}
            />
          )}
          {typeChips}
          {newChapterAlertBanner ?? tasteOnboardingBanner}
          <div style={{ height: 14 }} />
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 18 }}>
            <div style={{ flex: 7, minWidth: 0 }}>
              {renderOrderedHomeRails(false)}
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
