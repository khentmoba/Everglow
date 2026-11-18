// Port of lib/features/dashboard/presentation/screens/letterbox_archive_screen.dart.
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { orZero } from '../../core/theme/motion';
import { boxShadow, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { AlertDialog, showDialog, TextButton } from '../../shared/widgets/Dialogs';
import { EverglowBackground, type RadialGlow } from '../../shared/widgets/EverglowBackground';
import { EverglowEmptyState, EverglowErrorState, EverglowSkeleton } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { isNoteUnlocked, letterboxService, type HiddenNote } from './letterboxService';
import { showNoteDialog } from './NoteDialog';

type LetterFilter = 'all' | 'locked' | 'unread' | 'read';

const FILTERS: { id: LetterFilter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'locked', label: 'Locked' },
  { id: 'unread', label: 'Unread' },
  { id: 'read', label: 'Read' },
];

const LETTERBOX_GLOWS: RadialGlow[] = [
  { color: AppColors.auroraGold, alignment: [-0.7, -0.9], size: 0.9, opacity: 0.1 },
  { color: AppColors.softLavender, alignment: [0.9, 0.8], size: 0.7, opacity: 0.1 },
];

const MAX_RETRIES = 3;

const matchesFilter = (n: HiddenNote, filter: LetterFilter) => {
  const unlocked = isNoteUnlocked(n);
  if (filter === 'locked') return !unlocked;
  if (filter === 'unread') return unlocked && !n.isRead;
  if (filter === 'read') return n.isRead;
  return true;
};

const dmy = (d: Date) => `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`;

export function LetterboxArchivePage() {
  const navigate = useNavigate();
  const [filter, setFilter] = useState<LetterFilter>('all');
  const [allNotes, setAllNotes] = useState<HiddenNote[]>(() => letterboxService.cachedNotes);
  const [isLoading, setIsLoading] = useState(() => letterboxService.cachedNotes.length === 0);
  const [hasError, setHasError] = useState(false);
  const [subscription, setSubscription] = useState(0);
  const [searchNotes, setSearchNotes] = useState<HiddenNote[] | null>(null);
  const retries = useRef(0);

  useEffect(() => {
    let timer = 0;
    const unsub = letterboxService.notesAll()({
      data: (list) => {
        retries.current = 0;
        setAllNotes(list);
        setIsLoading(false);
        setHasError(false);
      },
      // `_scheduleSilentRetry`: resubscribe after 2s, 3s, 4s, then show the error.
      error: () => {
        if (retries.current < MAX_RETRIES) {
          retries.current++;
          timer = window.setTimeout(() => setSubscription((s) => s + 1), (1 + retries.current) * 1000);
        } else {
          setIsLoading(false);
          setHasError(true);
        }
      },
    });
    return () => {
      window.clearTimeout(timer);
      unsub();
    };
  }, [subscription]);

  const retry = () => {
    setHasError(false);
    setIsLoading(true);
    retries.current = 0;
    setSubscription((s) => s + 1);
  };

  const openNote = (note: HiddenNote) => {
    if (!isNoteUnlocked(note)) {
      void showLockedAlert(note);
      return;
    }
    if (!note.isRead) void letterboxService.markAsRead(note.id);
    void showNoteDialog(note);
  };

  const notes = allNotes.filter((n) => matchesFilter(n, filter));

  let list: ReactNode;
  if (isLoading && allNotes.length === 0) {
    list = (
      <div className="no-scrollbar" style={{ flex: 1, overflowY: 'auto', padding: 16 }}>
        {[0, 1, 2, 3, 4].map((i) => (
          <div key={i} style={{ paddingBottom: 12 }}>
            <EverglowSkeleton height={80} radius={16} />
          </div>
        ))}
      </div>
    );
  } else if (hasError && allNotes.length === 0) {
    list = <EverglowErrorState message="Could not load letters" onRetry={retry} icon="cloud_off" />;
  } else if (notes.length === 0) {
    list = (
      <EverglowEmptyState
        icon="mail_outline"
        title={filter === 'all' ? 'No letters yet' : `No ${filter} letters`}
        subtitle="Check back later! 🌸"
      />
    );
  } else {
    list = (
      <div className="no-scrollbar" style={{ flex: 1, overflowY: 'auto', padding: '8px 16px' }}>
        {notes.map((n) => (
          <LetterListTile key={n.id} note={n} onTap={() => openNote(n)} />
        ))}
      </div>
    );
  }

  return (
    <div style={{ position: 'fixed', inset: 0, display: 'flex', flexDirection: 'column', background: AppColors.inkDeep }}>
      <EverglowFeatureHeader
        title="Letter Archive"
        subtitle="every letter, kept"
        icon="mail_outline"
        hue={AppColors.blushGold}
        onBack={() => navigate('/dashboard')}
        actions={[
          <button
            key="search"
            type="button"
            className="bare-button"
            aria-label="Search letters"
            onClick={() => setSearchNotes(allNotes.filter((n) => matchesFilter(n, filter)))}
            style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
          >
            <Icon name="search" color={AppColors.blushGold} />
          </button>
        ]}
      />
      <div style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
          <EverglowBackground baseColor={AppColors.inkDeep} glows={LETTERBOX_GLOWS} />
        </div>
        {/* A horizontal SingleChildScrollView in a Column: as wide as its chips (each with 8px after it), centred. */}
        <div className="no-scrollbar" style={{ position: 'relative', padding: '8px 16px', overflowX: 'auto', flexShrink: 0 }}>
          <div style={{ display: 'flex', width: 'max-content', margin: '0 auto' }}>
            {FILTERS.map((f) => (
              <div key={f.id} style={{ paddingRight: 8 }}>
                <FilterChip label={f.label} selected={filter === f.id} onTap={() => setFilter(f.id)} />
              </div>
            ))}
          </div>
        </div>
        <div style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>{list}</div>
      </div>
      {searchNotes && (
        <SearchLettersPage
          notes={searchNotes}
          onBack={() => setSearchNotes(null)}
          onNoteTap={(n) => {
            setSearchNotes(null);
            openNote(n);
          }}
        />
      )}
    </div>
  );
}

