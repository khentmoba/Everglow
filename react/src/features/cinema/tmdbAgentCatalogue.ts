// Port of lib/features/cinema/data/services/tmdb/tmdb_agent_catalogue.dart.

const TITLES = [
  'Moonlit Cinema',
  'The Lantern Trail',
  'Letters from Tomorrow',
  'Summer at Sea',
  'The Midnight Library',
  'A Little Adventure',
  'Cloud Nine',
  'Starlight Station',
];

const RECORDS = TITLES.map((title, i) => ({
  id: 900000 + i,
  media_type: i < 4 ? 'movie' : 'tv',
  title,
  name: title,
  overview:
    'A fictional story about friendship and finding your way home. This title is demo data for testing the Cinema drawer.',
  release_date: '2025-06-01',
  first_air_date: '2025-06-01',
  original_language: 'en',
  genre_ids: [18, 12],
  genres: [
    { id: 18, name: 'Drama' },
    { id: 12, name: 'Adventure' },
  ],
  vote_average: 8.2,
  vote_count: 120,
  popularity: 30.0,
  runtime: 104,
  episode_run_time: [24],
  number_of_seasons: 1,
  number_of_episodes: 3,
  seasons: [{ season_number: 1, episode_count: 3, name: 'Season 1' }],
  spoken_languages: [{ english_name: 'English' }],
}));

export function agentTmdbResponse(urlStr: string): Record<string, unknown> | null {
  const url = new URL(urlStr, 'https://everglow-1c6db.web.app');
  const allSegs = url.pathname.split('/').filter(Boolean);
  const idx = allSegs.indexOf('proxyTmdb');
  const path = idx >= 0 ? allSegs.slice(idx + 1) : allSegs;
  if (path.length === 0) return null;

  if (path[0] === 'genre') {
    return {
      genres: [
        { id: 18, name: 'Drama' },
        { id: 12, name: 'Adventure' },
      ],
    };
  }

  if (path.length > 1 && /^\d+$/.test(path[1]) && (path[0] === 'movie' || path[0] === 'tv')) {
    const idNum = Number(path[1]);
    const match = RECORDS.find((r) => r.id === idNum && r.media_type === path[0]);
    if (!match) return null;
    if (path.length === 2) return match;
    if (path[2] === 'credits') return { cast: [] };
    if (path[2] === 'season') {
      return {
        episodes: [1, 2, 3].map((i) => ({
          id: i,
          episode_number: i,
          season_number: 1,
          name: `Demo Episode ${i}`,
          overview: 'A fictional episode for local testing.',
          runtime: 24,
          air_date: '2025-06-01',
        })),
      };
    }
    if (path[2] === 'similar') return { results: RECORDS };
    return { results: [] };
  }

  const type = path.includes('movie') ? 'movie' : path.includes('tv') ? 'tv' : null;
  const q = (url.searchParams.get('query') ?? '').toLowerCase();
  const page = Number(url.searchParams.get('page') ?? '1') || 1;
  const withoutGenres = new Set(
    (url.searchParams.get('without_genres') ?? '')
      .split(',')
      .map((s) => Number(s))
      .filter((n) => !Number.isNaN(n) && n > 0),
  );
  const langJa = url.searchParams.get('with_original_language') === 'ja';

  const filtered = RECORDS.filter((r) => {
    if (type && r.media_type !== type) return false;
    if (q && !r.title.toLowerCase().includes(q)) return false;
    if (withoutGenres.size > 0 && r.genre_ids.some((g) => withoutGenres.has(g))) return false;
    return true;
  }).map((r) => (langJa ? { ...r, original_language: 'ja', genre_ids: [16] } : r));

  return {
    page,
    total_pages: 1,
    total_results: filtered.length,
    results: page === 1 ? filtered : [],
  };
}
