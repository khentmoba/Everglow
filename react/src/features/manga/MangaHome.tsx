import { useMemo, useRef, useState, type ReactNode } from 'react';
import { reduceAmbientMotion } from '../../core/system/device';
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
  formatKatanaTime,
  formatCompactNumber,
  getPreferredMangaGenres,
  proxyKatanaImageUrl,
  setPreferredMangaGenres,
  type KatanaBookmark,
  type KatanaGenre,
  type KatanaHomeData,
  type KatanaManga,
  type KatanaWeekday,
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
  const allowBlur = !reduceAmbientMotion({
    width: typeof window !== 'undefined' ? window.innerWidth : 1024,
    height: typeof window !== 'undefined' ? window.innerHeight : 800,
  });
  const swipeStartRef = useRef<{ x: number; y: number } | null>(null);

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
        borderRadius: 16,
        overflow: 'hidden',
        background: KatanaColors.surface,
        border: `1px solid ${KatanaColors.borderStrong}`,
        marginBottom: 14,
      }}
    >
      {/* Cover-derived atmospheric backdrop (blur disabled on phone & low-end/reduced-motion devices) */}
      {backdropUrl && !compact && allowBlur ? (
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
            filter: 'blur(24px) saturate(1.15) brightness(0.42)',
            transform: 'scale(1.16)',
            opacity: 0.7,
            pointerEvents: 'none',
          }}
        />
      ) : (
        <div
          aria-hidden="true"
          style={{
            position: 'absolute',
            inset: 0,
            background: `radial-gradient(circle at 18% 24%, ${withAlpha(KatanaColors.accent, 0.16)} 0%, ${withAlpha(KatanaColors.surfaceAlt, 0.42)} 45%, ${withAlpha(KatanaColors.background, 0.96)} 100%)`,
            pointerEvents: 'none',
          }}
        />
      )}
      <div
        aria-hidden="true"
        style={{
          position: 'absolute',
          inset: 0,
          background: `linear-gradient(100deg, ${withAlpha(KatanaColors.background, 0.92)} 0%, ${withAlpha(KatanaColors.surface, 0.82)} 56%, ${withAlpha(KatanaColors.background, 0.72)} 100%)`,
          pointerEvents: 'none',
        }}
      />

      <div
        style={{
          position: 'relative',
          padding: compact ? '12px 12px' : desktop ? '20px 24px' : '16px 20px',
          display: 'flex',
          gap: compact ? 13 : desktop ? 24 : 20,
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
            width: compact ? 104 : desktop ? 164 : 128,
            height: compact ? 150 : desktop ? 236 : 184,
            borderRadius: 11,
            overflow: 'hidden',
            flexShrink: 0,
            background: KatanaColors.surfaceAlt,
            boxShadow: '0 10px 28px rgba(0,0,0,0.48)',
          }}
        >
          <KatanaCoverImage url={featured.coverUrl} title={featured.title} iconSize={compact ? 26 : 34} />
        </button>

        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: compact ? 4 : 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: compact ? 6 : 8, flexWrap: compact ? 'nowrap' : 'wrap', overflow: 'hidden' }}>
            <span
              style={{
                padding: '2px 7px',
                borderRadius: 6,
                background: KatanaColors.chipSelectedBg,
                border: `1px solid ${KatanaColors.chipSelectedBorder}`,
                fontFamily: Fonts.body,
                fontSize: 10,
                fontWeight: 700,
                color: KatanaColors.chipSelectedText,
                letterSpacing: 0.5,
                flexShrink: 0,
              }}
            >
              SPOTLIGHT
            </span>
            <span
              style={{
                padding: '2px 7px',
                borderRadius: 6,
                background: withAlpha(completed ? KatanaColors.green : KatanaColors.teal, 0.16),
                fontFamily: Fonts.body,
                fontSize: 10.5,
                fontWeight: 600,
                color: completed ? KatanaColors.green : KatanaColors.teal,
                flexShrink: 0,
              }}
            >
              {completed ? 'Completed' : 'Ongoing'}
            </span>
            {featured.rating != null && (
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, flexShrink: 0 }}>
                <Icon name="star" size={12} color={KatanaColors.accent} />
                <span style={{ fontFamily: Fonts.body, fontSize: 11.5, fontWeight: 700, color: KatanaColors.text }}>
                  {featured.rating.toFixed(1)}
                </span>
              </span>
            )}
            {!compact && featured.follows != null && featured.follows > 0 && (
              <span style={{ ...KatanaType.small, fontSize: 12 }}>
                {formatCompactNumber(featured.follows)} readers
              </span>
            )}
            {featured.latestChapter && (
              <span className="ellipsis" style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.link }}>
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
              className={compact ? 'ellipsis' : 'clamp-2'}
              style={{
                ...KatanaType.display,
                fontSize: compact ? 16 : 25,
                margin: 0,
              }}
            >
              {featured.title}
            </h1>
          </button>

          {!compact && featured.genres.length > 0 && (
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
                    background: withAlpha(KatanaColors.surfaceAlt, 0.88),
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
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 0, marginLeft: 2 }}>
                {candidates.map((c, i) => (
                  <button
                    key={c.slug}
                    type="button"
                    className="bare-button"
                    aria-label={`Show featured title ${i + 1}: ${c.title}`}
                    aria-pressed={i === index}
                    onClick={() => setIndex(i)}
                    style={{
                      minWidth: 40,
                      minHeight: 40,
                      margin: '0 -4px',
                      padding: 0,
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <span
                      style={{
                        width: i === index ? 20 : 7,
                        height: 7,
                        borderRadius: 99,
                        background: i === index ? KatanaColors.accent : KatanaColors.borderStrong,
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
                width: items.length === 1 ? '100%' : compact ? 248 : 312,
                maxWidth: items.length === 1 ? (compact ? undefined : 640) : undefined,
                flexShrink: items.length === 1 ? 1 : 0,
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                padding: 8,
                borderRadius: 11,
                background: KatanaColors.surface,
                border: `1px solid ${withAlpha(KatanaColors.border, 0.55)}`,
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
                    width: 42,
                    height: 42,
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

const WEEKDAYS: KatanaWeekday[] = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

function todayWeekday(): KatanaWeekday {
  const jsDay = new Date().getDay(); // 0=Sun..6=Sat
  return WEEKDAYS[(jsDay + 6) % 7];
}

function ReleaseCalendarRail({
  catalog,
  unreadBySlug,
  downloadedCounts,
  compact,
  onSelectManga,
}: {
  catalog: KatanaManga[];
  unreadBySlug: Record<string, number>;
  downloadedCounts: Record<string, number>;
  compact: boolean;
  onSelectManga: (slug: string) => void;
}) {
  const today = useMemo(() => todayWeekday(), []);
  const todayIdx = WEEKDAYS.indexOf(today);
  const [calendarMode, setCalendarMode] = useState<'upcoming' | 'recent'>('upcoming');
  const scheduled = useMemo(() => {
    const withDay = catalog.filter((m) => m.releaseDay);
    return calendarMode === 'upcoming'
      ? withDay.filter((m) => m.status.toLowerCase() !== 'completed')
      : withDay;
  }, [catalog, calendarMode]);
  const byDay = useMemo(() => {
    const map: Record<KatanaWeekday, KatanaManga[]> = {
      Mon: [], Tue: [], Wed: [], Thu: [], Fri: [], Sat: [], Sun: [],
    };
    for (const m of scheduled) {
      if (m.releaseDay) map[m.releaseDay].push(m);
    }
    return map;
  }, [scheduled]);
  const [selectedDay, setSelectedDay] = useState<KatanaWeekday>(() => {
    if (catalog.some((m) => m.releaseDay === today)) return today;
    return catalog.find((m) => m.releaseDay)?.releaseDay ?? today;
  });

  if (catalog.every((m) => !m.releaseDay)) return null;

  const activeItems = byDay[selectedDay] ?? [];
  const selectedIdx = WEEKDAYS.indexOf(selectedDay);
  const daysAhead = (selectedIdx - todayIdx + 7) % 7;
  const upcomingEtaLabel =
    daysAhead === 0 ? 'Expected today' : daysAhead === 1 ? 'Expected tomorrow' : `Expected in ${daysAhead}d`;

  return (
    <section aria-label="Release calendar" style={{ marginTop: 22 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
        <KatanaSectionHeader
          title={calendarMode === 'upcoming' ? 'Upcoming Releases' : 'Recently Updated by Day'}
          badge={selectedDay === today ? `Today · ${activeItems.length}` : `${selectedDay} · ${activeItems.length}`}
        />
        <div
          role="tablist"
          aria-label="Calendar view"
          style={{
            display: 'inline-flex',
            padding: 3,
            borderRadius: 9,
            background: KatanaColors.surfaceAlt,
          }}
        >
          {([
            { key: 'upcoming', label: 'Upcoming' },
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
                  padding: '4px 10px',
                  borderRadius: 6,
                  background: active ? KatanaColors.chipSelectedBg : 'transparent',
                  fontFamily: Fonts.body,
                  fontSize: 12,
                  fontWeight: active ? 700 : 500,
                  color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                }}
              >
                {m.label}
              </button>
            );
          })}
        </div>
      </div>
      <div style={{ ...KatanaType.small, fontSize: 11.5, marginTop: 3 }}>
        {calendarMode === 'upcoming'
          ? `Estimated weekly cadence for ongoing series · ${upcomingEtaLabel}.`
          : 'Grouped by each series’ latest catalog update day.'}
      </div>
      <div style={{ height: 10 }} />
      <div
        className="no-scrollbar"
        role="tablist"
        aria-label="Update day"
        style={{
          display: 'flex',
          gap: 6,
          overflowX: 'auto',
          marginBottom: 12,
          paddingBottom: 2,
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
                minHeight: compact ? 40 : 34,
                padding: '6px 12px',
                borderRadius: 99,
                background: active ? KatanaColors.accent : KatanaColors.surfaceAlt,
                border: `1px solid ${active ? KatanaColors.accent : isToday ? KatanaColors.borderStrong : KatanaColors.border}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
              }}
            >
              <span
                style={{
                  ...KatanaType.small,
                  fontSize: 12,
                  fontWeight: 700,
                  color: active ? KatanaColors.accentInk : KatanaColors.text,
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
                    background: active ? KatanaColors.accentInk : KatanaColors.accent,
                  }}
                />
              )}
              {count > 0 && (
                <span
                  style={{
                    ...KatanaType.small,
                    fontSize: 10.5,
                    fontWeight: 700,
                    color: active ? KatanaColors.accentInk : KatanaColors.textMuted,
                    opacity: active ? 0.85 : 1,
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
            padding: '16px 14px',
            borderRadius: 12,
            background: KatanaColors.surface,
            border: `1px solid ${KatanaColors.border}`,
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
            gap: 8,
          }}
        >
          {activeItems.slice(0, 6).map((m) => {
            const unread = unreadBySlug[m.slug] ?? 0;
            const dl = downloadedCounts[m.slug] ?? 0;
            return (
              <button
                key={m.slug}
                type="button"
                className="bare-button"
                onClick={() => onSelectManga(m.slug)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  padding: 8,
                  borderRadius: 11,
                  background: KatanaColors.surface,
                  border: `1px solid ${KatanaColors.border}`,
                  textAlign: 'left',
                  minHeight: 68,
                }}
              >
                <div style={{ position: 'relative', width: 44, height: 60, borderRadius: 7, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                  <KatanaCoverImage url={m.coverUrl} title={m.title} iconSize={16} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 13.5, fontWeight: 700, color: KatanaColors.text, lineHeight: 1.25 }}>
                    {m.title}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 6, marginTop: 4 }}>
                    {m.latestChapter && (
                      <span style={{ ...KatanaType.small, fontSize: 12, color: KatanaColors.link, fontWeight: 600 }}>
                        {chapterDisplayTitle(m.latestChapter)}
                      </span>
                    )}
                    {m.updateText && (
                      <span style={{ ...KatanaType.small, fontSize: 11.5 }}>{m.updateText}</span>
                    )}
                  </div>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4, flexShrink: 0 }}>
                  {unread > 0 && (
                    <span
                      style={{
                        padding: '2px 7px',
                        borderRadius: 99,
                        background: KatanaColors.accent,
                        color: KatanaColors.accentInk,
                        fontFamily: Fonts.body,
                        fontSize: 11,
                        fontWeight: 800,
                      }}
                    >
                      {unread} new
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
  scrollContainerRef,
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
      return setPreferredMangaGenres(next);
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

    for (const bm of libraryBookmarks) {
      const m = allCatalog.find((x) => x.slug === bm.slug);
      if (!m) continue;
      if (bm.libraryStatus === 'dropped') {
        m.genres.forEach((g) => droppedGenres.add(g.slug));
        continue;
      }
      if (bm.userScore != null && bm.userScore >= 8) {
        for (const g of m.genres) {
          const prev = ratedGenreSource.get(g.slug);
          if (!prev || bm.userScore > prev.score) {
            ratedGenreSource.set(g.slug, { title: bm.title, score: bm.userScore });
          }
        }
      }
      if (bm.libraryStatus === 'completed' || readingSlugs.has(bm.slug)) {
        m.genres.forEach((g) => {
          if (!readingGenreSource.has(g.slug)) readingGenreSource.set(g.slug, bm.title);
        });
      }
    }

    const explicitSet = new Set(tasteGenres);
    const candidates = allCatalog.filter((m) => !readingSlugs.has(m.slug) && !droppedSlugs.has(m.slug));
    const nonDuplicate = candidates.filter((m) => !latestLeadSlugs.has(m.slug));
    const pool = nonDuplicate.length >= 4 ? nonDuplicate : candidates;

    const usedBecauseTitles = new Map<string, number>();
    const scored = pool.map((m) => {
      const explicitMatches = m.genres.filter((g) => explicitSet.has(g.slug));
      const ratedMatch = m.genres.find((g) => ratedGenreSource.has(g.slug));
      const historyMatch = m.genres.find((g) => readingGenreSource.has(g.slug));
      const droppedPenalty = m.genres.filter((g) => droppedGenres.has(g.slug)).length * 1.5;
      const novelBonus = latestLeadSlugs.has(m.slug) ? 0 : 1.5;
      const ratedBonus = ratedMatch ? (ratedGenreSource.get(ratedMatch.slug)!.score / 10) * 3.5 : 0;
      const score =
        explicitMatches.length * 3 +
        ratedBonus +
        (historyMatch ? 2 : 0) +
        (m.rating ? m.rating / 5 : 0) +
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
  }, [allCatalog, currentlyReading, libraryBookmarks, tasteGenres, latestLeadSlugs]);

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
            {distinctHot.map((m) => (
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
          style={{ ...KatanaType.small, padding: '4px 8px', minHeight: compact ? 36 : 28, flexShrink: 0 }}
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
                minHeight: compact ? 40 : 36,
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

  const newChapterAlertBanner =
    !alertBannerDismissed && alertUnreadSeriesCount > 0 && type === 'all' && feedTab !== 'updates' ? (
      <div
        role="status"
        style={{
          marginTop: compact ? 6 : 8,
          padding: compact ? '4px 8px 4px 10px' : '8px 12px',
          borderRadius: compact ? 99 : 10,
          background: withAlpha(KatanaColors.accent, 0.12),
          border: `1px solid ${withAlpha(KatanaColors.accent, 0.38)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 8,
          flexWrap: 'nowrap',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, minWidth: 0, flex: 1 }}>
          <Icon name="notifications_active" size={15} color={KatanaColors.accent} />
          <span className="ellipsis" style={{ fontFamily: Fonts.body, fontSize: compact ? 12 : 13, fontWeight: 600, color: KatanaColors.text }}>
            {compact
              ? `${alertUnreadSeriesCount} new chapter ${alertUnreadSeriesCount === 1 ? 'update' : 'updates'}`
              : `${alertUnreadSeriesCount} followed ${alertUnreadSeriesCount === 1 ? 'series has' : 'series have'} new chapters`}
          </span>
        </div>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, flexShrink: 0 }}>
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              setAlertBannerDismissed(true);
              setFeedTab('updates');
            }}
            style={{
              minHeight: 40,
              padding: compact ? '6px 12px' : '6px 12px',
              borderRadius: compact ? 99 : 8,
              background: KatanaColors.accent,
              color: KatanaColors.accentInk,
              fontFamily: Fonts.body,
              fontSize: 12,
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
            style={{ width: 40, height: 40, display: 'grid', placeItems: 'center' }}
          >
            <Icon name="close" size={15} color={KatanaColors.textMuted} />
          </button>
        </div>
      </div>
    ) : null;

  const feedTitle =
    type !== 'all'
      ? TYPE_META[type].label
      : feedTab === 'new_hot'
        ? 'New & Hot'
        : feedTab === 'updates'
          ? 'My Library Updates'
          : 'Latest Updates';

  const freshnessLabel = data.fetchedAt
    ? `${data.sourceLabel ?? 'MangaKatana'} · ${data.fromCache ? 'Cached' : 'Updated'} ${formatKatanaTime(new Date(data.fetchedAt))}`
    : data.sourceLabel;

  const phoneFilterActiveCount =
    (type !== 'all' ? 1 : 0) +
    (feedTab !== 'latest' ? 1 : 0) +
    (feedUnreadOnly ? 1 : 0) +
    (feedAlertsOnly ? 1 : 0);

  const feedSection = (
    <section aria-label="Manga catalog feed">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
        <div style={{ minWidth: 0 }}>
          <KatanaSectionHeader title={feedTitle} badge={feedTab === 'updates' && libraryUnreadTotal > 0 ? `${libraryUnreadTotal} unread` : undefined} />
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
              minHeight: 40,
              padding: '0 12px',
              borderRadius: 99,
              background: phoneControlsOpen || phoneFilterActiveCount > 0 ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
              border: `1px solid ${phoneControlsOpen || phoneFilterActiveCount > 0 ? KatanaColors.chipSelectedBorder : withAlpha(KatanaColors.borderStrong, 0.7)}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              fontFamily: Fonts.body,
              fontSize: 12.5,
              fontWeight: 700,
              color: phoneControlsOpen || phoneFilterActiveCount > 0 ? KatanaColors.chipSelectedText : KatanaColors.text,
              flexShrink: 0,
            }}
          >
            <Icon name="tune" size={15} color={phoneControlsOpen || phoneFilterActiveCount > 0 ? KatanaColors.accent : KatanaColors.textMuted} />
            <span>Sort & Filter{phoneFilterActiveCount > 0 ? ` (${phoneFilterActiveCount})` : ''}</span>
          </button>
        ) : (
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
            <span style={{ ...KatanaType.small, fontWeight: 700 }}>Feed & Format</span>
            {viewToggle}
          </div>
          {typeChips}
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
                  minHeight: 36,
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
                  minHeight: 36,
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
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginTop: 10 }}>
          <button
            type="button"
            className="bare-button"
            aria-pressed={feedUnreadOnly}
            onClick={() => setFeedUnreadOnly((v) => !v)}
            style={{
              minHeight: 30,
              padding: '4px 10px',
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
              minHeight: 30,
              padding: '4px 10px',
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
            <CurrentlyReadingShelf
              items={currentlyReading}
              catalog={allCatalog}
              downloadedCounts={downloadedCounts}
              compact={compact}
              onSelectManga={onSelectManga}
              onResumeBookmark={onResumeBookmark}
              onViewAll={() => onViewAllReading?.()}
            />
            {!compact && typeChips}
            {newChapterAlertBanner}
            {tasteOnboardingBanner}
            <div style={{ height: compact ? 8 : 10 }} />
            {feedSection}
            {type === 'all' && (
              <ReleaseCalendarRail
                catalog={allCatalog}
                unreadBySlug={unreadBySlug}
                downloadedCounts={downloadedCounts}
                compact={compact}
                onSelectManga={onSelectManga}
              />
            )}
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
          {newChapterAlertBanner}
          {tasteOnboardingBanner}
          <div style={{ height: 14 }} />
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 18 }}>
            <div style={{ flex: 7, minWidth: 0 }}>
              {feedSection}
              {type === 'all' && (
                <ReleaseCalendarRail
                  catalog={allCatalog}
                  unreadBySlug={unreadBySlug}
                  downloadedCounts={downloadedCounts}
                  compact={false}
                  onSelectManga={onSelectManga}
                />
              )}
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
