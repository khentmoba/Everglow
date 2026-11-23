// Port of lib/features/journal/presentation/screens/journal_screen.dart.
import { useEffect, useMemo, useState, type CSSProperties } from 'react';
import type { DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import { authService, useAuth } from '../../core/services/auth';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { Align, linear, lineHeight, mixedLineHeight, shadowLayer, type BoxShadow } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useRememberedScroll } from '../../shared/utils/scrollMemory';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { TextButton } from '../../shared/widgets/Dialogs';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowIconButton, EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { EverglowEmptyState, EverglowSkeleton, EverglowStreamView } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { showAddJournalEntryDialog } from './AddJournalEntryDialog';
import { AuthorDot, showJournalDetailSheet } from './JournalDetailSheet';
import { JournalEntryCard } from './JournalEntryCard';
import { JOURNAL_CATEGORIES, journalService, preview, type JournalCategory, type JournalEntry } from './journalService';
import { journalCategoryColor, journalDayKey, journalMonthLabel, journalNumberFormat } from './journalUi';

const FIRST_PAGE_SIZE = 100;

function showAddDialog() {
  void showAddJournalEntryDialog(authService.currentUser ?? 'unknown');
}

function showEntryDetail(entry: JournalEntry) {
  void showJournalDetailSheet({
    entry,
    onEdit: (close) => {
      close();
      void showAddJournalEntryDialog(authService.currentUser ?? entry.author, entry);
    },
  });
}

type Filters = { category: JournalCategory | null; author: string | null; pinnedOnly: boolean; lockedOnly: boolean };

function visibleEntries(all: JournalEntry[], f: Filters): JournalEntry[] {
  return all
    .filter(
      (e) =>
        (f.category == null || e.category === f.category) &&
        (f.author == null || e.author.toLowerCase() === f.author) &&
        (!f.pinnedOnly || e.isPinned) &&
        (!f.lockedOnly || e.isLocked),
    )
    .sort((a, b) => (a.isPinned !== b.isPinned ? (a.isPinned ? -1 : 1) : b.createdAt.getTime() - a.createdAt.getTime()));
}

export function JournalPage() {
  useAuth();
  const [query, setQuery] = useState('');
  const [search, setSearch] = useState<{ run: number; term: string } | null>(null);
  const [filters, setFilters] = useState<Filters>({ category: null, author: null, pinnedOnly: false, lockedOnly: false });
  const [retry, setRetry] = useState(0);
  const searching = query.trim() !== '';
  const isFiltered = filters.category != null || filters.author != null || filters.pinnedOnly || filters.lockedOnly;

  // Searching walks every entry, so wait for the typing to settle instead of
  // rescanning the collection on each keystroke.
  useEffect(() => {
    const term = query.trim();
    if (term === '') {
      setSearch(null);
      return;
    }
    const t = window.setTimeout(() => setSearch((s) => ({ run: (s?.run ?? 0) + 1, term })), 320);
    return () => window.clearTimeout(t);
  }, [query]);

  const noMatch = <EverglowEmptyState icon="search_off" title="No matching entries" subtitle="Try adjusting filters or search" />;

  return (
    <EverglowScaffold
      backgroundColor={AppColors.inkDeep}
      centerMaxWidth={740}
      glows={[
        { color: AppColors.deepRose, alignment: [-0.8, -0.9], size: 0.7, opacity: 0.16 },
        { color: AppColors.plum, alignment: [0.8, -0.6], size: 0.6, opacity: 0.12 },
        { color: AppColors.auroraGold, alignment: [0.9, 0.9], size: 0.65, opacity: 0.08 },
      ]}
      floatingActionButton={<WriteFab />}
    >
      <EverglowFeatureHeader
        title="Our Journal"
        subtitle="words woven together"
        icon="menu_book"
        hue={AppColors.softLavender}
        actions={[
          <EverglowIconButton
            key="new"
            icon="edit_note"
            onPressed={showAddDialog}
            semanticLabel="New journal entry"
            tooltip="New entry"
            iconColor={AppColors.blushGold}
          />,
        ]}
      />
      <div style={{ padding: '2px 16px 10px' }}>
        <EverglowSearchField
          value={query}
          hint="Search memories, tags, dreams..."
          onChanged={(v) => setQuery(v)}
        />
      </div>
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <EverglowStreamView<JournalEntry[]>
          source={() => journalService.watchAll()}
          sourceKey={[retry]}
          label="journal-entries"
          errorMessage="Could not load journal"
          errorIcon="menu_book_outlined"
          onRetry={() => setRetry((r) => r + 1)}
          loadingView={
            <div style={{ padding: '4px 16px 20px', display: 'flex', flexDirection: 'column' }}>
              <EverglowSkeleton height={148} radius={20} />
              <div style={{ height: 12 }} />
              <EverglowSkeleton height={120} radius={16} />
            </div>
          }
          builder={(all) => {
            if (all.length === 0) {
              if (searching) return <Fill>{noMatch}</Fill>;
              return (
                <Fill>
                  <EverglowEmptyState
                    icon="edit_note"
                    title="Your journal is empty"
                    subtitle="Write your first memory together ✨"
                    ctaLabel="New Entry"
                    onCta={showAddDialog}
                  />
                </Fill>
              );
            }
            const entries = visibleEntries(all, filters);
            return (
              <Fill>
                <StoryCard entries={all} />
                <div style={{ height: 12, flexShrink: 0 }} />
                <ChapterRail
                  entries={all}
                  selected={filters.category}
                  onSelect={(category) => setFilters({ ...filters, category })}
                />
                <div style={{ height: 8, flexShrink: 0 }} />
                <AuthorRow filters={filters} onChange={setFilters} />
                <div style={{ height: 8, flexShrink: 0 }} />
                {!searching && <MemoryCapsule />}
                <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
                  {searching ? (
                    search && (
                      <SearchResults
                        key={search.run}
                        term={search.term}
                        filters={filters}
                        noMatch={noMatch}
                        onRetry={() => setSearch({ run: search.run + 1, term: search.term })}
                      />
                    )
                  ) : entries.length === 0 ? (
                    noMatch
                  ) : (
                    <PaginatedJournalList firstPage={entries} isFiltered={isFiltered} />
                  )}
                </div>
              </Fill>
            );
          }}
        />
      </div>
    </EverglowScaffold>
  );
}

