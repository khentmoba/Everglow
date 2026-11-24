// Port of lib/features/cinema/data/services/tmdb/tmdb_agent_catalogue.dart.
// Real public catalogue data, so agent-mode screens look like the live app.

interface DemoTitle {
  tmdbId: number;
  mediaType: 'movie' | 'tv';
  title: string;
  year: string;
  poster: string;
  backdrop: string;
  overview: string;
  genres: number[];
  score: number;
  votes: number;
  popularity: number;
  runtime?: number;
  episodeRunTime?: number;
  seasons?: number;
  episodes?: number;
}

const DEMO: DemoTitle[] = [
  {
    tmdbId: 693134, mediaType: 'movie', title: 'Dune: Part Two', year: '2024',
    poster: '/6izwz7rsy95ARzTR3poZ8H6c5pp.jpg', backdrop: '/eZ239CUp1d6OryZEBPnO2n87gMG.jpg',
    overview: 'Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.',
    genres: [878, 12], score: 8.1, votes: 6100, popularity: 240, runtime: 167,
  },
  {
    tmdbId: 872585, mediaType: 'movie', title: 'Oppenheimer', year: '2023',
    poster: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', backdrop: '/neeNHeXjMF5fXoCJRsOmkNGC7q.jpg',
    overview: 'The story of J. Robert Oppenheimer and the making of the atomic bomb.',
    genres: [18, 36], score: 8.1, votes: 9200, popularity: 210, runtime: 181,
  },
  {
    tmdbId: 157336, mediaType: 'movie', title: 'Interstellar', year: '2014',
    poster: '/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg', backdrop: '/8sNiAPPYU14PUepFNeSNGUTiHW.jpg',
    overview: "A team of explorers travels through a wormhole in space in an attempt to ensure humanity's survival.",
    genres: [878, 18], score: 8.4, votes: 34000, popularity: 190, runtime: 169,
  },
  {
    tmdbId: 27205, mediaType: 'movie', title: 'Inception', year: '2010',
    poster: '/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg', backdrop: '/8ZTVqvKDQ8emSGUEMjsS4yHAwrp.jpg',
    overview: 'A thief who steals corporate secrets through dream-sharing is given the inverse task: plant an idea in a mind.',
    genres: [28, 878, 53], score: 8.4, votes: 36000, popularity: 175, runtime: 148,
  },
  {
    tmdbId: 155, mediaType: 'movie', title: 'The Dark Knight', year: '2008',
    poster: '/qJ2tW6WMUDux911r6m7haRef0WH.jpg', backdrop: '/cfT29Im5VDvjE0RpyKOSdCKZal7.jpg',
    overview: 'Batman faces the Joker, a criminal mastermind who plunges Gotham into chaos.',
    genres: [18, 28, 80, 53], score: 8.5, votes: 32000, popularity: 160, runtime: 152,
  },
  {
    tmdbId: 603, mediaType: 'movie', title: 'The Matrix', year: '1999',
    poster: '/dXNAPwY7VrqMAo51EKhhCJfaGb5.jpg', backdrop: '/tlm8UkiQsitc8rSuIAscQDCnP8d.jpg',
    overview: 'A hacker learns that his reality is a simulation built by machines that rule the earth.',
    genres: [28, 878], score: 8.2, votes: 25000, popularity: 150, runtime: 136,
  },
  {
    tmdbId: 299534, mediaType: 'movie', title: 'Avengers: Endgame', year: '2019',
    poster: '/jtDv3lCnST0fZRvdYFwR5CVwK2x.jpg', backdrop: '/7RyHsO4yDXtBv1zUU3mTpHeQ0d5.jpg',
    overview: 'The remaining Avengers assemble once more to undo the damage left behind by Thanos.',
    genres: [12, 878, 28], score: 8.2, votes: 26000, popularity: 145, runtime: 181,
  },
  {
    tmdbId: 76600, mediaType: 'movie', title: 'Avatar: The Way of Water', year: '2022',
    poster: '/t6HIqrRAclMCA60NsSmeqe9RmNV.jpg', backdrop: '/kJsPVzdyBrYHLomuNv5SJDXUQ2f.jpg',
    overview: 'The Sully family fights to stay together and safe on the oceans of Pandora.',
    genres: [878, 12, 28], score: 7.6, votes: 12000, popularity: 130, runtime: 192,
  },
  {
    tmdbId: 66732, mediaType: 'tv', title: 'Stranger Things', year: '2016',
    poster: '/uOOtwVbSr4QDjAGIifLDwpb2Pdl.jpg', backdrop: '/9P4IIMYY3HifqeruZq0ZZ9g7YUi.jpg',
    overview: 'A boy vanishes and a small town uncovers a mystery of secret experiments and one strange little girl.',
    genres: [18, 10765, 9648], score: 8.6, votes: 17000, popularity: 230,
    episodeRunTime: 55, seasons: 4, episodes: 42,
  },
  {
    tmdbId: 100088, mediaType: 'tv', title: 'The Last of Us', year: '2023',
    poster: '/dmo6TYuuJgaYinXBPjrgG9mB5od.jpg', backdrop: '/lY2DhbA7Hy44fAKddr06UrXWWaQ.jpg',
    overview: 'A hardened survivor escorts a teenage girl across a ruined America.',
    genres: [18, 10765], score: 8.5, votes: 6000, popularity: 200,
    episodeRunTime: 56, seasons: 2, episodes: 16,
  },
  {
    tmdbId: 1396, mediaType: 'tv', title: 'Breaking Bad', year: '2008',
    poster: '/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg', backdrop: '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg',
    overview: "A chemistry teacher turns to making meth to secure his family's future.",
    genres: [18, 80], score: 8.9, votes: 14000, popularity: 185,
    episodeRunTime: 47, seasons: 5, episodes: 62,
  },
  {
    tmdbId: 545611, mediaType: 'movie', title: 'Everything Everywhere All at Once', year: '2022',
    poster: '/u68AjlvlutfEIcpmbYpKcdi09ut.jpg', backdrop: '/eZ239CUp1d6OryZEBPnO2n87gMG.jpg',
    overview: 'A laundromat owner is pulled into a multiverse where every version of her could matter.',
    genres: [28, 12, 878], score: 7.8, votes: 7800, popularity: 190, runtime: 139,
  },
  {
    tmdbId: 1399, mediaType: 'tv', title: 'Game of Thrones', year: '2011',
    poster: '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg', backdrop: '/lY2DhbA7Hy44fAKddr06UrXWWaQ.jpg',
    overview: 'Nine families fight for a throne while something colder waits in the north.',
    genres: [10765, 18, 10759], score: 8.4, votes: 24000, popularity: 230,
    episodeRunTime: 57, seasons: 8, episodes: 73,
  },
  {
    tmdbId: 82856, mediaType: 'tv', title: 'The Mandalorian', year: '2019',
    poster: '/sWgBv7LV2PRoQgkxwlibdGXKz1S.jpg', backdrop: '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg',
    overview: 'A bounty hunter crosses the outer rim with a child he was paid to deliver.',
    genres: [10765, 10759, 18], score: 8.4, votes: 8600, popularity: 185,
    episodeRunTime: 40, seasons: 3, episodes: 24,
  },
  {
    tmdbId: 438631, mediaType: 'movie', title: 'Dune', year: '2021',
    poster: '/v1tRXZ4JtD2Iv6fjkPvT4GiwslV.jpg', backdrop: '/eZ239CUp1d6OryZEBPnO2n87gMG.jpg',
    overview: 'The heir of a desert world has to survive the war that takes his family.',
    genres: [878, 12], score: 7.8, votes: 12000, popularity: 195, runtime: 155,
  },
  {
    tmdbId: 136315, mediaType: 'tv', title: 'The Bear', year: '2022',
    poster: '/eKfVzzEazSIjJMrw9ADa2x8ksLz.jpg', backdrop: '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg',
    overview: 'A fine-dining chef takes over his family’s sandwich shop and its noise.',
    genres: [18, 35], score: 8.3, votes: 1200, popularity: 140,
    episodeRunTime: 32, seasons: 3, episodes: 28,
  },
  {
    tmdbId: 119051, mediaType: 'tv', title: 'Wednesday', year: '2022',
    poster: '/9PFonBhy4cQy7Jz20NpMygczOkv.jpg', backdrop: '/5cvnxEHT3e39DvT6ARw4GNCFrB0.jpg',
    overview: 'Wednesday Addams navigates a school for the strange and a town with secrets.',
    genres: [18, 9648, 35], score: 8.0, votes: 3500, popularity: 165,
    episodeRunTime: 48, seasons: 1, episodes: 8,
  },
  {
    tmdbId: 76479, mediaType: 'tv', title: 'The Boys', year: '2019',
    poster: '/in1R2dDc421JxsoRWaIIAqVI2KE.jpg', backdrop: '/neeNHeXjMF5fXoCJRsOmkNGC7q.jpg',
    overview: 'Ordinary people take on the superheroes who own the country.',
    genres: [18, 10765, 35], score: 8.4, votes: 4200, popularity: 155,
    episodeRunTime: 60, seasons: 4, episodes: 32,
  },
  {
    tmdbId: 361743, mediaType: 'movie', title: 'Top Gun: Maverick', year: '2022',
    poster: '/n0YuM4f5lvGAP6MAW2kBIzugXnc.jpg', backdrop: '/8sNiAPPYU14PUepFNeSNGUTiHW.jpg',
    overview: 'After thirty years as a test pilot, Maverick trains a squad for a mission no one expects to survive.',
    genres: [28, 18], score: 8.2, votes: 10000, popularity: 180, runtime: 130,
  },
  {
    tmdbId: 569094, mediaType: 'movie', title: 'Spider-Man: Across the Spider-Verse', year: '2023',
    poster: '/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg', backdrop: '/eZ239CUp1d6OryZEBPnO2n87gMG.jpg',
    overview: 'Miles Morales meets a team of Spider-People and has to write his own story.',
    genres: [16, 28, 12], score: 8.4, votes: 9500, popularity: 200, runtime: 140,
  },
  {
    tmdbId: 414906, mediaType: 'movie', title: 'The Batman', year: '2022',
    poster: '/74xTEgt7R36Fpooo50r9T25onhq.jpg', backdrop: '/neeNHeXjMF5fXoCJRsOmkNGC7q.jpg',
    overview: 'A young Batman follows a trail of riddles through a city that would rather look away.',
    genres: [80, 9648, 53], score: 7.7, votes: 11000, popularity: 170, runtime: 176,
  },
  {
    tmdbId: 603692, mediaType: 'movie', title: 'John Wick: Chapter 4', year: '2023',
    poster: '/vZloFAK7NmvMGKE7VkF5UHaz0I.jpg', backdrop: '/8sNiAPPYU14PUepFNeSNGUTiHW.jpg',
    overview: 'John Wick takes the fight to the High Table, one city at a time.',
    genres: [28, 53, 80], score: 7.7, votes: 8000, popularity: 160, runtime: 170,
  },
  {
    tmdbId: 95396, mediaType: 'tv', title: 'Severance', year: '2022',
    poster: '/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg', backdrop: '/lY2DhbA7Hy44fAKddr06UrXWWaQ.jpg',
    overview: 'Office workers have their memories split so work and home never meet.',
    genres: [18, 9648, 10765], score: 8.4, votes: 1800, popularity: 150,
    episodeRunTime: 50, seasons: 2, episodes: 19,
  },
  {
    tmdbId: 94605, mediaType: 'tv', title: 'Arcane', year: '2021',
    poster: '/87C0wecB8bHb1PsrKBI4kJiEkgV.jpg', backdrop: '/5cvnxEHT3e39DvT6ARw4GNCFrB0.jpg',
    overview: 'Two sisters end up on opposite sides of a war between magic and conviction.',
    genres: [16, 10765, 18], score: 8.7, votes: 4500, popularity: 170,
    episodeRunTime: 42, seasons: 2, episodes: 18,
  },
];

