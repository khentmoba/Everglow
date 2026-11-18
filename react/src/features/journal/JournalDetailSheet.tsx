// Port of lib/features/journal/presentation/widgets/journal_detail_sheet.dart.
import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, M3Scheme, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { CssCurves, orZero } from '../../core/theme/motion';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { AlertDialog, showDialog, showModalBottomSheet, TextButton } from '../../shared/widgets/Dialogs';
import { ElevatedButton } from '../../shared/widgets/ElevatedButton';
import { EverglowIconButton } from '../../shared/widgets/EverglowScaffold';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { MemoryConnections } from './MemoryConnections';
import { categoryInfo, journalService, moodEmoji, type JournalEntry } from './journalService';
import {
  jm,
  journalAuthorHue,
  journalAuthorInitial,
  journalAuthorName,
  journalCategoryColor,
  journalReadingTime,
  yMMMd,
} from './journalUi';

export function showJournalDetailSheet(opts: {
  entry: JournalEntry;
  onEdit?: (close: () => void) => void;
  onToggleLock?: (id: string, locked: boolean) => Promise<void>;
}): Promise<void> {
  return showModalBottomSheet<void>((close) => (
    <JournalDetailSheet
      entry={opts.entry}
      close={() => close(null)}
      onEdit={opts.onEdit && (() => opts.onEdit!(() => close(null)))}
      onToggleLock={opts.onToggleLock}
    />
  )).then(() => undefined);
}

/** Optimistic flip: show it now, undo it if the write fails (core/utils/optimistic_action.dart). */
function optimistic(apply: () => void, action: () => Promise<void>, rollback: () => void, failText: string) {
  apply();
  action().catch(() => {
    rollback();
    showSnackBar(failText, { duration: 2000 });
  });
}

const chip: CSSProperties = { padding: '6px 10px', borderRadius: AppRadius.full, flexShrink: 0 };

