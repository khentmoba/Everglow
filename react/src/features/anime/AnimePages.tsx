import { useEffect, useMemo, useState } from 'react';
import { formattedDuration, formattedSize, offlineMedia, useOfflineMedia, type OfflineMediaItem } from '../../core/services/offlineMedia';
import { Align, boxShadow, linear } from '../../core/theme/paint';
import { withAlpha } from '../../core/theme/colors';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { LinearProgress } from '../../shared/widgets/LinearProgress';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import type { MediaItem } from '../cinema/cinemaTypes';
import {
  animexStoreActions,
  currentAnimeSeason,
  fetchAiringSchedule,
  fetchAnimexPage,
  type AnimexHistoryEntry,
  type AnimexMediaPage,
  type AnimexPageKind,
  type AnimexPlaylist,
  type AnimexScheduleEntry,
} from './animeService';
import { AnimeXTokens, bebasStyle, dmSansStyle, interBodyStyle } from './animeTokens';
import {
  AnimeXBadge,
  AnimeXFooter,
  AnimeXGrid,
  AnimeXGridSkeleton,
  AnimeXPosterRow,
  AnimeXPrimaryButton,
  AnimeXRowSkeleton,
  AnimeXSecondaryButton,
  AnimeXSectionHeader,
  AnimeXSpotlight,
  AnimeXTicker,
} from './AnimeUi';

const GENRES = [
  'Action', 'Adventure', 'Comedy', 'Drama', 'Ecchi', 'Fantasy', 'Horror', 'Isekai',
  'Mahou Shoujo', 'Mecha', 'Music', 'Mystery', 'Psychological', 'Reincarnation',
  'Romance', 'Sci-Fi', 'Slice of Life', 'Sports', 'Supernatural', 'Thriller',
];

const SORT_OPTIONS: [string, string][] = [
  ['TRENDING_DESC', 'Trending'],
  ['POPULARITY_DESC', 'Popularity'],
  ['SCORE_DESC', 'Top Rated'],
  ['START_DATE_DESC', 'Newest'],
  ['FAVOURITES_DESC', 'Favorites'],
];

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const SEASONS: ['WINTER' | 'SPRING' | 'SUMMER' | 'FALL', string][] = [
  ['WINTER', 'Winter'],
  ['SPRING', 'Spring'],
  ['SUMMER', 'Summer'],
  ['FALL', 'Fall'],
];

const PLAYLIST_EMOJIS: [string, string][] = [
  ['star', '★'], ['heart', '♥'], ['fire', '🔥'], ['book', '📖'], ['tv', '📺'],
  ['sparkles', '✨'], ['rocket', '🚀'], ['music', '🎵'], ['movie', '🎬'], ['crown', '👑'],
];

export interface AnimeNavActions {
  width: number;
  height: number;
  userName: string;
  titleJapanese: boolean;
  library: MediaItem[];
  history: AnimexHistoryEntry[];
  continueWatching: AnimexHistoryEntry[];
  playlists: AnimexPlaylist[];
  onWatch: (item: MediaItem, episode?: number) => void;
  /** Open the title's watch page scrolled to its about synopsis. */
  onInfo: (item: MediaItem) => void;
  onTrailer: (item: MediaItem) => void;
  onNavigate: (page: AnimexPageKind) => void;
  onPresetBrowse: (preset: { sort?: string; status?: string; season?: string; year?: number; genre?: string }) => void;
  onToggleLibrary: (item: MediaItem, add: boolean) => void;
  onClearHistory: (entries: AnimexHistoryEntry[]) => Promise<void>;
  onOpenDmca: () => void;
  onOpenSearch: () => void;
}

// ---------- Home ----------

interface HomeRowState {
  id: string;
  title: string;
  icon: string;
  loading: boolean;
  items: MediaItem[];
}

