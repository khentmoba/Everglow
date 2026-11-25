import { withAlpha } from '../../core/theme/colors';
import { Fonts } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import {
  estimateUnreadCount,
  formatKatanaTime,
  isBookmarkCaughtUp,
  resolveLibraryStatus,
  type KatanaBookmark,
  type KatanaLibraryStatus,
} from './katanaService';
import { getKatanaGridColumns, KatanaColors, KatanaType } from './katanaTokens';
import {
  KatanaCoverBadges,
  KatanaCoverImage,
  KatanaEmptyState,
} from './MangaUi';
import { loadResumeAnchor } from './readerSettings';

export const STATUS_LABELS: Record<KatanaLibraryStatus, { label: string; icon: string; color: string }> = {
  reading: { label: 'Reading', icon: 'auto_stories', color: KatanaColors.accent },
  on_hold: { label: 'On Hold', icon: 'pause_circle_outline', color: KatanaColors.orange },
  completed: { label: 'Completed', icon: 'check_circle', color: KatanaColors.green },
  planned: { label: 'Plan to Read', icon: 'schedule', color: KatanaColors.link },
  dropped: { label: 'Dropped', icon: 'cancel', color: KatanaColors.textLight },
};

export interface MangaLibraryCollectionViewProps {
  savedBookmarks: KatanaBookmark[];
  filteredLibrary: KatanaBookmark[];
  libraryViewMode: 'grid' | 'compact' | 'list';
  librarySelectMode: boolean;
  selectedLibrarySlugs: Set<string>;
  downloadedCounts: Record<string, number>;
  width: number;
  tablet: boolean;
  desktop: boolean;
  onToggleSelectSlug: (slug: string) => void;
  onOpenDetail: (slug: string) => void;
  onResumeBookmark: (bm: KatanaBookmark) => void;
  onExploreCatalog: () => void;
  onResetFilters: () => void;
}

function formatResumeProgressLabel(bm: KatanaBookmark): string {
  if (!bm.lastReadChapterTitle) return '';
  const anchor = bm.lastReadChapterId ? loadResumeAnchor(bm.slug, bm.lastReadChapterId) : null;
  const pageNum = anchor ? anchor.pageIdx + 1 : bm.lastReadPage;
  return `${bm.lastReadChapterTitle}${pageNum && pageNum > 1 ? ` · p.${pageNum}` : ''}`;
}