function JournalDetailSheet({
  entry: initial,
  close,
  onEdit,
  onToggleLock,
}: {
  entry: JournalEntry;
  close: () => void;
  onEdit?: () => void;
  onToggleLock?: (id: string, locked: boolean) => Promise<void>;
}) {
  const { height } = useViewport();
  const [entry, setEntry] = useState(initial);
  const [revealed, setRevealed] = useState(false);
  const [extent, setExtent] = useState(0.78);
  const [dragging, setDragging] = useState(false);
  const drag = useRef<{ y: number; extent: number } | null>(null);
  useEffect(() => setEntry(initial), [initial]);

  const hue = journalCategoryColor(entry.category);
  const cat = categoryInfo(entry.category);
  const locked = entry.isLocked && !revealed;

  const togglePin = () => {
    const next = !entry.isPinned;
    optimistic(
      () => setEntry((e) => ({ ...e, isPinned: next })),
      () => journalService.togglePin(entry.id, next),
      () => setEntry((e) => ({ ...e, isPinned: !next })),
      'Failed to update pin. Reverted.',
    );
  };
  const toggleLock = () => {
    const next = !entry.isLocked;
    optimistic(
      () => setEntry((e) => ({ ...e, isLocked: next })),
      () => (onToggleLock ?? ((id, l) => journalService.toggleLock(id, l)))(entry.id, next),
      () => setEntry((e) => ({ ...e, isLocked: !next })),
      'Failed to update lock. Reverted.',
    );
  };
  const confirmDelete = async () => {
    const confirm = await showDialog<boolean>((pop) => (
      <AlertDialog
        background={AppColors.velvet}
        title={<span style={{ ...AppTypography.outfitBold, color: AppColors.petalWhite }}>Delete entry?</span>}
        content={
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 14,
              lineHeight: lineHeight(14),
              color: withAlpha(AppColors.petalWhite, 0.7),
            }}
          >
            This cannot be undone.
          </span>
        }
        actions={[
          <TextButton key="c" onPressed={() => pop(false)}>
            Cancel
          </TextButton>,
          <TextButton key="d" color={AppColors.error} onPressed={() => pop(true)}>
            Delete
          </TextButton>,
        ]}
      />
    ));
    if (confirm !== true) return;
    try {
      await journalService.delete(entry.id);
      close();
    } catch {
      showSnackBar('Could not delete this page. Please try again.');
    }
  };

  // DraggableScrollableSheet(0.78, min 0.5, max 0.92): drag the top to resize, below the minimum to close.
  const onPointerDown = (e: React.PointerEvent) => {
    drag.current = { y: e.clientY, extent };
    setDragging(true);
    (e.target as Element).setPointerCapture?.(e.pointerId);
  };
  const onPointerMove = (e: React.PointerEvent) => {
    if (!drag.current) return;
    setExtent(Math.min(0.92, Math.max(0.3, drag.current.extent - (e.clientY - drag.current.y) / (height - 48))));
  };
  const onPointerUp = () => {
    drag.current = null;
    setDragging(false);
    if (extent < 0.5) close();
  };

  return (
    <div style={{ maxWidth: 640, margin: '0 auto' }}>
      {/* The app theme sets showDragHandle, so BottomSheet puts its own 48px handle row above the sheet. */}
      <div style={{ height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ width: 32, height: 4, borderRadius: 2, background: withAlpha(M3Scheme.onSurfaceVariant, 0.4) }} />
      </div>
      <div
        style={{
          height: extent * (height - 48),
          transition: dragging ? undefined : `height ${orZero(200)}ms ${CssCurves.easeOutStrong}`,
          background: `linear-gradient(${AppColors.velvet}, ${AppColors.inkDeep})`,
          borderRadius: `${AppRadius.x2}px ${AppRadius.x2}px 0 0`,
          boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.blushGold, 0.22)}`,
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
        }}
      >
        <div
          className="no-scrollbar"
          onScroll={(e) => e.currentTarget.scrollTop > 0 && extent < 0.92 && !dragging && setExtent(0.92)}
          style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '13px 21px 32px' }}
        >
          <div
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={onPointerUp}
            style={{ margin: '-13px -21px 0', padding: '13px 21px 16px', touchAction: 'none', cursor: 'grab' }}
          >
            <div
              style={{
                width: 40,
                height: 4,
                margin: '0 auto',
                borderRadius: 2,
                background: withAlpha(AppColors.petalWhite, 0.3),
              }}
            />
          </div>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <div
              style={{
                ...chip,
                background: withAlpha(hue, 0.16),
                border: `1px solid ${withAlpha(hue, 0.35)}`,
                ...AppTypography.outfitWhite,
                fontSize: 11,
                lineHeight: lineHeight(11),
                fontWeight: 700,
                color: hue,
              }}
            >
              {cat.emoji} {cat.displayName}
            </div>
            {entry.mood != null && (
              <>
                <div style={{ width: 8 }} />
                <div
                  style={{
                    ...chip,
                    background: withAlpha(AppColors.moonlight, 0.08),
                    ...AppTypography.outfitWhite,
                    fontSize: 11,
                    lineHeight: lineHeight(11),
                    color: withAlpha(AppColors.petalWhite, 0.75),
                  }}
                >
                  {moodEmoji(entry.mood)} {entry.mood}
                </div>
              </>
            )}
            <div style={{ flex: 1 }} />
            {onEdit && (
              <EverglowIconButton
                icon="edit"
                onPressed={onEdit}
                semanticLabel="Edit entry"
                tooltip="Edit"
                iconColor={AppColors.blushGold}
              />
            )}
            <EverglowIconButton
              icon={entry.isPinned ? 'push_pin' : 'push_pin_outlined'}
              onPressed={togglePin}
              semanticLabel={entry.isPinned ? 'Unpin entry' : 'Pin entry'}
              tooltip={entry.isPinned ? 'Unpin' : 'Pin'}
              iconColor={AppColors.blushGold}
            />
          </div>
          <div style={{ height: 12 }} />
          <div style={{ ...AppTypography.cormorantBold, fontSize: 28, lineHeight: lineHeight(28) }}>
            {entry.title === '' ? 'Untitled' : entry.title}
          </div>
          <div style={{ height: 10 }} />
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <AuthorDot author={entry.author} size={26} />
            <div style={{ width: 8 }} />
            <div
              style={{
                flex: 1,
                ...AppTypography.outfitWhite,
                fontSize: 11,
                lineHeight: lineHeight(11),
                color: withAlpha(AppColors.petalWhite, 0.6),
              }}
            >
              {journalAuthorName(entry.author)} • {yMMMd(entry.createdAt)} {jm(entry.createdAt)} •{' '}
              {journalReadingTime(entry.wordCount)}
            </div>
          </div>
          {entry.tags.length > 0 && (
            <>
              <div style={{ height: 12 }} />
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {entry.tags.map((t, i) => (
                  <span
                    key={`${t}-${i}`}
                    style={{
                      ...chip,
                      background: withAlpha(AppColors.softLavender, 0.12),
                      ...AppTypography.outfitWhite,
                      fontSize: 11,
                      lineHeight: lineHeight(11),
                      color: AppColors.softLavender,
                    }}
                  >
                    #{t}
                  </span>
                ))}
              </div>
            </>
          )}
          <div style={{ height: 16 }} />
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <div style={{ flex: 1, height: 1, background: withAlpha(AppColors.blushGold, 0.18) }} />
            <div style={{ padding: '0 10px', display: 'flex' }}>
              <Icon name="favorite" size={14} color={AppColors.deepRose} />
            </div>
            <div style={{ flex: 1, height: 1, background: withAlpha(AppColors.blushGold, 0.18) }} />
          </div>
          <div style={{ height: 16 }} />
          {locked ? (
            <LockedBox onReveal={() => setRevealed(true)} />
          ) : (
            <div
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 15,
                lineHeight: '25px', // measured: Flutter lays this 15 x 1.7 line out at 25px
                color: Derived.textHigh,
                whiteSpace: 'pre-wrap',
                overflowWrap: 'anywhere',
                userSelect: 'text',
              }}
            >
              {entry.content === '' ? 'No content.' : entry.content}
            </div>
          )}
          {!locked && <MemoryConnections entry={entry} />}
          <div style={{ height: 24 }} />
          <div style={{ display: 'flex' }}>
            <OutlinedIconButton
              icon={entry.isLocked ? 'lock_open' : 'lock'}
              label={entry.isLocked ? 'Unlock' : 'Lock'}
              color={AppColors.warmAmber}
              onPressed={toggleLock}
            />
            <div style={{ width: 12 }} />
            <OutlinedIconButton
              icon="delete_outline"
              label="Delete"
              color={AppColors.error}
              onPressed={() => void confirmDelete()}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

/** Expanded OutlinedButton.icon with a coloured foreground and a 30% side. */
function OutlinedIconButton({
  icon,
  label,
  color,
  onPressed,
}: {
  icon: string;
  label: string;
  color: string;
  onPressed: () => void;
}) {
  const [hovered, setHovered] = useState(false);
  return (
    <div style={{ flex: 1, height: 48, display: 'flex', alignItems: 'center' }}>
      <button
        type="button"
        className="bare-button"
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          width: '100%',
          height: 40,
          padding: '0 24px 0 16px',
          borderRadius: 20,
          border: `1px solid ${withAlpha(color, 0.3)}`,
          background: hovered ? withAlpha(color, 0.08) : 'transparent',
          boxSizing: 'border-box',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 8,
          ...AppTypography.labelLarge,
          lineHeight: lineHeight(14),
          color,
        }}
      >
        <Icon name={icon} size={16} color={color} />
        {label}
      </button>
    </div>
  );
}

function LockedBox({ onReveal }: { onReveal: () => void }) {
  return (
    <div
      style={{
        padding: 25,
        background: withAlpha(AppColors.inkDeep, 0.5),
        borderRadius: AppRadius.lg,
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.warmAmber, 0.22)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          width: 56,
          height: 56,
          borderRadius: '50%',
          background: withAlpha(AppColors.warmAmber, 0.12),
          border: `1px solid ${withAlpha(AppColors.warmAmber, 0.3)}`,
          boxSizing: 'border-box',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="lock" size={24} color={AppColors.warmAmber} />
      </div>
      <div style={{ height: 12 }} />
      <div style={{ ...AppTypography.cormorantBold, fontSize: 20, lineHeight: lineHeight(20) }}>Sealed with a kiss</div>
      <div style={{ height: 6 }} />
      <div
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 12,
          lineHeight: lineHeight(12),
          color: withAlpha(AppColors.petalWhite, 0.6),
          textAlign: 'center',
          whiteSpace: 'pre-line',
        }}
      >
        {'A private page, just between us.\nTap reveal to open it.'}
      </div>
      <div style={{ height: 16 }} />
      <ElevatedButton
        stretch
        radius={AppRadius.sm}
        onPressed={onReveal}
        icon={<Icon name="visibility" size={18} color={AppColors.petalWhite} />}
      >
        <span style={{ ...AppTypography.labelLarge, lineHeight: lineHeight(14), color: AppColors.petalWhite }}>Reveal</span>
      </ElevatedButton>
    </div>
  );
}

export function AuthorDot({ author, size = 26 }: { author: string; size?: number }) {
  const hue = journalAuthorHue(author);
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: withAlpha(hue, 0.16),
        border: `1px solid ${withAlpha(hue, 0.45)}`,
        boxSizing: 'border-box',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
      }}
    >
      <span style={{ ...AppTypography.outfitBold, fontSize: size * 0.42, lineHeight: lineHeight(size * 0.42), color: hue }}>
        {journalAuthorInitial(author)}
      </span>
    </div>
  );
}
