// Port of lib/features/ai/presentation/widgets/study_history_panel.dart.
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { orZero } from '../../core/theme/motion';
import { Align, letterSpacing, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { AlertDialog, showDialog, TextButton } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { studyHistory, type StudySession } from './studyDocs';

function groupByDate(sessions: StudySession[]): Map<string, StudySession[]> {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const yesterday = today - 86400000;
  const lastWeek = today - 7 * 86400000;
  const lastMonth = today - 30 * 86400000;
  const groups = new Map<string, StudySession[]>();
  for (const s of sessions) {
    const d = s.updatedAt;
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

export function StudyHistoryPanel({
  isOpen,
  activeSessionId,
  refreshKey,
  onClose,
  onNewStudy,
  onSelect,
}: {
  isOpen: boolean;
  activeSessionId: string | null;
  refreshKey: number;
  onClose: () => void;
  onNewStudy: () => void;
  onSelect: (session: StudySession) => void;
}) {
  const { width } = useViewport();
  const desktop = width >= 1024;
  const [sessions, setSessions] = useState<StudySession[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isDeleting, setIsDeleting] = useState(false);
  const [query, setQuery] = useState('');

  const refresh = useCallback(async () => {
    setIsLoading(true);
    try {
      const list = await studyHistory.listSessions(30);
      setSessions(list);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh, refreshKey]);

  useEffect(() => {
    if (isOpen) void refresh();
  }, [isOpen, refresh]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return sessions;
    return sessions.filter((s) => s.title.toLowerCase().includes(q) || s.sourceNames.some((n) => n.toLowerCase().includes(q)));
  }, [query, sessions]);

  const grouped = useMemo(() => groupByDate(filtered), [filtered]);

  const handleDelete = async (session: StudySession) => {
    const confirmed = await showDialog<boolean>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        title={<span style={{ ...AppTypography.titleMedium, color: Derived.textHigh }}>Delete study session?</span>}
        content={
          <span style={{ ...AppTypography.bodySmall, color: Derived.textMuted }}>
            “{session.title}” will be permanently deleted.
          </span>
        }
        actions={[
          <TextButton key="cancel" onPressed={() => close(false)} color={Derived.textMuted}>
            Cancel
          </TextButton>,
          <TextButton key="delete" onPressed={() => close(true)} color={AppColors.error}>
            Delete
          </TextButton>,
        ]}
      />
    ));
    if (confirmed !== true) return;
    setIsDeleting(true);
    try {
      await studyHistory.deleteSession(session.id);
      showSnackBar('Study deleted', { background: Derived.surfaceGlass, duration: 2000 });
    } catch {
      showSnackBar('Could not delete — try again.', { background: withAlpha(AppColors.deepRose, 0.9) });
    } finally {
      setIsDeleting(false);
      await refresh();
    }
  };

  const panel = (
    <PanelContent
      query={query}
      onQueryChanged={setQuery}
      sessions={filtered}
      isLoading={isLoading}
      isDeleting={isDeleting}
      grouped={grouped}
      activeId={activeSessionId}
      onNewStudy={onNewStudy}
      onClose={onClose}
      onSelect={onSelect}
      onDelete={(s) => void handleDelete(s)}
      onRefresh={() => void refresh()}
      desktop={desktop}
    />
  );

  if (desktop) return panel;
  if (!isOpen) return null;

  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 50 }}>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)' }} />
      <div style={{ position: 'absolute', top: 0, bottom: 0, left: 0 }}>{panel}</div>
    </div>
  );
}

