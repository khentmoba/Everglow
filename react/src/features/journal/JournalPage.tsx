// Port of lib/features/journal/presentation/screens/journal_screen.dart + entry card/detail/add dialogs.
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import {
  JOURNAL_CATEGORIES,
  JOURNAL_MOODS,
  journalAuthorHue,
  journalAuthorName,
  journalCategoryMeta,
  journalDayKey,
  journalMoodEmoji,
  journalService,
  type JournalCategory,
  type JournalEntry,
  type JournalMood,
} from './journalService';

function relativeDate(d: Date): string {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const day = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const diff = Math.round((today - day) / 86_400_000);
  if (diff <= 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  if (diff < 7) return `${diff}d ago`;
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function readingTime(words: number): string {
  if (words <= 0) return 'a quick note';
  const mins = Math.max(1, Math.ceil(words / 200));
  return `${mins} min read`;
}

export function JournalPage() {
  const auth = useAuth();
  const currentUser = auth.currentUser ?? 'khentsgdz';

  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<JournalEntry[] | null>(null);
  const [categoryFilter, setCategoryFilter] = useState<JournalCategory | null>(null);
  const [authorFilter, setAuthorFilter] = useState<string | null>(null);
  const [pinnedOnly, setPinnedOnly] = useState(false);
  const [lockedOnly, setLockedOnly] = useState(false);

  const [detailEntry, setDetailEntry] = useState<JournalEntry | null>(null);
  const [editingEntry, setEditingEntry] = useState<JournalEntry | null>(null);
  const [addOpen, setAddOpen] = useState(false);

  const allEntries = useSource<JournalEntry[]>(() => journalService.watchAll(100), [], []);

  useEffect(() => {
    const q = searchQuery.trim();
    if (!q) {
      setSearchResults(null);
      return;
    }
    const id = window.setTimeout(() => {
      void journalService
        .search(q)
        .then(setSearchResults)
        .catch(() => setSearchResults([]));
    }, 250);
    return () => clearTimeout(id);
  }, [searchQuery]);

  const visibleEntries = useMemo(() => {
    const base = searchQuery.trim() ? (searchResults ?? []) : allEntries;
    return base
      .filter((e) => {
        if (categoryFilter && e.category !== categoryFilter) return false;
        if (authorFilter && e.author.toLowerCase() !== authorFilter.toLowerCase()) return false;
        if (pinnedOnly && !e.isPinned) return false;
        if (lockedOnly && !e.isLocked) return false;
        return true;
      })
      .sort((a, b) => {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.getTime() - a.createdAt.getTime();
      });
  }, [allEntries, searchResults, searchQuery, categoryFilter, authorFilter, pinnedOnly, lockedOnly]);

  return (
    <div style={{ position: 'relative', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.deepRose, alignment: [-0.8, -0.9], size: 0.7, opacity: 0.16 },
          { color: AppColors.plum, alignment: [0.8, -0.6], size: 0.6, opacity: 0.12 },
          { color: AppColors.auroraGold, alignment: [0.9, 0.9], size: 0.65, opacity: 0.08 },
        ]}
      />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          flex: 1,
          width: '100%',
          maxWidth: 740,
          margin: '0 auto',
          display: 'flex',
          flexDirection: 'column',
          paddingBottom: 96,
        }}
      >
        <EverglowFeatureHeader
          title="Our Journal"
          subtitle="words woven together"
          icon="menu_book"
          hue={AppColors.softLavender}
          actions={[
            <Tooltip key="new" message="New entry">
              <button
                type="button"
                className="bare-button"
                aria-label="New journal entry"
                onClick={() => {
                  setEditingEntry(null);
                  setAddOpen(true);
                }}
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: '50%',
                  background: Derived.surfaceGlass,
                  border: `1px solid ${Derived.border}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="edit_note" size={20} color={AppColors.blushGold} />
              </button>
            </Tooltip>,
          ]}
        />

        {/* Search Field */}
        <div style={{ padding: '2px 16px 10px' }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              padding: '0 16px',
              minHeight: 48,
              background: withAlpha(AppColors.velvet, 0.38),
              borderRadius: AppRadius.xl,
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
            }}
          >
            <Icon name="search" size={18} color={withAlpha(AppColors.petalWhite, 0.42)} />
            <input
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search memories, tags, dreams..."
              style={{
                flex: 1,
                background: 'transparent',
                border: 'none',
                outline: 'none',
                ...AppTypography.outfitWhite,
                fontSize: 13.5,
                color: AppColors.petalWhite,
              }}
            />
            {searchQuery && (
              <button
                type="button"
                className="bare-button"
                onClick={() => setSearchQuery('')}
                aria-label="Clear search"
              >
                <Icon name="close" size={18} color={Derived.textMuted} />
              </button>
            )}
          </div>
        </div>

        {/* Story Card */}
        {allEntries.length > 0 && <StoryCard entries={allEntries} />}

        {/* Chapter Rail */}
        {allEntries.length > 0 && (
          <div
            className="no-scrollbar"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              overflowX: 'auto',
              padding: '0 16px',
              height: 42,
              marginTop: 12,
              marginBottom: 8,
            }}
          >
            <ChapterPill
              emoji="✨"
              name="All"
              count={allEntries.length}
              color={AppColors.blushGold}
              selected={categoryFilter == null}
              onClick={() => setCategoryFilter(null)}
            />
            {JOURNAL_CATEGORIES.map((c) => {
              const count = allEntries.filter((e) => e.category === c.id).length;
              return (
                <ChapterPill
                  key={c.id}
                  emoji={c.emoji}
                  name={c.label}
                  count={count}
                  color={c.color}
                  selected={categoryFilter === c.id}
                  onClick={() => setCategoryFilter(c.id)}
                />
              );
            })}
          </div>
        )}

        {/* Author + Filter Row */}
        {allEntries.length > 0 && (
          <div
            className="no-scrollbar"
            style={{
              display: 'flex',
              alignItems: 'center',
              overflowX: 'auto',
              padding: '0 16px',
              height: 34,
              marginBottom: 8,
            }}
          >
            <FilterChip
              label="All authors"
              color={AppColors.softLavender}
              selected={authorFilter == null}
              onClick={() => setAuthorFilter(null)}
            />
            <div style={{ width: 6, flexShrink: 0 }} />
            <FilterChip
              label="Khent"
              avatarDot="K"
              avatarHue={AppColors.auroraTeal}
              color={AppColors.auroraTeal}
              selected={authorFilter === 'khentsgdz'}
              onClick={() => setAuthorFilter(authorFilter === 'khentsgdz' ? null : 'khentsgdz')}
            />
            <div style={{ width: 6, flexShrink: 0 }} />
            <FilterChip
              label="Clair"
              avatarDot="C"
              avatarHue={AppColors.auroraRose}
              color={AppColors.auroraRose}
              selected={authorFilter === 'clairjassen'}
              onClick={() => setAuthorFilter(authorFilter === 'clairjassen' ? null : 'clairjassen')}
            />
            <div style={{ width: 10, flexShrink: 0 }} />
            <div style={{ width: 1, height: 16, background: withAlpha(AppColors.moonlight, 0.12), flexShrink: 0 }} />
            <div style={{ width: 10, flexShrink: 0 }} />
            <FilterChip
              label="📌 Pinned"
              color={AppColors.blushGold}
              selected={pinnedOnly}
              onClick={() => setPinnedOnly((p) => !p)}
            />
            <div style={{ width: 6, flexShrink: 0 }} />
            <FilterChip
              label="🔒 Locked"
              color={AppColors.warmAmber}
              selected={lockedOnly}
              onClick={() => setLockedOnly((p) => !p)}
            />
          </div>
        )}

        {/* Entries List */}
        {allEntries.length === 0 ? (
          <div style={{ padding: 48, textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <Icon name="edit_note" size={50} color={withAlpha(AppColors.blushGold, 0.7)} />
            <div style={{ height: 12 }} />
            <div style={{ ...AppTypography.outfitBold, fontSize: 16 }}>Your journal is empty</div>
            <div style={{ ...AppTypography.bodySmall, marginTop: 6, color: Derived.textMedium }}>
              Write your first memory together ✨
            </div>
            <div style={{ marginTop: 18 }}>
              <EverglowButton
                label="New Entry"
                onPressed={() => {
                  setEditingEntry(null);
                  setAddOpen(true);
                }}
              />
            </div>
          </div>
        ) : visibleEntries.length === 0 ? (
          <div style={{ padding: 48, textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <Icon name="search_off" size={44} color={Derived.textMuted} />
            <div style={{ height: 10 }} />
            <div style={{ ...AppTypography.outfitBold, fontSize: 15 }}>No matching entries</div>
            <div style={{ ...AppTypography.bodySmall, marginTop: 4, color: Derived.textMedium }}>
              Try adjusting filters or search
            </div>
          </div>
        ) : (
          <div style={{ padding: '8px 16px 0', display: 'flex', flexDirection: 'column', gap: 14 }}>
            {visibleEntries.map((entry, idx) => {
              const prev = idx > 0 ? visibleEntries[idx - 1] : null;
              let header: 'pinned' | 'month' | null = null;
              if (idx === 0) {
                header = entry.isPinned ? 'pinned' : 'month';
              } else if (prev) {
                if (prev.isPinned && entry.isPinned) {
                  header = null;
                } else if (
                  prev.isPinned !== entry.isPinned ||
                  prev.createdAt.getMonth() !== entry.createdAt.getMonth() ||
                  prev.createdAt.getFullYear() !== entry.createdAt.getFullYear()
                ) {
                  header = 'month';
                }
              }
              return (
                <div key={entry.id} style={{ display: 'flex', flexDirection: 'column' }}>
                  {header === 'pinned' && (
                    <>
                      <PinnedHeader />
                      <div style={{ height: 10 }} />
                    </>
                  )}
                  {header === 'month' && (
                    <>
                      <MonthHeader date={entry.createdAt} />
                      <div style={{ height: 10 }} />
                    </>
                  )}
                  <JournalEntryCard entry={entry} onClick={() => setDetailEntry(entry)} />
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Floating Write Pill */}
      <button
        type="button"
        className="bare-button"
        onClick={() => {
          setEditingEntry(null);
          setAddOpen(true);
        }}
        style={{
          position: 'fixed',
          right: 20,
          bottom: 24,
          padding: '13px 20px',
          borderRadius: AppRadius.full,
          background: `linear-gradient(135deg, ${AppColors.deepRose}, ${AppColors.auroraRose})`,
          boxShadow: `0 6px 16px ${withAlpha(AppColors.deepRose, 0.4)}, 0 2px 6px ${withAlpha(AppColors.auroraGold, 0.16)}`,
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          zIndex: 50,
          color: AppColors.petalWhite,
        }}
      >
        <Icon name="edit_note" size={21} color={AppColors.petalWhite} />
        <span style={{ ...AppTypography.outfitBold, fontSize: 14, letterSpacing: 0.4 }}>Write</span>
      </button>

      {detailEntry && (
        <JournalDetailModal
          entry={allEntries.find((e) => e.id === detailEntry.id) ?? detailEntry}
          currentUser={currentUser}
          onClose={() => setDetailEntry(null)}
          onEdit={(entry) => {
            setDetailEntry(null);
            setEditingEntry(entry);
            setAddOpen(true);
          }}
        />
      )}

      {addOpen && (
        <JournalEditorModal
          author={currentUser}
          existing={editingEntry}
          onClose={() => {
            setAddOpen(false);
            setEditingEntry(null);
          }}
        />
      )}
    </div>
  );
}

function StoryCard({ entries }: { entries: JournalEntry[] }) {
  const words = entries.reduce((acc, e) => acc + e.wordCount, 0);
  const wroteDays = useMemo(() => new Set(entries.map((e) => journalDayKey(e.createdAt))), [entries]);
  const last14 = useMemo(() => {
    const out: { key: string; filled: boolean; isToday: boolean }[] = [];
    for (let i = 0; i < 14; i++) {
      const d = new Date(Date.now() - (13 - i) * 86_400_000);
      const key = journalDayKey(d);
      out.push({ key, filled: wroteDays.has(key), isToday: i === 13 });
    }
    return out;
  }, [wroteDays]);

  return (
    <div style={{ padding: '0 16px' }}>
      <div
        style={{
          padding: '16px 18px 14px',
          background: `linear-gradient(135deg, ${withAlpha(AppColors.plum, 0.55)}, ${withAlpha(AppColors.velvet, 0.7)}, ${withAlpha(AppColors.inkDeep, 0.85)})`,
          borderRadius: 22,
          border: `1.2px solid ${withAlpha(AppColors.blushGold, 0.28)}`,
          boxShadow: `0 8px 20px ${withAlpha(AppColors.deepRose, 0.16)}, 0 4px 10px ${withAlpha(AppColors.inkDeep, 0.4)}`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.handwrittenTitle, fontSize: 25, color: AppColors.blushGold, lineHeight: 1.1 }}>
              our story so far
            </div>
            <div style={{ ...AppTypography.outfitWhite, fontSize: 11.5, color: withAlpha(AppColors.petalWhite, 0.65), marginTop: 3 }}>
              every word is a piece of us
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
            <StatPill icon="menu_book" value={String(entries.length)} label="entries" />
            <StatPill icon="draw" value={words.toLocaleString()} label="words" />
            <StatPill icon="calendar_today" value={String(wroteDays.size)} label="days" />
          </div>
        </div>

        <div
          style={{
            marginTop: 14,
            padding: '8px 12px',
            borderRadius: AppRadius.full,
            background: withAlpha(AppColors.inkDeep, 0.45),
            border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Icon name="auto_awesome" size={13} color={AppColors.blushGold} />
            <span style={{ ...AppTypography.outfitMedium, fontSize: 11, letterSpacing: 0.4, color: withAlpha(AppColors.petalWhite, 0.65) }}>
              last 2 weeks
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
            {last14.map((d) => (
              <span
                key={d.key}
                style={{
                  width: d.isToday ? 11 : 8.5,
                  height: d.isToday ? 11 : 8.5,
                  borderRadius: '50%',
                  background: d.filled
                    ? d.isToday
                      ? AppColors.auroraGold
                      : AppColors.blushGold
                    : withAlpha(AppColors.moonlight, 0.14),
                  border: d.isToday ? `1.2px solid ${AppColors.petalWhite}` : undefined,
                  boxShadow: d.filled
                    ? `0 0 ${d.isToday ? 8 : 4}px ${withAlpha(d.isToday ? AppColors.auroraGold : AppColors.blushGold, d.isToday ? 0.6 : 0.4)}`
                    : undefined,
                }}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function StatPill({ icon, value, label }: { icon: string; value: string; label: string }) {
  return (
    <div
      style={{
        padding: '5px 9px',
        background: withAlpha(AppColors.inkDeep, 0.4),
        borderRadius: 10,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
        <Icon name={icon} size={11} color={withAlpha(AppColors.blushGold, 0.85)} />
        <span style={{ ...AppTypography.outfitHeading, fontSize: 14, lineHeight: 1.1, color: AppColors.blushGold }}>
          {value}
        </span>
      </div>
      <span style={{ ...AppTypography.outfitMedium, fontSize: 9.5, letterSpacing: 0.3, color: withAlpha(AppColors.petalWhite, 0.6), marginTop: 2 }}>
        {label}
      </span>
    </div>
  );
}

function ChapterPill({
  emoji,
  name,
  count,
  color,
  selected,
  onClick,
}: {
  emoji: string;
  name: string;
  count: number;
  color: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        flexShrink: 0,
        padding: '7px 13px',
        borderRadius: AppRadius.full,
        background: selected
          ? `linear-gradient(180deg, ${withAlpha(color, 0.3)}, ${withAlpha(color, 0.12)})`
          : Derived.panelGlass,
        border: `${selected ? 1.3 : 1}px solid ${selected ? withAlpha(color, 0.7) : withAlpha(AppColors.moonlight, 0.11)}`,
        boxShadow: selected ? `0 3px 10px ${withAlpha(color, 0.25)}` : undefined,
        display: 'flex',
        alignItems: 'center',
        gap: 6,
      }}
    >
      <span style={{ fontSize: 13 }}>{emoji}</span>
      <span
        style={{
          ...AppTypography.outfitBold,
          fontSize: 11.5,
          color: selected ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.75),
        }}
      >
        {name}
      </span>
      {count > 0 && (
        <span
          style={{
            padding: '1.5px 6px',
            borderRadius: AppRadius.full,
            background: selected ? withAlpha(color, 0.3) : withAlpha(AppColors.moonlight, 0.08),
            ...AppTypography.outfitBold,
            fontSize: 10,
            color: selected ? AppColors.petalWhite : color,
          }}
        >
          {count}
        </span>
      )}
    </button>
  );
}

function AuthorDot({ letter, hue, size }: { letter: string; hue: string; size: number }) {
  return (
    <span
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: `linear-gradient(135deg, ${withAlpha(hue, 0.35)}, ${withAlpha(hue, 0.14)})`,
        border: `1px solid ${withAlpha(hue, 0.55)}`,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        ...AppTypography.outfitBold,
        fontSize: size * 0.52,
        color: hue,
        flexShrink: 0,
      }}
    >
      {letter}
    </span>
  );
}

function PinnedHeader() {
  return (
    <div style={{ padding: '10px 4px 6px', display: 'flex', alignItems: 'center' }}>
      <span
        style={{
          padding: '4px 10px',
          borderRadius: AppRadius.full,
          background: withAlpha(AppColors.blushGold, 0.12),
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
          display: 'inline-flex',
          alignItems: 'center',
          gap: 5,
          ...AppTypography.outfitBold,
          fontSize: 11,
          letterSpacing: 0.5,
          color: AppColors.blushGold,
          flexShrink: 0,
        }}
      >
        <Icon name="push_pin" size={12} color={AppColors.blushGold} />
        <span>Pinned with love</span>
      </span>
      <div style={{ width: 10 }} />
      <div
        style={{
          flex: 1,
          height: 1,
          background: `linear-gradient(90deg, ${withAlpha(AppColors.blushGold, 0.25)}, transparent)`,
        }}
      />
    </div>
  );
}

function MonthHeader({ date }: { date: Date }) {
  return (
    <div style={{ padding: '16px 4px 8px', display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          flex: 1,
          height: 1,
          background: `linear-gradient(90deg, transparent, ${withAlpha(AppColors.blushGold, 0.28)})`,
        }}
      />
      <div style={{ padding: '0 12px', display: 'flex', alignItems: 'center', gap: 7, flexShrink: 0 }}>
        <Icon name="auto_awesome" size={11} color={withAlpha(AppColors.blushGold, 0.65)} />
        <span
          style={{
            ...AppTypography.cormorantBold,
            fontSize: 18,
            letterSpacing: 0.8,
            color: AppColors.blushGold,
          }}
        >
          {date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
        </span>
        <Icon name="auto_awesome" size={11} color={withAlpha(AppColors.blushGold, 0.65)} />
      </div>
      <div
        style={{
          flex: 1,
          height: 1,
          background: `linear-gradient(90deg, ${withAlpha(AppColors.blushGold, 0.28)}, transparent)`,
        }}
      />
    </div>
  );
}

function FilterChip({
  label,
  color = AppColors.softLavender,
  avatarDot,
  avatarHue,
  selected,
  onClick,
}: {
  label: string;
  color?: string;
  avatarDot?: string;
  avatarHue?: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        flexShrink: 0,
        padding: '5.5px 11px',
        borderRadius: AppRadius.full,
        background: selected ? withAlpha(color, 0.18) : Derived.panelGlass,
        border: `${selected ? 1.2 : 1}px solid ${selected ? withAlpha(color, 0.7) : withAlpha(AppColors.moonlight, 0.1)}`,
        display: 'inline-flex',
        alignItems: 'center',
        gap: 5,
        ...AppTypography.outfitBold,
        fontSize: 11,
        color: selected ? color : withAlpha(AppColors.petalWhite, 0.65),
        whiteSpace: 'nowrap',
      }}
    >
      {avatarDot && avatarHue && <AuthorDot letter={avatarDot} hue={avatarHue} size={14} />}
      <span>{label}</span>
    </button>
  );
}

function JournalEntryCard({ entry, onClick }: { entry: JournalEntry; onClick: () => void }) {
  const cat = journalCategoryMeta(entry.category);
  const moodEmoji = journalMoodEmoji(entry.mood);
  const authorHue = journalAuthorHue(entry.author);
  const authorName = journalAuthorName(entry.author);
  const authorInitial = authorName ? authorName[0].toUpperCase() : '♥';

  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        width: '100%',
        textAlign: 'left',
        borderRadius: AppRadius.xl,
        overflow: 'hidden',
        background: `linear-gradient(135deg, ${withAlpha(AppColors.velvet, 0.4)}, ${withAlpha(AppColors.inkDeep, 0.7)}, ${withAlpha(cat.color, 0.04)})`,
        border: `${entry.isPinned ? 1.2 : 1}px solid ${entry.isPinned ? withAlpha(AppColors.blushGold, 0.36) : withAlpha(AppColors.moonlight, 0.1)}`,
        boxShadow: entry.isPinned
          ? `0 4px 12px ${withAlpha(AppColors.inkDeep, 0.35)}, 0 2px 16px ${withAlpha(AppColors.blushGold, 0.1)}`
          : `0 4px 12px ${withAlpha(AppColors.inkDeep, 0.35)}`,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div
        style={{
          height: 3.5,
          background: `linear-gradient(90deg, ${withAlpha(cat.color, 0.95)}, ${withAlpha(cat.color, 0.35)}, transparent)`,
        }}
      />
      <div style={{ padding: '14px 18px 16px' }}>
        {entry.isPinned && (
          <div style={{ marginBottom: 10 }}>
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 4,
                padding: '3.5px 9px',
                borderRadius: AppRadius.full,
                background: withAlpha(AppColors.blushGold, 0.14),
                border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
                ...AppTypography.outfitBold,
                fontSize: 10,
                letterSpacing: 0.5,
                color: AppColors.blushGold,
              }}
            >
              <Icon name="push_pin" size={11} color={AppColors.blushGold} />
              <span>Pinned with love</span>
            </span>
          </div>
        )}

        <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
              padding: '4.5px 10px',
              borderRadius: AppRadius.full,
              background: withAlpha(cat.color, 0.14),
              border: `1px solid ${withAlpha(cat.color, 0.32)}`,
              ...AppTypography.outfitBold,
              fontSize: 10.5,
              letterSpacing: 0.3,
              color: cat.color,
            }}
          >
            <span style={{ fontSize: 11 }}>{cat.emoji}</span>
            <span>{cat.label}</span>
          </span>
          {moodEmoji && entry.mood && (
            <span
              style={{
                padding: '4.5px 8px',
                borderRadius: AppRadius.full,
                background: withAlpha(AppColors.moonlight, 0.08),
                border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
                ...AppTypography.outfitMedium,
                fontSize: 10.5,
                color: withAlpha(AppColors.petalWhite, 0.8),
              }}
            >
              {moodEmoji} {entry.mood}
            </span>
          )}
          <span style={{ flex: 1 }} />
          {entry.isLocked && <Icon name="lock" size={13} color={withAlpha(AppColors.warmAmber, 0.95)} />}
          <span style={{ ...AppTypography.outfitMedium, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.52) }}>
            {relativeDate(entry.createdAt)}
          </span>
        </div>

        <div
          style={{
            marginTop: 10,
            ...AppTypography.cormorantBoldWhite,
            fontSize: 22,
            lineHeight: 1.22,
            letterSpacing: 0.2,
          }}
        >
          {entry.title || 'Untitled'}
        </div>

        <div style={{ height: 8 }} />
        {entry.isLocked ? (
          <div
            style={{
              padding: '14px 12px',
              borderRadius: AppRadius.sm,
              background: withAlpha(AppColors.inkDeep, 0.45),
              border: `1px solid ${withAlpha(AppColors.warmAmber, 0.2)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
            }}
          >
            <Icon name="lock_outline" size={15} color={withAlpha(AppColors.warmAmber, 0.85)} />
            <span
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 12,
                color: withAlpha(AppColors.petalWhite, 0.68),
                fontStyle: 'italic',
              }}
            >
              Sealed with a kiss — tap to open
            </span>
          </div>
        ) : (
          entry.content && (
            <div
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 13.5,
                color: withAlpha(AppColors.petalWhite, 0.76),
                display: '-webkit-box',
                WebkitLineClamp: 3,
                WebkitBoxOrient: 'vertical',
                overflow: 'hidden',
                lineHeight: 1.55,
              }}
            >
              {entry.content}
            </div>
          )
        )}

        {!entry.isLocked && entry.tags.length > 0 && (
          <div style={{ marginTop: 10, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {entry.tags.slice(0, 3).map((t) => (
              <span
                key={t}
                style={{
                  ...AppTypography.outfitMedium,
                  fontSize: 10.5,
                  padding: '3.5px 8px',
                  borderRadius: AppRadius.full,
                  background: withAlpha(AppColors.softLavender, 0.12),
                  border: `1px solid ${withAlpha(AppColors.softLavender, 0.18)}`,
                  color: AppColors.softLavender,
                }}
              >
                #{t}
              </span>
            ))}
          </div>
        )}

        <div style={{ height: 12 }} />
        <div style={{ height: 1, background: withAlpha(AppColors.moonlight, 0.08) }} />
        <div style={{ height: 10 }} />

        <div style={{ display: 'flex', alignItems: 'center' }}>
          <AuthorDot letter={authorInitial} hue={authorHue} size={22} />
          <div style={{ width: 8 }} />
          <span style={{ ...AppTypography.outfitBold, fontSize: 11.5, color: withAlpha(AppColors.petalWhite, 0.85) }}>
            {authorName}
          </span>
          <span
            style={{
              width: 3,
              height: 3,
              borderRadius: '50%',
              background: withAlpha(AppColors.petalWhite, 0.35),
              margin: '0 7px',
            }}
          />
          <span style={{ ...AppTypography.outfitMedium, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.48) }}>
            {readingTime(entry.wordCount)}
          </span>
          <span style={{ flex: 1 }} />
          <span style={{ ...AppTypography.outfitMedium, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.45) }}>
            {entry.wordCount.toLocaleString()} words
          </span>
        </div>
      </div>
    </button>
  );
}