function ContinueWatchingCard({ entry, onClick, width }: { entry: AnimexHistoryEntry; onClick: () => void; width: number }) {
  const [hovered, setHovered] = useState(false);
  const badgeLabel = entry.isMovie
    ? 'MOVIE'
    : entry.totalEpisodes > 1
      ? `EP ${entry.episode}/${entry.totalEpisodes}`
      : `EP ${entry.episode}`;
  const baseResume = entry.isMovie ? 'Resume movie' : `Resume Episode ${entry.episode}`;
  const resumeSec = entry.resumeSeconds;
  const resumeLabel =
    resumeSec != null && resumeSec > 0
      ? `${baseResume} · ${Math.floor(resumeSec / 60)}:${String(resumeSec % 60).padStart(2, '0')}`
      : baseResume;

  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        position: 'relative',
        width,
        height: 200,
        flexShrink: 0,
        borderRadius: AnimeXTokens.radius2xl,
        border: `1px solid ${hovered ? AnimeXTokens.accent : AnimeXTokens.border}`,
        boxShadow: boxShadow([{ color: '#0000004D', blur: 16, offset: [0, 6] }]),
        overflow: 'hidden',
        textAlign: 'left',
        transform: hovered ? 'translateY(-3px)' : undefined,
        transition: 'transform 180ms ease, border-color 180ms ease',
      }}
    >
      <div style={{ position: 'absolute', inset: 0, background: AnimeXTokens.surfaceRaised }}>
        {entry.posterUrl && (
          <img
            src={entry.posterUrl}
            alt={entry.title}
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          />
        )}
      </div>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: linear(['rgba(0,0,0,0.9)', 'rgba(0,0,0,0.55)'], {
            begin: Align.centerLeft,
            end: Align.centerRight,
          }),
        }}
      />
      <div style={{ position: 'absolute', left: 14, right: 62, bottom: 14, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
        <AnimeXBadge label={badgeLabel} kind="airing" />
        <div style={{ height: 10 }} />
        <div className="clamp-2" style={bebasStyle({ size: 24, color: '#FFFFFF' })}>
          {entry.title}
        </div>
        <div style={{ height: 6 }} />
        <div className="ellipsis" style={{ ...dmSansStyle({ size: 12, color: AnimeXTokens.accentWarm, weight: 600 }), maxWidth: '100%' }}>
          {resumeLabel}
        </div>
        {entry.progress != null && (
          <>
            <div style={{ height: 10 }} />
            <div style={{ width: '100%', height: 3, borderRadius: 3, background: 'rgba(255,255,255,0.15)', overflow: 'hidden' }}>
              <div style={{ width: `${Math.min(100, Math.max(0, entry.progress * 100))}%`, height: '100%', background: AnimeXTokens.accent }} />
            </div>
          </>
        )}
      </div>
      <div
        style={{
          position: 'absolute',
          right: 12,
          top: '50%',
          transform: 'translateY(-50%)',
          width: 40,
          height: 40,
          borderRadius: '50%',
          background: AnimeXTokens.accent,
          boxShadow: boxShadow([{ color: 'rgba(194,24,91,0.45)', blur: 12 }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="play_arrow" size={24} color="#FFFFFF" />
      </div>
    </button>
  );
}

export function AnimeXHomePage({ nav }: { nav: AnimeNavActions }) {
  const { season: curSeason, year: curYear } = currentAnimeSeason();
  const [rows, setRows] = useState<HomeRowState[]>([
    { id: 'trending', title: 'Trending This Week', icon: 'trending_up', loading: true, items: [] },
    { id: 'airing', title: 'Top Airing', icon: 'local_fire_department', loading: true, items: [] },
    { id: 'seasonal', title: `${curSeason} ${curYear}`, icon: 'bolt', loading: true, items: [] },
    { id: 'popular', title: 'Most Popular', icon: 'star', loading: true, items: [] },
    { id: 'completed', title: 'Recently Completed', icon: 'check_circle_outline', loading: true, items: [] },
  ]);
  const [retryCount, setRetryCount] = useState(0);

  useEffect(() => {
    let alive = true;
    const { season, year } = currentAnimeSeason();
    const specs: { id: string; opts: Parameters<typeof fetchAnimexPage>[0] }[] = [
      { id: 'trending', opts: { sort: 'TRENDING_DESC', perPage: 18, japaneseTitle: nav.titleJapanese } },
      { id: 'airing', opts: { sort: 'SCORE_DESC', status: 'RELEASING', perPage: 18, japaneseTitle: nav.titleJapanese } },
      { id: 'seasonal', opts: { season, seasonYear: year, sort: 'POPULARITY_DESC', perPage: 18, japaneseTitle: nav.titleJapanese } },
      { id: 'popular', opts: { sort: 'POPULARITY_DESC', perPage: 18, japaneseTitle: nav.titleJapanese } },
      { id: 'completed', opts: { sort: 'END_DATE_DESC', status: 'FINISHED', perPage: 18, japaneseTitle: nav.titleJapanese } },
    ];
    for (const spec of specs) {
      fetchAnimexPage(spec.opts).then((res) => {
        if (!alive) return;
        setRows((prev) => prev.map((r) => (r.id === spec.id ? { ...r, loading: false, items: res.items } : r)));
      });
    }
    return () => {
      alive = false;
    };
  }, [nav.titleJapanese, retryCount]);

  const cardWidth = nav.width < 600 ? AnimeXTokens.rowPosterWidthMobile : AnimeXTokens.rowPosterWidthDesktop;
  // A 280px card on an 820px tablet left 500px of dead space beside it.
  const continueWidth = nav.width >= 700 ? 340 : 280;
  const trending = rows[0];
  const airing = rows[1];
  const allFailed = rows.every((r) => !r.loading && r.items.length === 0);

  const viewAllForRow = (id: string) => {
    const { season, year } = currentAnimeSeason();
    if (id === 'trending') nav.onPresetBrowse({ sort: 'TRENDING_DESC' });
    else if (id === 'airing') nav.onPresetBrowse({ sort: 'SCORE_DESC', status: 'RELEASING' });
    else if (id === 'seasonal') nav.onPresetBrowse({ season, year, sort: 'POPULARITY_DESC' });
    else if (id === 'popular') nav.onPresetBrowse({ sort: 'POPULARITY_DESC' });
    else if (id === 'completed') nav.onPresetBrowse({ sort: 'END_DATE_DESC', status: 'FINISHED' });
  };

  // So the hero can say "Resume Ep 5 · 7:05" instead of "Watch Now".
  const resumeFor = (item: MediaItem) => {
    const entry = nav.continueWatching.find(
      (e) =>
        (item.anilistId != null && e.savedItem?.anilistId === item.anilistId) ||
        (item.tmdbId > 0 && e.savedItem?.tmdbId === item.tmdbId),
    );
    return entry ? { episode: entry.episode, resumeSeconds: entry.resumeSeconds } : undefined;
  };

  return (
    <div style={{ paddingBottom: 64, minHeight: '100%', display: 'flex', flexDirection: 'column' }}>
      <AnimeXSpotlight
        items={trending.items.slice(0, 5)}
        loading={trending.loading}
        width={nav.width}
        height={nav.height}
        resumeFor={resumeFor}
        onWatch={(it) => nav.onWatch(it)}
        onMoreInfo={(it) => nav.onInfo(it)}
        onTrailer={nav.onTrailer}
      />

      {nav.continueWatching.length > 0 && (
        <div style={{ marginTop: 24, marginBottom: 40 }}>
          <div style={{ padding: '0 24px' }}>
            <AnimeXSectionHeader
              icon="play_circle_filled"
              title="Continue Watching"
              viewAllLabel="History"
              onViewAll={() => nav.onNavigate('history')}
            />
          </div>
          <div className="no-scrollbar" style={{ display: 'flex', gap: 14, overflowX: 'auto', padding: '0 24px', height: 200 }}>
            {nav.continueWatching.slice(0, 12).map((e) => (
              <ContinueWatchingCard
                key={e.key}
                entry={e}
                width={continueWidth}
                onClick={() => e.savedItem && nav.onWatch(e.savedItem, e.episode)}
              />
            ))}
          </div>
        </div>
      )}

      <AnimeXTicker items={airing.items.slice(0, 14)} narrow={nav.width < 600} onSelect={(it) => nav.onWatch(it)} />

      {allFailed && (
        <div style={{ padding: '20px 24px 0' }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              padding: '14px 18px',
              background: 'rgba(194, 24, 91, 0.08)',
              borderRadius: AnimeXTokens.radiusLg,
              border: '1px solid rgba(194, 24, 91, 0.28)',
            }}
          >
            <Icon name="sync_problem" size={18} color={AnimeXTokens.accent} />
            <span style={{ ...dmSansStyle({ size: 13, weight: 600 }), flex: 1 }}>
              Anime feeds are temporarily unavailable
            </span>
            <button
              type="button"
              className="bare-button"
              onClick={() => setRetryCount((c) => c + 1)}
              style={dmSansStyle({ size: 12.5, color: AnimeXTokens.accent, weight: 700 })}
            >
              Retry
            </button>
          </div>
        </div>
      )}

      <div style={{ height: 40 }} />

      {rows.map((row) => (
        <div key={row.id} style={{ paddingBottom: 40 }}>
          <div style={{ padding: '0 24px' }}>
            <AnimeXSectionHeader icon={row.icon} title={row.title} onViewAll={() => viewAllForRow(row.id)} />
          </div>
          {row.loading ? (
            <AnimeXRowSkeleton cardWidth={cardWidth} />
          ) : row.items.length === 0 ? (
            <div style={{ padding: '0 24px' }}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  padding: '14px 18px',
                  borderRadius: AnimeXTokens.radiusLg,
                  background: AnimeXTokens.surfaceRaised,
                  border: `1px solid ${AnimeXTokens.border}`,
                }}
              >
                <Icon name="cloud_off" size={18} color={AnimeXTokens.textSecondary} />
                <span style={dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary })}>
                  Couldn&apos;t load {row.title.toLowerCase()}
                </span>
              </div>
            </div>
          ) : (
            <AnimeXPosterRow items={row.items} cardWidth={cardWidth} onSelect={(it) => nav.onWatch(it)} />
          )}
        </div>
      ))}

      <div style={{ padding: '24px 24px 0', maxWidth: 948 }}>
        <button
          type="button"
          className="bare-button"
          onClick={() => nav.onNavigate('schedule')}
          style={{
            width: '100%',
            display: 'flex',
            alignItems: 'center',
            gap: 16,
            padding: '18px 22px',
            borderRadius: AnimeXTokens.radius2xl + 4,
            background: linear(['rgba(194,24,91,0.14)', 'rgba(194,24,91,0.04)', 'rgba(24,24,34,0.6)']),
            border: '1px solid rgba(194, 24, 91, 0.25)',
            boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.3)', blur: 16, offset: [0, 6] }]),
          }}
        >
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: AnimeXTokens.radiusXl,
              background: linear([AnimeXTokens.accent, AnimeXTokens.accentHover], {
                begin: Align.topLeft,
                end: Align.bottomRight,
              }),
              boxShadow: boxShadow([{ color: 'rgba(194,24,91,0.4)', blur: 16, offset: [0, 4] }]),
              display: 'grid',
              placeItems: 'center',
              flexShrink: 0,
            }}
          >
            <Icon name="schedule" size={22} color="#FFF" />
          </div>
          <div style={{ flex: 1, textAlign: 'left' }}>
            <div style={dmSansStyle({ size: 16, weight: 800, color: AnimeXTokens.textPrimary })}>Airing Schedule</div>
            <div style={dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary })}>
              See what&apos;s airing this week — all 7 days
            </div>
          </div>
          <div
            style={{
              width: 36,
              height: 36,
              borderRadius: 99,
              background: 'rgba(194,24,91,0.12)',
              border: '1px solid rgba(194,24,91,0.4)',
              display: 'grid',
              placeItems: 'center',
            }}
          >
            <Icon name="arrow_forward" size={18} color={AnimeXTokens.accentWarm} />
          </div>
        </button>
      </div>

      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

// ---------- Browse ----------