const GENRE_NAMES: Record<number, string> = {
  28: 'Action', 12: 'Adventure', 16: 'Animation', 18: 'Drama', 36: 'History', 53: 'Thriller',
  80: 'Crime', 878: 'Science Fiction', 9648: 'Mystery', 10765: 'Sci-Fi & Fantasy',
};

const record = (d: DemoTitle) => ({
  id: d.tmdbId,
  media_type: d.mediaType,
  title: d.title,
  name: d.title,
  overview: d.overview,
  release_date: `${d.year}-06-01`,
  first_air_date: `${d.year}-06-01`,
  original_language: d.genres.includes(16) ? 'ja' : 'en',
  genre_ids: d.genres,
  genres: d.genres.map((id) => ({ id, name: GENRE_NAMES[id] ?? 'Drama' })),
  vote_average: d.score,
  vote_count: d.votes,
  popularity: d.popularity,
  poster_path: d.poster,
  backdrop_path: d.backdrop,
  runtime: d.runtime ?? 0,
  episode_run_time: [d.episodeRunTime ?? 45],
  number_of_seasons: d.seasons ?? 1,
  number_of_episodes: d.episodes ?? 1,
  seasons: Array.from({ length: d.seasons ?? 1 }, (_, i) => ({
    season_number: i + 1,
    episode_count: Math.max(1, Math.round((d.episodes ?? 1) / (d.seasons ?? 1))),
    name: `Season ${i + 1}`,
    poster_path: d.poster,
    air_date: `${Number(d.year) + i}-01-01`,
  })),
  spoken_languages: [{ english_name: 'English' }],
  status: 'Released',
  tagline: '',
});

