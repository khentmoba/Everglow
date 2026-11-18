import { useEffect, useMemo, useState } from 'react';
import { Align, boxShadow, linear } from '../../core/theme/paint';
import { Icon } from '../../shared/widgets/Icon';
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
  AnimeXFooter,
  AnimeXGrid,
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
  playlists: AnimexPlaylist[];
  onWatch: (item: MediaItem, episode?: number) => void;
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

  return (
    <div style={{ paddingBottom: 64 }}>
      <AnimeXSpotlight
        items={trending.items.slice(0, 5)}
        loading={trending.loading}
        width={nav.width}
        height={nav.height}
        onWatch={(it) => nav.onWatch(it)}
        onMoreInfo={(it) => nav.onWatch(it)}
        onTrailer={nav.onTrailer}
      />

      {nav.history.length > 0 && (
        <div style={{ marginTop: 24, marginBottom: 40 }}>
          <div style={{ padding: '0 24px' }}>
            <AnimeXSectionHeader
              icon="play_circle_filled"
              title="Continue Watching"
              viewAllLabel="History"
              onViewAll={() => nav.onNavigate('history')}
            />
          </div>
          <div className="no-scrollbar" style={{ display: 'flex', gap: 14, overflowX: 'auto', padding: '0 24px' }}>
            {nav.history.slice(0, 12).map((e) => (
              <div
                key={e.key}
                onClick={() => e.savedItem && nav.onWatch(e.savedItem, e.episode)}
                style={{
                  width: 170,
                  flexShrink: 0,
                  cursor: 'pointer',
                  background: AnimeXTokens.surface,
                  borderRadius: AnimeXTokens.radiusLg,
                  border: `1px solid ${AnimeXTokens.border}`,
                  overflow: 'hidden',
                }}
              >
                <div style={{ position: 'relative', height: 112, background: AnimeXTokens.surfaceRaised }}>
                  {e.posterUrl && <img src={e.posterUrl} alt={e.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
                  {e.progress != null && (
                    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 3, background: 'rgba(255,255,255,0.2)' }}>
                      <div style={{ width: `${e.progress * 100}%`, height: '100%', background: AnimeXTokens.accent }} />
                    </div>
                  )}
                </div>
                <div style={{ padding: 10 }}>
                  <div className="clamp-2" style={dmSansStyle({ size: 12.5, weight: 700, color: AnimeXTokens.textPrimary })}>
                    {e.title}
                  </div>
                  <div style={{ ...dmSansStyle({ size: 11, color: AnimeXTokens.accentWarm }), marginTop: 4 }}>
                    Episode {e.episode}
                  </div>
                </div>
              </div>
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

  return (
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto' }}>
      <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0 }}>Browse Anime</h1>
      <div style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }), marginTop: 2 }}>
        Filter by genre, release year, or popularity
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 18 }}>
        {SORT_OPTIONS.map(([code, label]) => {
          const active = sort === code;
          return (
            <button
              key={code}
              type="button"
              className="bare-button"
              onClick={() => { setSort(code); setPage(1); }}
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
        <button
          type="button"
          className="bare-button"
          onClick={() => { setMoviesOnly((v) => !v); setPage(1); }}
          style={{
            padding: '7px 14px',
            borderRadius: AnimeXTokens.radiusPill,
            background: moviesOnly ? AnimeXTokens.accent : 'rgba(255,255,255,0.06)',
            border: `1px solid ${moviesOnly ? AnimeXTokens.accent : AnimeXTokens.border}`,
          }}
        >
          <span style={dmSansStyle({ size: 12.5, color: moviesOnly ? '#FFF' : AnimeXTokens.textSecondary, weight: 600 })}>
            Movies Only
          </span>
        </button>
        <select
          value={year ?? ''}
          onChange={(e) => { setYear(e.target.value ? Number(e.target.value) : undefined); setPage(1); }}
          style={{
            padding: '7px 12px',
            borderRadius: AnimeXTokens.radiusPill,
            background: AnimeXTokens.surfaceRaised,
            color: AnimeXTokens.textPrimary,
            border: `1px solid ${AnimeXTokens.border}`,
            fontSize: 12.5,
          }}
        >
          <option value="">Any Year</option>
          {Array.from({ length: 16 }, (_, i) => new Date().getFullYear() - i).map((y) => (
            <option key={y} value={y}>{y}</option>
          ))}
        </select>
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 14, marginBottom: 24 }}>
        {GENRES.map((g) => {
          const active = selectedGenres.includes(g);
          return (
            <button
              key={g}
              type="button"
              className="bare-button"
              onClick={() => toggleGenre(g)}
              style={{
                padding: '5px 11px',
                borderRadius: AnimeXTokens.radiusMd,
                background: active ? 'rgba(194,24,91,0.22)' : 'rgba(255,255,255,0.04)',
                border: `1px solid ${active ? AnimeXTokens.accent : AnimeXTokens.border}`,
              }}
            >
              <span style={dmSansStyle({ size: 12, color: active ? '#FFF' : AnimeXTokens.textSecondary, weight: 500 })}>
                {g}
              </span>
            </button>
          );
        })}
      </div>

      {loading ? (
        <div style={{ padding: '48px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
          Loading anime…
        </div>
      ) : (data?.items.length ?? 0) === 0 ? (
        <div style={{ padding: '48px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
          No anime matched your filters.
        </div>
      ) : (
        <AnimeXGrid items={data!.items} width={nav.width} onSelect={(it) => nav.onWatch(it)} />
      )}

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

export function AnimeXSchedulePage({ nav }: { nav: AnimeNavActions }) {
  const todayIdx = (new Date().getDay() + 6) % 7;
  const [weekday, setWeekday] = useState(todayIdx);
  const [onlyMyList, setOnlyMyList] = useState(false);
  const [entries, setEntries] = useState<AnimexScheduleEntry[]>([]);
  const [loading, setLoading] = useState(true);

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

  const filtered = useMemo(() => {
    if (!onlyMyList) return entries;
    const keys = new Set(nav.library.map((x) => x.anilistId || x.tmdbId));
    return entries.filter((e) => keys.has(e.media.anilistId || e.media.tmdbId));
  }, [entries, onlyMyList, nav.library]);

  return (
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0 }}>Airing Schedule</h1>
          <div style={dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary })}>
            Weekly simulcast release calendar
          </div>
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={() => setOnlyMyList((v) => !v)}
          style={{
            padding: '7px 14px',
            borderRadius: AnimeXTokens.radiusPill,
            background: onlyMyList ? AnimeXTokens.accent : 'rgba(255,255,255,0.06)',
            border: `1px solid ${onlyMyList ? AnimeXTokens.accent : AnimeXTokens.border}`,
          }}
        >
          <span style={dmSansStyle({ size: 12.5, color: onlyMyList ? '#FFF' : AnimeXTokens.textSecondary, weight: 600 })}>
            My List Only
          </span>
        </button>
      </div>

      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', margin: '18px 0 24px' }} className="no-scrollbar">
        {WEEKDAYS.map((day, idx) => {
          const active = weekday === idx;
          return (
            <button
              key={day}
              type="button"
              className="bare-button"
              onClick={() => setWeekday(idx)}
              style={{
                padding: '8px 18px',
                borderRadius: AnimeXTokens.radiusMd,
                background: active ? AnimeXTokens.accent : AnimeXTokens.surfaceRaised,
                border: `1px solid ${active ? AnimeXTokens.accent : AnimeXTokens.border}`,
                flexShrink: 0,
              }}
            >
              <span style={dmSansStyle({ size: 13, color: active ? '#FFF' : AnimeXTokens.textSecondary, weight: 700 })}>
                {day}
              </span>
            </button>
          );
        })}
      </div>

      {loading ? (
        <div style={{ padding: '40px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
          Loading schedule…
        </div>
      ) : filtered.length === 0 ? (
        <div style={{ padding: '48px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
          {onlyMyList ? 'No anime from My List air on this day.' : 'No scheduled episodes found.'}
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: nav.width >= 760 ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 12 }}>
          {filtered.map((entry, idx) => (
            <div
              key={`${entry.media.anilistId || entry.media.tmdbId}-${entry.episode}-${idx}`}
              onClick={() => nav.onWatch(entry.media, entry.episode)}
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
              {entry.media.posterPath && (
                <img
                  src={entry.media.posterPath}
                  alt={entry.media.title}
                  style={{ width: 52, height: 74, borderRadius: AnimeXTokens.radiusMd, objectFit: 'cover', flexShrink: 0 }}
                />
              )}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="clamp-2" style={dmSansStyle({ size: 14, weight: 700 })}>{entry.media.title}</div>
                <div style={{ ...dmSansStyle({ size: 12, color: AnimeXTokens.accentWarm }), marginTop: 4 }}>
                  Episode {entry.episode} · {entry.airingAt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </div>
              </div>
              <Icon name="play_arrow" size={20} color={AnimeXTokens.textSecondary} />
            </div>
          ))}
        </div>
      )}

      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

// ---------- Search ----------

export function AnimeXSearchPage({ nav }: { nav: AnimeNavActions }) {
  const [queryText, setQueryText] = useState('');
  const [mode, setMode] = useState<'trending' | 'airing' | 'movies' | 'new'>('trending');
  const [results, setResults] = useState<MediaItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    const t = window.setTimeout(() => {
      setLoading(true);
      const q = queryText.trim();
      const opts = q
        ? { search: q, perPage: 30, japaneseTitle: nav.titleJapanese }
        : mode === 'trending'
          ? { sort: 'TRENDING_DESC', perPage: 30, japaneseTitle: nav.titleJapanese }
          : mode === 'airing'
            ? { sort: 'SCORE_DESC', status: 'RELEASING', perPage: 30, japaneseTitle: nav.titleJapanese }
            : mode === 'movies'
              ? { format: 'MOVIE', sort: 'POPULARITY_DESC', perPage: 30, japaneseTitle: nav.titleJapanese }
              : { sort: 'START_DATE_DESC', perPage: 30, japaneseTitle: nav.titleJapanese };
      fetchAnimexPage(opts).then((res) => {
        if (!alive) return;
        setResults(res.items);
        setLoading(false);
      });
    }, queryText.trim() ? 350 : 0);
    return () => {
      alive = false;
      window.clearTimeout(t);
    };
  }, [queryText, mode, nav.titleJapanese]);

  return (
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto' }}>
      <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0 }}>Search Anime</h1>
      <div
        style={{
          marginTop: 14,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          padding: '10px 14px',
          borderRadius: AnimeXTokens.radiusLg,
          background: AnimeXTokens.surfaceRaised,
          border: `1px solid ${AnimeXTokens.glassBorder}`,
        }}
      >
        <Icon name="search" size={20} color={AnimeXTokens.textSecondary} />
        <input
          value={queryText}
          onChange={(e) => setQueryText(e.target.value)}
          placeholder="Search titles, genres, studios…"
          autoFocus
          style={{
            flex: 1,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            color: AnimeXTokens.textPrimary,
            fontSize: 15,
            fontFamily: "'DM Sans', sans-serif",
          }}
        />
        {queryText && (
          <button type="button" className="bare-button" onClick={() => setQueryText('')}>
            <Icon name="close" size={18} color={AnimeXTokens.textSecondary} />
          </button>
        )}
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, margin: '14px 0 24px' }}>
        {([
          ['trending', 'Trending'],
          ['airing', 'Top Airing'],
          ['movies', 'Anime Movies'],
          ['new', 'Newest'],
        ] as const).map(([key, lbl]) => {
          const active = !queryText.trim() && mode === key;
          return (
            <button
              key={key}
              type="button"
              className="bare-button"
              onClick={() => { setQueryText(''); setMode(key); }}
              style={{
                padding: '6px 14px',
                borderRadius: AnimeXTokens.radiusPill,
                background: active ? AnimeXTokens.accent : 'rgba(255,255,255,0.06)',
                border: `1px solid ${active ? AnimeXTokens.accent : AnimeXTokens.border}`,
              }}
            >
              <span style={dmSansStyle({ size: 12.5, color: active ? '#FFF' : AnimeXTokens.textSecondary, weight: 600 })}>
                {lbl}
              </span>
            </button>
          );
        })}
      </div>

      {loading ? (
        <div style={{ padding: '48px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
          Searching…
        </div>
      ) : results.length === 0 ? (
        <div style={{ padding: '48px 0', textAlign: 'center', ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }) }}>
          No anime found.
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
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto' }}>
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

export function AnimeXMyListPage({ nav }: { nav: AnimeNavActions }) {
  const [tab, setTab] = useState<'all' | 'watching' | 'to-watch' | 'watched'>('all');
  const watching = nav.library.filter((x) => x.status === 'watching-self' || x.status === 'watching-together');
  const toWatch = nav.library.filter((x) => !x.status || x.status === 'to-watch');
  const watched = nav.library.filter((x) => x.status === 'watched-self' || x.status === 'watched-together');
  const shown =
    tab === 'watching' ? watching : tab === 'to-watch' ? toWatch : tab === 'watched' ? watched : nav.library;

  return (
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto' }}>
      <h1 style={{ ...bebasStyle({ size: 32 }), margin: 0 }}>My List</h1>
      <div style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }), marginTop: 2 }}>
        {nav.library.length} anime in your collection
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 14 }}>
        <AnimeXSecondaryButton label="Playlists" icon="queue_music" onClick={() => nav.onNavigate('playlists')} />
        <AnimeXSecondaryButton label="Seasonal" icon="calendar_today" onClick={() => nav.onNavigate('seasonal')} />
        <AnimeXSecondaryButton label="History" icon="history" onClick={() => nav.onNavigate('history')} />
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 16, marginBottom: 24 }}>
        {([
          ['all', `All (${nav.library.length})`],
          ['watching', `Watching (${watching.length})`],
          ['to-watch', `Plan to Watch (${toWatch.length})`],
          ['watched', `Completed (${watched.length})`],
        ] as const).map(([key, label]) => {
          const active = tab === key;
          return (
            <button
              key={key}
              type="button"
              className="bare-button"
              onClick={() => setTab(key)}
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
      </div>

      {shown.length === 0 ? (
        <div style={{ padding: '56px 0', textAlign: 'center' }}>
          <Icon name="bookmark_add" size={40} color={AnimeXTokens.textMuted} />
          <div style={{ ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary, weight: 600 }), marginTop: 12 }}>
            Your list is empty — add anime from Search
          </div>
          <div style={{ marginTop: 16 }}>
            <AnimeXPrimaryButton label="Search Anime" icon="search" onClick={nav.onOpenSearch} />
          </div>
        </div>
      ) : (
        <AnimeXGrid
          items={shown}
          width={nav.width}
          onSelect={(it) => nav.onWatch(it)}
          cardHoverAction={(it) => (
            <button
              type="button"
              className="bare-button"
              title="Remove from My List"
              onClick={() => nav.onToggleLibrary(it, false)}
              style={{
                width: 30,
                height: 30,
                borderRadius: 99,
                background: 'rgba(10, 10, 15, 0.85)',
                border: `1px solid ${AnimeXTokens.glassBorder}`,
                display: 'grid',
                placeItems: 'center',
              }}
            >
              <Icon name="close" size={16} color="#FFF" />
            </button>
          )}
        />
      )}

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
      <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto' }}>
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
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto' }}>
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
    <div style={{ padding: '20px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto' }}>
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
  return (
    <div style={{ padding: '24px 24px 64px', maxWidth: AnimeXTokens.pageMaxWidth, margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <Icon name="download_for_offline" size={26} color={AnimeXTokens.accent} />
        <h1 style={{ ...dmSansStyle({ size: 22, weight: 700 }), margin: 0 }}>Downloads</h1>
      </div>
      <div style={{ padding: '64px 0', textAlign: 'center' }}>
        <Icon name="download_for_offline" size={48} color={AnimeXTokens.textMuted} />
        <div style={{ ...dmSansStyle({ size: 16, weight: 700 }), marginTop: 14 }}>No downloaded anime yet</div>
        <div style={{ ...dmSansStyle({ size: 13, color: AnimeXTokens.textSecondary }), marginTop: 6 }}>
          Offline anime downloads are available in the desktop/native app.
        </div>
      </div>
      <AnimeXFooter onGoHome={() => nav.onNavigate('home')} onOpenDmca={nav.onOpenDmca} />
    </div>
  );
}

export function AnimeXDmcaPage({ onBack }: { onBack: () => void }) {
  return (
    <div style={{ padding: '24px 24px 64px', maxWidth: 760, margin: '0 auto' }}>
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