function JournalDetailModal({
  entry,
  currentUser,
  onClose,
  onEdit,
}: {
  entry: JournalEntry;
  currentUser: string;
  onClose: () => void;
  onEdit: (e: JournalEntry) => void;
}) {
  const [unlocked, setUnlocked] = useState(!entry.isLocked);
  const [perspective, setPerspective] = useState(entry.perspectives?.[currentUser] ?? '');

  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.68)',
        zIndex: 600,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 18,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 560,
          maxHeight: '88vh',
          overflowY: 'auto',
          background: AppColors.velvet,
          borderRadius: 24,
          border: `1px solid ${Derived.border}`,
          padding: 24,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
          <span style={{ ...AppTypography.labelSmall, color: AppColors.blushGold }}>
            {journalAuthorName(entry.author)} · {relativeDate(entry.createdAt)}
          </span>
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              type="button"
              className="bare-button"
              onClick={() => void journalService.togglePin(entry.id, !entry.isPinned)}
              title="Toggle pin"
            >
              <Icon name="push_pin" size={20} color={entry.isPinned ? AppColors.blushGold : Derived.textMuted} />
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={() => void journalService.toggleLock(entry.id, !entry.isLocked)}
              title="Toggle lock"
            >
              <Icon name={entry.isLocked ? 'lock' : 'lock_open'} size={20} color={AppColors.auroraLilac} />
            </button>
            <button type="button" className="bare-button" onClick={() => onEdit(entry)} title="Edit">
              <Icon name="edit" size={20} color={AppColors.roseQuartz} />
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                void journalService.deleteEntry(entry.id);
                onClose();
                showSnackBar('Entry deleted');
              }}
              title="Delete"
            >
              <Icon name="delete_outline" size={20} color={AppColors.error} />
            </button>
          </div>
        </div>

        <h2 style={{ ...AppTypography.cormorantBoldWhite, fontSize: 28, margin: '12px 0 8px' }}>
          {entry.title || 'Untitled'}
        </h2>

        {!unlocked ? (
          <div style={{ padding: '24px 0', textAlign: 'center' }}>
            <Icon name="lock" size={34} color={AppColors.auroraLilac} />
            <div style={{ ...AppTypography.bodyMedium, margin: '8px 0 14px' }}>
              This entry is tucked away privately.
            </div>
            <EverglowButton label="Reveal Entry" onPressed={() => setUnlocked(true)} />
          </div>
        ) : (
          <div style={{ ...AppTypography.bodyLarge, color: Derived.textHigh, whiteSpace: 'pre-wrap', lineHeight: 1.65 }}>
            {entry.content}
          </div>
        )}

        <div style={{ marginTop: 22, paddingTop: 16, borderTop: `1px solid ${Derived.border}` }}>
          <div style={{ ...AppTypography.labelSmall, color: AppColors.roseQuartz, marginBottom: 8 }}>
            Your perspective
          </div>
          <textarea
            value={perspective}
            onChange={(e) => setPerspective(e.target.value.slice(0, 1000))}
            rows={2}
            placeholder="Add how this memory felt for you..."
            style={{
              width: '100%',
              padding: 10,
              borderRadius: 12,
              background: withAlpha(AppColors.inkDeep, 0.5),
              border: `1px solid ${Derived.border}`,
              color: AppColors.petalWhite,
              outline: 'none',
            }}
          />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10 }}>
            <EverglowButton label="Close" variant="ghost" onPressed={onClose} />
            <EverglowButton
              label="Save Note"
              onPressed={async () => {
                await journalService.savePerspective(entry.id, currentUser, perspective);
                showSnackBar('Perspective saved');
              }}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