/** The builder's Column fills the stream view (Expanded in Flutter). */
function Fill({ children }: { children: React.ReactNode }) {
  return <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column' }}>{children}</div>;
}

function WriteFab() {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);
  const overlay = pressed ? 0.1 : hovered ? 0.08 : 0;
  const shadows: BoxShadow[] = [
    { color: withAlpha(AppColors.deepRose, 0.4), blur: 16, offset: [0, 6] },
    { color: withAlpha(AppColors.auroraGold, 0.16), blur: 6, offset: [0, 2] },
  ];
  const [ref, size] = useBoxSize<HTMLButtonElement>();
  return (
    <div style={{ position: 'relative' }}>
      {shadows.map((s, i) => (
        <div key={i} aria-hidden style={shadowLayer(s, { radius: AppRadius.full })} />
      ))}
      <button
        ref={ref}
        type="button"
        className="bare-button"
        onClick={showAddDialog}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => {
          setHovered(false);
          setPressed(false);
        }}
        onPointerDown={() => setPressed(true)}
        onPointerUp={() => setPressed(false)}
        style={{
          position: 'relative',
          height: 56,
          padding: '0 20px 0 16px',
          borderRadius: AppRadius.full,
          background: `linear-gradient(${withAlpha(AppColors.petalWhite, overlay)}, ${withAlpha(AppColors.petalWhite, overlay)}), ${linear(
            [AppColors.deepRose, AppColors.auroraRose],
            { begin: Align.topLeft, end: Align.bottomRight, size: size ?? [1, 1] },
          )}`,
          display: 'flex',
          alignItems: 'center',
          gap: 8,
        }}
      >
        <Icon name="edit_note" size={21} color={AppColors.petalWhite} />
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 14,
            lineHeight: lineHeight(14),
            letterSpacing: 0.4,
            color: AppColors.petalWhite,
          }}
        >
          Write
        </span>
      </button>
    </div>
  );
}

