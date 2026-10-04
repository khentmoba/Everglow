/// Minimal subset of media metadata needed to represent a title in a
/// Watch Party (movies, TV shows, and anime).
class MediaRef {
  final int tmdbId;
  final int? malId;
  final String mediaType; // 'movie' | 'tv'
  final bool isAnime;
  final int? season;
  final int? episode;
  final String title;
  final String posterPath;

  const MediaRef({
    required this.tmdbId,
    this.malId,
    required this.mediaType,
    this.isAnime = false,
    this.season,
    this.episode,
    required this.title,
    this.posterPath = '',
  });

  bool get isMovie => mediaType == 'movie';
}
