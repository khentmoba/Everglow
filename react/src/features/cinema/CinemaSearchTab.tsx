// Port of lib/features/cinema/presentation/widgets/tabs/cinema_search_tab.dart.
import { useEffect, useRef, useState } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import { cinemaTopInset } from './CinemaLibraryTab';
import { NetflixColors, type MediaItem } from './cinemaTypes';
import { NetflixPosterCard } from './NetflixUi';
import { searchMulti } from './tmdbService';

type State = {
  results: MediaItem[];
  searching: boolean;
  page: number;
  hasMore: boolean;
  failed: boolean;
  loadingMore: boolean;
};
const RESET: State = { results: [], searching: false, page: 0, hasMore: false, failed: false, loadingMore: false };
type ResultType = 'all' | 'movie' | 'tv';
type Filters = { type: ResultType; years: string[] };
const NO_FILTERS: Filters = { type: 'all', years: [] };

export function CinemaSearchTab({
  width,
  height,
  trendingGlobal,
  onMediaTap,
  onBrowse,
}: {
  width: number;
  height: number;
  trendingGlobal: MediaItem[];
  onMediaTap: (m: MediaItem) => void;
  /** The empty state's way out: the Browse shelves. */
  onBrowse: () => void;
}) {
  const isDesktop = width >= 1024;
  const h = isDesktop ? 48 : 16;
  const cols = isDesktop ? 6 : width >= 600 ? 5 : 3;
  const [query, setQuery] = useState('');
  const [state, setState] = useState<State>(RESET);
  const [filters, setFilters] = useState<Filters>(NO_FILTERS);
  const stateRef = useRef(state);
  stateRef.current = state;
  const version = useRef(0);
  const debounce = useRef<ReturnType<typeof setTimeout> | null>(null);
  const input = useRef<HTMLInputElement>(null);

  useEffect(
    () => () => {
      version.current++;
      if (debounce.current) clearTimeout(debounce.current);
    },
    [],
  );

  const performSearch = async (q: string, page = 1) => {
    const v = version.current;
    const pending = { ...stateRef.current, searching: page === 1, loadingMore: page > 1, failed: false };
    stateRef.current = pending;
    setState(pending);
    try {
      const { results } = await searchMulti(q, page, { failOnError: true });
      if (v !== version.current) return;
      const cur = stateRef.current;
      const seen = new Set(cur.results.map((m) => `${m.mediaType}:${m.tmdbId}`));
      const added = results.filter((m) => {
        const key = `${m.mediaType}:${m.tmdbId}`;
        if (m.isAnime || seen.has(key)) return false;
        seen.add(key);
        return true;
      });
      setState({
        ...cur,
        results: [...cur.results, ...added],
        page,
        // A page that brings nothing new means there is nothing left to load.
        hasMore: added.length > 0 && results.length > 0 && page < 500,
        searching: false,
        loadingMore: false,
      });
    } catch {
      if (v !== version.current) return;
      setState({ ...stateRef.current, failed: true, searching: false, loadingMore: false });
    }
  };

  const onSearchChanged = (q: string) => {
    if (debounce.current) clearTimeout(debounce.current);
    const v = ++version.current;
    const next = { ...RESET, searching: q.trim().length > 0 };
    stateRef.current = next;
    setState(next);
    setFilters(NO_FILTERS);
    if (!q.trim()) return;
    debounce.current = setTimeout(() => {
      if (v === version.current) void performSearch(q.trim());
    }, 500);
  };

  const runSearch = (q: string) => {
    setQuery(q);
    onSearchChanged(q);
    if (debounce.current) clearTimeout(debounce.current);
    if (q.trim()) void performSearch(q.trim());
  };

  const year = new Date().getFullYear();
  const chips = [
    ...(
      [
        ['All', 'all'],
        ['Movies', 'movie'],
        ['TV shows', 'tv'],
      ] as const
    ).map(([label, value]) => ({
      label,
      selected: filters.type === value,
      onTap: () => setFilters((f) => ({ ...f, type: value })),
    })),
    ...[0, 1, 2].map((offset) => {
      const y = String(year - offset);
      const selected = filters.years.includes(y);
      return {
        label: y,
        selected,
        onTap: () => setFilters((f) => ({ ...f, years: selected ? f.years.filter((x) => x !== y) : [...f.years, y] })),
      };
    }),
    { label: 'Clear', selected: false, onTap: () => setFilters(NO_FILTERS) },
  ];

  let filtered = state.results;
  if (filters.type !== 'all') filtered = filtered.filter((i) => i.mediaType === filters.type);
  if (filters.years.length) filtered = filtered.filter((i) => filters.years.includes(i.year));

  const grid = (items: MediaItem[]) => (
    <div style={{ padding: `0 ${h}px`, display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 10 }}>
      {items.map((item) => (
        <div key={`${item.mediaType}:${item.tmdbId}`} style={{ aspectRatio: '0.67' }}>
          <NetflixPosterCard item={item} compact onTap={() => onMediaTap(item)} />
        </div>
      ))}
    </div>
  );

  const heading = (text: string, top: number) => (
    <div
      style={{
        padding: `${top}px ${h}px 14px`,
        ...AppTypography.outfitHeading,
        fontSize: isDesktop ? 18 : 16,
        lineHeight: lineHeight(isDesktop ? 18 : 16),
        color: NetflixColors.textPrimary,
      }}
    >
      {text}
    </div>
  );

  return (
    // A Column filling the screen: the spinner and empty state centre in what is left.
    <div style={{ minHeight: height, display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: `${cinemaTopInset(width)}px ${h}px 4px` }}>
        <div
          style={{
            ...AppTypography.outfitHeading,
            fontSize: isDesktop ? 22 : 20,
            lineHeight: lineHeight(isDesktop ? 22 : 20),
            color: NetflixColors.textPrimary,
          }}
        >
          Search
        </div>
        <div style={{ height: 14 }} />
        <div
          style={{
            background: NetflixColors.surface,
            borderRadius: 8,
            border: `1px solid ${NetflixColors.hairline}`,
            display: 'flex',
            alignItems: 'center',
          }}
          onClick={() => input.current?.focus()}
        >
          <div style={{ width: 48, height: 48, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="search" size={21} color={NetflixColors.textSecondary} />
          </div>
          <input
            ref={input}
            value={query}
            placeholder="Search movie and TV titles"
            aria-label="Search movie and TV titles"
            className="cinema-search-input"
            onChange={(e) => {
              setQuery(e.target.value);
              onSearchChanged(e.target.value);
            }}
            style={{
              flex: 1,
              minWidth: 0,
              border: 'none',
              outline: 'none',
              background: 'transparent',
              padding: '15px 0 15px 4px',
              ...AppTypography.outfitWhite,
              fontSize: 16,
              lineHeight: '23px',
              color: NetflixColors.textPrimary,
              caretColor: AppColors.deepRose,
            }}
          />
          {query && (
            <button
              type="button"
              className="bare-button"
              aria-label="Clear search"
              title="Clear search"
              onClick={() => {
                setQuery('');
                onSearchChanged('');
              }}
              style={{
                width: 48,
                height: 48,
                flexShrink: 0,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                borderRadius: '50%',
              }}
            >
              <Icon name="close" size={18} color={NetflixColors.textMuted} />
            </button>
          )}
        </div>
      </div>

      {state.results.length > 0 && !state.searching && (
        <div
          className="no-scrollbar"
          style={{ margin: `10px ${h}px 4px`, height: 48, display: 'flex', gap: 8, overflowX: 'auto' }}
        >
          {chips.map((c) => (
            <SearchPill key={c.label} label={c.label} selected={c.selected} onTap={c.onTap} />
          ))}
        </div>
      )}

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        {state.searching ? (
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CircularProgress size={28} strokeWidth={2.5} color={NetflixColors.accent} />
          </div>
        ) : !query.trim() ? (
          <div>
            {trendingGlobal.length > 0 && (
              <div style={{ padding: `20px ${h}px 14px` }}>
                <div
                  style={{
                    ...AppTypography.outfitHeading,
                    fontSize: isDesktop ? 18 : 16,
                    lineHeight: lineHeight(isDesktop ? 18 : 16),
                    color: NetflixColors.textPrimary,
                  }}
                >
                  Popular Searches
                </div>
                <div style={{ height: 12 }} />
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                  {trendingGlobal.slice(0, 6).map((item) => (
                    <SearchPill
                      key={`${item.mediaType}:${item.tmdbId}`}
                      label={item.title}
                      selected={false}
                      onTap={() => runSearch(item.title)}
                    />
                  ))}
                </div>
              </div>
            )}
            {heading('Popular Now', 20)}
            {grid(trendingGlobal)}
            <div style={{ height: 120 }} />
          </div>
        ) : (
          <div>
            {filtered.length === 0 && !state.failed && (
              <div style={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 32px' }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                  <Icon name="search_off" size={42} color={NetflixColors.textMuted} />
                  <div style={{ height: 14 }} />
                  <div
                    style={{
                      ...AppTypography.outfitHeading,
                      fontSize: 17,
                      lineHeight: lineHeight(17),
                      color: NetflixColors.textPrimary,
                    }}
                  >
                    {state.results.length === 0 ? 'No results found' : 'No titles match these filters'}
                  </div>
                  <div style={{ height: 6 }} />
                  <div
                    style={{
                      textAlign: 'center',
                      ...AppTypography.outfitWhite,
                      fontSize: 13,
                      lineHeight: lineHeight(13),
                      color: NetflixColors.textMuted,
                    }}
                  >
                    {state.results.length === 0 ? 'Try a different title, or browse the shelves.' : 'Clear the filters or load more titles.'}
                  </div>
                  <div style={{ height: 14 }} />
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => {
                      if (state.results.length === 0) {
                        onBrowse();
                      } else {
                        setFilters(NO_FILTERS);
                      }
                    }}
                    style={{
                      height: 44,
                      padding: '0 18px',
                      borderRadius: 22,
                      background: NetflixColors.textPrimary,
                      ...AppTypography.outfitHeading,
                      fontSize: 13,
                      lineHeight: lineHeight(13),
                      color: NetflixColors.background,
                    }}
                  >
                    {state.results.length === 0 ? 'Browse movies' : 'Clear filters'}
                  </button>
                </div>
              </div>
            )}
            {filtered.length > 0 && (
              <div
                style={{
                  padding: `2px ${h}px 10px`,
                  ...AppTypography.outfitWhite,
                  fontSize: 13,
                  lineHeight: lineHeight(13),
                  color: NetflixColors.textMuted,
                }}
              >
                {`${filtered.length} ${filtered.length === 1 ? 'result' : 'results'} for “${query.trim()}”`}
              </div>
            )}
            {grid(filtered)}
            {(state.failed || state.hasMore) && (
              <div style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                {state.failed && (
                  <div
                    style={{
                      ...AppTypography.outfitWhite,
                      fontSize: 14,
                      lineHeight: lineHeight(14),
                      color: NetflixColors.textSecondary,
                    }}
                  >
                    Couldn’t search titles. Please try again.
                  </div>
                )}
                <FilledTextButton disabled={state.loadingMore} onPressed={() => void performSearch(query.trim(), state.page + 1)}>
                  {state.loadingMore ? 'Loading…' : state.failed ? 'Retry' : 'Load More'}
                </FilledTextButton>
              </div>
            )}
            <div style={{ height: 120 }} />
          </div>
        )}
      </div>
    </div>
  );
}

/** M3 TextButton, `minimumSize: Size(48, 48)`, white on the surface colour. */
function FilledTextButton({ children, onPressed, disabled }: { children: string; onPressed: () => void; disabled: boolean }) {
  const [hovered, setHovered] = useState(false);
  const fg = NetflixColors.textPrimary;
  const bg = NetflixColors.surface;
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
        background: hovered && !disabled ? `linear-gradient(${withAlpha(fg, 0.08)}, ${withAlpha(fg, 0.08)}), ${bg}` : bg,
        ...AppTypography.labelLarge,
        lineHeight: lineHeight(14),
        color: disabled ? withAlpha(AppColors.petalWhite, 0.38) : fg,
      }}
    >
      {children}
    </button>
  );
}

function SearchPill({ label, selected, onTap }: { label: string; selected: boolean; onTap: () => void }) {
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
        // 14px padding drawn around the 1px side.
        padding: '0 13px',
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
