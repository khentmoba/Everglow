import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Groups of browse options used by the Cinema Browse tab.
enum BrowseCategoryGroup { collection, genre, decade, language, sort }

/// A browse option that maps to TMDB discovery parameters.
/// Each option has an id, label, icon, color, and a group it belongs to.
class BrowseCategoryOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final BrowseCategoryGroup group;

  /// Media type for TMDB discovery ('movie' or 'tv').
  final String mediaType;

  /// TMDB genre id filter (for genre-type options).
  final int? genreId;

  /// Year range filter.
  final int? yearGte;
  final int? yearLte;

  /// Vote average minimum filter.
  final double? voteAverageGte;

  /// Vote count minimum filter.
  final int? voteCountGte;

  /// Original language filter.
  final String? withOriginalLanguage;

  /// Sort order for TMDB discover.
  final String sortBy;

  const BrowseCategoryOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.group,
    this.mediaType = 'movie',
    this.genreId,
    this.yearGte,
    this.yearLte,
    this.voteAverageGte,
    this.voteCountGte,
    this.withOriginalLanguage,
    this.sortBy = 'popularity.desc',
  });
}

/// All browse options for the Cinema screen.
final List<BrowseCategoryOption> cinemaBrowseOptions = [
  const BrowseCategoryOption(
    id: 'collection-movies',
    label: 'Movies',
    icon: Icons.movie_rounded,
    color: AppColors.deepRose,
    group: BrowseCategoryGroup.collection,
    mediaType: 'movie',
    sortBy: 'popularity.desc',
  ),
  const BrowseCategoryOption(
    id: 'collection-tv',
    label: 'TV Shows',
    icon: Icons.tv_rounded,
    color: AppColors.deepRose,
    group: BrowseCategoryGroup.collection,
    mediaType: 'tv',
    sortBy: 'popularity.desc',
  ),
  const BrowseCategoryOption(
    id: 'collection-new',
    label: 'New & Popular',
    icon: Icons.local_fire_department_rounded,
    color: AppColors.warmAmber,
    group: BrowseCategoryGroup.collection,
    mediaType: 'movie',
    yearGte: 2025,
    sortBy: 'popularity.desc',
  ),

  // ── Genre options (movies + TV) ─────────────────────────────
  ..._movieGenreOptions,
  ..._tvGenreOptions,

  // ── Decade options ──────────────────────────────────────────
  const BrowseCategoryOption(
    id: 'decade-2020s',
    label: '2020s',
    icon: Icons.replay_30_rounded,
    color: Color(0xFF00ACC1),
    group: BrowseCategoryGroup.decade,
    mediaType: 'movie',
    yearGte: 2020,
    yearLte: 2029,
    voteAverageGte: 6.0,
  ),
  const BrowseCategoryOption(
    id: 'decade-2010s',
    label: '2010s',
    icon: Icons.replay_30_rounded,
    color: Color(0xFF26A69A),
    group: BrowseCategoryGroup.decade,
    mediaType: 'movie',
    yearGte: 2010,
    yearLte: 2019,
    voteAverageGte: 6.5,
  ),
  const BrowseCategoryOption(
    id: 'decade-2000s',
    label: '2000s',
    icon: Icons.replay_30_rounded,
    color: Color(0xFF66BB6A),
    group: BrowseCategoryGroup.decade,
    mediaType: 'movie',
    yearGte: 2000,
    yearLte: 2009,
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'decade-1990s',
    label: '1990s',
    icon: Icons.replay_30_rounded,
    color: Color(0xFFEF5350),
    group: BrowseCategoryGroup.decade,
    mediaType: 'movie',
    yearGte: 1990,
    yearLte: 1999,
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'decade-1980s',
    label: '1980s',
    icon: Icons.replay_30_rounded,
    color: Color(0xFFAB47BC),
    group: BrowseCategoryGroup.decade,
    mediaType: 'movie',
    yearGte: 1980,
    yearLte: 1989,
    voteAverageGte: 7.0,
  ),

  // ── Language options ────────────────────────────────────────
  const BrowseCategoryOption(
    id: 'lang-ko',
    label: 'Korean',
    icon: Icons.language_rounded,
    color: Color(0xFFE53935),
    group: BrowseCategoryGroup.language,
    mediaType: 'tv',
    withOriginalLanguage: 'ko',
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'lang-ja',
    label: 'Japanese',
    icon: Icons.language_rounded,
    color: AppColors.accentPink,
    group: BrowseCategoryGroup.language,
    mediaType: 'tv',
    withOriginalLanguage: 'ja',
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'lang-hi',
    label: 'Hindi',
    icon: Icons.language_rounded,
    color: Color(0xFFFF7043),
    group: BrowseCategoryGroup.language,
    mediaType: 'movie',
    withOriginalLanguage: 'hi',
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'lang-es',
    label: 'Spanish',
    icon: Icons.language_rounded,
    color: Color(0xFFFDD835),
    group: BrowseCategoryGroup.language,
    mediaType: 'movie',
    withOriginalLanguage: 'es',
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'lang-fr',
    label: 'French',
    icon: Icons.language_rounded,
    color: Color(0xFF42A5F5),
    group: BrowseCategoryGroup.language,
    mediaType: 'movie',
    withOriginalLanguage: 'fr',
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'lang-de',
    label: 'German',
    icon: Icons.language_rounded,
    color: Color(0xFF7E57C2),
    group: BrowseCategoryGroup.language,
    mediaType: 'movie',
    withOriginalLanguage: 'de',
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'lang-zh',
    label: 'Chinese',
    icon: Icons.language_rounded,
    color: Color(0xFFEF5350),
    group: BrowseCategoryGroup.language,
    mediaType: 'movie',
    withOriginalLanguage: 'zh',
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'lang-pt',
    label: 'Portuguese',
    icon: Icons.language_rounded,
    color: Color(0xFF26A69A),
    group: BrowseCategoryGroup.language,
    mediaType: 'movie',
    withOriginalLanguage: 'pt',
    voteAverageGte: 7.0,
  ),
  const BrowseCategoryOption(
    id: 'lang-it',
    label: 'Italian',
    icon: Icons.language_rounded,
    color: Color(0xFFEF5350),
    group: BrowseCategoryGroup.language,
    mediaType: 'movie',
    withOriginalLanguage: 'it',
    voteAverageGte: 7.0,
  ),

  // ── Sort options ────────────────────────────────────────────
  const BrowseCategoryOption(
    id: 'sort-popular',
    label: 'Popular',
    icon: Icons.trending_up_rounded,
    color: AppColors.warmAmber,
    group: BrowseCategoryGroup.sort,
    sortBy: 'popularity.desc',
  ),
  const BrowseCategoryOption(
    id: 'sort-rated',
    label: 'Top Rated',
    icon: Icons.star_rounded,
    color: AppColors.animeGold,
    group: BrowseCategoryGroup.sort,
    sortBy: 'vote_average.desc',
    voteCountGte: 200,
  ),
  const BrowseCategoryOption(
    id: 'sort-newest',
    label: 'Newest',
    icon: Icons.fiber_new_rounded,
    color: Color(0xFF4CAF50),
    group: BrowseCategoryGroup.sort,
    sortBy: 'primary_release_date.desc',
  ),
  const BrowseCategoryOption(
    id: 'sort-oldest',
    label: 'Classics',
    icon: Icons.history_rounded,
    color: Color(0xFFAB47BC),
    group: BrowseCategoryGroup.sort,
    sortBy: 'primary_release_date.asc',
    voteCountGte: 500,
  ),
];