function EverglowSearchField({ value, hint, onChanged }: { value: string; hint: string; onChanged: (v: string) => void }) {
  const [focused, setFocused] = useState(false);
  const ms = orZero(AppMotion.fast);
  return (
    <div
      style={{
        position: 'relative',
        // The hidden label keeps room for a floating label, so the field is 61 tall, not 44.
        minHeight: 61,
        background: withAlpha(AppColors.velvet, 0.38),
        borderRadius: AppRadius.xl,
        boxShadow: [
          `inset 0 0 0 ${focused ? 1.3 : 1}px ${focused ? withAlpha(AppColors.blushGold, 0.42) : withAlpha(AppColors.moonlight, 0.1)}`,
          focused ? `0 0 7px ${withAlpha(AppColors.blushGold, 0.1)}` : '',
        ]
          .filter(Boolean)
          .join(', '),
        transition: `box-shadow ${ms}ms ${CssCurves.easeOutStrong}`,
        display: 'flex',
        alignItems: 'center',
        padding: 1,
        boxSizing: 'border-box',
      }}
    >
      <div style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon
          name="search"
          size={18}
          color={focused ? withAlpha(AppColors.blushGold, 0.85) : withAlpha(AppColors.petalWhite, 0.42)}
        />
      </div>
      <input
        className="money-input"
        value={value}
        aria-label={hint}
        placeholder={hint}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        onChange={(e) => onChanged(e.target.value)}
        style={{
          flex: 1,
          minWidth: 0,
          height: 48,
          padding: '0 0 0 4px',
          background: 'transparent',
          border: 'none',
          outline: 'none',
          ...AppTypography.outfitWhite,
          fontSize: 14,
          color: AppColors.petalWhite,
          // TextField text inherits M3 bodyLarge's 0.5 letter spacing.
          letterSpacing: 0.5,
          ['--hint-color' as string]: withAlpha(AppColors.petalWhite, 0.62),
          ['--hint-size' as string]: '13.5px',
        }}
      />
      {value !== '' ? (
        <div style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <button
            type="button"
            className="bare-button"
            aria-label="Clear"
            title="Clear"
            onClick={() => onChanged('')}
            style={{
              width: 40,
              height: 40,
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="close" size={18} color={withAlpha(AppColors.petalWhite, 0.52)} />
          </button>
        </div>
      ) : (
        <div style={{ width: 16, flexShrink: 0 }} />
      )}
    </div>
  );
}

function StoryCard({ entries }: { entries: JournalEntry[] }) {
  const words = entries.reduce((t, e) => t + e.wordCount, 0);
  const wrote = useMemo(() => new Set(entries.map((e) => journalDayKey(e.createdAt))), [entries]);
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const shadows: BoxShadow[] = [
    { color: withAlpha(AppColors.deepRose, 0.16), blur: 20, offset: [0, 8] },
    { color: withAlpha(AppColors.inkDeep, 0.4), blur: 10, offset: [0, 4] },
  ];
  const now = new Date();
  return (
    <div style={{ padding: '0 16px', flexShrink: 0 }}>
      <div style={{ position: 'relative' }}>
        {shadows.map((s, i) => (
          <div key={i} aria-hidden style={shadowLayer(s, { radius: 22 })} />
        ))}
        <div
          ref={ref}
          style={{
            position: 'relative',
            padding: '17.2px 19.2px 15.2px',
            background: linear(
              [withAlpha(AppColors.plum, 0.55), withAlpha(AppColors.velvet, 0.7), withAlpha(AppColors.inkDeep, 0.85)],
              {
                begin: Align.topLeft,
                end: Align.bottomRight,
                size: size ?? [1, 1],
              },
            ),
            borderRadius: 22,
            boxShadow: `inset 0 0 0 1.2px ${withAlpha(AppColors.blushGold, 0.28)}`,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div
                style={{
                  ...AppTypography.handwrittenTitle,
                  fontSize: 25,
                  lineHeight: lineHeight(25, 1.1),
                  color: AppColors.blushGold,
                }}
              >
                our story so far
              </div>
              <div style={{ height: 3 }} />
              <div
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 11.5,
                  lineHeight: lineHeight(11.5),
                  color: withAlpha(AppColors.petalWhite, 0.65),
                }}
              >
                every word is a piece of us
              </div>
            </div>
            <div style={{ width: 8 }} />
            <Stat value={`${entries.length}`} label="entries" icon="menu_book" />
            <div style={{ width: 6 }} />
            <Stat value={journalNumberFormat(words)} label="words" icon="draw" />
            <div style={{ width: 6 }} />
            <Stat value={`${wrote.size}`} label="days" icon="calendar_today" />
          </div>
          <div style={{ height: 14 }} />
          <div
            style={{
              padding: '9px 13px',
              background: withAlpha(AppColors.inkDeep, 0.45),
              borderRadius: AppRadius.full,
              boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.08)}`,
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <Icon name="auto_awesome" size={13} color={AppColors.blushGold} />
            <div style={{ width: 6 }} />
            <span
              style={{
                ...AppTypography.outfitMedium,
                fontSize: 11,
                lineHeight: lineHeight(11),
                letterSpacing: 0.4,
                color: withAlpha(AppColors.petalWhite, 0.65),
              }}
            >
              last 2 weeks
            </span>
            <div style={{ flex: 1 }} />
            {Array.from({ length: 14 }, (_, i) => {
              const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (13 - i));
              const filled = wrote.has(journalDayKey(day));
              const isToday = i === 13;
              const dot = isToday ? 11 : 8.5;
              const glow = isToday ? AppColors.auroraGold : AppColors.blushGold;
              return (
                <div key={i} style={{ paddingLeft: i === 0 ? 0 : 5, display: 'flex' }}>
                  <div
                    style={{
                      width: dot,
                      height: dot,
                      borderRadius: '50%',
                      background: filled ? glow : withAlpha(AppColors.moonlight, 0.14),
                      boxShadow:
                        [
                          isToday ? `inset 0 0 0 1.2px ${AppColors.petalWhite}` : '',
                          filled ? `0 0 ${isToday ? 8 : 4}px ${withAlpha(glow, isToday ? 0.6 : 0.4)}` : '',
                        ]
                          .filter(Boolean)
                          .join(', ') || undefined,
                    }}
                  />
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

function Stat({ value, label, icon }: { value: string; label: string; icon: string }) {
  return (
    <div
      style={{
        padding: '6px 10px',
        background: withAlpha(AppColors.inkDeep, 0.4),
        borderRadius: 10,
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.08)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <Icon name={icon} size={11} color={withAlpha(AppColors.blushGold, 0.85)} />
        <div style={{ width: 4 }} />
        <span
          style={{ ...AppTypography.outfitHeading, fontSize: 14, lineHeight: lineHeight(14, 1.1), color: AppColors.blushGold }}
        >
          {value}
        </span>
      </div>
      <div style={{ height: 2 }} />
      <span
        style={{
          ...AppTypography.outfitMedium,
          fontSize: 9.5,
          lineHeight: lineHeight(9.5),
          letterSpacing: 0.3,
          color: withAlpha(AppColors.petalWhite, 0.6),
        }}
      >
        {label}
      </span>
    </div>
  );
}

const rail: CSSProperties = {
  flexShrink: 0,
  display: 'flex',
  alignItems: 'stretch',
  overflowX: 'auto',
  padding: '0 16px',
};

function ChapterRail({
  entries,
  selected,
  onSelect,
}: {
  entries: JournalEntry[];
  selected: JournalCategory | null;
  onSelect: (c: JournalCategory | null) => void;
}) {
  return (
    <div className="no-scrollbar" style={{ ...rail, height: 42 }}>
      <ChapterPill
        emoji="✨"
        name="All"
        count={entries.length}
        color={AppColors.blushGold}
        selected={selected == null}
        onTap={() => onSelect(null)}
      />
      {JOURNAL_CATEGORIES.map((c) => (
        <div key={c.id} style={{ paddingLeft: 8, display: 'flex' }}>
          <ChapterPill
            emoji={c.emoji}
            name={c.displayName}
            count={entries.filter((e) => e.category === c.id).length}
            color={journalCategoryColor(c.id)}
            selected={selected === c.id}
            onTap={() => onSelect(c.id)}
          />
        </div>
      ))}
    </div>
  );
}

function ChapterPill({
  emoji,
  name,
  count,
  color,
  selected,
  onTap,
}: {
  emoji: string;
  name: string;
  count: number;
  color: string;
  selected: boolean;
  onTap: () => void;
}) {
  const border = selected ? 1.3 : 1;
  return (
    <div style={{ position: 'relative', flexShrink: 0, display: 'flex' }}>
      {selected && (
        <div
          aria-hidden
          style={shadowLayer({ color: withAlpha(color, 0.25), blur: 10, offset: [0, 3] }, { radius: AppRadius.full })}
        />
      )}
      <button
        type="button"
        className="bare-button"
        onClick={onTap}
        style={{
          position: 'relative',
          padding: `0 ${13 + border}px`,
          background: selected
            ? linear([withAlpha(color, 0.3), withAlpha(color, 0.12)], { begin: Align.topCenter, end: Align.bottomCenter })
            : Derived.panelGlass,
          borderRadius: AppRadius.full,
          boxShadow: `inset 0 0 0 ${border}px ${selected ? withAlpha(color, 0.7) : withAlpha(AppColors.moonlight, 0.11)}`,
          transition: 'background 180ms, box-shadow 180ms',
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <span style={{ fontSize: 13, lineHeight: mixedLineHeight(13) }}>{emoji}</span>
        <div style={{ width: 6 }} />
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 11.5,
            lineHeight: lineHeight(11.5),
            color: selected ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.75),
            whiteSpace: 'nowrap',
          }}
        >
          {name}
        </span>
        {count > 0 && (
          <>
            <div style={{ width: 6 }} />
            <span
              style={{
                padding: '1.5px 6px',
                background: selected ? withAlpha(color, 0.3) : withAlpha(AppColors.moonlight, 0.08),
                borderRadius: AppRadius.full,
                ...AppTypography.outfitBold,
                fontSize: 10,
                lineHeight: lineHeight(10),
                color: selected ? AppColors.petalWhite : color,
              }}
            >
              {count}
            </span>
          </>
        )}
      </button>
    </div>
  );
}

function AuthorRow({ filters, onChange }: { filters: Filters; onChange: (f: Filters) => void }) {
  const gap = (w: number) => <div style={{ width: w, flexShrink: 0 }} />;
  return (
    <div className="no-scrollbar" style={{ ...rail, height: 34 }}>
      <FilterChip
        label="All authors"
        selected={filters.author == null}
        accent={AppColors.softLavender}
        onTap={() => onChange({ ...filters, author: null })}
      />
      {gap(6)}
      <FilterChip
        label="Khent"
        dotAuthor="khentsgdz"
        selected={filters.author === 'khentsgdz'}
        accent={AppColors.auroraTeal}
        onTap={() => onChange({ ...filters, author: 'khentsgdz' })}
      />
      {gap(6)}
      <FilterChip
        label="Clair"
        dotAuthor="clairjassen"
        selected={filters.author === 'clairjassen'}
        accent={AppColors.auroraRose}
        onTap={() => onChange({ ...filters, author: 'clairjassen' })}
      />
      {gap(10)}
      <div style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}>
        <div style={{ width: 1, height: 16, background: withAlpha(AppColors.moonlight, 0.12) }} />
      </div>
      {gap(10)}
      <FilterChip
        label="📌 Pinned"
        selected={filters.pinnedOnly}
        accent={AppColors.blushGold}
        onTap={() => onChange({ ...filters, pinnedOnly: !filters.pinnedOnly })}
      />
      {gap(6)}
      <FilterChip
        label="🔒 Locked"
        selected={filters.lockedOnly}
        accent={AppColors.warmAmber}
        onTap={() => onChange({ ...filters, lockedOnly: !filters.lockedOnly })}
      />
    </div>
  );
}

function FilterChip({
  label,
  selected,
  accent,
  dotAuthor,
  onTap,
}: {
  label: string;
  selected: boolean;
  accent: string;
  dotAuthor?: string;
  onTap: () => void;
}) {
  const border = selected ? 1.2 : 1;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        flexShrink: 0,
        padding: `0 ${11 + border}px`,
        background: selected ? withAlpha(accent, 0.18) : Derived.panelGlass,
        borderRadius: AppRadius.full,
        boxShadow: `inset 0 0 0 ${border}px ${selected ? withAlpha(accent, 0.7) : withAlpha(AppColors.moonlight, 0.1)}`,
        transition: 'background 160ms, box-shadow 160ms',
        display: 'flex',
        alignItems: 'center',
      }}
    >
      {dotAuthor && (
        <>
          <AuthorDot author={dotAuthor} size={14} />
          <div style={{ width: 5 }} />
        </>
      )}
      <span
        style={{
          ...AppTypography.outfitBold,
          fontSize: 11,
          lineHeight: mixedLineHeight(11),
          color: selected ? accent : withAlpha(AppColors.petalWhite, 0.65),
          whiteSpace: 'nowrap',
        }}
      >
        {label}
      </span>
    </button>
  );
}

function MemoryCapsule() {
  const [entry, setEntry] = useState<JournalEntry | null>(null);
  useEffect(() => {
    let live = true;
    journalService.getOnThisDay().then(
      (data) => live && setEntry(data[0] ?? null),
      () => undefined,
    );
    return () => {
      live = false;
    };
  }, []);
  if (entry == null) return null;
  const p = preview(entry);
  const text = entry.isLocked ? 'A sealed page from the past...' : p.length > 60 ? `${p.slice(0, 60)}…` : p;
  return (
    <div style={{ padding: '4px 16px', flexShrink: 0 }}>
      <button
        type="button"
        className="bare-button"
        onClick={() => showEntryDetail(entry)}
        style={{
          width: '100%',
          padding: '13px 15px',
          background: linear([withAlpha(AppColors.blushGold, 0.16), withAlpha(AppColors.deepRose, 0.14)]),
          borderRadius: AppRadius.lg,
          boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.blushGold, 0.28)}`,
          display: 'flex',
          alignItems: 'center',
          textAlign: 'left',
        }}
      >
        <div
          style={{
            width: 36,
            height: 36,
            borderRadius: '50%',
            background: withAlpha(AppColors.blushGold, 0.14),
            boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.blushGold, 0.35)}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <Icon name="history" size={17} color={AppColors.blushGold} />
        </div>
        <div style={{ width: 12 }} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 10,
              lineHeight: lineHeight(10),
              fontWeight: 700,
              letterSpacing: 0.6,
              color: AppColors.blushGold,
            }}
          >
            On this day in {entry.createdAt.getFullYear()}
          </div>
          <div style={{ height: 2 }} />
          <div
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 12,
              lineHeight: lineHeight(12),
              color: withAlpha(AppColors.petalWhite, 0.85),
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            "{entry.title === '' ? 'Untitled' : entry.title}" — {text}
          </div>
        </div>
        <Icon name="chevron_right" size={18} color={AppColors.blushGold} />
      </button>
    </div>
  );
}

