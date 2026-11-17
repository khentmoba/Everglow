// Port of lib/features/ai/presentation/widgets/motchi_sidebar.dart,
// motchi_sidebar_panel.dart and motchi_sidebar_tiles.dart.
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { Logger } from '../../core/system/logger';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { orZero } from '../../core/theme/motion';
import { letterSpacing, lineHeight } from '../../core/theme/paint';
import { AppTypography, Fonts } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { AlertDialog, showDialog, TextButton } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { aiChat, useAIChat } from './aiChat';
import type { AISession } from './motchiDomain';

function groupByDate(sessions: AISession[]): Map<string, AISession[]> {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const yesterday = today - 86400000;
  const lastWeek = today - 7 * 86400000;
  const lastMonth = today - 30 * 86400000;
  const groups = new Map<string, AISession[]>();
  for (const s of sessions) {
    const d = s.createdAt;
    const day = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    const label =
      day >= today
        ? 'Today'
        : day >= yesterday
          ? 'Yesterday'
          : day >= lastWeek
            ? 'Last 7 days'
            : day >= lastMonth
              ? 'Last 30 days'
              : 'Older';
    const list = groups.get(label) ?? [];
    list.push(s);
    groups.set(label, list);
  }
  return groups;
}

export function MotchiSidebar({
  isOpen,
  onClose,
  onNewChat,
  navigationBusy = false,
  onSessionOpened,
}: {
  isOpen: boolean;
  onClose: () => void;
  onNewChat: () => void;
  navigationBusy?: boolean;
  onSessionOpened?: () => void;
}) {
  const { width } = useViewport();
  const isDesktop = width >= 1024;
  const ai = useAIChat();
  const [archived, setArchived] = useState<AISession[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [historyFailed, setHistoryFailed] = useState(false);
  const [switchingId, setSwitchingId] = useState<string | null>(null);
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null);
  const [query, setQuery] = useState('');

  useEffect(() => {
    const unsub = aiChat.watchSessions(
      50,
      (sessions) => {
        setArchived(sessions);
        setIsLoading(false);
        setHistoryFailed(false);
      },
      (error) => {
        Logger.e('Motchi history failed to load', error);
        setIsLoading(false);
        setHistoryFailed(true);
      },
    );
    return unsub;
  }, []);

  const liveSession = useMemo<AISession | null>(() => {
    const live = ai.assistantConversation;
    if (!live || live.messages.length === 0) return null;
    const preview = (live.messages.find((m) => m.role === 'user') ?? live.messages[0]).content;
    const title = preview.length > 56 ? `${preview.slice(0, 56)}…` : preview;
    return {
      id: '__live__',
      feature: live.feature,
      messageCount: live.messages.length,
      hasSummary: false,
      summary: null,
      createdAt: live.updatedAt,
      title: title === '' ? 'Current conversation' : title,
    };
  }, [ai.assistantConversation]);

  const sessions = useMemo(() => {
    if (!liveSession) return archived;
    const dup = archived.some((s) => s.messageCount === liveSession.messageCount && s.title === liveSession.title);
    return dup ? archived : [liveSession, ...archived];
  }, [archived, liveSession]);

  const effectiveActiveId = useMemo(() => {
    const hasLive = liveSession != null;
    if (!hasLive && activeSessionId === '__live__') return null;
    if (activeSessionId == null) return hasLive ? '__live__' : null;
    if (activeSessionId !== '__live__' && !archived.some((s) => s.id === activeSessionId)) {
      return hasLive ? '__live__' : null;
    }
    return activeSessionId;
  }, [activeSessionId, archived, liveSession]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return sessions;
    return sessions.filter((s) => s.title.toLowerCase().includes(q) || (s.summary ?? '').toLowerCase().includes(q));
  }, [query, sessions]);

  const grouped = useMemo(() => groupByDate(filtered), [filtered]);
  const busy = navigationBusy || switchingId != null || ai.isLoading || ai.isNavigating;

  const refresh = async () => {
    setIsLoading(true);
    try {
      const list = await aiChat.listSessions(50);
      setArchived(list);
      setIsLoading(false);
      setHistoryFailed(false);
    } catch (e) {
      Logger.e('Motchi history failed to load', e);
      setIsLoading(false);
      setHistoryFailed(true);
    }
  };

  const handleNewChat = () => {
    if (busy) return;
    setActiveSessionId(null);
    if (!isDesktop) onClose();
    onNewChat();
  };

  const switchSession = async (session: AISession) => {
    if (busy) return;
    if (session.id === '__live__') {
      setActiveSessionId(session.id);
      onSessionOpened?.();
      onClose();
      return;
    }
    setSwitchingId(session.id);
    try {
      await aiChat.switchSession(session.id);
      setActiveSessionId(session.id);
      onSessionOpened?.();
      onClose();
    } catch (e) {
      Logger.e('Motchi conversation failed to open', e);
      showSnackBar('Couldn’t open this conversation. Please try again.');
    } finally {
      setSwitchingId(null);
    }
  };

  const deleteSession = async (session: AISession) => {
    if (busy) return;
    const confirmed = await showDialog<boolean>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        radius={AppRadius.x2}
        borderColor={withAlpha(AppColors.blushGold, 0.2)}
        title={
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div
              style={{
                padding: 6,
                borderRadius: AppRadius.sm,
                background: withAlpha(AppColors.deepRose, 0.15),
                display: 'flex',
              }}
            >
              <Icon name="delete_outline" size={18} color={AppColors.deepRose} />
            </div>
            <span style={{ ...AppTypography.titleMedium, fontSize: 16, fontWeight: 600 }}>Delete conversation?</span>
          </div>
        }
        content={
          <div style={{ ...AppTypography.bodySmall, color: Derived.textMuted, lineHeight: 1.4 }}>
            This will permanently delete this conversation from your history.
          </div>
        }
        actions={[
          <TextButton key="cancel" onPressed={() => close(false)} color={Derived.textMuted}>
            Cancel
          </TextButton>,
          <button
            key="delete"
            type="button"
            className="bare-button"
            onClick={() => close(true)}
            style={{
              height: 40,
              padding: '0 20px',
              borderRadius: AppRadius.lg,
              background: AppColors.deepRose,
              color: AppColors.petalWhite,
              ...AppTypography.labelLarge,
              display: 'inline-flex',
              alignItems: 'center',
            }}
          >
            Delete
          </button>,
        ]}
      />
    ));
    if (confirmed !== true) return;
    try {
      if (session.id === '__live__') {
        await aiChat.clearConversation('assistant', false);
        setActiveSessionId(null);
      } else {
        await aiChat.deleteSession(session.id);
        if (activeSessionId === session.id) setActiveSessionId(null);
      }
      showSnackBar('Conversation deleted', { background: AppColors.velvet, duration: 2000 });
    } catch (e) {
      showSnackBar(`Failed to delete: ${e}`, { background: withAlpha(AppColors.deepRose, 0.9) });
    }
  };

  const panel = (
    <SidebarPanel
      query={query}
      onQueryChanged={setQuery}
      sessions={filtered}
      isLoading={isLoading}
      historyFailed={historyFailed}
      switchingId={switchingId}
      busy={busy}
      grouped={grouped}
      activeId={effectiveActiveId}
      onNewChat={handleNewChat}
      onClose={onClose}
      onSwitch={(s) => void switchSession(s)}
      onDelete={(s) => void deleteSession(s)}
      onRefresh={() => void refresh()}
      desktop={isDesktop}
    />
  );

  if (isDesktop) return panel;

  const panelWidth = width < 400 ? Math.max(280, width * 0.82) : Math.min(340, width * 0.82);
  const ms = orZero(250);

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        zIndex: 50,
        pointerEvents: isOpen ? 'auto' : 'none',
      }}
    >
      <div
        onClick={onClose}
        style={{
          position: 'absolute',
          inset: 0,
          background: withAlpha(AppColors.inkDeep, 0.65),
          opacity: isOpen ? 1 : 0,
          transition: `opacity ${ms}ms ease`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          top: 0,
          bottom: 0,
          left: 0,
          width: panelWidth,
          transform: `translateX(${isOpen ? '0%' : '-100%'})`,
          transition: `transform ${ms}ms cubic-bezier(0.32, 0.72, 0, 1)`,
        }}
      >
        {panel}
      </div>
    </div>
  );
}

