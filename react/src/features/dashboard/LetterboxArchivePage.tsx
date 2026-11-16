// Port of lib/features/dashboard/presentation/screens/letterbox_archive_screen.dart.
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { Align, boxShadow, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground, type RadialGlow } from '../../shared/widgets/EverglowBackground';
import { Icon } from '../../shared/widgets/Icon';
import { isNoteUnlocked, letterboxService, type HiddenNote } from './letterboxService';

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

export function LetterboxArchivePage() {
  const navigate = useNavigate();
  const [filter, setFilter] = useState<LetterFilter>('all');
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [allNotes, setAllNotes] = useState<HiddenNote[]>(() => letterboxService.cachedNotes);
  const [isLoading, setIsLoading] = useState(() => letterboxService.cachedNotes.length === 0);
  const [hasError, setHasError] = useState(false);
  const [retrySeq, setRetrySeq] = useState(0);
  const [openNote, setOpenNote] = useState<HiddenNote | null>(null);
  const [lockedNote, setLockedNote] = useState<HiddenNote | null>(null);

  useEffect(() => {
    let cancelled = false;
    const unsub = letterboxService.notesAll()({
      data: (list) => {
        if (cancelled) return;
        setAllNotes(list);
        setIsLoading(false);
        setHasError(false);
      },
      error: () => {
        if (cancelled) return;
        setIsLoading(false);
        setHasError(true);
      },
    });
    return () => {
      cancelled = true;
      unsub();
    };
  }, [retrySeq]);

  const filterNotes = (notes: HiddenNote[]) => {
    let out = notes.filter((n) => {
      const unlocked = isNoteUnlocked(n);
      if (filter === 'locked') return !unlocked;
      if (filter === 'unread') return unlocked && !n.isRead;
      if (filter === 'read') return n.isRead;
      return true;
    });
    const q = searchQuery.trim().toLowerCase();
    if (q) {
      out = out.filter((n) => n.title.toLowerCase().includes(q) || n.content.toLowerCase().includes(q));
    }
    return out;
  };

  const handleOpen = (note: HiddenNote) => {
    if (!isNoteUnlocked(note)) {
      setLockedNote(note);
      return;
    }
    if (!note.isRead) {
      setAllNotes((prev) => prev.map((n) => (n.id === note.id ? { ...n, isRead: true } : n)));
      void letterboxService.markAsRead(note.id);
    }
    setOpenNote(note);
  };

  const notes = filterNotes(allNotes);

  return (
    <div style={{ position: 'fixed', inset: 0, display: 'flex', flexDirection: 'column', background: AppColors.inkDeep }}>
      <EverglowBackground baseColor={AppColors.inkDeep} glows={LETTERBOX_GLOWS} />

      <header
        style={{
          position: 'relative',
          height: 56,
          padding: '0 8px',
          display: 'flex',
          alignItems: 'center',
          flexShrink: 0,
        }}
      >
        <button
          type="button"
          className="bare-button"
          aria-label="Back to dashboard"
          onClick={() => navigate('/dashboard')}
          style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >
          <Icon name="arrow_back_ios_new" size={20} color={AppColors.roseQuartz} />
        </button>
        <div style={{ width: 16 }} />
        <h1 style={{ margin: 0, ...AppTypography.cormorantBold, fontSize: 24, flex: 1 }}>Letter Archive</h1>
        <button
          type="button"
          className="bare-button"
          aria-label="Search letters"
          onClick={() => setSearchOpen((v) => !v)}
          style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >
          <Icon name={searchOpen ? 'close' : 'search'} size={22} color={AppColors.blushGold} />
        </button>
      </header>

      {searchOpen && (
        <div style={{ position: 'relative', padding: '0 16px 8px' }}>
          <input
            autoFocus
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search letters…"
            style={{
              width: '100%',
              padding: '10px 14px',
              borderRadius: 14,
              background: withAlpha(AppColors.velvet, 0.7),
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
              color: AppColors.petalWhite,
              outline: 'none',
              ...AppTypography.outfitMedium,
              fontSize: 13,
            }}
          />
        </div>
      )}

      <div
        className="no-scrollbar"
        style={{
          position: 'relative',
          padding: '14px 16px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 8,
          overflowX: 'auto',
          flexShrink: 0,
        }}
      >
        {FILTERS.map((f) => {
          const selected = filter === f.id;
          return (
            <button
              key={f.id}
              type="button"
              className="bare-button"
              onClick={() => setFilter(f.id)}
              style={{
                height: 34,
                padding: '0 14px',
                borderRadius: 999,
                background: selected ? withAlpha(AppColors.deepRose, 0.4) : withAlpha(AppColors.velvet, 0.5),
                border: `1px solid ${selected ? withAlpha(AppColors.blushGold, 0.5) : withAlpha(AppColors.moonlight, 0.15)}`,
                ...AppTypography.outfitWhite,
                fontSize: 12,
                fontWeight: selected ? 700 : 500,
                color: selected ? AppColors.petalWhite : AppColors.roseQuartz,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                whiteSpace: 'nowrap',
              }}
            >
              {selected && <Icon name="check" size={14} color={AppColors.petalWhite} />}
              <span>{f.label}</span>
            </button>
          );
        })}
      </div>

      <div className="no-scrollbar" style={{ position: 'relative', flex: 1, overflowY: 'auto', padding: '8px 16px 24px' }}>
        {isLoading && allNotes.length === 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, paddingTop: 8 }}>
            {[0, 1, 2, 3, 4].map((i) => (
              <div
                key={i}
                style={{
                  height: 80,
                  borderRadius: 16,
                  background: withAlpha(AppColors.moonlight, 0.08),
                }}
              />
            ))}
          </div>
        ) : hasError && allNotes.length === 0 ? (
          <div style={{ padding: 48, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
            <Icon name="cloud_off" size={44} color={AppColors.roseQuartz} />
            <span style={{ ...AppTypography.outfitMedium, color: Derived.textMedium }}>Could not load letters</span>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setHasError(false);
                setIsLoading(true);
                setRetrySeq((s) => s + 1);
              }}
              style={{
                padding: '8px 18px',
                borderRadius: 999,
                background: withAlpha(AppColors.deepRose, 0.25),
                border: `1px solid ${withAlpha(AppColors.blushGold, 0.4)}`,
                ...AppTypography.outfitBold,
                color: AppColors.blushGold,
              }}
            >
              Retry
            </button>
          </div>
        ) : notes.length === 0 ? (
          <div style={{ padding: 48, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
            <Icon name="mail_outline" size={44} color={withAlpha(AppColors.roseQuartz, 0.6)} />
            <span style={{ ...AppTypography.cormorantBold, fontSize: 22, color: AppColors.petalWhite }}>
              {filter === 'all' ? 'No letters yet' : `No ${filter} letters`}
            </span>
            <span style={{ ...AppTypography.outfitMedium, fontSize: 13, color: Derived.textMuted }}>
              Check back later! 🌸
            </span>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {notes.map((note) => {
              const unlocked = isNoteUnlocked(note);
              const isNew = unlocked && !note.isRead;
              const diffMs = note.unlockDate.getTime() - Date.now();
              const diffDays = Math.floor(diffMs / 86_400_000);
              const diffHours = Math.floor(diffMs / 3_600_000);
              const badgeText = diffDays > 0 ? `${diffDays}d` : diffHours > 0 ? `${diffHours}h` : 'Soon';

              return (
                <button
                  key={note.id}
                  type="button"
                  className="bare-button"
                  onClick={() => handleOpen(note)}
                  style={{
                    width: '100%',
                    textAlign: 'left',
                    padding: 16,
                    background: isNew ? withAlpha(AppColors.deepRose, 0.2) : withAlpha(AppColors.velvet, 0.4),
                    borderRadius: 16,
                    border: `1px solid ${isNew ? withAlpha(AppColors.blushGold, 0.4) : withAlpha(AppColors.moonlight, 0.1)}`,
                    display: 'flex',
                    alignItems: 'center',
                  }}
                >
                  <div
                    style={{
                      width: 44,
                      height: 44,
                      borderRadius: '50%',
                      background: unlocked
                        ? isNew
                          ? withAlpha(AppColors.deepRose, 0.3)
                          : AppColors.velvet
                        : withAlpha(AppColors.blushGold, 0.15),
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                    }}
                  >
                    <Icon
                      name={unlocked ? (note.isRead ? 'drafts' : 'favorite') : 'lock_outline'}
                      variant={unlocked && !note.isRead ? 'round' : 'outlined'}
                      size={20}
                      color={
                        unlocked
                          ? isNew
                            ? AppColors.deepRose
                            : AppColors.roseQuartz
                          : AppColors.blushGold
                      }
                    />
                  </div>
                  <div style={{ width: 14, flexShrink: 0 }} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div
                      style={{
                        ...AppTypography.outfitWhite,
                        fontSize: 14,
                        fontWeight: isNew ? 700 : 500,
                        color: AppColors.petalWhite,
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                    >
                      {note.title}
                    </div>
                    <div style={{ height: 4 }} />
                    <div
                      className="clamp-2"
                      style={{
                        ...AppTypography.outfitWhite,
                        fontSize: 12,
                        color: withAlpha(AppColors.roseQuartz, 0.6),
                      }}
                    >
                      {unlocked
                        ? note.content.length > 60
                          ? `${note.content.slice(0, 60)}...`
                          : note.content
                        : `Sealed until ${note.unlockDate.getDate()}/${note.unlockDate.getMonth() + 1}/${note.unlockDate.getFullYear()}`}
                    </div>
                  </div>
                  {!unlocked && (
                    <div
                      style={{
                        marginLeft: 8,
                        padding: '4px 10px',
                        background: withAlpha(AppColors.blushGold, 0.15),
                        borderRadius: 12,
                        border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 4,
                        flexShrink: 0,
                      }}
                    >
                      <Icon name="lock_clock" size={12} color={AppColors.blushGold} />
                      <span style={{ ...AppTypography.outfitWhite, fontSize: 11, fontWeight: 700, color: AppColors.blushGold }}>
                        {badgeText}
                      </span>
                    </div>
                  )}
                  {isNew && (
                    <div
                      style={{
                        marginLeft: 8,
                        width: 8,
                        height: 8,
                        borderRadius: '50%',
                        background: AppColors.blushGold,
                        boxShadow: boxShadow([{ blur: 6, color: withAlpha(AppColors.blushGold, 0.5) }]),
                        flexShrink: 0,
                      }}
                    />
                  )}
                </button>
              );
            })}
          </div>
        )}
      </div>

      {lockedNote && (
        <div
          onClick={() => setLockedNote(null)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.72),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 340,
              padding: 24,
              borderRadius: 24,
              background: AppColors.velvet,
              textAlign: 'center',
            }}
          >
            <div style={{ ...AppTypography.cormorantBold, fontSize: 22 }}>Still sealed 🤫</div>
            <div style={{ height: 14 }} />
            <Icon name="lock_outline" size={48} color={withAlpha(AppColors.blushGold, 0.7)} />
            <div style={{ height: 14 }} />
            <div style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.petalWhite, 0.8) }}>
              This letter will unlock on {lockedNote.unlockDate.getDate()}/{lockedNote.unlockDate.getMonth() + 1}/
              {lockedNote.unlockDate.getFullYear()}.
            </div>
            <div style={{ height: 16 }} />
            <button
              type="button"
              className="bare-button"
              onClick={() => setLockedNote(null)}
              style={{ margin: '0 auto', padding: '8px 16px', ...AppTypography.outfitBold, color: AppColors.blushGold }}
            >
              I&apos;ll wait 🌸
            </button>
          </div>
        </div>
      )}

      {openNote && (
        <div
          onClick={() => setOpenNote(null)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.72),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 480,
              padding: 24,
              borderRadius: 28,
              background: linear(['#381E3E', AppColors.velvet, AppColors.inkDeep], {
                begin: Align.topLeft,
                end: Align.bottomRight,
                stops: [0, 0.45, 1],
              }),
              border: `1.2px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
              boxShadow: '0 20px 40px rgba(16,10,28,0.8)',
            }}
          >
            <div style={{ ...AppTypography.cormorantBold, fontSize: 26, color: AppColors.petalWhite, textAlign: 'center' }}>
              {openNote.title}
            </div>
            <div style={{ height: 16 }} />
            <div style={{ ...AppTypography.bodyLarge, color: Derived.textHigh, lineHeight: 1.6, textAlign: 'center' }}>
              {openNote.content}
            </div>
            <div style={{ height: 22 }} />
            <button
              type="button"
              className="bare-button"
              onClick={() => setOpenNote(null)}
              style={{
                width: '100%',
                padding: '12px 16px',
                borderRadius: 999,
                background: linear([AppColors.auroraRose, AppColors.deepRose]),
                ...AppTypography.outfitBold,
                color: AppColors.petalWhite,
                textAlign: 'center',
              }}
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