/** `AppBar` with a transparent background: 56px leading slot, title 16px after it, actions flush right. */
function LetterAppBar({
  title,
  titleSize,
  onBack,
  action,
}: {
  title: string;
  titleSize?: number;
  onBack: () => void;
  action?: ReactNode;
}) {
  return (
    <header style={{ height: 56, display: 'flex', alignItems: 'center', flexShrink: 0 }}>
      <div style={{ width: 56, height: 56, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <button
          type="button"
          className="bare-button"
          aria-label="Back"
          onClick={onBack}
          style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >
          <Icon name="arrow_back_ios_new" color={AppColors.roseQuartz} />
        </button>
      </div>
      <h1
        style={{
          margin: 0,
          paddingLeft: 16,
          flex: 1,
          minWidth: 0,
          ...AppTypography.cormorantBold,
          fontSize: titleSize ?? 22,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {title}
      </h1>
      {action}
    </header>
  );
}

/**
 * M3 `FilterChip` in the app's stadium shape: 32px tall (the 1px side is stroked on
 * the edge, so it reads 33), 16px label padding, an 18px checkmark slot when selected.
 */
function FilterChip({ label, selected, onTap }: { label: string; selected: boolean; onTap: () => void }) {
  return (
    <div style={{ height: 48, display: 'flex', alignItems: 'center' }}>
      <button
        type="button"
        className="bare-button"
        aria-pressed={selected}
        onClick={onTap}
        style={{
          height: 33,
          boxSizing: 'border-box',
          padding: selected ? '0 16px 0 8px' : '0 16px',
          borderRadius: 999,
          background: selected ? withAlpha(AppColors.deepRose, 0.4) : withAlpha(AppColors.velvet, 0.5),
          border: `1px solid ${selected ? withAlpha(AppColors.blushGold, 0.5) : withAlpha(AppColors.moonlight, 0.15)}`,
          display: 'flex',
          alignItems: 'center',
          whiteSpace: 'nowrap',
          cursor: 'pointer',
        }}
      >
        {selected && (
          <span style={{ width: 18, display: 'flex', justifyContent: 'center', marginRight: 6 }}>
            <Icon name="check" size={14} color={AppColors.petalWhite} />
          </span>
        )}
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 12,
            lineHeight: lineHeight(12),
            fontWeight: selected ? 700 : 500,
            color: selected ? AppColors.petalWhite : AppColors.roseQuartz,
          }}
        >
          {label}
        </span>
      </button>
    </div>
  );
}

function showLockedAlert(note: HiddenNote) {
  const diff = note.unlockDate.getTime() - Date.now();
  const days = Math.trunc(diff / 86_400_000);
  const hours = Math.trunc(diff / 3_600_000);
  const countdown =
    days > 0 ? `${days} day${days === 1 ? '' : 's'}` : hours > 0 ? `${hours} hour${hours === 1 ? '' : 's'}` : 'soon';
  return showDialog<void>((close) => (
    <AlertDialog
      background={AppColors.velvet}
      radius={24}
      title={<div style={{ ...AppTypography.cormorantBold, fontSize: 22, textAlign: 'center' }}>Still sealed 🤫</div>}
      content={
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <Icon name="lock_outline" variant="filled" size={48} color={withAlpha(AppColors.blushGold, 0.7)} />
          <div style={{ height: 16 }} />
          <div
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 14,
              lineHeight: lineHeight(14),
              color: withAlpha(AppColors.petalWhite, 0.8),
              textAlign: 'center',
            }}
          >
            This letter will unlock in {countdown}.
          </div>
        </div>
      }
      actions={[
        <TextButton key="ok" onPressed={() => close(null)}>
          <span style={{ ...AppTypography.outfitWhite, fontSize: 14, fontWeight: 700, color: AppColors.blushGold }}>
            I&apos;ll wait 🌸
          </span>
        </TextButton>,
      ]}
    />
  ));
}

