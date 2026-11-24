// Port of lib/features/cinema/presentation/widgets/tabs/cinema_browse_tab.dart.
import { useEffect, useRef, useState } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import {
  BROWSE_GROUP_META,
  BROWSE_GROUPS,
  CINEMA_BROWSE_OPTIONS,
  type BrowseCategoryGroup,
  type BrowseCategoryOption,
} from './cinemaBrowseConfig';
import { cinemaTopInset } from './CinemaLibraryTab';
import { NetflixColors, type MediaItem } from './cinemaTypes';
import { NetflixPosterCard } from './NetflixUi';
import { discoverMedia } from './tmdbService';

type Selection = {
  collection: string;
  genre: string | null;
  decade: string | null;
  language: string | null;
  sort: string | null;
};
const DEFAULT_SELECTION: Selection = {
  collection: 'collection-movies',
  genre: null,
  decade: null,
  language: null,
  sort: null,
};

type State = { results: MediaItem[]; page: number; hasMore: boolean; loading: boolean; failed: boolean };
const EMPTY: State = { results: [], page: 0, hasMore: true, loading: false, failed: false };

const optionById = (id: string | null) => (id ? CINEMA_BROWSE_OPTIONS.find((o) => o.id === id) : undefined);

/** Facets combine: collection is the base, genre/decade/language narrow it, sort orders it. */
function queryFor(sel: Selection) {
  const collection = optionById(sel.collection) ?? CINEMA_BROWSE_OPTIONS[0];
  const genre = optionById(sel.genre);
  const decade = optionById(sel.decade);
  const language = optionById(sel.language);
  const sort = optionById(sel.sort);
  const mediaType = genre?.mediaType ?? collection.mediaType;
  return {
    mediaType,
    sortBy: sort?.sortBy ?? collection.sortBy,
    withGenres: genre?.genreId != null ? [genre.genreId] : undefined,
    withoutGenres: language?.withoutGenres ?? collection.withoutGenres,
    withOriginalLanguage: language?.withOriginalLanguage ?? collection.withOriginalLanguage,
    yearGte: decade?.yearGte ?? collection.yearGte,
    yearLte: decade?.yearLte ?? collection.yearLte,
    voteAverageGte: decade?.voteAverageGte ?? language?.voteAverageGte ?? collection.voteAverageGte,
    voteCountGte: sort?.voteCountGte ?? collection.voteCountGte,
  };
}

function summaryOf(sel: Selection): string {
  return [optionById(sel.genre)?.label, optionById(sel.decade)?.label, optionById(sel.language)?.label]
    .filter(Boolean)
    .join(' · ');
}