/// TMDB movie genre options for the Browse tab.
List<BrowseCategoryOption> get _movieGenreOptions => [
  const BrowseCategoryOption(
    id: 'genre-movie-28',
    label: 'Action',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFE53935),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 28,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-12',
    label: 'Adventure',
    icon: Icons.explore_rounded,
    color: Color(0xFFFF6F00),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 12,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-16',
    label: 'Animation',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF00ACC1),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 16,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-35',
    label: 'Comedy',
    icon: Icons.sentiment_very_satisfied_rounded,
    color: Color(0xFFFDD835),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 35,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-80',
    label: 'Crime',
    icon: Icons.gavel_rounded,
    color: Color(0xFF455A64),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 80,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-18',
    label: 'Drama',
    icon: Icons.theater_comedy_rounded,
    color: Color(0xFF1565C0),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 18,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-14',
    label: 'Fantasy',
    icon: Icons.auto_stories_rounded,
    color: Color(0xFF7B1FA2),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 14,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-27',
    label: 'Horror',
    icon: Icons.brightness_3_rounded,
    color: Color(0xFF4A148C),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 27,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-9648',
    label: 'Mystery',
    icon: Icons.youtube_searched_for_rounded,
    color: Color(0xFF37474F),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 9648,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-10749',
    label: 'Romance',
    icon: Icons.favorite_rounded,
    color: AppColors.accentPink,
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 10749,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-878',
    label: 'Sci-Fi',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.animeCyan,
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 878,
  ),
  const BrowseCategoryOption(
    id: 'genre-movie-53',
    label: 'Thriller',
    icon: Icons.sensors_rounded,
    color: Color(0xFF607D8B),
    group: BrowseCategoryGroup.genre,
    mediaType: 'movie',
    genreId: 53,
  ),
];

