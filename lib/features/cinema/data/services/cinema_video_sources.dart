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

  static const Set<String> _cinemaIds = {'flux-cinesrc'};

  static const Set<String> _noAdsIds = {
    'flux-cinesrc',
    'videasy',
    'movish',
    'vidbolt',
  };

  static bool _isNoAds(VideoSourceConfig p) =>
      p.sandboxSafe || _noAdsIds.contains(p.id);

  /// Returns the provider list for the cinema player.
  ///
  /// For non-anime content the verified cinema servers are promoted first
  /// with the shared sources (Firestore or hardcoded) following behind.
  /// No-ads providers (CineSrc/Videasy/Movish/VidBolt) are always at the
  /// top; ad-heavy mirrors (VsEmbed/VidRock/111Movies/Vidsrc/MultiEmbed)
  /// are forced to the bottom regardless of Firestore ordering.
  /// Anime keeps its existing behavior: Videasy first, no cinema-only servers,
  /// but still groups remaining no-ads before ad-heavy.
  static List<VideoSourceConfig> selectable(
    List<VideoSourceConfig> shared, {
    required bool isAnime,
  }) {
    if (isAnime) {
      final videasy = shared.where((p) => p.id == 'videasy').toList();
      final rest = shared.where((p) => p.id != 'videasy').toList();
      final restNoAds = rest.where(_isNoAds).toList();
      final restAdHeavy = rest.where((p) => !_isNoAds(p)).toList();
      return [...videasy, ...restNoAds, ...restAdHeavy];
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
    final remaining = byId.values.toList();
    final noAds = remaining.where(_isNoAds).toList();
    final adHeavy = remaining.where((p) => !_isNoAds(p)).toList();
    merged.addAll(noAds);
    merged.addAll(adHeavy);
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
