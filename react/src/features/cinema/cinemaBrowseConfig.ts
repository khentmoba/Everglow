// Port of lib/features/cinema/data/cinema_browse_config.dart.
import { AppColors } from '../../core/theme/colors';

export type BrowseCategoryGroup = 'collection' | 'genre' | 'decade' | 'language' | 'sort';

export interface BrowseCategoryOption {
  id: string;
  label: string;
  icon: string;
  color: string;
  group: BrowseCategoryGroup;
  mediaType: 'movie' | 'tv';
  genreId?: number;
  withoutGenres?: number[];
  yearGte?: number;
  yearLte?: number;
  voteAverageGte?: number;
  voteCountGte?: number;
  withOriginalLanguage?: string;
  sortBy?: string;
}

export const BROWSE_GROUP_META: Record<BrowseCategoryGroup, { title: string; subtitle: string }> = {
  collection: { title: 'Collections', subtitle: 'Curated starting points' },
  genre: { title: 'Genres', subtitle: 'Pick a mood' },
  decade: { title: 'By Decade', subtitle: 'Movies through time' },
  language: { title: 'World Series', subtitle: 'Live-action dramas & regional hits' },
  sort: { title: 'Rankings', subtitle: 'Top rated & trending' },
};

export const CINEMA_BROWSE_OPTIONS: BrowseCategoryOption[] = [
  { id: 'collection-movies', label: 'Movies', icon: 'movie', color: AppColors.cinemaRed, group: 'collection', mediaType: 'movie', sortBy: 'popularity.desc' },
  { id: 'collection-tv', label: 'TV Shows', icon: 'tv', color: AppColors.cinemaRed, group: 'collection', mediaType: 'tv', sortBy: 'popularity.desc' },
  { id: 'collection-new', label: 'Popular', icon: 'local_fire_department', color: AppColors.warmAmber, group: 'collection', mediaType: 'movie', yearGte: 2025, sortBy: 'popularity.desc' },

  { id: 'genre-action', label: 'Action', icon: 'bolt', color: '#E53935', group: 'genre', mediaType: 'movie', genreId: 28 },
  { id: 'genre-comedy', label: 'Comedy', icon: 'sentiment_satisfied_alt', color: '#FFB300', group: 'genre', mediaType: 'movie', genreId: 35 },
  { id: 'genre-romance', label: 'Romance', icon: 'favorite', color: '#EC407A', group: 'genre', mediaType: 'movie', genreId: 10749 },
  { id: 'genre-horror', label: 'Horror', icon: 'visibility', color: '#8E24AA', group: 'genre', mediaType: 'movie', genreId: 27 },
  { id: 'genre-scifi', label: 'Sci-Fi', icon: 'rocket_launch', color: '#1E88E5', group: 'genre', mediaType: 'movie', genreId: 878 },
  { id: 'genre-drama', label: 'Drama', icon: 'theater_comedy', color: '#43A047', group: 'genre', mediaType: 'movie', genreId: 18 },
  { id: 'genre-thriller', label: 'Thriller', icon: 'psychology', color: '#F4511E', group: 'genre', mediaType: 'movie', genreId: 53 },
  { id: 'genre-fantasy', label: 'Fantasy', icon: 'auto_fix_high', color: '#7E57C2', group: 'genre', mediaType: 'movie', genreId: 14 },
  { id: 'genre-animation', label: 'Animation', icon: 'animation', color: '#26C6DA', group: 'genre', mediaType: 'movie', genreId: 16 },
  { id: 'genre-doc', label: 'Documentary', icon: 'menu_book', color: '#78909C', group: 'genre', mediaType: 'movie', genreId: 99 },
  { id: 'genre-crime', label: 'Crime', icon: 'local_police', color: '#D81B60', group: 'genre', mediaType: 'tv', genreId: 80 },
  { id: 'genre-mystery', label: 'Mystery', icon: 'search', color: '#5E35B1', group: 'genre', mediaType: 'tv', genreId: 9648 },

  { id: 'decade-2020s', label: '2020s', icon: 'replay_30', color: '#00ACC1', group: 'decade', mediaType: 'movie', yearGte: 2020, yearLte: 2029, voteAverageGte: 6.0 },
  { id: 'decade-2010s', label: '2010s', icon: 'replay_30', color: '#26A69A', group: 'decade', mediaType: 'movie', yearGte: 2010, yearLte: 2019, voteAverageGte: 6.5 },
  { id: 'decade-2000s', label: '2000s', icon: 'replay_30', color: '#66BB6A', group: 'decade', mediaType: 'movie', yearGte: 2000, yearLte: 2009, voteAverageGte: 7.0 },
  { id: 'decade-1990s', label: '1990s', icon: 'replay_30', color: '#EF5350', group: 'decade', mediaType: 'movie', yearGte: 1990, yearLte: 1999, voteAverageGte: 7.0 },
  { id: 'decade-1980s', label: '1980s', icon: 'replay_30', color: '#AB47BC', group: 'decade', mediaType: 'movie', yearGte: 1980, yearLte: 1989, voteAverageGte: 7.0 },

  { id: 'lang-ko', label: 'Korean', icon: 'language', color: '#E53935', group: 'language', mediaType: 'tv', withOriginalLanguage: 'ko', voteAverageGte: 7.0 },
  { id: 'lang-ja', label: 'Japanese', icon: 'language', color: AppColors.cinemaRed, group: 'language', mediaType: 'tv', withOriginalLanguage: 'ja', withoutGenres: [16], voteAverageGte: 7.0 },
  { id: 'lang-hi', label: 'Hindi', icon: 'language', color: AppColors.warmAmber, group: 'language', mediaType: 'tv', withOriginalLanguage: 'hi', voteAverageGte: 6.5 },
  { id: 'lang-es', label: 'Spanish', icon: 'language', color: '#FB8C00', group: 'language', mediaType: 'tv', withOriginalLanguage: 'es', voteAverageGte: 7.0 },

  { id: 'sort-top-movies', label: 'Top Rated Movies', icon: 'star', color: AppColors.warmAmber, group: 'sort', mediaType: 'movie', sortBy: 'vote_average.desc', voteCountGte: 1000 },
  { id: 'sort-top-tv', label: 'Top Rated Series', icon: 'workspace_premium', color: AppColors.cinemaRed, group: 'sort', mediaType: 'tv', sortBy: 'vote_average.desc', voteCountGte: 500 },
];