const RECORDS = DEMO.map(record);

const EPISODE_BLURBS = [
  'A quiet morning turns into the day everything changes on {show}.',
  'An old promise comes due, and nobody is ready to pay it.',
  'Two people take the long way round and say almost nothing.',
  'The plan works, which turns out to be the problem.',
  'A door that was locked all season is finally open.',
  'Someone tells the truth, and it costs them the room.',
  'A message arrives from a place nobody can reach.',
  'The rain stops, and the aftermath is worse than the storm.',
];

const EPISODE_TITLES = [
  'Pilot', 'The Long Way Home', 'Quiet Hours', 'Crossing Lines', 'Nightfall',
  'What We Keep', 'Signal Fire', 'After the Rain', 'Two Roads', 'Last Light',
];

export function agentTmdbResponse(urlStr: string): Record<string, unknown> | null {
  const url = new URL(urlStr, 'https://everglow-1c6db.web.app');
  const allSegs = url.pathname.split('/').filter(Boolean);
  const idx = allSegs.indexOf('proxyTmdb');
  const path = idx >= 0 ? allSegs.slice(idx + 1) : allSegs;
  if (path.length === 0) return null;

  if (path[0] === 'genre') {
    return { genres: Object.entries(GENRE_NAMES).map(([id, name]) => ({ id: Number(id), name })) };
  }

  if (path.length > 1 && /^\d+$/.test(path[1]) && (path[0] === 'movie' || path[0] === 'tv')) {
    const idNum = Number(path[1]);
    const match = RECORDS.find((r) => r.id === idNum && r.media_type === path[0]);
    if (!match) return null;
    if (path.length === 2) return { ...match, credits: { cast: [] }, videos: { results: [] } };
    if (path[2] === 'credits') {
      return {
        cast: ['Mara Ellis', 'Jonah Reyes', 'Ines Duarte', 'Theo Park', 'Ada Kim'].map((name, i) => ({
          id: 700 + i,
          name,
          character: ['Lead', 'Partner', 'Mentor', 'Rival', 'Ally'][i],
          profile_path: '',
        })),
      };
    }
    if (path[2] === 'season') {
      const seasonNumber = Number(path[3] ?? '1') || 1;
      const count = Math.min(10, match.seasons?.[seasonNumber - 1]?.episode_count ?? 8);
      // Screens should not show seven copies of one frame: rotate the catalogue art.
      const at = Math.max(0, RECORDS.findIndex((r) => r.id === idNum && r.media_type === path[0]));
      return {
        episodes: Array.from({ length: count }, (_, i) => ({
          id: seasonNumber * 100 + i + 1,
          episode_number: i + 1,
          season_number: seasonNumber,
          name: EPISODE_TITLES[i % EPISODE_TITLES.length],
          // Each episode gets its own line and length, so a list of rows is not
          // eight copies of one sentence with one runtime.
          overview: EPISODE_BLURBS[i % EPISODE_BLURBS.length].replace('{show}', match.name),
          runtime: (match.episode_run_time?.[0] ?? 45) + (i % 3) * 2,
          air_date: `${match.first_air_date.slice(0, 4)}-06-${String(i + 1).padStart(2, '0')}`,
          // Stills come from the title itself, and they alternate between its
          // backdrop and its poster: eight rows of one identical image read as a
          // broken asset, and the fixture has no per-episode art.
          still_path: i % 2 === 0 ? RECORDS[at].backdrop_path : RECORDS[at].poster_path,
        })),
      };
    }
    if (path[2] === 'similar') return { results: RECORDS.filter((r) => r.id !== idNum) };
    if (path[2] === 'videos') return { results: [] };
    if (path[2] === 'reviews') return { results: [] };
    if (path[2] === 'external_ids') return { imdb_id: '' };
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
  const withGenres = (url.searchParams.get('with_genres') ?? '')
    .split(',')
    .map((s) => Number(s))
    .filter((n) => !Number.isNaN(n) && n > 0);
  const langJa = url.searchParams.get('with_original_language') === 'ja';

  const filtered = RECORDS.filter((r) => {
    if (type && r.media_type !== type) return false;
    if (q && !r.name.toLowerCase().includes(q)) return false;
    if (withoutGenres.size > 0 && r.genre_ids.some((g) => withoutGenres.has(g))) return false;
    if (withGenres.length > 0 && !r.genre_ids.some((g) => withGenres.includes(g))) return false;
    return true;
  }).map((r) => (langJa ? { ...r, original_language: 'ja', genre_ids: [16] } : r));

  const language = url.searchParams.get('with_original_language');
  const spoken = language ? filtered.filter((r) => r.original_language === language) : filtered;

  return {
    page,
    total_pages: 1,
    total_results: spoken.length,
    results: page === 1 ? spoken : [],
  };
}
