class MediaRef {
  final int tmdbId;
  final int? malId;
  final String mediaType;
  final bool isAnime;
  final int? season;
  final int? episode;
  final int? episodeCount;
  final String title;
  final String posterPath;

  const MediaRef({
    required this.tmdbId,
    this.malId,
    required this.mediaType,
    this.isAnime = false,
    this.season,
    this.episode,
    this.episodeCount,
    required this.title,
    this.posterPath = '',
  });

  bool get isMovie => mediaType == 'movie';
}