function SearchResults({
  term,
  filters,
  noMatch,
  onRetry,
}: {
  term: string;
  filters: Filters;
  noMatch: React.ReactNode;
  onRetry: () => void;
}) {
  const [state, setState] = useState<{ data?: JournalEntry[]; error?: boolean }>({});
  const scrollRef = useRememberedScroll<HTMLDivElement>('journal:entries');
  useEffect(() => {
    let live = true;
    journalService.search(term).then(
      (data) => live && setState({ data }),
      () => live && setState({ error: true }),
    );
    return () => {
      live = false;
    };
  }, [term]);
  if (state.error)
    return (
      <EverglowEmptyState icon="menu_book_outlined" title="Search failed" subtitle="Try again" ctaLabel="Retry" onCta={onRetry} />
    );
  if (state.data == null) {
    return (
      <div style={{ padding: 20 }}>
        <EverglowSkeleton height={120} radius={16} />
      </div>
    );
  }
  const entries = visibleEntries(state.data, filters);
  if (entries.length === 0) return <>{noMatch}</>;
  return (
    <div ref={scrollRef} className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '8px 16px 96px' }}>
      {entries.map((e, i) => (
        <div key={e.id} style={{ paddingTop: i === 0 ? 0 : 14 }}>
          <JournalEntryCard entry={e} onTap={() => showEntryDetail(e)} />
        </div>
      ))}
    </div>
  );
}