export function MangaLibraryCollectionView({
  savedBookmarks,
  filteredLibrary,
  libraryViewMode,
  librarySelectMode,
  selectedLibrarySlugs,
  downloadedCounts,
  width,
  tablet,
  desktop,
  onToggleSelectSlug,
  onOpenDetail,
  onResumeBookmark,
  onExploreCatalog,
  onResetFilters,
}: MangaLibraryCollectionViewProps) {
  if (filteredLibrary.length === 0) {
    return (
      <KatanaEmptyState
        icon="bookmarks"
        title={savedBookmarks.length === 0 ? 'Your library is empty' : 'No titles match this filter'}
        subtitle={
          savedBookmarks.length === 0
            ? 'Add manga, manhwa, or manhua from any detail page to track reading progress and organize shelves.'
            : 'Try switching shelves or clearing your search.'
        }
        actionLabel={savedBookmarks.length === 0 ? 'Explore Catalog' : 'Show All'}
        actionIcon={savedBookmarks.length === 0 ? 'explore' : 'restart_alt'}
        onAction={() => {
          if (savedBookmarks.length === 0) onExploreCatalog();
          else onResetFilters();
        }}
      />
    );
  }

  if (libraryViewMode === 'list') {
    return (
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: desktop || tablet
            ? 'repeat(2, minmax(0, 1fr))'
            : '1fr',
          columnGap: 24,
        }}
      >
        {filteredLibrary.map((bm) => {
          const st = resolveLibraryStatus(bm);
          const meta = STATUS_LABELS[st];
          const unread = estimateUnreadCount(bm);
          const dlCount = downloadedCounts[bm.slug] ?? 0;
          const caughtUp = isBookmarkCaughtUp(bm);
          const selected = selectedLibrarySlugs.has(bm.slug);
          const resumeLabel = formatResumeProgressLabel(bm);
          const actionLabel =
            st === 'completed'
              ? 'Re-read'
              : caughtUp || !bm.lastReadChapterId
                ? 'Read'
                : 'Resume';
          return (
            <div
              key={bm.slug}
              style={{
                padding: '12px 0',
                borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.75)}`,
                background: selected ? withAlpha(KatanaColors.accent, 0.08) : 'transparent',
              }}
            >
              <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                {librarySelectMode && (
                  <button
                    type="button"
                    className="bare-button"
                    aria-label={`Select ${bm.title}`}
                    onClick={() => onToggleSelectSlug(bm.slug)}
                    style={{
                      width: 44,
                      height: 44,
                      display: 'grid',
                      placeItems: 'center',
                      flexShrink: 0,
                    }}
                  >
                    <Icon
                      name={selected ? 'check_box' : 'check_box_outline_blank'}
                      size={20}
                      color={selected ? KatanaColors.accent : KatanaColors.textLight}
                    />
                  </button>
                )}
                <button
                  type="button"
                  className="bare-button"
                  aria-label={`Open ${bm.title}`}
                  onClick={() => (librarySelectMode ? onToggleSelectSlug(bm.slug) : onOpenDetail(bm.slug))}
                  style={{
                    position: 'relative',
                    width: 58,
                    height: 84,
                    borderRadius: 6,
                    overflow: 'hidden',
                    flexShrink: 0,
                    background: KatanaColors.surfaceAlt,
                  }}
                >
                  <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={22} />
                  <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                </button>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => (librarySelectMode ? onToggleSelectSlug(bm.slug) : onOpenDetail(bm.slug))}
                    style={{ textAlign: 'left', width: '100%' }}
                  >
                    <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 14.5, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
                      {bm.title}
                    </div>
                  </button>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginTop: 4 }}>
                    <span
                      style={{
                        fontFamily: Fonts.body,
                        fontSize: 11.5,
                        fontWeight: 600,
                        color: caughtUp ? KatanaColors.green : meta.color,
                      }}
                    >
                      {caughtUp ? 'Caught Up' : meta.label}
                    </span>
                    {bm.readChapterIds.length > 0 && (
                      <span className="katana-tabular" style={{ ...KatanaType.small, fontSize: 11.5 }}>· {bm.readChapterIds.length} ch read</span>
                    )}
                  </div>
                  {resumeLabel && (
                    <div className="ellipsis" style={{ ...KatanaType.small, color: KatanaColors.textMuted, marginTop: 3 }}>
                      {resumeLabel}
                      {bm.latestChapterTitle ? ` · ${bm.latestChapterTitle}` : ''}
                    </div>
                  )}
                </div>
                {!librarySelectMode && (
                  <button
                    type="button"
                    className="bare-button"
                    aria-label={`${actionLabel} ${bm.title}`}
                    onClick={() => onResumeBookmark(bm)}
                    style={{
                      minHeight: 38,
                      padding: '0 10px',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 4,
                      fontFamily: Fonts.body,
                      fontSize: 12.5,
                      fontWeight: 700,
                      color: KatanaColors.accentSoft,
                      flexShrink: 0,
                    }}
                  >
                    <Icon name="play_arrow" size={16} color={KatanaColors.accent} />
                    <span>{actionLabel}</span>
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    );
  }

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${getKatanaGridColumns(width, libraryViewMode === 'compact')}, minmax(0, 1fr))`,
        columnGap: libraryViewMode === 'compact' ? 10 : 14,
        rowGap: libraryViewMode === 'compact' ? 14 : 20,
      }}
    >
      {filteredLibrary.map((bm) => {
        const unread = estimateUnreadCount(bm);
        const readCount = bm.readChapterIds.length;
        const totalCount = readCount + unread;
        const progressPct = totalCount > 0 ? Math.min(100, Math.round((readCount / totalCount) * 100)) : 0;
        const dlCount = downloadedCounts[bm.slug] ?? 0;
        const selected = selectedLibrarySlugs.has(bm.slug);
        const resumeLabel = formatResumeProgressLabel(bm);
        return (
          <div
            key={bm.slug}
            style={{
              position: 'relative',
              display: 'flex',
              flexDirection: 'column',
            }}
          >
            <div
              style={{
                position: 'relative',
                width: '100%',
                aspectRatio: '2 / 3',
                borderRadius: 6,
                overflow: 'hidden',
                background: KatanaColors.surfaceAlt,
                boxShadow: selected
                  ? `0 0 0 2px ${KatanaColors.accent}, 0 6px 18px rgba(0,0,0,0.45)`
                  : '0 6px 18px rgba(0,0,0,0.38)',
              }}
            >
              <button
                type="button"
                className="bare-button"
                aria-label={`Open ${bm.title}`}
                onClick={() => (librarySelectMode ? onToggleSelectSlug(bm.slug) : onOpenDetail(bm.slug))}
                style={{
                  position: 'relative',
                  width: '100%',
                  height: '100%',
                  display: 'block',
                  textAlign: 'left',
                }}
              >
                <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={24} />
                <div
                  aria-hidden="true"
                  style={{
                    position: 'absolute',
                    inset: 'auto 0 0 0',
                    height: '36%',
                    background: 'linear-gradient(to top, rgba(8,8,10,0.88) 0%, transparent 100%)',
                    pointerEvents: 'none',
                  }}
                />
                <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                {bm.userScore != null && !librarySelectMode && (
                  <span
                    className="katana-tabular"
                    style={{
                      position: 'absolute',
                      bottom: 9,
                      left: 7,
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 3,
                      fontFamily: Fonts.body,
                      fontSize: 11.5,
                      fontWeight: 700,
                      color: '#FFFFFF',
                      textShadow: '0 1px 4px rgba(0,0,0,0.85)',
                    }}
                  >
                    <Icon name="star" size={11} color={KatanaColors.accent} />
                    {bm.userScore.toFixed(1)}
                  </span>
                )}
                {librarySelectMode && (
                  <span
                    style={{
                      position: 'absolute',
                      top: 6,
                      left: 6,
                      width: 24,
                      height: 24,
                      borderRadius: 6,
                      background: selected ? KatanaColors.accent : withAlpha(KatanaColors.background, 0.78),
                      display: 'grid',
                      placeItems: 'center',
                    }}
                  >
                    <Icon
                      name={selected ? 'check' : 'check_box_outline_blank'}
                      size={16}
                      color={selected ? KatanaColors.accentInk : KatanaColors.text}
                    />
                  </span>
                )}
                {libraryViewMode === 'compact' && (
                  <div
                    style={{
                      position: 'absolute',
                      inset: 'auto 0 0 0',
                      padding: '22px 38px 8px 8px',
                      background: `linear-gradient(to top, ${withAlpha(KatanaColors.background, 0.94)}, transparent)`,
                    }}
                  >
                    <div
                      className="clamp-2"
                      style={{
                        fontFamily: Fonts.body,
                        fontSize: 12.5,
                        fontWeight: 600,
                        color: KatanaColors.text,
                        lineHeight: 1.2,
                      }}
                    >
                      {bm.title}
                    </div>
                  </div>
                )}
                {progressPct > 0 && (
                  <div
                    aria-hidden="true"
                    style={{
                      position: 'absolute',
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 2.5,
                      background: 'rgba(255,255,255,0.16)',
                    }}
                  >
                    <div style={{ width: `${progressPct}%`, height: '100%', background: KatanaColors.accent }} />
                  </div>
                )}
              </button>
              {!librarySelectMode && (
                <button
                  type="button"
                  className="bare-button"
                  aria-label={`Resume ${bm.title}`}
                  title={resumeLabel ? `Resume ${resumeLabel}` : `Start ${bm.title}`}
                  onClick={() => onResumeBookmark(bm)}
                  style={{
                    position: 'absolute',
                    right: 0,
                    bottom: 0,
                    width: 44,
                    height: 44,
                    display: 'grid',
                    placeItems: 'center',
                  }}
                >
                  <span
                    aria-hidden="true"
                    style={{
                      width: 30,
                      height: 30,
                      borderRadius: 99,
                      background: 'rgba(8,8,10,0.82)',
                      display: 'grid',
                      placeItems: 'center',
                    }}
                  >
                    <Icon name="play_arrow" size={17} color="#FFFFFF" />
                  </span>
                </button>
              )}
            </div>
            {libraryViewMode === 'grid' && (
              <button
                type="button"
                className="bare-button"
                onClick={() => (librarySelectMode ? onToggleSelectSlug(bm.slug) : onOpenDetail(bm.slug))}
                style={{ textAlign: 'left', paddingTop: 7, width: '100%' }}
              >
                <div
                  className="clamp-2"
                  style={{
                    fontFamily: Fonts.body,
                    fontSize: 13.5,
                    fontWeight: 600,
                    color: KatanaColors.text,
                    lineHeight: 1.25,
                  }}
                >
                  {bm.title}
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 3 }}>
                  <span
                    className="katana-tabular"
                    style={{
                      ...KatanaType.small,
                      fontSize: 11.5,
                      fontWeight: 600,
                      color: unread > 0 ? KatanaColors.accentSoft : KatanaColors.textLight,
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {readCount}/{totalCount} ch
                  </span>
                  {(() => {
                    const anchor = bm.lastReadChapterId ? loadResumeAnchor(bm.slug, bm.lastReadChapterId) : null;
                    const pageNum = anchor ? anchor.pageIdx + 1 : bm.lastReadPage;
                    return pageNum && pageNum > 1 ? (
                      <span className="katana-tabular" style={{ ...KatanaType.small, fontSize: 11, color: KatanaColors.textLight, whiteSpace: 'nowrap' }}>· p.{pageNum}</span>
                    ) : null;
                  })()}
                </div>
                <div style={{ ...KatanaType.small, fontSize: 11, color: KatanaColors.textLight, marginTop: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {formatKatanaTime(bm.lastReadAt) || STATUS_LABELS[resolveLibraryStatus(bm)].label}
                </div>
              </button>
            )}
          </div>
        );
      })}
    </div>
  );
}
