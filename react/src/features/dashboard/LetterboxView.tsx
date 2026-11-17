// Port of lib/features/dashboard/presentation/widgets/letterbox_view.dart + note_card.dart.
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { Align, letterSpacing, lineHeight, linear, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { AlertDialog, showDialog, TextButton } from '../../shared/widgets/Dialogs';
import { gardenStore } from '../daily_bloom/gardenService';
import { showNoteDialog } from './NoteDialog';
import { FeatureSection, SectionPillLink } from './FeatureSection';
import { isNoteUnlocked, letterboxService, type HiddenNote } from './letterboxService';

export function LetterboxView() {
  const navigate = useNavigate();
  const [notes, setNotes] = useState<HiddenNote[]>(() => letterboxService.cachedNotes.slice(0, 10));
  const [loading, setLoading] = useState(() => letterboxService.cachedNotes.length === 0);
  const [hasError, setHasError] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const unsub = letterboxService.notesPreview(10)({
      data: (list) => {
        if (cancelled) return;
        setNotes(list);
        setLoading(false);
        setHasError(false);
      },
      error: () => {
        if (cancelled) return;
        setLoading(false);
        setHasError(true);
      },
    });
    return () => {
      cancelled = true;
      unsub();
    };
  }, []);

  const sealed = notes.filter((n) => !isNoteUnlocked(n)).length;
  const unread = notes.filter((n) => isNoteUnlocked(n) && !n.isRead).length;
  const subtitle =
    loading && notes.length === 0
      ? 'fetching letters…'
      : notes.length === 0
        ? 'no letters yet'
        : sealed > 0 && unread > 0
          ? `${sealed} sealed · ${unread} waiting to be read`
          : sealed > 0
            ? `${sealed} sealed ${sealed === 1 ? 'letter' : 'letters'}`
            : unread > 0
              ? `${unread} waiting to be read`
              : `${notes.length} ${notes.length === 1 ? 'letter' : 'letters'} · all read ♥`;

  const handleTap = (note: HiddenNote) => {
    if (!isNoteUnlocked(note)) {
      void showLockedAlert(note);
      return;
    }
    if (!note.isRead) {
      void letterboxService.markAsRead(note.id);
      void gardenStore.recordInteraction();
    }
    void showNoteDialog(note);
  };

  return (
    <div style={{ padding: '6px 16px' }}>
      <FeatureSection
        icon="mail_outline"
        hue={AppColors.blushGold}
        title="Letterbox"
        subtitle={subtitle}
        trailing={
          <div style={{ display: 'inline-flex', alignItems: 'center' }}>
            <SectionPillLink label="View all" onTap={() => navigate('/letterbox')} />
            <Tooltip message="View all letters">
              <button
                type="button"
                className="bare-button"
                aria-label="Letters"
                onClick={(e) => {
                  e.stopPropagation();
                  navigate('/letterbox');
                }}
                style={{ width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
              >
                <Icon name="refresh" size={15} color={withAlpha(AppColors.blushGold, 0.4)} />
              </button>
            </Tooltip>
          </div>
        }
      >
        <div style={{ height: 188 }}>
          {loading && notes.length === 0 ? (
            <div style={{ display: 'flex', gap: 12 }}>
              {[0, 1, 2].map((i) => (
                <div key={i} style={{ width: 156, height: 188, borderRadius: 22, background: AppColors.shimmerBase }} />
              ))}
            </div>
          ) : hasError && notes.length === 0 ? (
            <div
              style={{
                height: 188,
                borderRadius: 20,
                background: withAlpha(AppColors.velvet, 0.35),
                border: `1px solid ${Derived.border}`,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <span style={{ ...AppTypography.outfitWhite, fontSize: 12 }}>Could not load letters</span>
            </div>
          ) : (
            <div className="no-scrollbar" style={{ overflowX: 'auto', height: 188 }}>
              <div style={{ display: 'flex', width: 'max-content' }}>
                {notes.map((n) => (
                  <NoteCard key={n.id} note={n} onTap={() => handleTap(n)} />
                ))}
              </div>
            </div>
          )}
        </div>
      </FeatureSection>
    </div>
  );
}

function showLockedAlert(note: HiddenNote) {
  const d = note.unlockDate;
  return showDialog<void>((close) => (
    <AlertDialog
      background={AppColors.velvet}
      radius={24}
      title={<div style={{ ...AppTypography.cormorantBold, fontSize: 24, textAlign: 'center' }}>No peeking! 🤫</div>}
      content={
        <div
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 14,
            lineHeight: lineHeight(14),
            color: withAlpha(AppColors.petalWhite, 0.8),
            textAlign: 'center',
          }}
        >
          This letter is still sealed. It will unlock on {d.getDate()}/{d.getMonth() + 1}/{d.getFullYear()}.
        </div>
      }
      actions={[
        <TextButton key="ok" onPressed={() => close(null)}>
          <span style={{ ...AppTypography.outfitWhite, fontSize: 14, fontWeight: 700, color: AppColors.blushGold }}>
            Okay, I&apos;ll wait! 🌸
          </span>
        </TextButton>,
      ]}
    />
  ));
}

function NoteCard({ note, onTap }: { note: HiddenNote; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  const unlocked = isNoteUnlocked(note);
  const isNew = unlocked && !note.isRead;
  const hue = !unlocked ? AppColors.blushGold : isNew ? AppColors.auroraRose : AppColors.softLavender;
  const icon = !unlocked ? 'lock_outline' : isNew ? 'favorite' : 'drafts';

  const diffMs = Math.max(0, note.unlockDate.getTime() - Date.now());
  const days = Math.floor(diffMs / 86_400_000);
  const hours = Math.floor(diffMs / 3_600_000);
  const pillLabel = !unlocked
    ? days > 0
      ? `opens in ${days}d`
      : hours > 0
        ? `opens in ${hours}h`
        : 'opens soon'
    : isNew
      ? 'tap to read'
      : 'read';
  const pillIcon = !unlocked ? 'hourglass_bottom' : isNew ? 'touch_app' : 'check';

  return (
    <div style={{ paddingRight: 12 }}>
      <button
        type="button"
        className="bare-button"
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        onClick={onTap}
        style={{
          position: 'relative',
          width: 156,
          height: 188,
          borderRadius: 22,
          overflow: 'hidden',
          background: linear(
            [withAlpha(hue, isNew ? 0.22 : 0.14), withAlpha(AppColors.velvet, 0.92), withAlpha(AppColors.inkDeep, 0.96)],
            { begin: Align.topLeft, end: Align.bottomRight, stops: [0, 0.55, 1], size: [156, 188] },
          ),
          border: `${isNew ? 1.4 : 1}px solid ${withAlpha(hue, hovered ? 0.6 : isNew ? 0.45 : 0.24)}`,
          transform: hovered ? 'translateY(-4px) scale(1.02)' : undefined,
          transition: 'transform 160ms cubic-bezier(0.23, 1, 0.32, 1)',
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 24,
            right: 24,
            height: 1,
            background: linear([AppColors.transparent, withAlpha(hue, 0.55), AppColors.transparent]),
          }}
        />
        <div style={{ position: 'absolute', right: -12, bottom: -12, pointerEvents: 'none' }} aria-hidden>
          <Icon name="mail_outline" size={88} color={withAlpha(AppColors.petalWhite, 0.05)} />
        </div>
        {isNew && (
          <div
            style={{
              position: 'absolute',
              top: 10,
              left: 10,
              padding: '3px 8px',
              borderRadius: 999,
              background: linear([AppColors.auroraRose, AppColors.deepRose]),
            }}
          >
            <span style={{ ...AppTypography.outfitHeading, fontSize: 8, ...letterSpacing(1.2), color: AppColors.petalWhite }}>
              NEW
            </span>
          </div>
        )}
        <div
          style={{
            position: 'relative',
            height: '100%',
            padding: '14px 12px 12px',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <div style={{ position: 'relative', width: 54, height: 54 }}>
            <div
              style={shadowLayer({ color: withAlpha(hue, isNew ? 0.35 : 0.18), blur: isNew ? 18 : 12 }, { circle: true })}
              aria-hidden
            />
            <div
              style={{
                position: 'relative',
                width: 54,
                height: 54,
                borderRadius: '50%',
                background: linear([withAlpha(hue, isNew ? 0.4 : 0.28), withAlpha(hue, 0.08)], {
                  begin: Align.topLeft,
                  end: Align.bottomRight,
                  size: [54, 54],
                }),
                border: `1.2px solid ${withAlpha(hue, 0.5)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name={icon} variant="outlined" size={24} color={hue} />
            </div>
          </div>
          <div style={{ height: 10 }} />
          <span
            className="clamp-2"
            style={{
              ...AppTypography.cormorantBold,
              fontSize: 16,
              lineHeight: 1.15,
              color: AppColors.petalWhite,
              textAlign: 'center',
            }}
          >
            {note.title}
          </span>
          <div style={{ height: 8 }} />
          <div
            style={{
              padding: '4px 10px',
              borderRadius: 999,
              background: withAlpha(hue, isNew ? 0.16 : 0.1),
              border: `1px solid ${withAlpha(hue, 0.3)}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
            }}
          >
            <Icon name={pillIcon} size={11} color={hue} />
            <span style={{ ...AppTypography.outfitBold, fontSize: 10.5, color: withAlpha(hue, 0.95) }}>{pillLabel}</span>
          </div>
        </div>
      </button>
    </div>
  );
}