export function CinemaBrowseTab({
  width,
  initialOptionId,
  onMediaTap,
}: {
  width: number;
  /** `_pendingBrowseOption`; the page remounts the tab (`browse-$seed`) when it changes. */
  initialOptionId: string | null;
  onMediaTap: (m: MediaItem) => void;
}) {
  const isDesktop = width >= 1024;
  const h = isDesktop ? 48 : 16;
  const [selection, setSelection] = useState<Selection>(() => {
    const option = optionById(initialOptionId);
    if (!option) return DEFAULT_SELECTION;
    if (option.group === 'collection') return { ...DEFAULT_SELECTION, collection: option.id };
    return { ...DEFAULT_SELECTION, [option.group]: option.id } as Selection;
  });
  const [state, setState] = useState<State>(EMPTY);
  const stateRef = useRef(state);
  stateRef.current = state;
  const selectionRef = useRef(selection);
  selectionRef.current = selection;
  const version = useRef(0);
  const alive = useRef(true);
  useEffect(
    () => () => {
      alive.current = false;
    },
    [],
  );

  const loadMore = async (fresh?: State) => {
    const s = fresh ?? stateRef.current;
    if (s.loading || !s.hasMore) return;
    const v = version.current;
    const page = s.page + 1;
    const loading = { ...s, loading: true, failed: false };
    stateRef.current = loading;
    setState(loading);
    try {
      const { results } = await discoverMedia({ ...queryFor(selectionRef.current), page, failOnError: true });
      if (!alive.current || v !== version.current) return;
      const cur = stateRef.current;
      const seen = new Set(cur.results.map((m) => `${m.mediaType}:${m.tmdbId}`));
      const sel = selectionRef.current;
      const filterAnime = sel.language === 'lang-ja' || sel.genre === 'genre-movie-16';
      const added = results.filter((m) => {
        if (filterAnime && m.isAnime) return false;
        const key = `${m.mediaType}:${m.tmdbId}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });
      setState({
        ...cur,
        results: [...cur.results, ...added],
        page,
        hasMore: results.length >= 20 && page < 500,
        loading: false,
      });
    } catch {
      if (!alive.current || v !== version.current) return;
      setState({ ...stateRef.current, failed: true, loading: false });
    }
  };

  const apply = (next: Selection) => {
    version.current++;
    selectionRef.current = next;
    setSelection(next);
    const fresh = { ...EMPTY };
    stateRef.current = fresh;
    setState(fresh);
    void loadMore(fresh);
  };

  // Browse shows titles at once; filters narrow what is already there.
  useEffect(() => {
    const fresh = { ...EMPTY };
    stateRef.current = fresh;
    void loadMore(fresh);
  }, []);

  const pick = (option: BrowseCategoryOption) => {
    const group = option.group;
    if (group === 'genre' && selectionRef.current.genre === option.id) {
      return apply({ ...selectionRef.current, genre: null });
    }
    if (group === 'collection') {
      const nextGenre = optionById(selectionRef.current.genre);
      // A movie genre cannot filter a TV collection.
      const keepGenre = nextGenre && nextGenre.mediaType === option.mediaType ? selectionRef.current.genre : null;
      return apply({ ...selectionRef.current, collection: option.id, genre: keepGenre });
    }
    const current = selectionRef.current[group as 'decade' | 'language' | 'sort'];
    return apply({ ...selectionRef.current, [group]: current === option.id ? null : option.id });
  };

  const [facetsOpen, setFacetsOpen] = useState(false);
  const facetCount = [selection.genre, selection.decade, selection.language, selection.sort].filter(Boolean).length;
  const collectionOptions = CINEMA_BROWSE_OPTIONS.filter((o) => o.group === 'collection');
  const collection = optionById(selection.collection) ?? CINEMA_BROWSE_OPTIONS[0];
  const summary = summaryOf(selection);
  const clearFacets = () =>
    apply({ ...selectionRef.current, genre: null, decade: null, language: null, sort: null });

  return (
    <div>
      <div style={{ padding: `${cinemaTopInset(width)}px ${h}px 4px` }}>
        <div
          style={{
            ...AppTypography.outfitHeading,
            fontSize: isDesktop ? 22 : 20,
            lineHeight: lineHeight(isDesktop ? 22 : 20),
            color: NetflixColors.textPrimary,
          }}
        >
          {collection.group === 'collection' ? collection.label : 'Browse'}
        </div>
        <div style={{ height: 6 }} />
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            ...AppTypography.outfitWhite,
            fontSize: 13,
            lineHeight: lineHeight(13),
            color: NetflixColors.textMuted,
          }}
        >
          <span>{state.loading && state.results.length === 0 ? 'Loading titles…' : `${state.results.length} titles`}</span>
          {summary ? <span>· {summary}</span> : null}
          {(selection.genre || selection.decade || selection.language) && (
            <button
              type="button"
              className="bare-button"
              onClick={clearFacets}
              style={{
                ...AppTypography.outfitHeading,
                fontSize: 13,
                lineHeight: lineHeight(13),
                // Clearing filters is not a destructive act; red is for the brand.
                color: NetflixColors.textPrimary,
                textDecoration: 'underline',
              }}
            >
              Clear
            </button>
          )}
        </div>
      </div>

      <div style={{ height: 8 }} />
      {/* Collections stay in reach; the long facet rows open on request, so a
          filter tapped above the grid does not push the posters off-screen. */}
      <FilterGroup group="collection" options={collectionOptions} selection={selection} onPick={pick} h={h} isDesktop={isDesktop} />
      <div style={{ padding: `0 ${h}px`, display: 'flex', alignItems: 'center', gap: 10 }}>
        <button
          type="button"
          className="bare-button"
          aria-label="Filters"
          aria-expanded={facetsOpen}
          onClick={() => setFacetsOpen((open) => !open)}
          style={{
            height: 44,
            padding: '0 14px',
            display: 'inline-flex',
            alignItems: 'center',
            gap: 8,
            borderRadius: 999,
            border: `1px solid ${facetCount > 0 ? NetflixColors.textPrimary : NetflixColors.hairline}`,
            ...AppTypography.outfitHeading,
            fontSize: 13,
            color: facetCount > 0 ? NetflixColors.textPrimary : NetflixColors.textSecondary,
          }}
        >
          <Icon name="tune" size={16} color={facetCount > 0 ? NetflixColors.textPrimary : NetflixColors.textSecondary} />
          <span>{facetCount > 0 ? `Filters · ${facetCount}` : 'Filters'}</span>
          <Icon name={facetsOpen ? 'expand_less' : 'expand_more'} size={16} color={NetflixColors.textSecondary} />
        </button>
      </div>
      {facetsOpen && (
        <div style={{ paddingTop: 4 }}>
          {BROWSE_GROUPS.filter((g) => g !== 'collection').map((group) => {
            const options = CINEMA_BROWSE_OPTIONS.filter((o) => {
              if (o.group !== group) return false;
              if (group === 'genre') return o.mediaType === collection.mediaType;
              return true;
            });
            if (options.length === 0) return null;
            return (
              <FilterGroup key={group} group={group} options={options} selection={selection} onPick={pick} h={h} isDesktop={isDesktop} />
            );
          })}
        </div>
      )}
      <div style={{ height: 12 }} />
      <Results state={state} width={width} h={h} onMediaTap={onMediaTap} onLoadMore={() => void loadMore()} />
      <div style={{ height: 100 }} />
    </div>
  );
}

function FilterGroup({
  group,
  options,
  selection,
  onPick,
  h,
  isDesktop,
}: {
  group: BrowseCategoryGroup;
  options: BrowseCategoryOption[];
  selection: Selection;
  onPick: (o: BrowseCategoryOption) => void;
  h: number;
  isDesktop: boolean;
}) {
  const selectedId = selection[group as 'genre' | 'decade' | 'language' | 'sort'];
  // Results are always in some order. When nothing has been picked, the first
  // chip is that order, so it reads as selected rather than adding a second chip
  // with the same meaning at the end of a scrolling row.
  const effectiveId = selectedId ?? (group === 'sort' ? (options[0]?.id ?? null) : null);
  return (
    <div style={{ padding: '18px 0 0' }}>
      <div
        style={{
          padding: `0 ${h}px 8px`,
          ...AppTypography.outfitHeading,
          fontSize: isDesktop ? 16 : 15,
          lineHeight: lineHeight(isDesktop ? 16 : 15),
          color: NetflixColors.textSecondary,
        }}
      >
        {BROWSE_GROUP_META[group].title}
      </div>
      <div className="no-scrollbar" style={{ height: 48, display: 'flex', gap: 8, padding: `0 ${h}px`, overflowX: 'auto' }}>
        {options.map((o) => (
          <BrowsePill key={o.id} label={o.label} selected={effectiveId === o.id} onTap={() => onPick(o)} />
        ))}
        <div style={{ flex: `0 0 ${h - 8}px` }} />
      </div>
    </div>
  );
}

function Results({
  state,
  width,
  h,
  onMediaTap,
  onLoadMore,
}: {
  state: State;
  width: number;
  h: number;
  onMediaTap: (m: MediaItem) => void;
  onLoadMore: () => void;
}) {
  if (state.loading && state.results.length === 0) {
    return (
      <div style={{ padding: 48, display: 'flex', justifyContent: 'center' }}>
        <CircularProgress size={28} strokeWidth={2.5} color={NetflixColors.accent} />
      </div>
    );
  }
  if (state.failed && state.results.length === 0) return <BrowseError onRetry={onLoadMore} />;
  if (state.results.length === 0) {
    return (
      <div
        style={{
          padding: '20px 16px 32px',
          textAlign: 'center',
          ...AppTypography.outfitWhite,
          fontSize: 13.5,
          lineHeight: lineHeight(13.5),
          color: NetflixColors.textMuted,
        }}
      >
        No titles found for this filter.
      </div>
    );
  }
  const cols = width >= 1024 ? 6 : width >= 600 ? 5 : 3;
  return (
    <>
      <div style={{ padding: `0 ${h}px`, display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 10 }}>
        {state.results.map((item) => (
          <div key={`${item.mediaType}:${item.tmdbId}`}>
            <div style={{ aspectRatio: '0.67' }}>
              <NetflixPosterCard item={item} compact caption onTap={() => onMediaTap(item)} />
            </div>
          </div>
        ))}
      </div>
      {state.failed ? (
        <BrowseError onRetry={onLoadMore} />
      ) : (
        state.hasMore && (
          <div style={{ padding: '18px 16px 8px', display: 'flex', justifyContent: 'center' }}>
            <FlatTextButton background={NetflixColors.surface} disabled={state.loading} onPressed={onLoadMore}>
              {state.loading ? 'Loading…' : 'Load More'}
            </FlatTextButton>
          </div>
        )
      )}
    </>
  );
}

function BrowseError({ onRetry }: { onRetry: () => void }) {
  return (
    <div style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ ...AppTypography.outfitWhite, fontSize: 14, lineHeight: lineHeight(14), color: NetflixColors.textSecondary }}>
        Couldn’t load titles. Please try again.
      </div>
      <FlatTextButton onPressed={onRetry}>Retry</FlatTextButton>
    </div>
  );
}

/** M3 TextButton with `minimumSize: Size(48, 48)` and a white foreground. */
function FlatTextButton({
  children,
  onPressed,
  background,
  disabled = false,
}: {
  children: string;
  onPressed: () => void;
  background?: string;
  disabled?: boolean;
}) {
  const [hovered, setHovered] = useState(false);
  const fg = NetflixColors.textPrimary;
  return (
    <button
      type="button"
      className="bare-button"
      disabled={disabled}
      onClick={onPressed}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        minWidth: 48,
        height: 48,
        padding: '0 12px',
        borderRadius: 24,
        background:
          hovered && !disabled
            ? `linear-gradient(${withAlpha(fg, 0.08)}, ${withAlpha(fg, 0.08)}), ${background ?? 'transparent'}`
            : (background ?? 'transparent'),
        ...AppTypography.labelLarge,
        lineHeight: lineHeight(14),
        color: disabled ? withAlpha(AppColors.petalWhite, 0.38) : fg,
      }}
    >
      {children}
    </button>
  );
}

function BrowsePill({ label, selected, onTap }: { label: string; selected: boolean; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  // One selected language everywhere: a white chip (same as My List), not a red block.
  const bg = selected ? NetflixColors.textPrimary : NetflixColors.surface;
  return (
    <button
      type="button"
      className="bare-button"
      aria-pressed={selected}
      onClick={onTap}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        flexShrink: 0,
        minWidth: 48,
        height: 48,
        padding: '0 14px',
        boxSizing: 'border-box',
        borderRadius: 24,
        border: `1px solid ${selected ? NetflixColors.textPrimary : NetflixColors.hairline}`,
        background: hovered ? `linear-gradient(${withAlpha('#FFFFFF', 0.08)}, ${withAlpha('#FFFFFF', 0.08)}), ${bg}` : bg,
        ...AppTypography.outfitHeading,
        fontSize: 12,
        lineHeight: lineHeight(12),
        color: selected ? NetflixColors.background : NetflixColors.textPrimary,
        whiteSpace: 'nowrap',
      }}
    >
      {label}
    </button>
  );
}
