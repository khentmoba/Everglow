import '../models/video_source_config.dart';
import 'cinema_video_sources.dart';

/// Builds the embed URL for a [VideoSourceConfig].
///
/// Shared by the web iframe player and the native external-launch player so
/// both platforms resolve the same provider URLs. The web player previously
/// owned this logic; keep provider-specific quirks here so Android doesn't
/// drift from the web behavior.
String buildVideoSourceUrl(
  VideoSourceConfig provider, {
  required String mediaType,
  required String id,
  required int season,
  required int episode,
}) {
  final cinemaUrl = CinemaVideoSources.buildUrl(
    provider,
    mediaType: mediaType,
    id: id,
    season: season,
    episode: episode,
  );
  if (cinemaUrl != null) return cinemaUrl;

  final movieBase = provider.movieUrl;
  final tvBase = provider.tvUrl;
  final isVideasy =
      movieBase.contains('videasy') || tvBase.contains('videasy');

  if (mediaType == 'tv') {
    if (tvBase.contains('vidsrc.to')) {
      return '$tvBase$id?season=$season&episode=$episode';
    } else if (tvBase.contains('multiembed.mov')) {
      return '$tvBase$id&tmdb=1&s=$season&e=$episode';
    } else if (provider.id == 'vsembed') {
      return '$tvBase$id?season=$season&episode=$episode';
    } else if (tvBase.contains('embed') && !tvBase.endsWith('/')) {
      return '$tvBase$id?season=$season&episode=$episode';
    } else {
      final separator = tvBase.endsWith('/') ? '' : '/';
      final base = '$tvBase$separator$id/$season/$episode';
      return isVideasy
          ? '$base?autoplay=true&nextButton=true&episodeSelector=true'
          : base;
    }
  }

  if (movieBase.contains('multiembed.mov')) {
    return '$movieBase$id&tmdb=1';
  }
  final separator =
      movieBase.endsWith('/') || movieBase.contains('?') || movieBase.contains('=')
          ? ''
          : '/';
  final base = '$movieBase$separator$id';
  return isVideasy ? '$base?autoplay=true' : base;
}