function PanelContent({
  query,
  onQueryChanged,
  sessions,
  isLoading,
  isDeleting,
  grouped,
  activeId,
  onNewStudy,
  onClose,
  onSelect,
  onDelete,
  onRefresh,
  desktop,
}: {
  query: string;
  onQueryChanged: (q: string) => void;
  sessions: StudySession[];
  isLoading: boolean;
  isDeleting: boolean;
  grouped: Map<string, StudySession[]>;
  activeId: string | null;
  onNewStudy: () => void;
  onClose: () => void;
  onSelect: (s: StudySession) => void;
  onDelete: (s: StudySession) => void;
  onRefresh: () => void;
  desktop: boolean;
}) {
  const [searchFocused, setSearchFocused] = useState(false);

  return (
    <div
      style={{
        width: desktop ? 320 : 300,
        height: '100%',
        background: AppColors.twilight,
        borderRight: `1px solid ${withAlpha(AppColors.blushGold, 0.1)}`,
        borderLeft: desktop ? `1px solid ${withAlpha(AppColors.blushGold, 0.06)}` : undefined,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* Header */}
      <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center' }}>
        <div
          style={{
            width: 28,
            height: 28,
            borderRadius: '50%',
            background: withAlpha(AppColors.softLavender, 0.14),
            border: `1px solid ${withAlpha(AppColors.softLavender, 0.35)}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <Icon name="school" size={15} color={AppColors.softLavender} />
        </div>
        <div style={{ width: 10 }} />
        <div style={{ ...AppTypography.titleMedium, fontSize: 16, lineHeight: lineHeight(16) }}>Study history</div>
        <div style={{ flex: 1 }} />
        <button
          type="button"
          className="bare-button"
          aria-label="Close"
          onClick={onClose}
          style={{ padding: 6, borderRadius: AppRadius.sm, display: 'flex' }}
        >
          <Icon name="close" size={18} color={Derived.textMuted} />
        </button>
      </div>

      <div style={{ height: 1, background: withAlpha(AppColors.blushGold, 0.06) }} />

      {/* Search */}
      <div style={{ padding: '10px 12px' }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            background: Derived.surfaceGlass,
            borderRadius: AppRadius.lg,
            border: `1px solid ${searchFocused ? withAlpha(AppColors.blushGold, 0.35) : Derived.border}`,
            padding: '0 8px 0 10px',
          }}
        >
          <Icon name="search" size={18} color={Derived.textMuted} />
          <input
            value={query}
            onChange={(e) => onQueryChanged(e.target.value)}
            onFocus={() => setSearchFocused(true)}
            onBlur={() => setSearchFocused(false)}
            placeholder="Search studies"
            style={{
              flex: 1,
              minWidth: 0,
              background: 'transparent',
              border: 'none',
              outline: 'none',
              padding: '10px 8px',
              ...AppTypography.bodySmall,
              color: Derived.textMedium,
            }}
          />
          {query && (
            <button
              type="button"
              className="bare-button"
              aria-label="Clear search"
              onClick={() => onQueryChanged('')}
              style={{ padding: 4, display: 'flex' }}
            >
              <Icon name="close" size={16} color={Derived.textMuted} />
            </button>
          )}
        </div>
      </div>

      {/* New study button */}
      <div style={{ padding: '2px 12px 8px' }}>
        <button
          type="button"
          className="bare-button"
          onClick={onNewStudy}
          style={{
            width: '100%',
            padding: '11px 14px',
            borderRadius: AppRadius.lg,
            background: linear([AppColors.blushGold, AppColors.deepRose], {
              begin: Align.topLeft,
              end: Align.bottomRight,
            }),
            transition: `all ${orZero(160)}ms ease`,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
          }}
        >
          <Icon name="add" size={18} color={AppColors.petalWhite} />
          <span style={{ ...AppTypography.bodySmall, color: AppColors.petalWhite, fontWeight: 600 }}>New study</span>
          <span style={{ flex: 1 }} />
          <Icon name="edit" size={16} color={withAlpha(AppColors.petalWhite, 0.9)} />
        </button>
      </div>

      {/* History header */}
      <div style={{ padding: '0 12px', display: 'flex', alignItems: 'center' }}>
        <span
          style={{
            ...AppTypography.bodySmall,
            color: withAlpha(AppColors.roseQuartz, 0.76 * 0.7),
            fontWeight: 600,
            ...letterSpacing(0.6),
          }}
        >
          History
        </span>
        <div style={{ flex: 1 }} />
        <button
          type="button"
          className="bare-button"
          aria-label="Refresh"
          onClick={onRefresh}
          style={{ width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >
          <Icon name="refresh" size={18} color={Derived.textMuted} />
        </button>
      </div>

      {/* Session list */}
      <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
        {isLoading ? (
          <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CircularProgress size={24} strokeWidth={2} color={withAlpha(AppColors.blushGold, 0.65)} />
          </div>
        ) : sessions.length === 0 ? (
          <div
            style={{
              height: '100%',
              padding: AppSpacing.lg + 8,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              textAlign: 'center',
            }}
          >
            <Icon name="menu_book_outlined" size={28} color={Derived.textDisabled} />
            <div style={{ height: 10 }} />
            <div style={{ ...AppTypography.bodySmall, color: Derived.textMuted, lineHeight: 1.5, whiteSpace: 'pre-line' }}>
              {query ? `No matches for “${query}”.` : 'No study sessions yet.\nAsk Motchi about a PDF to start one.'}
            </div>
          </div>
        ) : (
          <div style={{ padding: '8px 12px' }}>
            {[...grouped.entries()].map(([label, list]) => (
              <div key={label} style={{ marginBottom: 8 }}>
                <div
                  style={{
                    padding: '6px 8px',
                    ...AppTypography.bodySmall,
                    color: withAlpha(AppColors.roseQuartz, 0.76 * 0.6),
                    fontSize: 11,
                    fontWeight: 600,
                    ...letterSpacing(0.5),
                  }}
                >
                  {label}
                </div>
                {list.map((s) => (
                  <SessionItem
                    key={s.id}
                    session={s}
                    isActive={s.id === activeId}
                    deleting={isDeleting}
                    onTap={() => onSelect(s)}
                    onDelete={() => onDelete(s)}
                  />
                ))}
              </div>
            ))}
          </div>
        )}
      </div>

      {desktop && (
        <div
          style={{
            padding: '8px 12px 12px',
            ...AppTypography.bodySmall,
            color: Derived.textDisabled,
            fontSize: 10,
            lineHeight: 1.4,
          }}
        >
          Study sessions are shared — you both see the same shelf history.
        </div>
      )}
    </div>
  );
}

function SessionItem({
  session,
  isActive,
  deleting,
  onTap,
  onDelete,
}: {
  session: StudySession;
  isActive: boolean;
  deleting: boolean;
  onTap: () => void;
  onDelete: () => void;
}) {
  const now = new Date();
  const d = session.updatedAt;
  const isToday = now.getDate() === d.getDate() && now.getMonth() === d.getMonth() && now.getFullYear() === d.getFullYear();
  const dateStr = isToday
    ? d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const sourcesPreview =
    session.sourceNames.length === 0
      ? 'No sources'
      : session.sourceNames.length === 1
        ? session.sourceNames[0]
        : `${session.sourceNames[0]} +${session.sourceNames.length - 1}`;

  return (
    <div
      onClick={onTap}
      style={{
        marginBottom: 2,
        padding: '9px 10px',
        borderRadius: AppRadius.lg,
        background: isActive ? withAlpha(AppColors.blushGold, 0.12) : 'transparent',
        border: `1px solid ${isActive ? withAlpha(AppColors.blushGold, 0.3) : 'transparent'}`,
        display: 'flex',
        alignItems: 'center',
        gap: 6,
        cursor: 'pointer',
      }}
    >
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          className="ellipsis"
          style={{
            ...AppTypography.bodySmall,
            color: isActive ? Derived.textHigh : Derived.textMedium,
            fontWeight: isActive ? 600 : 400,
          }}
        >
          {session.title}
        </div>
        <div
          className="ellipsis"
          style={{
            marginTop: 2,
            ...AppTypography.bodySmall,
            color: withAlpha(AppColors.softLavender, 0.85),
            fontSize: 10,
          }}
        >
          {sourcesPreview}
        </div>
        <div
          className="ellipsis"
          style={{
            marginTop: 2,
            ...AppTypography.bodySmall,
            color: Derived.textDisabled,
            fontSize: 10,
          }}
        >
          {dateStr} · {session.messageCount} messages
        </div>
      </div>
      <button
        type="button"
        className="bare-button"
        disabled={deleting}
        aria-label="Delete study session"
        onClick={(e) => {
          e.stopPropagation();
          onDelete();
        }}
        style={{ padding: 6, borderRadius: AppRadius.sm, display: 'flex', opacity: deleting ? 0.4 : 1 }}
      >
        <Icon name="delete_outline" size={16} color={Derived.textDisabled} />
      </button>
    </div>
  );
}