function SidebarPanel({
  query,
  onQueryChanged,
  sessions,
  isLoading,
  historyFailed,
  switchingId,
  busy,
  grouped,
  activeId,
  onNewChat,
  onClose,
  onSwitch,
  onDelete,
  onRefresh,
  desktop,
}: {
  query: string;
  onQueryChanged: (q: string) => void;
  sessions: AISession[];
  isLoading: boolean;
  historyFailed: boolean;
  switchingId: string | null;
  busy: boolean;
  grouped: Map<string, AISession[]>;
  activeId: string | null;
  onNewChat: () => void;
  onClose: () => void;
  onSwitch: (s: AISession) => void;
  onDelete: (s: AISession) => void;
  onRefresh: () => void;
  desktop: boolean;
}) {
  const navigate = useNavigate();
  const [searchFocused, setSearchFocused] = useState(false);

  return (
    <div
      style={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: AppColors.inkDeep,
        borderRight: `1px solid ${withAlpha(AppColors.blushGold, 0.12)}`,
        borderLeft: desktop ? `1px solid ${withAlpha(AppColors.blushGold, 0.06)}` : undefined,
        boxShadow: desktop ? undefined : '4px 0 24px rgba(0,0,0,0.45)',
        paddingTop: desktop ? 0 : 'env(safe-area-inset-top)',
        paddingBottom: desktop ? 0 : 'env(safe-area-inset-bottom)',
      }}
    >
      {/* Header */}
      <div style={{ padding: '8px 8px 8px 16px', display: 'flex', alignItems: 'center' }}>
        <img
          src="/images/motchi_avatar.webp"
          alt=""
          width={24}
          height={24}
          style={{ width: 24, height: 24, borderRadius: AppRadius.xs, objectFit: 'cover', flexShrink: 0 }}
        />
        <div style={{ width: 10 }} />
        <div
          style={{
            flex: 1,
            fontFamily: Fonts.reading,
            fontSize: 16,
            fontWeight: 500,
            color: AppColors.petalWhite,
            lineHeight: lineHeight(16),
          }}
        >
          Motchi
        </div>
        <MaterialIconButton icon="close" size={20} tooltip="Close sidebar" color={Derived.textMuted} onPressed={onClose} />
      </div>

      <div style={{ height: 1, background: withAlpha(AppColors.blushGold, 0.07) }} />

      {/* New conversation */}
      <div style={{ padding: '10px 12px 6px' }}>
        <button
          type="button"
          className="bare-button"
          disabled={busy}
          onClick={onNewChat}
          style={{
            width: '100%',
            minHeight: 48,
            padding: '0 16px',
            borderRadius: AppRadius.sm,
            background: Derived.glassSoft,
            color: AppColors.petalWhite,
            fontFamily: Fonts.reading,
            fontSize: 14,
            fontWeight: 400,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            opacity: busy ? 0.5 : 1,
            cursor: busy ? 'default' : 'pointer',
          }}
        >
          <Icon name="add" size={19} color={AppColors.petalWhite} />
          <span>New conversation</span>
        </button>
      </div>

      {/* Hub tiles */}
      <div style={{ padding: '2px 12px 6px', display: 'flex', gap: 6 }}>
        <HubTile
          icon="wb_twilight"
          label="Today"
          onTap={() => {
            if (!desktop) onClose();
            navigate('/motchi-today');
          }}
        />
        <HubTile
          icon="menu_book"
          label="Memories"
          onTap={() => {
            if (!desktop) onClose();
            navigate('/motchi-memory');
          }}
        />
        <HubTile
          icon="psychology"
          label="Trivia"
          onTap={() => {
            if (!desktop) onClose();
            navigate('/motchi-trivia');
          }}
        />
      </div>

      {/* Search */}
      <div style={{ padding: '2px 12px 6px' }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            background: Derived.surfaceGlass,
            borderRadius: AppRadius.lg,
            border: `1px solid ${withAlpha(AppColors.blushGold, searchFocused ? 0.45 : 0.12)}`,
            padding: '0 6px 0 10px',
            minHeight: 36,
          }}
        >
          <Icon name="search" size={17} color={query ? AppColors.blushGold : Derived.textMuted} />
          <input
            value={query}
            onChange={(e) => onQueryChanged(e.target.value)}
            onFocus={() => setSearchFocused(true)}
            onBlur={() => setSearchFocused(false)}
            placeholder="Search conversations..."
            style={{
              flex: 1,
              minWidth: 0,
              background: 'transparent',
              border: 'none',
              outline: 'none',
              padding: '8px 6px',
              ...AppTypography.bodySmall,
              color: Derived.textHigh,
            }}
          />
          {query && (
            <button
              type="button"
              className="bare-button"
              aria-label="Clear search"
              onClick={() => onQueryChanged('')}
              style={{ width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
            >
              <Icon name="close" size={15} color={Derived.textMuted} />
            </button>
          )}
        </div>
      </div>

      {/* History header */}
      <div style={{ padding: '6px 12px 4px 16px', display: 'flex', alignItems: 'center' }}>
        <span
          style={{
            ...AppTypography.bodySmall,
            color: withAlpha(AppColors.roseQuartz, 0.76 * 0.8),
            fontWeight: 700,
            fontSize: 11.5,
            ...letterSpacing(0.5),
          }}
        >
          History
        </span>
        <div style={{ width: 6 }} />
        <span
          style={{
            padding: '1px 6px',
            background: Derived.surfaceGlass,
            borderRadius: AppRadius.full,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.15)}`,
            ...AppTypography.labelSmall,
            color: AppColors.blushGold,
            fontSize: 9.5,
            fontWeight: 700,
          }}
        >
          {sessions.length}
        </span>
        {query && (
          <>
            <div style={{ width: 6 }} />
            <span style={{ ...AppTypography.bodySmall, color: Derived.textDisabled, fontSize: 10, fontStyle: 'italic' }}>
              filtered
            </span>
          </>
        )}
        <div style={{ flex: 1 }} />
        <MaterialIconButton
          icon="refresh"
          size={17}
          tooltip="Refresh conversations"
          color={Derived.textMuted}
          onPressed={isLoading ? undefined : onRefresh}
        />
      </div>

      {historyFailed && (
        <div style={{ padding: '0 16px' }}>
          <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium }}>
            History couldn’t load. Your current chat is still here.
          </div>
          <TextButton
            onPressed={isLoading ? undefined : onRefresh}
            icon={<Icon name="refresh" size={18} color={AppColors.deepRose} />}
          >
            Try again
          </TextButton>
        </div>
      )}

      {/* Session list */}
      <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
        {isLoading ? (
          <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CircularProgress size={24} strokeWidth={2} color={withAlpha(AppColors.blushGold, 0.75)} />
          </div>
        ) : sessions.length === 0 ? (
          historyFailed ? null : (
            <div
              style={{
                height: '100%',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                padding: AppSpacing.lg,
                textAlign: 'center',
              }}
            >
              <Icon name={query ? 'search_off' : 'pets'} size={30} color={withAlpha(AppColors.blushGold, 0.45)} />
              <div style={{ height: 10 }} />
              <div
                style={{
                  ...AppTypography.bodySmall,
                  color: Derived.textMuted,
                  fontSize: 12,
                  lineHeight: 1.4,
                  whiteSpace: 'pre-line',
                }}
              >
                {query ? `No matches for “${query}”.` : 'No conversations yet.\nStart chatting to see history here.'}
              </div>
              {query && (
                <>
                  <div style={{ height: 8 }} />
                  <TextButton
                    onPressed={() => onQueryChanged('')}
                    color={AppColors.blushGold}
                    icon={<Icon name="close" size={14} color={AppColors.blushGold} />}
                  >
                    Clear search
                  </TextButton>
                </>
              )}
            </div>
          )
        ) : (
          <div style={{ padding: '4px 10px' }}>
            {[...grouped.entries()].map(([label, list]) => (
              <div key={label} style={{ marginBottom: 4 }}>
                <div style={{ padding: '8px 8px 4px', display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span
                    style={{
                      ...AppTypography.bodySmall,
                      color: withAlpha(AppColors.roseQuartz, 0.76 * 0.65),
                      fontSize: 10.5,
                      fontWeight: 700,
                      ...letterSpacing(0.5),
                    }}
                  >
                    {label}
                  </span>
                  <span style={{ ...AppTypography.bodySmall, color: Derived.textDisabled, fontSize: 10 }}>· {list.length}</span>
                </div>
                {list.map((s) => (
                  <SessionItem
                    key={s.id}
                    session={s}
                    isActive={s.id === activeId}
                    isLoading={switchingId === s.id}
                    onTap={busy ? undefined : () => onSwitch(s)}
                    onDelete={busy ? undefined : () => onDelete(s)}
                  />
                ))}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Footer */}
      <div style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 6 }}>
        <Icon name="lock_outline" size={12} color={Derived.textDisabled} />
        <span
          style={{
            fontFamily: Fonts.reading,
            fontWeight: 400,
            fontSize: 11,
            color: Derived.textDisabled,
          }}
        >
          Private to Khent & Clair
        </span>
      </div>
    </div>
  );
}

function HubTile({ icon, label, onTap }: { icon: string; label: string; onTap: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        flex: 1,
        minWidth: 44,
        minHeight: 52,
        padding: '8px 4px',
        borderRadius: AppRadius.sm,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 5,
        fontFamily: Fonts.reading,
        fontSize: 12.5,
        fontWeight: 400,
        color: Derived.textMedium,
      }}
    >
      <Icon name={icon} size={17} color={Derived.textMuted} />
      <span className="ellipsis" style={{ maxWidth: '100%' }}>
        {label}
      </span>
    </button>
  );
}

function SessionItem({
  session,
  isActive,
  isLoading,
  onTap,
  onDelete,
}: {
  session: AISession;
  isActive: boolean;
  isLoading: boolean;
  onTap?: () => void;
  onDelete?: () => void;
}) {
  const isLive = session.id === '__live__';
  const now = new Date();
  const d = session.createdAt;
  const isToday = now.getDate() === d.getDate() && now.getMonth() === d.getMonth() && now.getFullYear() === d.getFullYear();
  const dateStr = isLive
    ? 'Active now'
    : isToday
      ? d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
      : d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const hasPreview = Boolean(session.summary?.trim());

  return (
    <div
      style={{
        marginBottom: 4,
        borderRadius: AppRadius.sm,
        background: isActive ? Derived.glassSoft : 'transparent',
        display: 'flex',
        alignItems: 'center',
        padding: '8px 4px 8px 12px',
        cursor: onTap ? 'pointer' : 'default',
      }}
      onClick={onTap}
    >
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          className="clamp-2"
          style={{
            fontFamily: Fonts.reading,
            fontWeight: isActive ? 500 : 400,
            fontSize: 14,
            lineHeight: 1.4,
            color: Derived.textHigh,
          }}
        >
          {session.title}
        </div>
        {hasPreview && (
          <div
            className="ellipsis"
            style={{
              fontFamily: Fonts.reading,
              fontWeight: 400,
              fontSize: 12.5,
              color: Derived.textMuted,
            }}
          >
            {session.summary!.trim()}
          </div>
        )}
        <div
          className="ellipsis"
          style={{
            fontFamily: Fonts.reading,
            fontWeight: 400,
            fontSize: 11,
            color: Derived.textDisabled,
          }}
        >
          {dateStr} · {session.messageCount} msg{session.messageCount === 1 ? '' : 's'}
          {session.hasSummary && !hasPreview ? ' · summary' : ''}
        </div>
      </div>
      {isLoading ? (
        <div style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <CircularProgress size={20} strokeWidth={2} color={AppColors.deepRose} />
        </div>
      ) : (
        <div onClick={(e) => e.stopPropagation()}>
          <MaterialIconButton
            icon="delete_outline"
            size={18}
            tooltip="Delete conversation"
            color={Derived.textMuted}
            onPressed={onDelete}
          />
        </div>
      )}
    </div>
  );
}
