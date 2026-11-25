import { useEffect, useState } from 'react';
import { withAlpha } from '../../core/theme/colors';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import {
  clearKatanaHistory,
  estimateUnreadCount,
  fetchKatanaDetail,
  formatKatanaTime,
  isBookmarkCaughtUp,
  isKatanaIncognitoSession,
  removeKatanaHistoryEntry,
  setKatanaHistoryPaused,
  setKatanaIncognitoSession,
  subscribeKatanaIncognitoSession,
  type KatanaBookmark,
  type KatanaHistoryEntry,
  type KatanaManga,
} from './katanaService';
import { KatanaColors, KatanaFonts as Fonts, KatanaType } from './katanaTokens';
import {
  KatanaBreadcrumb,
  KatanaCoverBadges,
  KatanaCoverImage,
  KatanaEmptyState,
  KatanaSectionHeader,
  type KatanaNavKey,
} from './MangaUi';

export function MangaReadingHistoryView({
  tab,
  historySubView,
  setHistorySubView,
  savedBookmarks,
  historyEntries,
  setHistoryEntries,
  groupedHistory,
  currentlyReading,
  historyPaused,
  setHistoryPaused,
  userName,
  isCoupleUser,
  partnerUsername,
  partnerDisplayLabel,
  showPartnerReading,
  setShowPartnerReading,
  tablet,
  compactCard,
  downloadedCounts,
  resumingSlug,
  onNav,
  onOpenDetail,
  onOpenChapter,
  onResumeBookmark,
  onRemoveFromReading,
}: {
  tab: 'reading' | 'history';
  historySubView: 'history' | 'updates';
  setHistorySubView: (v: 'history' | 'updates') => void;
  savedBookmarks: KatanaBookmark[];
  historyEntries: KatanaHistoryEntry[];
  setHistoryEntries: (entries: KatanaHistoryEntry[]) => void;
  groupedHistory: Array<{ label: string; items: KatanaHistoryEntry[] }>;
  currentlyReading: KatanaBookmark[];
  historyPaused: boolean;
  setHistoryPaused: (v: boolean) => void;
  userName: string;
  isCoupleUser: boolean;
  partnerUsername: string;
  partnerDisplayLabel: string;
  showPartnerReading: boolean;
  setShowPartnerReading: (v: boolean) => void;
  tablet: boolean;
  compactCard: boolean;
  downloadedCounts: Record<string, number>;
  resumingSlug: string | null;
  onNav: (next: KatanaNavKey) => void;
  onOpenDetail: (slug: string) => void;
  onOpenChapter: (manga: KatanaManga, chapterId: string, page?: number) => void;
  onResumeBookmark: (bm: KatanaBookmark) => void;
  onRemoveFromReading: (slug: string, title: string) => void;
}) {
  const [incognitoSession, setIncognitoSession] = useState(() => isKatanaIncognitoSession());
  useEffect(() => subscribeKatanaIncognitoSession(setIncognitoSession), []);
  return (
    <div>
      <KatanaBreadcrumb items={[tab === 'history' ? 'History' : 'Currently Reading']} onHome={() => onNav('home')} />
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
        <KatanaSectionHeader
          title={
            tab === 'history'
              ? historySubView === 'updates'
                ? 'Chapter Updates Inbox'
                : 'Reading History'
              : 'Currently Reading'
          }
          badge={String(
            tab === 'history'
              ? historySubView === 'updates'
                ? savedBookmarks.filter((b) => estimateUnreadCount(b) > 0).length
                : historyEntries.length
              : currentlyReading.length,
          )}
        />
        {tab === 'reading' && isCoupleUser && partnerUsername ? (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 12 }}>
            {[false, true].map((partner) => {
              const active = showPartnerReading === partner;
              const label = partner ? partnerDisplayLabel : 'Mine';
              return (
                <button
                  key={label}
                  type="button"
                  className="bare-button"
                  onClick={() => setShowPartnerReading(partner)}
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
                  {label}
                </button>
              );
            })}
          </div>
        ) : null}
      </div>

      <div
        style={{
          marginTop: 8,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: 10,
          borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.85)}`,
        }}
      >
        <div role="group" aria-label="Reading views" style={{ display: 'inline-flex', gap: 20 }}>
          {(
            [
              ['reading', 'Reading'],
              ['history', 'History'],
              ['updates', `Updates (${savedBookmarks.filter((b) => estimateUnreadCount(b) > 0).length})`],
            ] as const
          ).map(([k, lbl]) => {
            const active =
              k === 'reading'
                ? tab === 'reading'
                : k === 'history'
                  ? tab === 'history' && historySubView === 'history'
                  : tab === 'history' && historySubView === 'updates';
            return (
              <button
                key={k}
                type="button"
                aria-pressed={active}
                className="bare-button"
                onClick={() => {
                  if (k === 'reading') {
                    onNav('reading');
                  } else if (k === 'history') {
                    setHistorySubView('history');
                    if (tab !== 'history') onNav('history');
                  } else {
                    setHistorySubView('updates');
                    if (tab !== 'history') onNav('history');
                  }
                }}
                style={{
                  minHeight: 44,
                  padding: '6px 0',
                  borderBottom: `2px solid ${active ? KatanaColors.accent : 'transparent'}`,
                  marginBottom: -1,
                  fontFamily: Fonts.body,
                  fontSize: 13.5,
                  fontWeight: active ? 700 : 500,
                  color: active ? KatanaColors.text : KatanaColors.textMuted,
                }}
              >
                {lbl}
              </button>
            );
          })}
        </div>
        {tab === 'history' && historySubView === 'history' && (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 12, flexWrap: 'wrap', paddingBottom: 4 }}>
            <button
              type="button"
              className="bare-button"
              aria-pressed={incognitoSession}
              title="One-session Incognito Reading: suppresses history, read-chapter marking, and tracker pushes until this tab closes"
              onClick={() => {
                const next = !incognitoSession;
                setKatanaIncognitoSession(next);
                showSnackBar(
                  next
                    ? 'Incognito session enabled — reading progress & trackers paused for this session'
                    : 'Incognito session ended',
                );
              }}
              style={{
                minHeight: 36,
                padding: '0 2px',
                display: 'inline-flex',
                alignItems: 'center',
                gap: 5,
                fontFamily: Fonts.body,
                fontSize: 12.5,
                fontWeight: 600,
                color: incognitoSession ? KatanaColors.accentSoft : KatanaColors.textMuted,
              }}
            >
              <Icon name="policy" size={15} color={incognitoSession ? KatanaColors.accent : KatanaColors.textMuted} />
              <span>{incognitoSession ? 'Incognito On' : 'Incognito'}</span>
            </button>
            <button
              type="button"
              className="bare-button"
              aria-pressed={historyPaused}
              onClick={() => {
                const next = !historyPaused;
                setHistoryPaused(next);
                setKatanaHistoryPaused(userName, next);
                showSnackBar(next ? 'History logging paused across sessions' : 'History logging resumed');
              }}
              style={{
                minHeight: 36,
                padding: '0 2px',
                display: 'inline-flex',
                alignItems: 'center',
                gap: 5,
                fontFamily: Fonts.body,
                fontSize: 12.5,
                fontWeight: 600,
                color: historyPaused ? KatanaColors.accentSoft : KatanaColors.textMuted,
              }}
            >
              <Icon name={historyPaused ? 'visibility_off' : 'history_toggle_off'} size={15} color={historyPaused ? KatanaColors.accent : KatanaColors.textMuted} />
              <span>{historyPaused ? 'Paused' : 'Pause'}</span>
            </button>
            {historyEntries.length > 0 && (
              <button
                type="button"
                className="bare-button"
                onClick={() =>
                  void showDialog<void>((close) => (
                    <AlertDialog
                      background={KatanaColors.surface}
                      title={<div style={KatanaType.title}>Clear Reading History</div>}
                      content={<div style={KatanaType.small}>Remove all entries from your reading history? Your saved library bookmarks stay intact.</div>}
                      actions={[
                        <TextButton key="cancel" onPressed={() => close(null)} color={KatanaColors.textMuted}>
                          Cancel
                        </TextButton>,
                        <TextButton
                          key="clear"
                          color="#FF453A"
                          onPressed={() => {
                            close(null);
                            clearKatanaHistory(userName);
                            setHistoryEntries([]);
                            showSnackBar('Cleared reading history');
                          }}
                        >
                          Clear History
                        </TextButton>,
                      ]}
                    />
                  ))
                }
                style={{
                  minHeight: 36,
                  padding: '0 2px',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 4,
                  fontFamily: Fonts.body,
                  fontSize: 12.5,
                  fontWeight: 600,
                  color: KatanaColors.textLight,
                }}
              >
                <Icon name="delete_sweep" size={15} color={KatanaColors.textLight} />
                <span>Clear</span>
              </button>
            )}
          </div>
        )}
      </div>
      <div style={{ height: 14 }} />
      {tab === 'history' && historySubView === 'updates' ? (
        (() => {
          const updatedSeries = savedBookmarks
            .filter((b) => estimateUnreadCount(b) > 0)
            .sort((a, b) => estimateUnreadCount(b) - estimateUnreadCount(a) || (b.lastReadAt?.getTime() ?? b.addedAt.getTime()) - (a.lastReadAt?.getTime() ?? a.addedAt.getTime()));
          if (updatedSeries.length === 0) {
            return (
              <KatanaEmptyState
                icon="notifications_none"
                title="You're all caught up"
                subtitle="New chapters for your followed series will appear here as soon as they drop."
                actionLabel="Browse Manga"
                actionIcon="home"
                onAction={() => onNav('home')}
              />
            );
          }
          return (
            <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', columnGap: 24 }}>
              {updatedSeries.map((bm) => {
                const unread = estimateUnreadCount(bm);
                return (
                  <div key={bm.slug} style={{ padding: '12px 0', borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.75)}` }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0 }}>
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => onOpenDetail(bm.slug)}
                        style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0, textAlign: 'left', overflow: 'hidden' }}
                      >
                        <div style={{ position: 'relative', width: 48, height: 68, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                          <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={18} />
                        </div>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div className="ellipsis" style={{ fontFamily: Fonts.body, fontWeight: 600, color: KatanaColors.text, fontSize: compactCard ? 14 : 14.5 }}>{bm.title}</div>
                          <div className="ellipsis" style={{ ...KatanaType.accent, fontSize: 12.5, marginTop: 2 }}>
                            +{unread} new {unread === 1 ? 'chapter' : 'chapters'}
                            {bm.latestChapterTitle ? ` · ${bm.latestChapterTitle}` : ''}
                          </div>
                          <div className="ellipsis" style={{ ...KatanaType.small, fontSize: 12, marginTop: 2 }}>
                            {bm.lastReadChapterTitle ? `Last read: ${bm.lastReadChapterTitle}` : 'Not started yet'}
                          </div>
                        </div>
                      </button>
                      <button
                        type="button"
                        className="bare-button"
                        aria-label={`Read ${bm.title}`}
                        onClick={() => void onResumeBookmark(bm)}
                        style={{
                          width: 40,
                          height: 40,
                          borderRadius: 99,
                          background: withAlpha(KatanaColors.accent, 0.14),
                          display: 'grid',
                          placeItems: 'center',
                          flexShrink: 0,
                        }}
                      >
                        <Icon name="play_arrow" size={20} color={KatanaColors.accent} />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          );
        })()
      ) : tab === 'history' ? (
        historyEntries.length === 0 ? (
          <KatanaEmptyState
            icon="history"
            title="No reading history yet"
            subtitle="Every chapter you open appears here in chronological order so you can jump right back in."
            actionLabel="Browse Manga"
            actionIcon="home"
            onAction={() => onNav('home')}
          />
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {groupedHistory.map((group) => (
              <section key={group.label} aria-label={`${group.label} reading history`}>
                <div style={{ ...KatanaType.small, fontWeight: 700, color: KatanaColors.textMuted, marginBottom: 8, textTransform: 'uppercase', letterSpacing: 0.6 }}>
                  {group.label} ({group.items.length})
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', columnGap: 24 }}>
                  {group.items.map((entry) => (
                    <div key={`${entry.slug}-${entry.chapterId}-${entry.readAt}`} style={{ padding: '11px 0', borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.75)}` }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0 }}>
                        <button
                          type="button"
                          className="bare-button"
                          onClick={() => onOpenDetail(entry.slug)}
                          style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0, textAlign: 'left', overflow: 'hidden' }}
                        >
                          <div style={{ position: 'relative', width: 46, height: 66, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                            <KatanaCoverImage url={entry.coverUrl} title={entry.title} iconSize={18} />
                          </div>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div className="ellipsis" style={{ fontFamily: Fonts.body, fontWeight: 600, color: KatanaColors.text, fontSize: compactCard ? 14 : 14.5 }}>{entry.title}</div>
                            <div className="ellipsis" style={{ ...KatanaType.accent, fontSize: 12.5, marginTop: 2 }}>{entry.chapterTitle}</div>
                            <div className="ellipsis" style={{ ...KatanaType.small, fontSize: 12, marginTop: 2 }}>
                              {formatKatanaTime(new Date(entry.readAt))}
                              {entry.page && entry.page > 1 ? ` · Page ${entry.page}` : ''}
                            </div>
                          </div>
                        </button>
                        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, flexShrink: 0 }}>
                          <button
                            type="button"
                            className="bare-button"
                            aria-label={`Read ${entry.title} ${entry.chapterTitle}`}
                            onClick={() => {
                              void (async () => {
                                const loaded = await fetchKatanaDetail(entry.slug);
                                if (loaded && loaded.chapters.length > 0) {
                                  onOpenChapter(loaded, entry.chapterId, entry.page || 1);
                                } else {
                                  onOpenDetail(entry.slug);
                                }
                              })();
                            }}
                            style={{ width: 40, height: 40, borderRadius: 99, background: withAlpha(KatanaColors.accent, 0.14), display: 'grid', placeItems: 'center' }}
                          >
                            <Icon name="play_arrow" size={20} color={KatanaColors.accent} />
                          </button>
                          <button
                            type="button"
                            className="bare-button"
                            aria-label={`Remove ${entry.title} ${entry.chapterTitle} from history`}
                            onClick={() => setHistoryEntries(removeKatanaHistoryEntry(userName, entry.slug, entry.chapterId))}
                            style={{ width: 40, height: 40, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                          >
                            <Icon name="close" size={17} color={KatanaColors.textLight} />
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </section>
            ))}
          </div>
        )
      ) : currentlyReading.length === 0 ? (
        <KatanaEmptyState
          icon="auto_stories"
          title={showPartnerReading ? `${partnerDisplayLabel} isn't reading anything right now` : 'Nothing in progress'}
          subtitle="Open any chapter to track your place automatically across devices."
          actionLabel="Browse Manga"
          actionIcon="home"
          onAction={() => onNav('home')}
        />
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', columnGap: 24 }}>
          {currentlyReading.map((bm) => {
            const unread = estimateUnreadCount(bm);
            const dlCount = downloadedCounts[bm.slug] ?? 0;
            const caughtUp = isBookmarkCaughtUp(bm);
            return (
              <div key={bm.slug} style={{ padding: '12px 0', borderBottom: `1px solid ${withAlpha(KatanaColors.border, 0.75)}` }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => onOpenDetail(bm.slug)}
                    style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0, textAlign: 'left' }}
                  >
                    <div style={{ position: 'relative', width: 56, height: 82, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                      <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={20} />
                      <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 14.5, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>{bm.title}</div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginTop: 4 }}>
                        <span style={{ ...KatanaType.small, color: KatanaColors.accentSoft, fontWeight: 600 }}>
                          {bm.lastReadChapterTitle} · Page {bm.lastReadPage || 1}
                        </span>
                        {caughtUp && (
                          <span style={{ fontFamily: Fonts.body, color: KatanaColors.green, fontSize: 11.5, fontWeight: 600 }}>
                            · Caught Up
                          </span>
                        )}
                      </div>
                    </div>
                  </button>
                  <button
                    type="button"
                    className="bare-button"
                    aria-label={`Resume ${bm.title}`}
                    onClick={() => void onResumeBookmark(bm)}
                    style={{
                      width: 40,
                      height: 40,
                      borderRadius: '50%',
                      background: withAlpha(KatanaColors.accent, 0.14),
                      display: 'grid',
                      placeItems: 'center',
                      flexShrink: 0,
                    }}
                  >
                    <Icon name={resumingSlug === bm.slug ? 'hourglass_top' : 'play_arrow'} size={20} color={KatanaColors.accent} />
                  </button>
                  {!showPartnerReading && (
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Remove ${bm.title} from reading`}
                      title="Remove from Currently Reading"
                      onClick={() => void onRemoveFromReading(bm.slug, bm.title)}
                      style={{
                        width: 40,
                        height: 40,
                        display: 'grid',
                        placeItems: 'center',
                        flexShrink: 0,
                      }}
                    >
                      <Icon name="close" size={18} color={KatanaColors.textLight} />
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