function BrowseSelect({
  value,
  options,
  onChange,
}: {
  value: string;
  options: [string, string][];
  onChange: (value: string) => void;
}) {
  const label = options.find(([k]) => k === value)?.[1] ?? options[0]?.[1] ?? '';
  return (
    <div
      style={{
        position: 'relative',
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        padding: '9px 14px',
        flexShrink: 0,
        whiteSpace: 'nowrap',
        borderRadius: AnimeXTokens.radiusMd,
        background: 'rgba(255,255,255,0.05)',
        border: `1px solid ${AnimeXTokens.border}`,
      }}
    >
      <span style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textPrimary, weight: 600 }), whiteSpace: 'nowrap' }}>{label}</span>
      <Icon name="keyboard_arrow_down" size={16} color={AnimeXTokens.textSecondary} />
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        aria-label={label}
        style={{
          position: 'absolute',
          inset: 0,
          opacity: 0,
          cursor: 'pointer',
          background: AnimeXTokens.surfaceRaised,
          color: AnimeXTokens.textPrimary,
        }}
      >
        {options.map(([k, lbl]) => (
          <option key={k} value={k} style={{ background: AnimeXTokens.surfaceRaised, color: AnimeXTokens.textPrimary }}>
            {lbl}
          </option>
        ))}
      </select>
    </div>
  );
}

export function AnimeXBrowsePage({
  nav,
  initialPreset,
}: {
  nav: AnimeNavActions;
  initialPreset: { sort?: string; status?: string; season?: string; year?: number; genre?: string } | null;
}) {
  const [sort, setSort] = useState(initialPreset?.sort || 'TRENDING_DESC');
  const [selectedGenres, setSelectedGenres] = useState<string[]>(initialPreset?.genre ? [initialPreset.genre] : []);
  const [year, setYear] = useState<number | undefined>(initialPreset?.year);
  const [moviesOnly, setMoviesOnly] = useState(false);
  const [genreMenuOpen, setGenreMenuOpen] = useState(false);
  const [page, setPage] = useState(1);
  const [data, setData] = useState<AnimexMediaPage | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetchAnimexPage({
      sort,
      genres: selectedGenres.length ? selectedGenres : undefined,
      seasonYear: year,
      format: moviesOnly ? 'MOVIE' : undefined,
      page,
      perPage: 24,
      japaneseTitle: nav.titleJapanese,
    }).then((res) => {
      if (!alive) return;
      setData(res);
      setLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [sort, selectedGenres, year, moviesOnly, page, nav.titleJapanese]);

  const toggleGenre = (g: string) => {
    setPage(1);
    setSelectedGenres((prev) => (prev.includes(g) ? prev.filter((x) => x !== g) : [...prev, g]));
  };

  const currentYear = new Date().getFullYear();
  const years = Array.from({ length: currentYear - 1990 + 1 }, (_, i) => String(currentYear - i));

  return (
    <div style={{ padding: '20px 24px 64px', position: 'relative', minHeight: '100%', display: 'flex', flexDirection: 'column' }}>
      <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0, textTransform: 'uppercase' }}>Browse</h1>
      <div style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }), marginTop: 2 }}>
        Explore anime
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 8, marginTop: 16 }}>
        <BrowseSelect
          value={sort}
          options={SORT_OPTIONS}
          onChange={(v) => {
            setSort(v);
            setPage(1);
          }}
        />
        <BrowseSelect
          value={moviesOnly ? 'MOVIE' : 'ALL'}
          options={[
            ['ALL', 'All types'],
            ['MOVIE', 'Movies'],
          ]}
          onChange={(v) => {
            setMoviesOnly(v === 'MOVIE');
            setPage(1);
          }}
        />
        <div style={{ position: 'relative' }}>
          <button
            type="button"
            className="bare-button"
            onClick={() => setGenreMenuOpen((v) => !v)}
            style={{
              display: 'inline-flex',
              flexShrink: 0,
              alignItems: 'center',
              gap: 8,
              padding: '9px 14px',
              borderRadius: AnimeXTokens.radiusMd,
              whiteSpace: 'nowrap',
              background: selectedGenres.length > 0 ? 'rgba(194,24,91,0.16)' : 'rgba(255,255,255,0.05)',
              border: `1px solid ${selectedGenres.length > 0 ? AnimeXTokens.accent : AnimeXTokens.border}`,
            }}
          >
            <span style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textPrimary, weight: 600 }), whiteSpace: 'nowrap' }}>
              {selectedGenres.length === 0 ? 'All genres' : `${selectedGenres.length} genre${selectedGenres.length === 1 ? '' : 's'}`}
            </span>
            <Icon name="keyboard_arrow_down" size={16} color={AnimeXTokens.textSecondary} />
          </button>
          {genreMenuOpen && (
            <div
              style={{
                position: 'absolute',
                top: '100%',
                left: 0,
                marginTop: 6,
                width: 240,
                maxHeight: 320,
                overflowY: 'auto',
                zIndex: 60,
                padding: 8,
                borderRadius: AnimeXTokens.radiusLg,
                background: AnimeXTokens.surfaceRaised,
                border: `1px solid ${AnimeXTokens.border}`,
                boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.55)', blur: 20, offset: [0, 8] }]),
              }}
            >
              {GENRES.map((g) => {
                const active = selectedGenres.includes(g);
                return (
                  <button
                    key={g}
                    type="button"
                    className="bare-button"
                    onClick={() => toggleGenre(g)}
                    style={{
                      width: '100%',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 10,
                      padding: '8px 10px',
                      borderRadius: AnimeXTokens.radiusSm,
                      background: active ? 'rgba(194,24,91,0.18)' : 'transparent',
                      textAlign: 'left',
                    }}
                  >
                    <Icon name={active ? 'check_box' : 'check_box_outline_blank'} size={17} color={active ? AnimeXTokens.accent : AnimeXTokens.textSecondary} />
                    <span style={dmSansStyle({ size: 13, color: AnimeXTokens.textPrimary })}>{g}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>
        <BrowseSelect
          value={year ? String(year) : 'ALL'}
          options={[['ALL', 'All years'], ...years.map((y): [string, string] => [y, y])]}
          onChange={(v) => {
            setYear(v === 'ALL' ? undefined : Number(v));
            setPage(1);
          }}
        />
      </div>

      {selectedGenres.length > 0 && (
        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 8, marginTop: 12 }}>
          {selectedGenres.map((g) => (
            <button
              key={g}
              type="button"
              className="bare-button"
              onClick={() => toggleGenre(g)}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                padding: '5px 10px',
                borderRadius: AnimeXTokens.radiusPill,
                background: 'rgba(194,24,91,0.18)',
                border: `1px solid ${AnimeXTokens.accent}`,
              }}
            >
              <span style={dmSansStyle({ size: 12, color: '#FFF', weight: 600 })}>{g}</span>
              <Icon name="close" size={14} color={AnimeXTokens.textSecondary} />
            </button>
          ))}
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              setSelectedGenres([]);
              setPage(1);
            }}
            style={{ padding: '4px 8px' }}
          >
            <span style={dmSansStyle({ size: 12, color: AnimeXTokens.accentWarm, weight: 700 })}>Clear all</span>
          </button>
        </div>
      )}

      <div style={{ marginTop: 24 }}>
        {loading ? (
          <AnimeXGridSkeleton width={nav.width} />
        ) : (data?.items.length ?? 0) === 0 ? (
          <div style={{ padding: '48px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
            No anime matched your filters.
          </div>
        ) : (
          <AnimeXGrid items={data!.items} width={nav.width} onSelect={(it) => nav.onWatch(it)} />
        )}
      </div>

      {data && (page > 1 || data.hasNextPage) && (
        <div style={{ display: 'flex', justifyContent: 'center', gap: 12, marginTop: 28 }}>
          <AnimeXSecondaryButton label="Previous" onClick={() => page > 1 && setPage(page - 1)} />
          <span style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }), alignSelf: 'center' }}>
            Page {page}
          </span>
          {data.hasNextPage && <AnimeXSecondaryButton label="Next" onClick={() => setPage(page + 1)} />}
        </div>
      )}

      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

// ---------- Schedule ----------

