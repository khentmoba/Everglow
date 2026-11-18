// Port of lib/features/cinema/presentation/widgets/tabs/cinema_browse_tab.dart.
import { useEffect, useRef, useState } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { BROWSE_GROUP_META, BROWSE_GROUPS, CINEMA_BROWSE_OPTIONS, type BrowseCategoryOption } from './cinemaBrowseConfig';
import { cinemaTopInset } from './CinemaLibraryTab';
import { NetflixColors, type MediaItem } from './cinemaTypes';
import { NetflixPosterCard } from './NetflixUi';
import { discoverMedia } from './tmdbService';

type State = { selected: string | null; results: MediaItem[]; page: number; hasMore: boolean; loading: boolean; failed: boolean };
const EMPTY: State = { selected: null, results: [], page: 0, hasMore: true, loading: false, failed: false };

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
  const [state, setState] = useState<State>(EMPTY);
  const stateRef = useRef(state);
  stateRef.current = state;
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
    if (s.loading || !s.hasMore || !s.selected) return;
    const option = CINEMA_BROWSE_OPTIONS.find((o) => o.id === s.selected)!;
    const v = version.current;
    const page = s.page + 1;
    const loading = { ...s, loading: true, failed: false };
    stateRef.current = loading;
    setState(loading);
    try {
      const { results } = await discoverMedia({
        mediaType: option.mediaType,
        sortBy: option.sortBy,
        withGenres: option.genreId == null ? undefined : [option.genreId],
        withoutGenres: option.withoutGenres,
        yearGte: option.yearGte,
        yearLte: option.yearLte,
        voteAverageGte: option.voteAverageGte,
        voteCountGte: option.voteCountGte,
        withOriginalLanguage: option.withOriginalLanguage,
        page,
        failOnError: true,
      });
      if (!alive.current || v !== version.current) return;
      const cur = stateRef.current;
      const seen = new Set(cur.results.map((m) => `${m.mediaType}:${m.tmdbId}`));
      const filterAnime = option.id === 'lang-ja' || !!option.withoutGenres?.includes(16);
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

  const select = (option: BrowseCategoryOption) => {
    version.current++;
    const fresh = { ...EMPTY, selected: option.id };
    stateRef.current = fresh;
    setState(fresh);
    void loadMore(fresh);
  };

  useEffect(() => {
    const option = initialOptionId ? CINEMA_BROWSE_OPTIONS.find((o) => o.id === initialOptionId) : undefined;
    if (option) select(option);
    // Only on mount, like initState's post-frame callback.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
          Browse
        </div>
      </div>
      {BROWSE_GROUPS.map((group) => {
        const options = CINEMA_BROWSE_OPTIONS.filter((o) => o.group === group);
        if (options.length === 0) return null;
        return (
          <div key={group} style={{ padding: '14px 0 6px' }}>
            <div
              style={{
                padding: `0 ${h}px 10px`,
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
                <BrowsePill key={o.id} label={o.label} selected={state.selected === o.id} onTap={() => select(o)} />
              ))}
              {/* ListView's end padding. */}
              <div style={{ flex: `0 0 ${h - 8}px` }} />
            </div>
          </div>
        );
      })}
      <div style={{ height: 16 }} />
      {state.selected && <Results state={state} width={width} h={h} onMediaTap={onMediaTap} onLoadMore={() => void loadMore()} />}
      <div style={{ height: 100 }} />
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
      <div
        style={{
          padding: `18px ${h}px 12px`,
          ...AppTypography.outfitWhite,
          fontSize: 13,
          lineHeight: lineHeight(13),
          fontWeight: 500,
          color: NetflixColors.textMuted,
        }}
      >
        {state.results.length} titles
      </div>
      <div style={{ padding: `0 ${h}px`, display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 10 }}>
        {state.results.map((item) => (
          <div key={`${item.mediaType}:${item.tmdbId}`} style={{ aspectRatio: '0.67' }}>
            <NetflixPosterCard item={item} compact onTap={() => onMediaTap(item)} />
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
  const bg = selected ? NetflixColors.accent : NetflixColors.surface;
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
        border: `1px solid ${selected ? NetflixColors.accent : NetflixColors.hairline}`,
        background: hovered ? `linear-gradient(${withAlpha('#FFFFFF', 0.08)}, ${withAlpha('#FFFFFF', 0.08)}), ${bg}` : bg,
        ...AppTypography.outfitHeading,
        fontSize: 12,
        lineHeight: lineHeight(12),
        color: NetflixColors.textPrimary,
        whiteSpace: 'nowrap',
      }}
    >
      {label}
    </button>
  );
}