/** `_LetterArchiveSearchDelegate`: a pushed page listing the letters that pass the current filter. */
function SearchLettersPage({
  notes,
  onBack,
  onNoteTap,
}: {
  notes: HiddenNote[];
  onBack: () => void;
  onNoteTap: (n: HiddenNote) => void;
}) {
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const raf = requestAnimationFrame(() => setShown(true));
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onBack();
    window.addEventListener('keydown', onKey);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('keydown', onKey);
    };
  }, [onBack]);
  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 700,
        background: AppColors.inkDeep,
        display: 'flex',
        flexDirection: 'column',
        opacity: shown ? 1 : 0,
        transform: `scale(${shown ? 1 : 0.85})`,
        transition: `opacity ${orZero(300)}ms cubic-bezier(0.4, 0, 0.2, 1), transform ${orZero(300)}ms cubic-bezier(0.4, 0, 0.2, 1)`,
      }}
    >
      <LetterAppBar title="Search Letters" onBack={onBack} />
      {notes.length === 0 ? (
        <EverglowEmptyState icon="search_off" title="No letters found" />
      ) : (
        <div className="no-scrollbar" style={{ flex: 1, overflowY: 'auto', padding: 16 }}>
          {notes.map((n) => (
            <LetterListTile key={n.id} note={n} onTap={() => onNoteTap(n)} />
          ))}
        </div>
      )}
    </div>
  );
}