function formatRemaining(ms: number): string {
  if (ms <= 0) return 'Airing now';
  const totalSec = Math.floor(ms / 1000);
  const days = Math.floor(totalSec / 86400);
  const hours = Math.floor((totalSec % 86400) / 3600);
  const mins = Math.floor((totalSec % 3600) / 60);
  if (days >= 1) return `in ${days}d ${hours}h`;
  if (hours >= 1) return `in ${hours}h ${mins}m`;
  if (mins >= 1) return `in ${mins}m`;
  return `in ${totalSec}s`;
}

function airingLabel(airingAt: Date, now: Date): string {
  const sameDay =
    airingAt.getFullYear() === now.getFullYear() &&
    airingAt.getMonth() === now.getMonth() &&
    airingAt.getDate() === now.getDate();
  if (airingAt.getTime() <= now.getTime()) return sameDay ? 'Aired today' : 'Aired';
  if (!sameDay) return 'Airs';
  return airingAt.getHours() >= 18 ? 'Airs tonight' : 'Airs today';
}

function isMediaInList(media: MediaItem, library: MediaItem[]): boolean {
  return library.some((item) => {
    if (media.anilistId && item.anilistId && media.anilistId > 0) return media.anilistId === item.anilistId;
    return media.source === item.source && media.tmdbId > 0 && media.tmdbId === item.tmdbId;
  });
}