/// TMDB TV genre options for the Browse tab.
List<BrowseCategoryOption> get _tvGenreOptions => [
  const BrowseCategoryOption(
    id: 'genre-tv-10759',
    label: 'Action & Adventure',
    icon: Icons.shield_rounded,
    color: Color(0xFFEF6C00),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 10759,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-16',
    label: 'Animated',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF00ACC1),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 16,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-35',
    label: 'Comedy',
    icon: Icons.sentiment_very_satisfied_rounded,
    color: Color(0xFFFDD835),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 35,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-80',
    label: 'Crime',
    icon: Icons.gavel_rounded,
    color: Color(0xFF455A64),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 80,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-18',
    label: 'Drama',
    icon: Icons.theater_comedy_rounded,
    color: Color(0xFF1565C0),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 18,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-10751',
    label: 'Family',
    icon: Icons.family_restroom_rounded,
    color: Color(0xFF66BB6A),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 10751,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-10762',
    label: 'Kids',
    icon: Icons.child_care_rounded,
    color: Color(0xFF42A5F5),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 10762,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-9648',
    label: 'Mystery',
    icon: Icons.youtube_searched_for_rounded,
    color: Color(0xFF37474F),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 9648,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-10765',
    label: 'Sci-Fi & Fantasy',
    icon: Icons.public_rounded,
    color: Color(0xFF3949AB),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 10765,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-10764',
    label: 'Reality',
    icon: Icons.videocam_rounded,
    color: Color(0xFF8D6E63),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 10764,
  ),
  const BrowseCategoryOption(
    id: 'genre-tv-10767',
    label: 'Talk',
    icon: Icons.mic_rounded,
    color: Color(0xFF78909C),
    group: BrowseCategoryGroup.genre,
    mediaType: 'tv',
    genreId: 10767,
  ),
];

/// Group metadata for rendering browse group headers.
class BrowseGroupMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;

  const BrowseGroupMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });
}

/// Metadata lookup for each browse category group.
BrowseGroupMeta browseGroupMeta(BrowseCategoryGroup group) {
  switch (group) {
    case BrowseCategoryGroup.collection:
      return const BrowseGroupMeta(
        title: 'Collections',
        subtitle: 'CURATED PICKS',
        icon: Icons.local_fire_department_rounded,
        tint: AppColors.deepRose,
      );
    case BrowseCategoryGroup.genre:
      return const BrowseGroupMeta(
        title: 'Genres',
        subtitle: 'EXPLORE BY CATEGORY',
        icon: Icons.category_rounded,
        tint: AppColors.deepRose,
      );
    case BrowseCategoryGroup.decade:
      return const BrowseGroupMeta(
        title: 'Decades',
        subtitle: 'TIME CAPSULE',
        icon: Icons.timeline_rounded,
        tint: Color(0xFF26A69A),
      );
    case BrowseCategoryGroup.language:
      return const BrowseGroupMeta(
        title: 'Languages',
        subtitle: 'WORLD CINEMA',
        icon: Icons.language_rounded,
        tint: Color(0xFF42A5F5),
      );
    case BrowseCategoryGroup.sort:
      return const BrowseGroupMeta(
        title: 'Sort',
        subtitle: 'ORDER BY',
        icon: Icons.sort_rounded,
        tint: AppColors.warmAmber,
      );
  }
}
