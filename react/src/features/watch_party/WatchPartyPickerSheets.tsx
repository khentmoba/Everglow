// Port of lib/features/watch_party/presentation/widgets/watch_party_media_picker_sheet.dart
// and watch_party_episode_picker_sheet.dart.
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Logger } from '../../core/system/logger';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { orZero } from '../../core/theme/motion';
import { boxShadow, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { fetchAnimexPage } from '../anime/animeService';
import { TmdbImages, type MediaItem } from '../cinema/cinemaTypes';
import { fetchTrending, searchMulti } from '../cinema/tmdbService';
import type { MediaRef } from './watchPartyService';

export type WatchPartyPickerCategory = 'cinema' | 'anime';

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

/** The 48px drag-handle row the app theme's `showDragHandle` puts above every modal sheet. */
export function SheetFrame({ children }: { children: ReactNode }) {
  return (
    <div style={{ maxWidth: 640, margin: '0 auto' }}>
      <div style={{ height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ width: 32, height: 4, borderRadius: 2, background: withAlpha(AppColors.moonlight, 0.35) }} />
      </div>
      {children}
    </div>
  );
}

const sheetBox = {
  background: AppColors.inkDeep,
  borderRadius: '24px 24px 0 0',
  borderTop: `1.5px solid ${withAlpha(AppColors.moonlight, 0.2)}`,
  boxSizing: 'border-box' as const,
  display: 'flex',
  flexDirection: 'column' as const,
};

/** Opens `WatchPartyMediaPickerSheet`; resolves with the picked title, or null. */
export function showWatchPartyMediaPicker(opts: { currentTitle: string; initialCategory: WatchPartyPickerCategory }) {
  return showModalBottomSheet<MediaRef>((close) => (
    <SheetFrame>
      <WatchPartyMediaPickerSheet {...opts} onSelect={(m) => close(m)} onClose={() => close(null)} />
    </SheetFrame>
  ));
}

function WatchPartyMediaPickerSheet({
  currentTitle,
  initialCategory,
  onSelect,
  onClose,
}: {
  currentTitle: string;
  initialCategory: WatchPartyPickerCategory;
  onSelect: (m: MediaRef) => void;
  onClose: () => void;
}) {
  const { height } = useViewport();
  const [category, setCategory] = useState(initialCategory);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [results, setResults] = useState<MediaItem[]>([]);
  const trending = useRef<{ cinema: MediaItem[]; anime: MediaItem[] }>({ cinema: [], anime: [] });
  const live = useRef({ category, query });
  live.current = { category, query };
  const debounce = useRef<number | undefined>(undefined);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    void (async () => {
      try {
        const cinema = await fetchTrending('all', 'day');
        if (!alive) return;
        trending.current.cinema = cinema;
        if (live.current.category === 'cinema' && !live.current.query.trim()) {
          setResults(cinema);
          setLoading(false);
        }
      } catch (e) {
        Logger.e('WatchPartyMediaPicker: initial cinema trending load failed', e);
        if (alive) setLoading(false);
      }
      try {
        const page = await fetchAnimexPage({ sort: 'TRENDING_DESC', perPage: 20 });
        if (!alive) return;
        trending.current.anime = page.items;
        if (live.current.category === 'anime' && !live.current.query.trim()) {
          setResults(page.items);
          setLoading(false);
        }
      } catch (e) {
        Logger.e('WatchPartyMediaPicker: initial anime trending load failed', e);
      }
    })();
    return () => {
      alive = false;
      window.clearTimeout(debounce.current);
    };
  }, []);

  const performSearch = async (q: string, cat: WatchPartyPickerCategory) => {
    setLoading(true);
    setErrorMessage(null);
    try {
      const items =
        cat === 'cinema'
          ? (await searchMulti(q)).results.filter((m) => m.mediaType === 'movie' || m.mediaType === 'tv')
          : (await fetchAnimexPage({ search: q, perPage: 25 })).items;
      if (live.current.query.trim() !== q || live.current.category !== cat) return;
      setResults(items);
      setLoading(false);
    } catch {
      setLoading(false);
      setErrorMessage('Could not load search results. Please try again.');
    }
  };

  const changeCategory = (next: WatchPartyPickerCategory) => {
    if (next === category) return;
    setCategory(next);
    live.current.category = next;
    const q = query.trim();
    if (q) {
      void performSearch(q, next);
    } else {
      setResults(trending.current[next]);
      setLoading(false);
      setErrorMessage(null);
    }
  };

  const changeQuery = (text: string) => {
    setQuery(text);
    live.current.query = text;
    window.clearTimeout(debounce.current);
    const q = text.trim();
    if (!q) {
      setLoading(false);
      setErrorMessage(null);
      setResults(trending.current[category]);
      return;
    }
    setLoading(true);
    debounce.current = window.setTimeout(() => void performSearch(q, category), 350);
  };

  const pickMovie = (item: MediaItem) => {
    const isAnime = item.isAnime || category === 'anime';
    onSelect({
      tmdbId: item.tmdbId,
      malId: isAnime && item.tmdbId > 0 ? item.tmdbId : undefined,
      mediaType: 'movie',
      isAnime,
      title: item.title,
      posterPath: item.posterPath,
    });
  };

  const pickTvOrAnime = async (item: MediaItem, isAnime: boolean) => {
    const picked = await showEpisodePicker({
      title: item.title,
      isAnime,
      maxEpisodes: isAnime ? (item.episodeCount ?? 26) : 24,
    });
    if (!picked) return;
    onSelect({
      tmdbId: item.tmdbId,
      malId: isAnime && item.tmdbId > 0 ? item.tmdbId : undefined,
      mediaType: isAnime && item.format.toLowerCase() === 'movie' ? 'movie' : 'tv',
      isAnime,
      season: isAnime ? 1 : picked.season,
      episode: picked.episode,
      episodeCount: item.episodeCount,
      title: item.title,
      posterPath: item.posterPath,
    });
  };

  const sheetHeight = clamp(height * 0.88, 420, 780);
  const searching = query.trim().length > 0;

  let list: ReactNode;
  if (loading && results.length === 0) {
    list = (
      <Centered>
        <CircularProgress size={36} strokeWidth={4} color={AppColors.deepRose} />
      </Centered>
    );
  } else if (errorMessage) {
    list = (
      <Centered>
        <div style={{ padding: 24, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <Icon name="error_outline" size={36} color={AppColors.deepRose} />
          <div style={{ height: 10 }} />
          <div style={{ ...AppTypography.outfitMuted, color: AppColors.petalWhite, fontSize: 13, textAlign: 'center' }}>
            {errorMessage}
          </div>
        </div>
      </Centered>
    );
  } else if (results.length === 0) {
    list = (
      <Centered>
        <Icon name="search_off" size={44} color={AppColors.mutedPurple} />
        <div style={{ height: 10 }} />
        <div style={{ ...AppTypography.outfitHeading, color: AppColors.petalWhite, fontSize: 15, lineHeight: lineHeight(15) }}>
          No titles found
        </div>
        <div style={{ height: 4 }} />
        <div style={{ ...AppTypography.outfitMuted, color: AppColors.mutedPurple, fontSize: 12, lineHeight: lineHeight(12) }}>
          Try another search term or check spelling
        </div>
      </Centered>
    );
  } else {
    const header = searching
      ? `Search Results (${results.length})`
      : category === 'cinema'
        ? '🔥 Trending Movies & TV'
        : '🌸 Trending Anime';
    list = (
      <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto', padding: '6px 18px' }}>
        <div
          style={{
            padding: '4px 0 10px',
            ...AppTypography.outfitBold,
            color: withAlpha(AppColors.petalWhite, 0.7),
            fontSize: 12,
            lineHeight: lineHeight(12),
            letterSpacing: 0.5,
          }}
        >
          {header}
        </div>
        {results.map((item, i) => (
          <MediaTile
            key={`${item.mediaType}:${item.tmdbId}:${i}`}
            item={item}
            category={category}
            onPickMovie={pickMovie}
            onPickSeries={(it, anime) => void pickTvOrAnime(it, anime)}
          />
        ))}
      </div>
    );
  }

  return (
    <div style={{ ...sheetBox, height: sheetHeight }}>
      <div
        style={{
          width: 44,
          height: 4,
          margin: '10px auto 8px',
          borderRadius: 2,
          background: withAlpha(AppColors.petalWhite, 0.25),
          flexShrink: 0,
        }}
      />
      <div style={{ padding: '4px 16px 12px 20px', display: 'flex', alignItems: 'center' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...AppTypography.outfitHeading, color: AppColors.petalWhite, fontSize: 18, lineHeight: lineHeight(18) }}>
            Choose Title to Watch Together
          </div>
          <div style={{ height: 2 }} />
          <div
            style={{
              ...AppTypography.outfitMuted,
              color: withAlpha(AppColors.petalWhite, 0.6),
              fontSize: 12,
              lineHeight: lineHeight(12),
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {currentTitle ? `Currently watching: ${currentTitle}` : 'Pick any movie, TV show, or anime'}
          </div>
        </div>
        <CloseButton onClick={onClose} size={24} />
      </div>
      <div
        style={{
          margin: '4px 18px',
          padding: 4,
          background: AppColors.shimmerBase,
          borderRadius: AppRadius.full,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
          display: 'flex',
        }}
      >
        <CategoryTab active={category === 'cinema'} icon="movie" label="Movies & TV" onTap={() => changeCategory('cinema')} />
        <CategoryTab active={category === 'anime'} icon="auto_awesome" label="Anime" onTap={() => changeCategory('anime')} />
      </div>
      <div
        style={{
          margin: '10px 18px 6px',
          background: AppColors.shimmerBase,
          borderRadius: 14,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.16)}`,
          display: 'flex',
          alignItems: 'center',
          minHeight: 50,
          boxSizing: 'border-box',
        }}
      >
        <div style={{ width: 48, display: 'flex', justifyContent: 'center', flexShrink: 0 }}>
          <Icon name="search" size={20} color={AppColors.mutedPurple} />
        </div>
        <input
          value={query}
          onChange={(e) => changeQuery(e.target.value)}
          placeholder={category === 'cinema' ? 'Search movies or TV shows...' : 'Search anime (English or Romaji)...'}
          className="picker-search-input"
          style={{
            flex: 1,
            minWidth: 0,
            border: 'none',
            outline: 'none',
            background: 'transparent',
            padding: '12px 0 12px 4px',
            ...AppTypography.outfitWhite,
            fontSize: 14,
            caretColor: AppColors.deepRose,
          }}
        />
        {query && (
          <button
            type="button"
            className="bare-button"
            aria-label="Clear"
            onClick={() => changeQuery('')}
            style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
          >
            <Icon name="clear" size={18} color={AppColors.mutedPurple} />
          </button>
        )}
      </div>
      <div style={{ height: 8, flexShrink: 0 }} />
      <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>{list}</div>
      <div style={{ height: 16, flexShrink: 0 }} />
    </div>
  );
}

function Centered({ children }: { children: ReactNode }) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {children}
    </div>
  );
}

function CloseButton({ onClick, size }: { onClick: () => void; size: number }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="Close"
      onClick={onClick}
      style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: '50%' }}
    >
      <Icon name="close" size={size} color={AppColors.petalWhite} />
    </button>
  );
}

function CategoryTab({ active, icon, label, onTap }: { active: boolean; icon: string; label: string; onTap: () => void }) {
  const color = active ? '#FFFFFF' : AppColors.mutedPurple;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        flex: 1,
        padding: '8px 0',
        borderRadius: AppRadius.full,
        background: active ? withAlpha(AppColors.deepRose, 0.85) : 'transparent',
        boxShadow: active ? boxShadow([{ color: withAlpha(AppColors.deepRose, 0.4), blur: 8, offset: [0, 2] }]) : 'none',
        transition: `background ${orZero(200)}ms, box-shadow ${orZero(200)}ms`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name={icon} size={16} color={color} />
      <div style={{ width: 6 }} />
      <span
        style={{
          ...AppTypography.outfitHeading,
          color,
          fontSize: 13,
          lineHeight: lineHeight(13),
          fontWeight: active ? 600 : 500,
        }}
      >
        {label}
      </span>
    </button>
  );
}

function MediaTile({
  item,
  category,
  onPickMovie,
  onPickSeries,
}: {
  item: MediaItem;
  category: WatchPartyPickerCategory;
  onPickMovie: (m: MediaItem) => void;
  onPickSeries: (m: MediaItem, isAnime: boolean) => void;
}) {
  const isAnime = category === 'anime' || item.isAnime;
  const isMovie = item.mediaType === 'movie' || (isAnime && item.format.toLowerCase() === 'movie');
  const p = item.posterPath;
  const posterUrl = p ? (p.startsWith('http') || p.startsWith('/assets') ? p : `${TmdbImages.poster}${p}`) : '';
  const badge = isAnime ? (isMovie ? 'Anime Movie' : 'Anime Series') : isMovie ? 'Movie' : 'TV Show';
  const extra = isAnime
    ? item.episodeCount && item.episodeCount > 0
      ? `${item.episodeCount} eps`
      : item.year || 'Anime'
    : item.year || 'Cinema';
  const hue = isAnime ? AppColors.animeGold : AppColors.deepRose;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={() => (isMovie ? onPickMovie(item) : onPickSeries(item, isAnime))}
      style={{
        width: '100%',
        marginBottom: 10,
        padding: 8,
        boxSizing: 'border-box',
        background: withAlpha(AppColors.shimmerBase, 0.5),
        borderRadius: 12,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
        display: 'flex',
        alignItems: 'center',
        textAlign: 'left',
      }}
    >
      <div
        style={{
          width: 50,
          height: 72,
          borderRadius: 8,
          overflow: 'hidden',
          flexShrink: 0,
          background: AppColors.shimmerBase,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {posterUrl ? (
          <img src={posterUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
        ) : (
          <Icon name="movie" size={24} color={AppColors.mutedPurple} />
        )}
      </div>
      <div style={{ width: 12 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          className="clamp-2"
          style={{
            ...AppTypography.outfitHeading,
            color: AppColors.petalWhite,
            fontSize: 14.5,
            lineHeight: lineHeight(14.5),
            fontWeight: 600,
          }}
        >
          {item.title}
        </div>
        <div style={{ height: 6 }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <span
            style={{
              padding: '2px 6px',
              borderRadius: 4,
              background: withAlpha(hue, 0.15),
              ...AppTypography.outfitMuted,
              color: hue,
              fontSize: 10.5,
              lineHeight: lineHeight(10.5),
              fontWeight: 600,
            }}
          >
            {badge}
          </span>
          <div style={{ width: 8 }} />
          <span
            style={{ ...AppTypography.outfitMuted, color: AppColors.mutedPurple, fontSize: 11.5, lineHeight: lineHeight(11.5) }}
          >
            {extra}
          </span>
        </div>
      </div>
      <div style={{ width: 8 }} />
      <div
        style={{
          padding: '6px 12px',
          borderRadius: AppRadius.full,
          background: withAlpha(AppColors.deepRose, 0.2),
          border: `1px solid ${withAlpha(AppColors.deepRose, 0.5)}`,
          display: 'flex',
          alignItems: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name="play_arrow" size={15} color={AppColors.petalWhite} />
        <div style={{ width: 4 }} />
        <span
          style={{
            ...AppTypography.outfitHeading,
            color: AppColors.petalWhite,
            fontSize: 12,
            lineHeight: lineHeight(12),
            fontWeight: 600,
          }}
        >
          {isMovie ? 'Watch' : 'Episodes'}
        </span>
      </div>
    </button>
  );
}

/** Opens `WatchPartyEpisodePickerSheet`; resolves with the season and episode, or null. */
export function showEpisodePicker(opts: { title: string; isAnime: boolean; maxEpisodes?: number; maxSeasons?: number }) {
  return showModalBottomSheet<{ season: number; episode: number }>((close) => (
    <SheetFrame>
      <EpisodePickerSheet {...opts} onConfirm={(season, episode) => close({ season, episode })} onClose={() => close(null)} />
    </SheetFrame>
  ));
}

function EpisodePickerSheet({
  title,
  isAnime,
  maxSeasons = 20,
  maxEpisodes: maxEpisodesRaw = 24,
  onConfirm,
  onClose,
}: {
  title: string;
  isAnime: boolean;
  maxSeasons?: number;
  maxEpisodes?: number;
  onConfirm: (season: number, episode: number) => void;
  onClose: () => void;
}) {
  const { height } = useViewport();
  const maxEpisodes = clamp(maxEpisodesRaw, 1, 2000);
  const [season, setSeason] = useState(1);
  const [episode, setEpisode] = useState(1);
  const label = (text: string) => (
    <div style={{ ...AppTypography.outfitHeading, color: AppColors.petalWhite, fontSize: 13, lineHeight: lineHeight(13) }}>
      {text}
    </div>
  );
  return (
    <div style={{ ...sheetBox, height: clamp(height * 0.86, 380, 720), padding: '14px 20px 20px' }}>
      <div
        style={{ width: 44, height: 4, margin: '0 auto', borderRadius: 2, background: withAlpha(AppColors.petalWhite, 0.22) }}
      />
      <div style={{ height: 14 }} />
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...AppTypography.outfitHeading, color: AppColors.petalWhite, fontSize: 18, lineHeight: lineHeight(18) }}>
            Pick an episode
          </div>
          <div style={{ height: 2 }} />
          <div
            style={{
              ...AppTypography.outfitMuted,
              color: AppColors.mutedPurple,
              fontSize: 12,
              lineHeight: lineHeight(12),
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {title}
          </div>
        </div>
        <CloseButton onClick={onClose} size={20} />
      </div>
      <div style={{ height: 12 }} />
      {!isAnime && (
        <>
          {label('Season')}
          <div style={{ height: 6 }} />
          <div
            style={{
              padding: '2px 8px',
              background: AppColors.shimmerBase,
              borderRadius: 12,
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
            }}
          >
            <StepButton icon="remove_circle_outline" enabled={season > 1} onTap={() => setSeason(season - 1)} />
            <span
              style={{ ...AppTypography.outfitHeading, color: AppColors.petalWhite, fontSize: 17, lineHeight: lineHeight(17) }}
            >
              {season}
            </span>
            <StepButton icon="add_circle_outline" enabled={season < maxSeasons} onTap={() => setSeason(season + 1)} />
          </div>
          <div style={{ height: 14 }} />
        </>
      )}
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <div style={{ flex: 1 }}>{label('Episode')}</div>
        <span style={{ ...AppTypography.outfitHeading, color: AppColors.roseQuartz, fontSize: 12, lineHeight: lineHeight(12) }}>
          S{season} E{episode}
        </span>
      </div>
      <div style={{ height: 8 }} />
      <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
        <EpisodeGrid count={maxEpisodes} active={episode} onPick={setEpisode} />
      </div>
      <div style={{ height: 10 }} />
      <button
        type="button"
        className="bare-button"
        onClick={() => onConfirm(season, episode)}
        style={{
          height: 48,
          flexShrink: 0,
          borderRadius: AppRadius.full,
          background: linear([AppColors.auroraRose, AppColors.deepRose]),
          boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.4), blur: 12, offset: [0, 4] }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="play_arrow" size={20} color="#FFFFFF" />
        <div style={{ width: 6 }} />
        <span style={{ ...AppTypography.outfitHeading, color: '#FFFFFF', fontSize: 14, lineHeight: lineHeight(14) }}>
          {isAnime ? `Watch episode ${episode}` : `Watch S${season} E${episode}`}
        </span>
      </button>
    </div>
  );
}

/** SliverGridDelegateWithMaxCrossAxisExtent(58, spacing 8, aspect 1.35). */
function EpisodeGrid({ count, active, onPick }: { count: number; active: number; onPick: (n: number) => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setWidth(el.clientWidth));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  const cols = Math.max(1, Math.ceil(width / (58 + 8)));
  const cell = (width - (cols - 1) * 8) / cols;
  return (
    <div
      ref={ref}
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`,
        gridAutoRows: cell > 0 ? cell / 1.35 : 40,
        gap: 8,
        paddingBottom: 8,
      }}
    >
      {Array.from({ length: count }, (_, i) => {
        const n = i + 1;
        const on = n === active;
        return (
          <button
            key={n}
            type="button"
            className="bare-button"
            aria-label={`Episode ${n}`}
            aria-pressed={on}
            onClick={() => onPick(n)}
            style={{
              borderRadius: AppRadius.xs,
              background: on ? withAlpha(AppColors.deepRose, 0.85) : AppColors.shimmerBase,
              border: `1px solid ${on ? AppColors.roseQuartz : withAlpha(AppColors.moonlight, 0.14)}`,
              boxSizing: 'border-box',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              ...AppTypography.outfitHeading,
              fontSize: 13,
              color: on ? AppColors.petalWhite : Derived.textMedium,
            }}
          >
            {n}
          </button>
        );
      })}
    </div>
  );
}

function StepButton({ icon, enabled, onTap }: { icon: string; enabled: boolean; onTap: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      disabled={!enabled}
      onClick={onTap}
      style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: '50%' }}
    >
      <Icon name={icon} size={24} color={enabled ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.2)} />
    </button>
  );
}