export function AnimeXSchedulePage({ nav }: { nav: AnimeNavActions }) {
  const now = new Date();
  const todayIdx = (now.getDay() + 6) % 7;
  const [weekday, setWeekday] = useState(todayIdx);
  const [filterChoice, setFilterChoice] = useState<boolean | null>(null);
  const [entries, setEntries] = useState<AnimexScheduleEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const onlyMyList = filterChoice ?? nav.library.length > 0;

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetchAiringSchedule(weekday).then((res) => {
      if (!alive) return;
      setEntries(res);
      setLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [weekday]);

  const dateForDay = (dayIndex: number) => {
    const monday = new Date(now);
    monday.setDate(now.getDate() - todayIdx + dayIndex);
    return monday.getDate();
  };

  const filtered = useMemo(() => {
    if (!onlyMyList) return entries;
    return entries.filter((e) => isMediaInList(e.media, nav.library));
  }, [entries, onlyMyList, nav.library]);

  const nextUp = useMemo(() => {
    let best: AnimexScheduleEntry | null = null;
    for (const entry of filtered) {
      if (entry.airingAt.getTime() <= now.getTime()) continue;
      if (!best || entry.airingAt.getTime() < best.airingAt.getTime()) best = entry;
    }
    return best;
  }, [filtered]);

  return (
    <div style={{ padding: '20px 24px 64px', minHeight: '100%', display: 'flex', flexDirection: 'column' }}>
      <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0, textTransform: 'uppercase' }}>Airing Schedule</h1>
      <div style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }), marginTop: 2 }}>
        This week&apos;s anime broadcasts
      </div>

      {nextUp && (
        <div
          onClick={() => nav.onWatch(nextUp.media, nextUp.episode)}
          style={{
            marginTop: 16,
            padding: 12,
            borderRadius: AnimeXTokens.radiusLg,
            background: AnimeXTokens.surface,
            border: '1px solid rgba(194,24,91,0.45)',
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            cursor: 'pointer',
          }}
        >
          {nextUp.media.posterPath && (
            <img
              src={nextUp.media.posterPath}
              alt={nextUp.media.title}
              style={{ width: 48, height: 68, borderRadius: AnimeXTokens.radiusMd, objectFit: 'cover', flexShrink: 0 }}
            />
          )}
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.1, color: AnimeXTokens.accentWarm, textTransform: 'uppercase' }}>
              NEXT UP
            </div>
            <div style={{ ...dmSansStyle({ size: 14.5, weight: 700 }), marginTop: 2 }}>{nextUp.media.title}</div>
            <div style={{ ...dmSansStyle({ size: 12, color: AnimeXTokens.textSecondary }), marginTop: 2 }}>
              Episode {nextUp.episode} · {nextUp.airingAt.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
            </div>
            <div style={{ ...dmSansStyle({ size: 12, color: AnimeXTokens.accentWarm, weight: 700 }), marginTop: 3 }}>
              {formatRemaining(nextUp.airingAt.getTime() - now.getTime())}
            </div>
          </div>
          <button
            type="button"
            className="bare-button"
            onClick={(e) => {
              e.stopPropagation();
              nav.onToggleLibrary(nextUp.media, !isMediaInList(nextUp.media, nav.library));
            }}
            style={{ padding: 8 }}
            aria-label="Toggle My List"
          >
            <Icon
              name={isMediaInList(nextUp.media, nav.library) ? 'bookmark_added' : 'bookmark_add'}
              size={20}
              color={AnimeXTokens.textSecondary}
            />
          </button>
        </div>
      )}

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 16 }}>
        {([
          [true, 'My List'],
          [false, 'All anime'],
        ] as const).map(([val, label]) => {
          const selected = onlyMyList === val;
          return (
            <button
              key={label}
              type="button"
              className="bare-button"
              onClick={() => setFilterChoice(val)}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                padding: '7px 14px',
                borderRadius: AnimeXTokens.radiusPill,
                background: selected ? 'rgba(194,24,91,0.18)' : 'rgba(255,255,255,0.05)',
                border: `1px solid ${selected ? 'rgba(194,24,91,0.45)' : AnimeXTokens.border}`,
              }}
            >
              {selected && <Icon name="check" size={15} color={AnimeXTokens.textPrimary} />}
              <span style={dmSansStyle({ size: 12.5, color: selected ? AnimeXTokens.textPrimary : AnimeXTokens.textSecondary, weight: 600 })}>
                {label}
              </span>
            </button>
          );
        })}
      </div>

      <div style={{ display: 'flex', gap: 4, margin: '16px 0 24px' }}>
        {WEEKDAYS.map((day, idx) => {
          const active = weekday === idx;
          return (
            <button
              key={day}
              type="button"
              className="bare-button"
              onClick={() => setWeekday(idx)}
              style={{
                flex: 1,
                minHeight: 56,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 2,
                borderRadius: AnimeXTokens.radiusMd,
                background: 'transparent',
                border: `1px solid ${active ? AnimeXTokens.accent : AnimeXTokens.border}`,
              }}
            >
              <span style={dmSansStyle({ size: 12, color: active ? AnimeXTokens.textPrimary : AnimeXTokens.textSecondary, weight: active ? 700 : 500 })}>
                {day}
              </span>
              <span style={dmSansStyle({ size: 10, color: active ? AnimeXTokens.accentWarm : AnimeXTokens.textSecondary, weight: active ? 700 : 500 })}>
                {dateForDay(idx)}
              </span>
            </button>
          );
        })}
      </div>

      <div style={dmSansStyle({ size: 15, weight: 700 })}>{onlyMyList ? 'My List' : 'All anime'}</div>
      <div style={{ ...dmSansStyle({ size: 12, color: AnimeXTokens.textSecondary }), marginTop: 2, marginBottom: 14 }}>
        Broadcast times only — aired does not mean playable.
      </div>

      {loading ? (
        <div style={{ padding: '40px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
          Loading schedule…
        </div>
      ) : filtered.length === 0 ? (
        <div style={{ padding: '24px 0', ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }) }}>
          {onlyMyList
            ? nav.library.length === 0
              ? 'Add anime to My List to see their broadcast dates here.'
              : 'No airings from your list in this day’s schedule.'
            : 'No scheduled episodes found.'}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {filtered.map((entry, idx) => {
            const inList = isMediaInList(entry.media, nav.library);
            const dateStr = entry.airingAt.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
            const timeStr = entry.airingAt.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
            return (
              <div
                key={`${entry.media.anilistId || entry.media.tmdbId}-${entry.episode}-${idx}`}
                onClick={() => nav.onWatch(entry.media, entry.episode)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 14,
                  padding: 12,
                  borderRadius: AnimeXTokens.radiusLg,
                  background: AnimeXTokens.card,
                  border: `1px solid ${inList ? AnimeXTokens.accent : AnimeXTokens.border}`,
                  cursor: 'pointer',
                }}
              >
                {entry.media.posterPath && (
                  <img
                    src={entry.media.posterPath}
                    alt={entry.media.title}
                    style={{ width: 54, height: 78, borderRadius: AnimeXTokens.radiusMd, objectFit: 'cover', flexShrink: 0 }}
                  />
                )}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="clamp-2" style={dmSansStyle({ size: 14, weight: 700 })}>{entry.media.title}</div>
                  <div style={{ marginTop: 6 }}>
                    <span
                      style={{
                        display: 'inline-block',
                        padding: '2px 7px',
                        borderRadius: 6,
                        background: 'rgba(255,255,255,0.06)',
                        border: `1px solid ${AnimeXTokens.border}`,
                        fontSize: 11,
                        fontWeight: 700,
                        color: AnimeXTokens.textPrimary,
                      }}
                    >
                      EP {entry.episode}
                    </span>
                  </div>
                  <div style={{ ...dmSansStyle({ size: 12, color: AnimeXTokens.accentWarm }), marginTop: 6 }}>
                    {airingLabel(entry.airingAt, now)} · {dateStr}
                  </div>
                  <div style={{ ...dmSansStyle({ size: 11.5, color: AnimeXTokens.textSecondary }), marginTop: 2 }}>
                    {timeStr} local time
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

// ---------- Search ----------

export function AnimeXSearchPage({ nav }: { nav: AnimeNavActions }) {
  const [queryText, setQueryText] = useState('');
  const [mode, setMode] = useState<'all' | 'trending' | 'airing' | 'movies' | 'new'>('trending');
  const [results, setResults] = useState<MediaItem[]>([]);
  const [loading, setLoading] = useState(true);

  const runSearch = (q: string, targetMode: 'all' | 'trending' | 'airing' | 'movies' | 'new') => {
    setLoading(true);
    const opts = q
      ? { search: q, perPage: 30, japaneseTitle: nav.titleJapanese }
      : targetMode === 'trending'
        ? { sort: 'TRENDING_DESC', perPage: 30, japaneseTitle: nav.titleJapanese }
        : targetMode === 'airing'
          ? { sort: 'SCORE_DESC', status: 'RELEASING', perPage: 30, japaneseTitle: nav.titleJapanese }
          : targetMode === 'movies'
            ? { format: 'MOVIE', sort: 'POPULARITY_DESC', perPage: 30, japaneseTitle: nav.titleJapanese }
            : targetMode === 'new'
              ? { sort: 'START_DATE_DESC', perPage: 30, japaneseTitle: nav.titleJapanese }
              : { sort: 'TRENDING_DESC', perPage: 30, japaneseTitle: nav.titleJapanese };
    fetchAnimexPage(opts).then((res) => {
      setResults(res.items);
      setLoading(false);
    });
  };

  useEffect(() => {
    const q = queryText.trim();
    if (!q) return;
    const t = window.setTimeout(() => runSearch(q, mode), 450);
    return () => window.clearTimeout(t);
  }, [queryText, nav.titleJapanese]);

  // An empty search box is not a dead end: show trending immediately so she can
  // start something without knowing a title.
  useEffect(() => {
    runSearch('', mode);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, nav.titleJapanese]);

  return (
    <div style={{ padding: '20px 24px 64px', minHeight: '100%', display: 'flex', flexDirection: 'column' }}>
      <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0, textTransform: 'uppercase' }}>Discover Anime</h1>
      <div style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }), marginTop: 2 }}>
        Search thousands of anime titles
      </div>
      <div
        style={{
          marginTop: 20,
          height: 46,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          padding: '0 14px',
          borderRadius: AnimeXTokens.radiusLg,
          background: 'rgba(255,255,255,0.05)',
          border: `1px solid ${AnimeXTokens.borderStrong}`,
        }}
      >
        <Icon name="search" size={19} color={AnimeXTokens.textSecondary} />
        <input
          value={queryText}
          onChange={(e) => {
            const val = e.target.value;
            setQueryText(val);
            if (!val.trim()) runSearch('', mode);
          }}
          placeholder="Search anime..."
          style={{
            flex: 1,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            color: AnimeXTokens.textPrimary,
            fontSize: 14,
            fontFamily: "'DM Sans', sans-serif",
          }}
        />
        {queryText && (
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              setQueryText('');
              runSearch('', mode);
            }}
          >
            <Icon name="close" size={17} color={AnimeXTokens.textSecondary} />
          </button>
        )}
      </div>

      <div className="no-scrollbar" style={{ display: 'flex', flexWrap: 'nowrap', alignItems: 'center', gap: 8, margin: '14px 0 24px', overflowX: 'auto' }}>
        {([
          ['all', 'All'],
          ['trending', 'Trending'],
          ['airing', 'Top Airing'],
          ['movies', 'Movies'],
          ['new', 'New'],
        ] as const).map(([key, lbl]) => {
          const active = !queryText.trim() && mode === key;
          return (
            <button
              key={key}
              type="button"
              className="bare-button"
              onClick={() => {
                setQueryText('');
                setMode(key);
                runSearch('', key);
              }}
              style={{
                flexShrink: 0,
                padding: '7px 14px',
                borderRadius: 999,
                whiteSpace: 'nowrap',
                background: active ? 'rgba(194,24,91,0.16)' : 'rgba(255,255,255,0.05)',
                border: `1px solid ${active ? 'rgba(194,24,91,0.4)' : AnimeXTokens.border}`,
              }}
            >
              <span style={dmSansStyle({ size: 12.5, color: active ? AnimeXTokens.accentText : AnimeXTokens.textSecondary, weight: 600 })}>
                {lbl}
              </span>
            </button>
          );
        })}
      </div>

      {!queryText.trim() && nav.history.length > 0 && !loading && (
        <div style={{ marginBottom: 26 }}>
          <AnimeXSectionHeader icon="history" title="Pick up where you stopped" />
          <div className="no-scrollbar" style={{ display: 'flex', gap: 14, overflowX: 'auto', paddingBottom: 4 }}>
            {nav.history.slice(0, 8).map((e) => (
              <ContinueWatchingCard
                key={`rec-${e.key}`}
                entry={e}
                width={260}
                onClick={() => e.savedItem && nav.onWatch(e.savedItem, e.episode)}
              />
            ))}
          </div>
        </div>
      )}

      {loading ? (
        <AnimeXGridSkeleton width={nav.width} count={9} />
      ) : results.length === 0 ? (
        <div style={{ padding: '40px 0', textAlign: 'center' }}>
          <div style={dmSansStyle({ size: 15, color: AnimeXTokens.textPrimary, weight: 700 })}>
            {queryText.trim() ? 'Nothing matched that title' : 'Nothing to show right now'}
          </div>
          <div style={{ height: 6 }} />
          <div style={dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary })}>
            {queryText.trim() ? 'Try a shorter title, or pick a category above.' : 'Try again in a moment.'}
          </div>
          <div style={{ height: 16 }} />
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              setQueryText('');
              setMode('trending');
            }}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 8,
              minHeight: 44,
              padding: '0 18px',
              borderRadius: AnimeXTokens.radiusPill,
              background: withAlpha(AnimeXTokens.accent, 0.18),
              border: `1px solid ${AnimeXTokens.accent}`,
            }}
          >
            <Icon name="trending_up" size={16} color={AnimeXTokens.accentText} />
            <span style={dmSansStyle({ size: 13, color: AnimeXTokens.accentText, weight: 700 })}>Show trending</span>
          </button>
        </div>
      ) : (
        <AnimeXGrid items={results} width={nav.width} onSelect={(it) => nav.onWatch(it)} />
      )}

      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

// ---------- History ----------