/** An envelope: a folded flap across the top, a wax seal that shows the letter's state, and the title in serif. */
function LetterListTile({ note, onTap }: { note: HiddenNote; onTap: () => void }) {
  const unlocked = isNoteUnlocked(note);
  const isNew = unlocked && !note.isRead;
  const tint = unlocked ? (isNew ? AppColors.deepRose : AppColors.roseQuartz) : AppColors.blushGold;
  const sealLabel = unlocked ? (isNew ? 'New letter' : 'Read letter') : 'Sealed letter';
  return (
    <div style={{ paddingBottom: 14 }}>
      <button
        type="button"
        className="bare-button"
        onClick={onTap}
        style={{
          position: 'relative',
          width: '100%',
          textAlign: 'left',
          padding: '30px 18px 16px 76px',
          minHeight: 104,
          boxSizing: 'border-box',
          overflow: 'hidden',
          background: `linear-gradient(160deg, ${withAlpha(tint, isNew ? 0.24 : 0.12)}, ${withAlpha(AppColors.velvet, 0.75)} 70%)`,
          borderRadius: 18,
          border: `1px solid ${withAlpha(tint, isNew ? 0.5 : 0.22)}`,
          boxShadow: boxShadow([{ blur: 18, offset: [0, 8], color: withAlpha(AppColors.inkDeep, 0.45) }]),
          display: 'flex',
          alignItems: 'center',
          cursor: 'pointer',
        }}
      >
        <svg
          aria-hidden
          viewBox="0 0 100 20"
          preserveAspectRatio="none"
          style={{ position: 'absolute', left: 0, top: 0, width: '100%', height: 26 }}
        >
          <path d="M0 0 L50 18 L100 0" fill={withAlpha(tint, 0.1)} stroke={withAlpha(tint, 0.35)} strokeWidth={0.6} vectorEffect="non-scaling-stroke" />
        </svg>
        <div
          aria-label={sealLabel}
          role="img"
          style={{
            position: 'absolute',
            left: 16,
            top: '50%',
            marginTop: -2,
            transform: 'translateY(-50%)',
            width: 46,
            height: 46,
            borderRadius: '50%',
            background: `radial-gradient(circle at 35% 30%, ${withAlpha(AppColors.petalWhite, 0.35)}, ${tint} 55%, ${withAlpha(tint, 0.7)})`,
            boxShadow: boxShadow([{ blur: isNew ? 14 : 6, color: withAlpha(tint, isNew ? 0.6 : 0.3) }]),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon
            name={unlocked ? (note.isRead ? 'drafts_outlined' : 'favorite') : 'lock_outline'}
            variant="filled"
            size={20}
            color={AppColors.inkDeep}
          />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              ...AppTypography.cormorantBold,
              fontSize: 19,
              lineHeight: lineHeight(19),
              color: AppColors.petalWhite,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {note.title}
          </div>
          <div style={{ height: 2 }} />
          <div
            className="clamp-2"
            style={{
              ...AppTypography.handwrittenBody,
              fontSize: 17,
              lineHeight: 1.15,
              color: withAlpha(unlocked ? AppColors.roseQuartz : AppColors.blushGold, 0.75),
            }}
          >
            {unlocked
              ? note.content.length > 60
                ? `${note.content.slice(0, 60)}...`
                : note.content
              : `Sealed until ${dmy(note.unlockDate)}`}
          </div>
        </div>
        {!unlocked && (
          <>
            <div style={{ width: 8, flexShrink: 0 }} />
            <CountdownBadge unlockDate={note.unlockDate} />
          </>
        )}
        {isNew && (
          <span
            style={{
              position: 'absolute',
              top: 8,
              right: 12,
              ...AppTypography.outfitWhite,
              fontSize: 10,
              lineHeight: lineHeight(10),
              fontWeight: 700,
              letterSpacing: 1.2,
              color: AppColors.blushGold,
            }}
          >
            NEW
          </span>
        )}
      </button>
    </div>
  );
}

function CountdownBadge({ unlockDate }: { unlockDate: Date }) {
  const diff = unlockDate.getTime() - Date.now();
  const days = Math.trunc(diff / 86_400_000);
  const hours = Math.trunc(diff / 3_600_000);
  const text = days > 0 ? `${days}d` : hours > 0 ? `${hours}h` : 'Soon';
  return (
    <div
      style={{
        padding: '4px 10px',
        background: withAlpha(AppColors.blushGold, 0.15),
        borderRadius: 12,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
        display: 'flex',
        alignItems: 'center',
        flexShrink: 0,
      }}
    >
      <Icon name="lock_clock" size={12} color={AppColors.blushGold} />
      <div style={{ width: 4 }} />
      <span
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 11,
          lineHeight: lineHeight(11),
          fontWeight: 700,
          color: AppColors.blushGold,
        }}
      >
        {text}
      </span>
    </div>
  );
}
