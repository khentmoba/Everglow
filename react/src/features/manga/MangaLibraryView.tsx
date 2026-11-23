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
  KatanaButton,
  KatanaCard,
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
          gridTemplateColumns: desktop
            ? 'repeat(3, minmax(0, 1fr))'
            : tablet
              ? 'repeat(2, minmax(0, 1fr))'
              : '1fr',
          gap: 12,
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
            <KatanaCard
              key={bm.slug}
              padding={12}
              style={
                selected
                  ? { borderColor: KatanaColors.accent, background: withAlpha(KatanaColors.accent, 0.06) }
                  : undefined
              }
            >
              <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                {librarySelectMode && (
                  <button
                    type="button"
                    className="bare-button"
                    aria-label={`Select ${bm.title}`}
                    onClick={() => onToggleSelectSlug(bm.slug)}
                    style={{
                      width: 32,
                      height: 32,
                      display: 'grid',
                      placeItems: 'center',
                      flexShrink: 0,
                      marginTop: 2,
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
                    width: 72,
                    height: 104,
                    borderRadius: 8,
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
                    <div className="clamp-2" style={KatanaType.title}>
                      {bm.title}
                    </div>
                  </button>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginTop: 6 }}>
                    <span
                      style={{
                        padding: '2px 8px',
                        borderRadius: 99,
                        background: withAlpha(meta.color, 0.16),
                        fontFamily: Fonts.body,
                        fontSize: 11,
                        fontWeight: 700,
                        color: meta.color,
                      }}
                    >
                      {caughtUp ? 'Caught Up' : meta.label}
                    </span>
                    {bm.readChapterIds.length > 0 && (
                      <span style={KatanaType.small}>{bm.readChapterIds.length} ch read</span>
                    )}
                  </div>
                  {resumeLabel && (
                    <div style={{ ...KatanaType.small, color: KatanaColors.link, marginTop: 6 }}>
                      {resumeLabel}
                      {bm.latestChapterTitle ? ` · Latest: ${bm.latestChapterTitle}` : ''}
                    </div>
                  )}
                  {!librarySelectMode && (
                    <div style={{ marginTop: 8, display: 'flex', gap: 6 }}>
                      <KatanaButton
                        label={actionLabel}
                        icon="play_arrow"
                        size="sm"
                        onClick={() => onResumeBookmark(bm)}
                      />
                    </div>
                  )}
                </div>
              </div>
            </KatanaCard>
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
        gap: libraryViewMode === 'compact' ? 10 : 14,
      }}
    >
      {filteredLibrary.map((bm) => {
        const unread = estimateUnreadCount(bm);
        const readCount = bm.readChapterIds.length;
        const dlCount = downloadedCounts[bm.slug] ?? 0;
        const selected = selectedLibrarySlugs.has(bm.slug);
        const resumeLabel = formatResumeProgressLabel(bm);
        return (
          <div
            key={bm.slug}
            style={{
              position: 'relative',
              borderRadius: 11,
              overflow: 'hidden',
              background: KatanaColors.surface,
              border: `2px solid ${selected ? KatanaColors.accent : KatanaColors.border}`,
              display: 'flex',
              flexDirection: 'column',
            }}
          >
            <button
              type="button"
              className="bare-button"
              onClick={() => (librarySelectMode ? onToggleSelectSlug(bm.slug) : onOpenDetail(bm.slug))}
              style={{
                textAlign: 'left',
                display: 'flex',
                flexDirection: 'column',
                flex: 1,
                width: '100%',
              }}
            >
              <div
                style={{
                  position: 'relative',
                  width: '100%',
                  aspectRatio: '2 / 3',
                  background: KatanaColors.surfaceAlt,
                }}
              >
                <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={24} />
                <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                {bm.userScore != null && !librarySelectMode && (
                  <span
                    style={{
                      position: 'absolute',
                      top: 6,
                      left: 6,
                      padding: '2px 6px',
                      borderRadius: 6,
                      background: withAlpha(KatanaColors.background, 0.86),
                      border: `1px solid ${withAlpha(KatanaColors.accent, 0.55)}`,
                      fontFamily: Fonts.body,
                      fontSize: 10.5,
                      fontWeight: 800,
                      color: KatanaColors.accentSoft,
                    }}
                  >
                    ★ {bm.userScore}
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
                      padding: '22px 44px 8px 8px',
                      background: `linear-gradient(to top, ${withAlpha(KatanaColors.background, 0.94)}, transparent)`,
                    }}
                  >
                    <div
                      className="clamp-2"
                      style={{
                        fontFamily: Fonts.body,
                        fontSize: 12.5,
                        fontWeight: 700,
                        color: KatanaColors.text,
                        lineHeight: 1.2,
                      }}
                    >
                      {bm.title}
                    </div>
                  </div>
                )}
              </div>
              {libraryViewMode === 'grid' && (
                <div style={{ padding: '8px 9px 10px', paddingRight: 50 }}>
                  <div
                    className="clamp-2"
                    style={{
                      fontFamily: Fonts.body,
                      fontSize: 13,
                      fontWeight: 600,
                      color: KatanaColors.text,
                      lineHeight: 1.25,
                    }}
                  >
                    {bm.title}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 4, flexWrap: 'wrap' }}>
                    <span
                      style={{
                        ...KatanaType.small,
                        fontSize: 11.5,
                        fontWeight: 700,
                        color: unread > 0 ? KatanaColors.accentSoft : KatanaColors.textMuted,
                      }}
                    >
                      {readCount} / {readCount + unread}
                    </span>
                    {unread > 0 && (
                      <span
                        aria-label={`${unread} unread`}
                        style={{ width: 6, height: 6, borderRadius: 99, background: KatanaColors.accent, flexShrink: 0 }}
                      />
                    )}
                    <span style={{ ...KatanaType.small, fontSize: 11, whiteSpace: 'nowrap' }}>
                      {formatKatanaTime(bm.lastReadAt) || STATUS_LABELS[resolveLibraryStatus(bm)].label}
                    </span>
                  </div>
                </div>
              )}
            </button>
            {!librarySelectMode && (
              <button
                type="button"
                className="bare-button"
                aria-label={`Resume ${bm.title}`}
                title={resumeLabel ? `Resume ${resumeLabel}` : `Start ${bm.title}`}
                onClick={(e) => {
                  e.stopPropagation();
                  onResumeBookmark(bm);
                }}
                style={{
                  position: 'absolute',
                  right: 8,
                  bottom: libraryViewMode === 'grid' ? 40 : 8,
                  width: 44,
                  height: 44,
                  borderRadius: 99,
                  background: KatanaColors.accent,
                  boxShadow: '0 4px 12px rgba(0,0,0,0.55)',
                  display: 'grid',
                  placeItems: 'center',
                }}
              >
                <Icon name="play_arrow" size={22} color={KatanaColors.accentInk} />
              </button>
            )}
          </div>
        );
      })}
    </div>
  );
}