function PaginatedJournalList({ firstPage, isFiltered }: { firstPage: JournalEntry[]; isFiltered: boolean }) {
  const [older, setOlder] = useState<JournalEntry[]>([]);
  const [cursor, setCursor] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [exhausted, setExhausted] = useState(false);
  const [error, setError] = useState(false);
  const scrollRef = useRememberedScroll<HTMLDivElement>('journal:entries:paged');
  const canPage = !isFiltered && firstPage.length >= FIRST_PAGE_SIZE && !exhausted;

  const loadMore = async () => {
    if (loadingMore || !canPage) return;
    setLoadingMore(true);
    setError(false);
    try {
      const isFirst = cursor == null && older.length === 0;
      const page =
        isFirst && firstPage.length > 0
          ? await journalService.fetchOlderThan(firstPage[firstPage.length - 1].createdAt, 20)
          : await journalService.fetchPage(cursor, 20);
      const seen = new Set([...firstPage, ...older].map((e) => e.id));
      setOlder([...older, ...page.items.filter((e) => !seen.has(e.id))]);
      setCursor(page.nextCursor);
      setExhausted(page.nextCursor == null);
    } catch {
      setError(true);
    } finally {
      setLoadingMore(false);
    }
  };

  const entries = [...firstPage, ...older];
  const headerFor = (idx: number): 'pinned' | 'month' | null => {
    const e = entries[idx];
    if (idx === 0) return e.isPinned ? 'pinned' : 'month';
    const prev = entries[idx - 1];
    if (prev.isPinned && e.isPinned) return null;
    if (prev.isPinned !== e.isPinned) return 'month';
    if (prev.createdAt.getMonth() !== e.createdAt.getMonth() || prev.createdAt.getFullYear() !== e.createdAt.getFullYear())
      return 'month';
    return null;
  };

  return (
    <div ref={scrollRef} className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '8px 16px 96px' }}>
      {entries.map((e, i) => {
        const header = headerFor(i);
        return (
          <div key={e.id} style={{ paddingTop: i === 0 ? 0 : 14, display: 'flex', flexDirection: 'column' }}>
            {header != null && (
              <>
                {header === 'pinned' ? <PinnedHeader /> : <MonthHeader date={e.createdAt} />}
                <div style={{ height: 10 }} />
              </>
            )}
            <JournalEntryCard entry={e} onTap={() => showEntryDetail(e)} />
          </div>
        );
      })}
      {canPage && (
        <div style={{ paddingTop: entries.length > 0 ? 14 : 0 }}>
          {error ? (
            <EverglowEmptyState
              icon="menu_book_outlined"
              title="Could not load older entries"
              subtitle="Try again"
              ctaLabel="Retry"
              onCta={() => void loadMore()}
            />
          ) : (
            <div style={{ padding: '12px 0', display: 'flex', justifyContent: 'center' }}>
              {loadingMore ? (
                <CircularProgress size={24} strokeWidth={2} color={AppColors.deepRose} />
              ) : (
                <TextButton onPressed={() => void loadMore()}>Load older entries</TextButton>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function PinnedHeader() {
  return (
    <div style={{ padding: '10px 4px 6px', display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          padding: '5px 11px',
          background: withAlpha(AppColors.blushGold, 0.12),
          borderRadius: AppRadius.full,
          boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.blushGold, 0.3)}`,
          display: 'flex',
          alignItems: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name="push_pin" size={12} color={AppColors.blushGold} />
        <div style={{ width: 5 }} />
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 11,
            lineHeight: lineHeight(11),
            letterSpacing: 0.5,
            color: AppColors.blushGold,
          }}
        >
          Pinned with love
        </span>
      </div>
      <div style={{ width: 10 }} />
      <div style={{ flex: 1, height: 1, background: linear([withAlpha(AppColors.blushGold, 0.25), 'rgba(0,0,0,0)']) }} />
    </div>
  );
}

function MonthHeader({ date }: { date: Date }) {
  return (
    <div style={{ padding: '16px 4px 8px', display: 'flex', alignItems: 'center' }}>
      <div style={{ flex: 1, height: 1, background: linear(['rgba(0,0,0,0)', withAlpha(AppColors.blushGold, 0.28)]) }} />
      <div style={{ padding: '0 12px', display: 'flex', alignItems: 'center' }}>
        <Icon name="auto_awesome" size={11} color={withAlpha(AppColors.blushGold, 0.65)} />
        <div style={{ width: 7 }} />
        <span
          style={{
            ...AppTypography.cormorantBold,
            fontSize: 18,
            lineHeight: lineHeight(18),
            letterSpacing: 0.8,
            color: AppColors.blushGold,
          }}
        >
          {journalMonthLabel(date)}
        </span>
        <div style={{ width: 7 }} />
        <Icon name="auto_awesome" size={11} color={withAlpha(AppColors.blushGold, 0.65)} />
      </div>
      <div style={{ flex: 1, height: 1, background: linear([withAlpha(AppColors.blushGold, 0.28), 'rgba(0,0,0,0)']) }} />
    </div>
  );
}
