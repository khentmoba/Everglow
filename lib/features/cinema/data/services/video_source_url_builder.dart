import '../models/video_source_config.dart';
import 'cinema_video_sources.dart';

String buildVideoSourceUrl(
  VideoSourceConfig provider, {
  required String mediaType,
  required String id,
  required int season,
  required int episode,
  int? startSeconds,
  String? title,
}) {
  final cinemaUrl = CinemaVideoSources.buildUrl(
    provider,
    mediaType: mediaType,
    id: id,
    season: season,
    episode: episode,
    title: title,
  );
  if (cinemaUrl != null) {
    return _withStartSeconds(cinemaUrl, startSeconds);
  }

  final movieBase = provider.movieUrl;
  final tvBase = provider.tvUrl;
  final isVideasy = movieBase.contains('videasy') || tvBase.contains('videasy');

  if (mediaType == 'tv') {
    if (tvBase.contains('multiembed.mov')) {
      return '$tvBase$id&tmdb=1&s=$season&e=$episode';
    } else if (provider.id == 'vsembed') {
      return '$tvBase$id?season=$season&episode=$episode';
    } else if (tvBase.contains('embed') && !tvBase.endsWith('/')) {
      return '$tvBase$id?season=$season&episode=$episode';
    } else {
      final separator = tvBase.endsWith('/') ? '' : '/';
      final base = '$tvBase$separator$id/$season/$episode';
      final url = isVideasy
          ? '$base?autoplay=true&nextButton=true&episodeSelector=true'
          : base;
      return _withStartSeconds(url, startSeconds);
    }
  }

  if (movieBase.contains('multiembed.mov')) {
    return '$movieBase$id&tmdb=1';
  }
  final separator =
      movieBase.endsWith('/') ||
          movieBase.contains('?') ||
          movieBase.contains('=')
      ? ''
      : '/';
  final base = '$movieBase$separator$id';
  final base2 = isVideasy ? '$base?autoplay=true' : base;
  return _withStartSeconds(base2, startSeconds);
}

String _withStartSeconds(String url, int? startSeconds) {
  if (startSeconds == null || startSeconds <= 0) return url;
  return url.contains('?')
      ? '$url&start=$startSeconds'
      : '$url?start=$startSeconds';
}
