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
  KatanaButton,
  KatanaCard,
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
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
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
          <div style={{ display: 'inline-flex', gap: 4, padding: 3, borderRadius: 99, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
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
                    padding: '4px 12px',
                    borderRadius: 99,
                    background: active ? KatanaColors.accent : 'transparent',
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
                    fontWeight: 700,
                    color: active ? KatanaColors.accentInk : KatanaColors.textMuted,
                  }}
                >
                  {lbl}
                </button>
              );
            })}
          </div>
        </div>
        {tab === 'history' && historySubView === 'history' ? (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
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
                minHeight: 44,
                padding: '5px 11px',
                borderRadius: 99,
                background: incognitoSession ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                border: `1px solid ${incognitoSession ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 5,
                fontFamily: Fonts.body,
                fontSize: 12,
                fontWeight: 700,
                color: incognitoSession ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
              }}
            >
              <Icon name="policy" size={15} color={incognitoSession ? KatanaColors.accent : KatanaColors.textMuted} />
              <span>{incognitoSession ? 'Incognito Session On' : 'Incognito Session'}</span>
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
                minHeight: 44,
                padding: '5px 11px',
                borderRadius: 99,
                background: historyPaused ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                border: `1px solid ${historyPaused ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 5,
                fontFamily: Fonts.body,
                fontSize: 12,
                fontWeight: 700,
                color: historyPaused ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
              }}
            >
              <Icon name={historyPaused ? 'visibility_off' : 'history_toggle_off'} size={15} color={historyPaused ? KatanaColors.accent : KatanaColors.textMuted} />
              <span>{historyPaused ? 'History Paused' : 'Pause History'}</span>
            </button>
            {historyEntries.length > 0 && (
              <KatanaButton
                label="Clear History"
                icon="delete_sweep"
                size="sm"
                filled={false}
                color={KatanaColors.textMuted}
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
              />
            )}
          </div>
        ) : tab === 'reading' && isCoupleUser && partnerUsername ? (
          <div style={{ display: 'inline-flex', gap: 4, padding: 3, borderRadius: 99, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
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
                    minHeight: 44,
                    padding: '5px 12px',
                    borderRadius: 99,
                    background: active ? KatanaColors.accent : 'transparent',
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
                    fontWeight: 700,
                    color: active ? KatanaColors.accentInk : KatanaColors.textMuted,
                  }}
                >
                  {label}
                </button>
              );
            })}
          </div>
        ) : null}
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
            <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 10 }}>
              {updatedSeries.map((bm) => {
                const unread = estimateUnreadCount(bm);
                return (
                  <KatanaCard key={bm.slug} padding={compactCard ? 9 : 11}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => onOpenDetail(bm.slug)}
                        style={{ display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 0, textAlign: 'left', overflow: 'hidden' }}
                      >
                        <div style={{ position: 'relative', width: 46, height: 66, borderRadius: 7, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                          <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={18} />
                        </div>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div className="ellipsis" style={{ ...KatanaType.title, fontSize: compactCard ? 13.5 : 14.5 }}>{bm.title}</div>
                          <div className="ellipsis" style={{ ...KatanaType.accent, fontSize: 12, marginTop: 2 }}>
                            {unread} new {unread === 1 ? 'chapter' : 'chapters'}
                            {bm.latestChapterTitle ? ` · ${bm.latestChapterTitle}` : ''}
                          </div>
                          <div className="ellipsis" style={{ ...KatanaType.small, fontSize: 12, marginTop: 2 }}>
                            {bm.lastReadChapterTitle ? `Last read: ${bm.lastReadChapterTitle}` : 'Not started yet'}
                          </div>
                        </div>
                      </button>
                      <KatanaButton
                        label="Read"
                        icon="play_arrow"
                        size="sm"
                        onClick={() => void onResumeBookmark(bm)}
                      />
                    </div>
                  </KatanaCard>
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
                <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 10 }}>
                  {group.items.map((entry) => (
                    <KatanaCard key={`${entry.slug}-${entry.chapterId}-${entry.readAt}`} padding={compactCard ? 8 : 10}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: compactCard ? 8 : 12, minWidth: 0 }}>
                        <button
                          type="button"
                          className="bare-button"
                          onClick={() => onOpenDetail(entry.slug)}
                          style={{ display: 'flex', alignItems: 'center', gap: compactCard ? 9 : 12, flex: 1, minWidth: 0, textAlign: 'left', overflow: 'hidden' }}
                        >
                          <div style={{ position: 'relative', width: compactCard ? 42 : 48, height: compactCard ? 60 : 68, borderRadius: 7, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                            <KatanaCoverImage url={entry.coverUrl} title={entry.title} iconSize={18} />
                          </div>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div className="ellipsis" style={{ ...KatanaType.title, fontSize: compactCard ? 13.5 : 14.5 }}>{entry.title}</div>
                            <div className="ellipsis" style={{ ...KatanaType.accent, fontSize: 12, marginTop: 2 }}>{entry.chapterTitle}</div>
                            <div className="ellipsis" style={{ ...KatanaType.small, fontSize: 12, marginTop: 2 }}>
                              {formatKatanaTime(new Date(entry.readAt))}
                              {entry.page && entry.page > 1 ? ` · Page ${entry.page}` : ''}
                            </div>
                          </div>
                        </button>
                        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, flexShrink: 0 }}>
                          <KatanaButton
                            label="Read"
                            icon="play_arrow"
                            size="sm"
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
                          />
                          <button
                            type="button"
                            className="bare-button"
                            aria-label={`Remove ${entry.title} ${entry.chapterTitle} from history`}
                            onClick={() => setHistoryEntries(removeKatanaHistoryEntry(userName, entry.slug, entry.chapterId))}
                            style={{ width: 44, height: 44, borderRadius: 8, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}`, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                          >
                            <Icon name="close" size={16} color={KatanaColors.textMuted} />
                          </button>
                        </div>
                      </div>
                    </KatanaCard>
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
        <div style={{ display: 'grid', gridTemplateColumns: tablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 12 }}>
          {currentlyReading.map((bm) => {
            const unread = estimateUnreadCount(bm);
            const dlCount = downloadedCounts[bm.slug] ?? 0;
            const caughtUp = isBookmarkCaughtUp(bm);
            return (
              <KatanaCard key={bm.slug} padding={12}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => onOpenDetail(bm.slug)}
                    style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0, textAlign: 'left' }}
                  >
                    <div style={{ position: 'relative', width: 58, height: 84, borderRadius: 8, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                      <KatanaCoverImage url={bm.coverUrl} title={bm.title} iconSize={20} />
                      <KatanaCoverBadges unreadCount={unread} downloadedCount={dlCount} />
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div className="clamp-2" style={KatanaType.title}>{bm.title}</div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginTop: 4 }}>
                        <span style={{ ...KatanaType.small, color: KatanaColors.link }}>
                          {bm.lastReadChapterTitle} · Page {bm.lastReadPage || 1}
                        </span>
                        {caughtUp && (
                          <span style={{ padding: '1px 6px', borderRadius: 4, background: withAlpha(KatanaColors.green, 0.16), color: KatanaColors.green, fontSize: 12, fontWeight: 700 }}>
                            Caught Up
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
                      width: 44,
                      height: 44,
                      borderRadius: '50%',
                      background: KatanaColors.accent,
                      display: 'grid',
                      placeItems: 'center',
                      flexShrink: 0,
                    }}
                  >
                    <Icon name={resumingSlug === bm.slug ? 'hourglass_top' : 'play_arrow'} size={20} color={KatanaColors.accentInk} />
                  </button>
                  {!showPartnerReading && (
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Remove ${bm.title} from reading`}
                      title="Remove from Currently Reading"
                      onClick={() => void onRemoveFromReading(bm.slug, bm.title)}
                      style={{
                        width: 44,
                        height: 44,
                        borderRadius: '50%',
                        background: KatanaColors.surfaceAlt,
                        border: `1px solid ${KatanaColors.border}`,
                        display: 'grid',
                        placeItems: 'center',
                        flexShrink: 0,
                      }}
                    >
                      <Icon name="close" size={18} color={KatanaColors.textMuted} />
                    </button>
                  )}
                </div>
              </KatanaCard>
            );
          })}
        </div>
      )}
    </div>
  );
}