export function AnimeXHistoryPage({ nav }: { nav: AnimeNavActions }) {
  const [confirmClear, setConfirmClear] = useState(false);

  return (
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto', minHeight: '100%', boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <div>
          <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0 }}>History</h1>
          <div style={dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary })}>
            {nav.history.length ? `${nav.history.length} watched` : 'Your watched anime appear here'}
          </div>
        </div>
        {nav.history.length > 0 && (
          <button
            type="button"
            className="bare-button"
            onClick={() => setConfirmClear(true)}
            style={{
              padding: '8px 14px',
              borderRadius: AnimeXTokens.radiusMd,
              background: 'rgba(255,255,255,0.05)',
              border: `1px solid ${AnimeXTokens.border}`,
            }}
          >
            <span style={dmSansStyle({ size: 12.5, color: AnimeXTokens.textSecondary, weight: 600 })}>Clear History</span>
          </button>
        )}
      </div>

      {nav.history.length === 0 ? (
        <div style={{ padding: '64px 0', textAlign: 'center' }}>
          <Icon name="history" size={44} color={AnimeXTokens.textMuted} />
          <div style={{ ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }), marginTop: 12 }}>
            No watch history yet
          </div>
        </div>
      ) : (
        <div style={{ marginTop: 20, display: 'grid', gridTemplateColumns: nav.width >= 720 ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 12 }}>
          {nav.history.map((e) => (
            <div
              key={e.key}
              onClick={() => e.savedItem && nav.onWatch(e.savedItem, e.episode)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 14,
                padding: 12,
                borderRadius: AnimeXTokens.radiusLg,
                background: AnimeXTokens.surface,
                border: `1px solid ${AnimeXTokens.border}`,
                cursor: 'pointer',
              }}
            >
              {e.posterUrl && (
                <img
                  src={e.posterUrl}
                  alt={e.title}
                  style={{ width: 56, height: 80, borderRadius: AnimeXTokens.radiusMd, objectFit: 'cover', flexShrink: 0 }}
                />
              )}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="clamp-2" style={dmSansStyle({ size: 14, weight: 700 })}>{e.title}</div>
                <div style={{ ...dmSansStyle({ size: 12, color: AnimeXTokens.accentWarm }), marginTop: 4 }}>
                  Episode {e.episode} · {e.audio.toUpperCase()}
                </div>
              </div>
              <Icon name="play_arrow" size={22} color={AnimeXTokens.textPrimary} />
            </div>
          ))}
        </div>
      )}

      {confirmClear && (
        <div
          onClick={() => setConfirmClear(false)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', zIndex: 80, display: 'grid', placeItems: 'center', padding: 20 }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{ width: '100%', maxWidth: 400, padding: 22, borderRadius: 16, background: AnimeXTokens.surfaceRaised, border: `1px solid ${AnimeXTokens.glassBorder}` }}
          >
            <div style={dmSansStyle({ size: 17, weight: 700 })}>Clear watching progress?</div>
            <div style={{ ...dmSansStyle({ size: 13.5, color: AnimeXTokens.textSecondary }), marginTop: 8 }}>
              This clears the saved resume points on all your devices. Your titles stay in My List.
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 18 }}>
              <AnimeXSecondaryButton label="Cancel" onClick={() => setConfirmClear(false)} />
              <AnimeXPrimaryButton
                label="Clear"
                onClick={async () => {
                  await nav.onClearHistory(nav.history);
                  setConfirmClear(false);
                }}
              />
            </div>
          </div>
        </div>
      )}

      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

// ---------- My List ----------

function MyListSectionTitle({ title, count }: { title: string; count: number }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', marginBottom: 16 }}>
      <span style={dmSansStyle({ size: 16.8, color: AnimeXTokens.textPrimary, weight: 700 })}>{title}</span>
      <div style={{ width: 10 }} />
      <span
        style={{
          padding: '2px 8px',
          background: 'rgba(255,255,255,0.06)',
          borderRadius: 999,
          ...dmSansStyle({ size: 11, color: AnimeXTokens.textSecondary, weight: 700 }),
        }}
      >
        {count}
      </span>
    </div>
  );
}