function JournalEditorModal({
  author,
  existing,
  onClose,
}: {
  author: string;
  existing: JournalEntry | null;
  onClose: () => void;
}) {
  const [title, setTitle] = useState(existing?.title ?? '');
  const [content, setContent] = useState(existing?.content ?? '');
  const [category, setCategory] = useState<JournalCategory>((existing?.category as JournalCategory) ?? 'daily');
  const [mood, setMood] = useState<JournalMood | undefined>(existing?.mood as JournalMood | undefined);
  const [tagsRaw, setTagsRaw] = useState((existing?.tags ?? []).join(', '));
  const [isPinned, setIsPinned] = useState(existing?.isPinned ?? false);
  const [isLocked, setIsLocked] = useState(existing?.isLocked ?? false);
  const [saving, setSaving] = useState(false);

  const save = async () => {
    if (!title.trim() && !content.trim()) return;
    setSaving(true);
    const tags = tagsRaw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    try {
      if (existing) {
        await journalService.updateEntry(existing.id, {
          title: title.trim() || 'Untitled',
          content: content.trim(),
          category,
          mood,
          tags,
          isPinned,
          isLocked,
        });
      } else {
        await journalService.addEntry({
          title: title.trim() || 'Untitled',
          content: content.trim(),
          author,
          category,
          mood,
          tags,
          isPinned,
          isLocked,
        });
      }
      showSnackBar(existing ? 'Entry updated' : 'Entry saved');
      onClose();
    } catch {
      showSnackBar('Could not save journal entry');
      setSaving(false);
    }
  };

  return (
    <div
      onClick={() => !saving && onClose()}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.68)',
        zIndex: 600,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 18,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 500,
          maxHeight: '90vh',
          overflowY: 'auto',
          background: AppColors.velvet,
          borderRadius: 24,
          border: `1px solid ${Derived.border}`,
          padding: 22,
          display: 'flex',
          flexDirection: 'column',
          gap: 12,
        }}
      >
        <div style={{ ...AppTypography.titleLarge, color: AppColors.petalWhite }}>
          {existing ? 'Edit Entry' : 'New Journal Entry'}
        </div>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Title"
          style={editorFieldStyle}
        />
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {JOURNAL_CATEGORIES.map((c) => (
            <FilterChip
              key={c.id}
              label={`${c.emoji} ${c.label}`}
              color={c.color}
              selected={category === c.id}
              onClick={() => setCategory(c.id)}
            />
          ))}
        </div>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {JOURNAL_MOODS.map((m) => (
            <FilterChip
              key={m.id}
              label={`${m.emoji} ${m.label}`}
              selected={mood === m.id}
              onClick={() => setMood(mood === m.id ? undefined : m.id)}
            />
          ))}
        </div>
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          rows={6}
          placeholder="Write from the heart..."
          style={{ ...editorFieldStyle, resize: 'vertical' }}
        />
        <input
          value={tagsRaw}
          onChange={(e) => setTagsRaw(e.target.value)}
          placeholder="Tags (comma separated)"
          style={editorFieldStyle}
        />
        <div style={{ display: 'flex', gap: 16 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, ...AppTypography.bodySmall }}>
            <input type="checkbox" checked={isPinned} onChange={(e) => setIsPinned(e.target.checked)} />
            Pin to top
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, ...AppTypography.bodySmall }}>
            <input type="checkbox" checked={isLocked} onChange={(e) => setIsLocked(e.target.checked)} />
            Lock entry
          </label>
        </div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <EverglowButton label="Cancel" variant="ghost" onPressed={onClose} enabled={!saving} />
          <EverglowButton label={saving ? 'Saving…' : 'Save'} enabled={!saving} onPressed={() => void save()} />
        </div>
      </div>
    </div>
  );
}

const editorFieldStyle = {
  width: '100%',
  padding: '11px 14px',
  borderRadius: 12,
  background: withAlpha(AppColors.inkDeep, 0.55),
  border: `1px solid ${Derived.border}`,
  color: AppColors.petalWhite,
  outline: 'none',
  fontSize: 14,
};
