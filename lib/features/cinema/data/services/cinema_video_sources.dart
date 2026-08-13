import '../models/video_source_config.dart';

/// Cinema-only embed servers verified as playable in live testing.
///
/// These stay out of the shared [VideoSourceService] list on purpose:
/// anime playback and watch parties keep their existing provider sets,
/// while the cinema player merges these into its server picker.
class CinemaVideoSources {
  CinemaVideoSources._();

  /// CineSrc streaming API (ShuttleTV lineage).
  static const VideoSourceConfig cineSrc = VideoSourceConfig(
    id: 'flux-cinesrc',
    name: 'CineSrc',
    shortName: 'CineSrc',
    desc: 'No ads, high quality, sometimes unstable',
    movieUrl: 'https://cinesrc.st/embed/movie/',
    tvUrl: 'https://cinesrc.st/embed/tv/',
    isRecommended: true,
    sandboxSafe: true,
  );

  /// Ordered cinema-only servers verified in live testing.
  static const List<VideoSourceConfig> cinemaOnly = [cineSrc];

  static const Set<String> _cinemaIds = {
    'flux-cinesrc',
  };

  /// Returns the provider list for the cinema player.
  ///
  /// For non-anime content the verified cinema servers are promoted first
  /// with the shared sources (Firestore or hardcoded) following behind.
  /// Anime keeps its existing behavior: Videasy first, no cinema-only servers.
  static List<VideoSourceConfig> selectable(
    List<VideoSourceConfig> shared, {
    required bool isAnime,
  }) {
    if (isAnime) {
      final videasy = shared.where((p) => p.id == 'videasy').toList();
      final rest = shared.where((p) => p.id != 'videasy').toList();
      return [...videasy, ...rest];
    }

    final byId = <String, VideoSourceConfig>{};
    for (final source in shared) {
      byId[source.id] = source;
    }

    final merged = <VideoSourceConfig>[];
    for (final fluxSource in cinemaOnly) {
      final existing = byId[fluxSource.id];
      merged.add(existing ?? fluxSource);
      byId.remove(fluxSource.id);
    }
    merged.addAll(byId.values);
    return merged;
  }

  /// Builds the embed URL for a cinema-only server, or `null` when the
  /// provider is not part of the cinema-only registry.
  static String? buildUrl(
    VideoSourceConfig provider, {
    required String mediaType,
    required String id,
    required int season,
    required int episode,
  }) {
    if (!_cinemaIds.contains(provider.id)) return null;

    if (mediaType == 'tv') {
      return '${provider.tvUrl}$id?s=$season&e=$episode';
    }

    return '${provider.movieUrl}$id';
  }
}
