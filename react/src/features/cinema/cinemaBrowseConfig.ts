// Port of lib/features/cinema/data/cinema_browse_config.dart.
import { AppColors } from '../../core/theme/colors';

export type BrowseCategoryGroup = 'collection' | 'genre' | 'decade' | 'language' | 'sort';
export const BROWSE_GROUPS: BrowseCategoryGroup[] = ['collection', 'genre', 'decade', 'language', 'sort'];

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
  sortBy: string;
}

export const BROWSE_GROUP_META: Record<BrowseCategoryGroup, { title: string; subtitle: string; icon: string; tint: string }> = {
  collection: { title: 'Type', subtitle: 'MOVIES OR SHOWS', icon: 'local_fire_department', tint: AppColors.cinemaRed },
  genre: { title: 'Genres', subtitle: 'EXPLORE BY CATEGORY', icon: 'category', tint: AppColors.cinemaRed },
  decade: { title: 'Decades', subtitle: 'TIME CAPSULE', icon: 'timeline', tint: '#26A69A' },
  language: { title: 'Languages', subtitle: 'WORLD CINEMA', icon: 'language', tint: '#42A5F5' },
  sort: { title: 'Sort', subtitle: 'ORDER BY', icon: 'sort', tint: AppColors.warmAmber },
};

type Partial = Omit<BrowseCategoryOption, 'mediaType' | 'sortBy'> & { mediaType?: 'movie' | 'tv'; sortBy?: string };
const opt = (o: Partial): BrowseCategoryOption => ({ mediaType: 'movie', sortBy: 'popularity.desc', ...o });

const genre = (mediaType: 'movie' | 'tv', genreId: number, label: string, icon: string, color: string) =>
  opt({ id: `genre-${mediaType}-${genreId}`, label, icon, color, group: 'genre', mediaType, genreId });

const decade = (year: number, color: string, voteAverageGte: number) =>
  opt({
    id: `decade-${year}s`,
    label: `${year}s`,
    icon: 'replay_30',
    color,
    group: 'decade',
    yearGte: year,
    yearLte: year + 9,
    voteAverageGte,
  });

const lang = (code: string, label: string, color: string, mediaType: 'movie' | 'tv' = 'movie', withoutGenres?: number[]) =>
  opt({
    id: `lang-${code}`,
    label,
    icon: 'language',
    color,
    group: 'language',
    mediaType,
    withOriginalLanguage: code,
    withoutGenres,
    voteAverageGte: 7.0,
  });

export const CINEMA_BROWSE_OPTIONS: BrowseCategoryOption[] = [
  opt({ id: 'collection-movies', label: 'Movies', icon: 'movie', color: AppColors.cinemaRed, group: 'collection' }),
  opt({ id: 'collection-tv', label: 'TV Shows', icon: 'tv', color: AppColors.cinemaRed, group: 'collection', mediaType: 'tv' }),
  opt({
    id: 'collection-new',
    label: 'Popular',
    icon: 'local_fire_department',
    color: AppColors.warmAmber,
    group: 'collection',
    yearGte: 2025,
  }),

  genre('movie', 28, 'Action', 'local_fire_department', '#E53935'),
  genre('movie', 12, 'Adventure', 'explore', '#FF6F00'),
  genre('movie', 16, 'Animation', 'auto_awesome', '#00ACC1'),
  genre('movie', 35, 'Comedy', 'sentiment_very_satisfied', '#FDD835'),
  genre('movie', 80, 'Crime', 'gavel', '#455A64'),
  genre('movie', 18, 'Drama', 'theater_comedy', '#1565C0'),
  genre('movie', 14, 'Fantasy', 'auto_stories', '#7B1FA2'),
  genre('movie', 27, 'Horror', 'brightness_3', '#4A148C'),
  genre('movie', 9648, 'Mystery', 'youtube_searched_for', '#37474F'),
  genre('movie', 10749, 'Romance', 'favorite', AppColors.cinemaRed),
  genre('movie', 878, 'Sci-Fi', 'rocket_launch', AppColors.animeCyan),
  genre('movie', 53, 'Thriller', 'sensors', '#607D8B'),

  genre('tv', 10759, 'Action & Adventure', 'shield', '#EF6C00'),
  genre('tv', 16, 'Animated', 'auto_awesome', '#00ACC1'),
  genre('tv', 35, 'Comedy', 'sentiment_very_satisfied', '#FDD835'),
  genre('tv', 80, 'Crime', 'gavel', '#455A64'),
  genre('tv', 18, 'Drama', 'theater_comedy', '#1565C0'),
  genre('tv', 10751, 'Family', 'family_restroom', '#66BB6A'),
  genre('tv', 10762, 'Kids', 'child_care', '#42A5F5'),
  genre('tv', 9648, 'Mystery', 'youtube_searched_for', '#37474F'),
  genre('tv', 10765, 'Sci-Fi & Fantasy', 'public', '#3949AB'),
  genre('tv', 10764, 'Reality', 'videocam', '#8D6E63'),
  genre('tv', 10767, 'Talk', 'mic', '#78909C'),

  decade(2020, '#00ACC1', 6.0),
  decade(2010, '#26A69A', 6.5),
  decade(2000, '#66BB6A', 7.0),
  decade(1990, '#EF5350', 7.0),
  decade(1980, '#AB47BC', 7.0),

  lang('ko', 'Korean', '#E53935', 'tv'),
  lang('ja', 'Japanese', AppColors.cinemaRed, 'tv', [16]),
  lang('hi', 'Hindi', '#FF7043'),
  lang('es', 'Spanish', '#FDD835'),
  lang('fr', 'French', '#42A5F5'),
  lang('de', 'German', '#7E57C2'),
  lang('zh', 'Chinese', '#EF5350'),
  lang('pt', 'Portuguese', '#26A69A'),
  lang('it', 'Italian', '#EF5350'),

  opt({ id: 'sort-popular', label: 'Popular', icon: 'trending_up', color: AppColors.warmAmber, group: 'sort' }),
  opt({
    id: 'sort-rated',
    label: 'Top Rated',
    icon: 'star',
    color: AppColors.animeGold,
    group: 'sort',
    sortBy: 'vote_average.desc',
    voteCountGte: 200,
  }),
  opt({
    id: 'sort-newest',
    label: 'Newest',
    icon: 'fiber_new',
    color: '#4CAF50',
    group: 'sort',
    sortBy: 'primary_release_date.desc',
  }),
  opt({
    id: 'sort-oldest',
    label: 'Classics',
    icon: 'history',
    color: '#AB47BC',
    group: 'sort',
    sortBy: 'primary_release_date.asc',
    voteCountGte: 500,
  }),
];