export function AnimeXMyListPage({ nav }: { nav: AnimeNavActions }) {
  const [source, setSource] = useState(0);
  const watching = nav.library.filter((x) => x.status === 'watching-self' || x.status === 'watching-together');
  const toWatch = nav.library.filter((x) => !x.status || x.status === 'to-watch');
  const watched = nav.library.filter((x) => x.status === 'watched-self' || x.status === 'watched-together');

  const sources = ['Everglow', 'AniList', 'MAL'];
  const removeBtn = (it: MediaItem) => (
    <button
      type="button"
      className="bare-button"
      title="Remove from My List"
      onClick={() => nav.onToggleLibrary(it, false)}
      style={{
        width: 30,
        height: 30,
        borderRadius: 99,
        background: 'rgba(10, 10, 15, 0.8)',
        border: `1px solid ${AnimeXTokens.borderStrong}`,
        display: 'grid',
        placeItems: 'center',
      }}
    >
      <Icon name="bookmark_remove" size={15} color={AnimeXTokens.textPrimary} />
    </button>
  );

  return (
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto', minHeight: '100%', boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      <h1 style={{ ...bebasStyle({ size: 32, color: AnimeXTokens.textPrimary }), margin: 0 }}>My List</h1>
      <div style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }), marginTop: 2 }}>
        {nav.library.length} anime in your collection
      </div>

      <div style={{ marginTop: 16 }}>
        <div
          style={{
            display: 'inline-flex',
            padding: 2,
            background: 'rgba(255,255,255,0.05)',
            borderRadius: 999,
            border: '1px solid rgba(255,255,255,0.1)',
          }}
        >
          {sources.map((label, i) => {
            const active = source === i;
            return (
              <button
                key={label}
                type="button"
                className="bare-button"
                onClick={() => {
                  setSource(i);
                  if (i !== 0) {
                    showSnackBar(`${label} sync is ready - connect your ${label} account to pull your list`, {
                      background: AnimeXTokens.surfaceRaised,
                    });
                  }
                }}
                style={{
                  padding: '5px 14px',
                  borderRadius: 999,
                  background: active ? AnimeXTokens.accent : 'transparent',
                }}
              >
                <span style={dmSansStyle({ size: 11.5, color: active ? '#FFF' : AnimeXTokens.textSecondary, weight: 700 })}>
                  {label}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 12 }}>
        {(
          [
            ['Playlists', 'video_library', 'outlined', () => nav.onNavigate('playlists')],
            ['Seasonal', 'calendar_view_month', 'round', () => nav.onNavigate('seasonal')],
            ['History', 'history', 'round', () => nav.onNavigate('history')],
            ['Downloads', 'download_for_offline', 'outlined', () => nav.onNavigate('downloads')],
          ] as const
        ).map(([label, icon, variant, onTap]) => (
          <button
            key={label}
            type="button"
            className="bare-button"
            onClick={onTap}
            style={{
              padding: '8px 14px',
              background: 'rgba(255,255,255,0.05)',
              borderRadius: AnimeXTokens.radiusMd,
              border: `1px solid ${AnimeXTokens.border}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 8,
            }}
          >
            <Icon name={icon} variant={variant} size={15} color={AnimeXTokens.accent} />
            <span style={dmSansStyle({ size: 12.5, color: AnimeXTokens.textPrimary, weight: 600 })}>{label}</span>
          </button>
        ))}
      </div>

      <div style={{ height: 24 }} />

      {nav.library.length === 0 ? (
        <div style={{ padding: '50px 0', textAlign: 'center' }}>
          <Icon name="bookmark_add" variant="outlined" size={40} color={AnimeXTokens.textMuted} />
          <div style={{ ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary, weight: 600 }), marginTop: 12 }}>
            Your list is empty - add anime from Search
          </div>
        </div>
      ) : (
        <>
          {watching.length > 0 && (
            <>
              <MyListSectionTitle title="Watching" count={watching.length} />
              <AnimeXGrid items={watching} width={nav.width} onSelect={(it) => nav.onWatch(it)} cardHoverAction={removeBtn} />
              <div style={{ height: 28 }} />
            </>
          )}
          {toWatch.length > 0 && (
            <>
              <MyListSectionTitle title="Plan to Watch" count={toWatch.length} />
              <AnimeXGrid items={toWatch} width={nav.width} onSelect={(it) => nav.onWatch(it)} cardHoverAction={removeBtn} />
              <div style={{ height: 28 }} />
            </>
          )}
          {watched.length > 0 && (
            <>
              <MyListSectionTitle title="Completed" count={watched.length} />
              <AnimeXGrid items={watched} width={nav.width} onSelect={(it) => nav.onWatch(it)} cardHoverAction={removeBtn} />
            </>
          )}
        </>
      )}

      <div style={{ height: 24 }} />
      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

// ---------- Playlists ----------

export function AnimeXPlaylistsPage({ nav }: { nav: AnimeNavActions }) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [name, setName] = useState('');
  const [emoji, setEmoji] = useState('star');

  const selected = nav.playlists.find((p) => p.id === selectedId) ?? null;

  if (selected) {
    return (
      <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto', minHeight: '100%', boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
        <button
          type="button"
          className="bare-button"
          onClick={() => setSelectedId(null)}
          style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginBottom: 14 }}
        >
          <Icon name="arrow_back" size={18} color={AnimeXTokens.textSecondary} />
          <span style={dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary })}>All Playlists</span>
        </button>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
          <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0 }}>
            {PLAYLIST_EMOJIS.find(([k]) => k === selected.emoji)?.[1] ?? '✨'} {selected.name}
          </h1>
          <button
            type="button"
            className="bare-button"
            onClick={() => { animexStoreActions.deletePlaylist(selected.id); setSelectedId(null); }}
            style={dmSansStyle({ size: 13, color: '#F87171', weight: 600 })}
          >
            Delete Playlist
          </button>
        </div>
        {selected.items.length === 0 ? (
          <div style={{ padding: '48px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
            No anime in this playlist yet — add from any anime page.
          </div>
        ) : (
          <AnimeXGrid items={selected.items} width={nav.width} onSelect={(it) => nav.onWatch(it)} />
        )}
        <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
      </div>
    );
  }

  return (
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto', minHeight: '100%', boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <div>
          <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0 }}>Playlists</h1>
          <div style={dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary })}>Your custom collections</div>
        </div>
        <AnimeXPrimaryButton label="Create" icon="add" onClick={() => setCreateOpen(true)} />
      </div>

      {nav.playlists.length === 0 ? (
        <div style={{ padding: '60px 0', textAlign: 'center' }}>
          <Icon name="bookmark_add" size={40} color={AnimeXTokens.textMuted} />
          <div style={{ ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary, weight: 600 }), marginTop: 12 }}>
            No playlists yet - create your first one
          </div>
        </div>
      ) : (
        <div style={{ marginTop: 24, display: 'grid', gridTemplateColumns: nav.width >= 720 ? 'repeat(3, minmax(0, 1fr))' : '1fr', gap: 14 }}>
          {nav.playlists.map((pl) => (
            <div
              key={pl.id}
              onClick={() => setSelectedId(pl.id)}
              style={{
                padding: 18,
                borderRadius: AnimeXTokens.radiusLg,
                background: AnimeXTokens.surface,
                border: `1px solid ${AnimeXTokens.border}`,
                cursor: 'pointer',
              }}
            >
              <div style={{ fontSize: 26 }}>{PLAYLIST_EMOJIS.find(([k]) => k === pl.emoji)?.[1] ?? '✨'}</div>
              <div style={{ ...dmSansStyle({ size: 16, weight: 700 }), marginTop: 8 }}>{pl.name}</div>
              <div style={{ ...dmSansStyle({ size: 12, color: AnimeXTokens.textSecondary }), marginTop: 4 }}>
                {pl.items.length} anime
              </div>
            </div>
          ))}
        </div>
      )}

      {createOpen && (
        <div
          onClick={() => setCreateOpen(false)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', zIndex: 80, display: 'grid', placeItems: 'center', padding: 20 }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{ width: '100%', maxWidth: 400, padding: 22, borderRadius: 16, background: AnimeXTokens.surfaceRaised, border: `1px solid ${AnimeXTokens.glassBorder}` }}
          >
            <div style={dmSansStyle({ size: 17, weight: 700 })}>New Playlist</div>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Playlist name…"
              style={{
                width: '100%',
                marginTop: 12,
                padding: '10px 12px',
                borderRadius: 10,
                background: AnimeXTokens.bg,
                border: `1px solid ${AnimeXTokens.border}`,
                color: '#FFF',
                outline: 'none',
              }}
            />
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 12 }}>
              {PLAYLIST_EMOJIS.map(([k, glyph]) => (
                <button
                  key={k}
                  type="button"
                  className="bare-button"
                  onClick={() => setEmoji(k)}
                  style={{
                    width: 34,
                    height: 34,
                    borderRadius: 8,
                    background: emoji === k ? AnimeXTokens.accent : 'rgba(255,255,255,0.06)',
                    display: 'grid',
                    placeItems: 'center',
                    fontSize: 16,
                  }}
                >
                  {glyph}
                </button>
              ))}
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 18 }}>
              <AnimeXSecondaryButton label="Cancel" onClick={() => setCreateOpen(false)} />
              <AnimeXPrimaryButton
                label="Create"
                onClick={() => {
                  if (!name.trim()) return;
                  animexStoreActions.createPlaylist(name, emoji);
                  setName('');
                  setCreateOpen(false);
                }}
              />
            </div>
          </div>
        </div>
      )}

      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

// ---------- Seasonal ----------

export function AnimeXSeasonalPage({ nav }: { nav: AnimeNavActions }) {
  const initial = currentAnimeSeason();
  const [season, setSeason] = useState(initial.season);
  const [year, setYear] = useState(initial.year);
  const [page, setPage] = useState(1);
  const [data, setData] = useState<AnimexMediaPage | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetchAnimexPage({
      season,
      seasonYear: year,
      sort: 'POPULARITY_DESC',
      page,
      perPage: 24,
      japaneseTitle: nav.titleJapanese,
    }).then((res) => {
      if (!alive) return;
      setData(res);
      setLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [season, year, page, nav.titleJapanese]);

  return (
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto', minHeight: '100%', boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0 }}>Seasonal Anime</h1>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, margin: '14px 0 24px', alignItems: 'center' }}>
        {SEASONS.map(([code, label]) => {
          const active = season === code;
          return (
            <button
              key={code}
              type="button"
              className="bare-button"
              onClick={() => { setSeason(code); setPage(1); }}
              style={{
                padding: '7px 14px',
                borderRadius: AnimeXTokens.radiusPill,
                background: active ? AnimeXTokens.accent : 'rgba(255,255,255,0.06)',
                border: `1px solid ${active ? AnimeXTokens.accent : AnimeXTokens.border}`,
              }}
            >
              <span style={dmSansStyle({ size: 12.5, color: active ? '#FFF' : AnimeXTokens.textSecondary, weight: 600 })}>
                {label}
              </span>
            </button>
          );
        })}
        <select
          value={year}
          onChange={(e) => { setYear(Number(e.target.value)); setPage(1); }}
          style={{
            padding: '7px 12px',
            borderRadius: AnimeXTokens.radiusPill,
            background: AnimeXTokens.surfaceRaised,
            color: AnimeXTokens.textPrimary,
            border: `1px solid ${AnimeXTokens.border}`,
          }}
        >
          {Array.from({ length: 12 }, (_, i) => new Date().getFullYear() + 1 - i).map((y) => (
            <option key={y} value={y}>{y}</option>
          ))}
        </select>
      </div>

      {loading ? (
        <div style={{ padding: '48px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
          Loading seasonal chart…
        </div>
      ) : (
        <AnimeXGrid items={data?.items ?? []} width={nav.width} onSelect={(it) => nav.onWatch(it)} />
      )}

      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

// ---------- Downloads / DMCA ----------

export function AnimeXDownloadsPage({ nav }: { nav: AnimeNavActions }) {
  const service = useOfflineMedia();
  const items = service.animeItems;

  const playOffline = (item: OfflineMediaItem) => {
    const numId = Number(item.mediaId) || 0;
    const media: MediaItem = {
      id: item.id,
      tmdbId: numId,
      anilistId: numId > 0 ? numId : undefined,
      title: item.title,
      posterPath: item.coverUrl,
      backdropPath: '',
      year: '',
      mediaType: 'tv',
      status: '',
      isAnime: true,
      userName: nav.userName,
      addedAt: new Date(),
      source: 'anilist',
      synopsis: '',
      airingStatus: '',
      format: '',
      studio: '',
      genres: [],
      remindMe: false,
    };
    nav.onWatch(media, item.episode ?? 1);
  };

  const confirmClearAll = () =>
    void showDialog<void>((close) => (
      <AlertDialog
        background={AnimeXTokens.surfaceRaised}
        title={<div style={dmSansStyle({ size: 17, weight: 700 })}>Clear Anime Downloads</div>}
        content={
          <div style={dmSansStyle({ size: 13.5, color: AnimeXTokens.textSecondary })}>
            Remove all offline anime episodes from this device?
          </div>
        }
        actions={[
          <TextButton key="cancel" onPressed={() => close(null)} color={AnimeXTokens.textSecondary}>
            Cancel
          </TextButton>,
          <TextButton
            key="clear"
            color="#FF453A"
            onPressed={() => {
              close(null);
              void offlineMedia.clearAll('anime');
            }}
          >
            Clear All
          </TextButton>,
        ]}
      />
    ));

  const groups = new Map<string, OfflineMediaItem[]>();
  for (const item of items) {
    const list = groups.get(item.mediaId) ?? [];
    list.push(item);
    groups.set(item.mediaId, list);
  }

  return (
    <div style={{ padding: '24px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto', minHeight: '100%', boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
          <Icon name="download_for_offline" size={26} color={AnimeXTokens.accent} />
          <h1 style={{ ...dmSansStyle({ size: 22, weight: 700 }), margin: 0 }}>Downloads</h1>
          {items.length > 0 && (
            <span
              style={{
                padding: '2px 8px',
                borderRadius: 999,
                background: AnimeXTokens.surfaceRaised,
                border: `1px solid ${AnimeXTokens.border}`,
                ...dmSansStyle({ size: 12, color: AnimeXTokens.textSecondary, weight: 600 }),
              }}
            >
              {items.length}
            </span>
          )}
        </div>
        {items.length > 0 && (
          <button
            type="button"
            className="bare-button"
            onClick={confirmClearAll}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '6px 10px' }}
          >
            <Icon name="delete_sweep" variant="outlined" size={18} color={AnimeXTokens.textMuted} />
            <span style={dmSansStyle({ size: 13, color: AnimeXTokens.textMuted, weight: 600 })}>Clear All</span>
          </button>
        )}
      </div>

      {items.length === 0 ? (
        <div style={{ padding: '64px 0', textAlign: 'center' }}>
          <Icon name="download_for_offline" size={48} color={AnimeXTokens.textMuted} />
          <div style={{ ...dmSansStyle({ size: 16, weight: 700 }), marginTop: 14 }}>No downloaded anime yet</div>
          <div style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }), marginTop: 6 }}>
            Downloaded episodes for offline viewing will appear here.
          </div>
          <div style={{ marginTop: 20, display: 'flex', justifyContent: 'center' }}>
            <AnimeXPrimaryButton label="Browse Anime" icon="explore" onClick={() => nav.onNavigate('browse')} />
          </div>
        </div>
      ) : (
        <>
          <div
            style={{
              marginTop: 16,
              padding: '12px 16px',
              borderRadius: AnimeXTokens.radiusLg,
              background: AnimeXTokens.surface,
              border: `1px solid ${AnimeXTokens.border}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: 12,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Icon name="storage" size={18} color={AnimeXTokens.accent} />
              <span style={dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary })}>Offline storage used</span>
            </div>
            <span style={dmSansStyle({ size: 13.5, color: AnimeXTokens.textPrimary, weight: 700 })}>
              {service.formattedAnimeStorage}
            </span>
          </div>

          <div style={{ marginTop: 20, display: 'flex', flexDirection: 'column', gap: 16 }}>
            {[...groups.values()].map((eps) => {
              const sorted = [...eps].sort((a, b) => (a.episode ?? 0) - (b.episode ?? 0));
              const head = sorted[0];
              return (
                <div
                  key={head.mediaId}
                  style={{
                    borderRadius: AnimeXTokens.radiusLg,
                    background: AnimeXTokens.surface,
                    border: `1px solid ${AnimeXTokens.border}`,
                    overflow: 'hidden',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderBottom: `1px solid ${AnimeXTokens.border}` }}>
                    {head.coverUrl && (
                      <img
                        src={head.coverUrl}
                        alt={head.title}
                        style={{ width: 44, height: 62, borderRadius: AnimeXTokens.radiusMd, objectFit: 'cover', flexShrink: 0 }}
                      />
                    )}
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div className="clamp-1" style={dmSansStyle({ size: 14.5, weight: 700 })}>{head.title}</div>
                      <div style={dmSansStyle({ size: 12, color: AnimeXTokens.textSecondary })}>
                        {sorted.length} {sorted.length === 1 ? 'episode' : 'episodes'} offline
                      </div>
                    </div>
                  </div>
                  {sorted.map((ep, idx) => {
                    const dur = formattedDuration(ep);
                    const meta = `${formattedSize(ep)}${dur ? ` • ${dur}` : ''}`;
                    return (
                      <div
                        key={ep.id}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: 12,
                          padding: '10px 12px',
                          borderTop: idx > 0 ? `1px solid ${AnimeXTokens.border}` : undefined,
                        }}
                      >
                        <button
                          type="button"
                          className="bare-button"
                          onClick={() => playOffline(ep)}
                          style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 12, textAlign: 'left' }}
                        >
                          <div
                            style={{
                              width: 34,
                              height: 34,
                              borderRadius: '50%',
                              background: 'rgba(255,255,255,0.06)',
                              display: 'grid',
                              placeItems: 'center',
                              flexShrink: 0,
                            }}
                          >
                            <Icon name="play_arrow" size={18} color={AnimeXTokens.accent} />
                          </div>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={dmSansStyle({ size: 13.5, weight: 600 })}>
                              {ep.subtitle || `Episode ${ep.episode ?? 1}`}
                            </div>
                            <div style={dmSansStyle({ size: 11.5, color: AnimeXTokens.textSecondary })}>{meta}</div>
                            {ep.status === 'downloading' && (
                              <div style={{ marginTop: 4 }}>
                                <LinearProgress value={ep.progress} color={AnimeXTokens.accent} />
                              </div>
                            )}
                          </div>
                        </button>
                        <button
                          type="button"
                          className="bare-button"
                          aria-label={`Delete ${ep.subtitle || ep.title}`}
                          onClick={() => void offlineMedia.deleteDownload(ep.id)}
                          style={{ width: 34, height: 34, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                        >
                          <Icon name="delete_outline" size={18} color={AnimeXTokens.textMuted} />
                        </button>
                      </div>
                    );
                  })}
                </div>
              );
            })}
          </div>
        </>
      )}
      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

export function AnimeXDmcaPage({ onBack }: { onBack: () => void }) {
  return (
    <div style={{ padding: '24px 24px 64px', maxWidth: 760, margin: '0 auto', minHeight: '100%', boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      <button type="button" className="bare-button" onClick={onBack} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginBottom: 16 }}>
        <Icon name="arrow_back" size={18} color={AnimeXTokens.textSecondary} />
        <span style={dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary })}>Back</span>
      </button>
      <h1 style={{ ...bebasStyle({ size: 34 }), margin: 0 }}>DMCA & Media Attribution</h1>
      <p style={{ ...interBodyStyle({ size: 14, color: AnimeXTokens.textSecondary }), marginTop: 14 }}>
        Everglow indexes metadata from AniList, MyAnimeList/Jikan, and TMDB and loads external video streams solely via third-party embeds. No copyrighted video files are hosted on Everglow servers.
      </p>
    </div>
  );
}

// ---------- Watch / Detail Page ----------
