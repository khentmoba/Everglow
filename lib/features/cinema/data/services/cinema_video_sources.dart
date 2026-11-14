import 'dart:convert';

import '../models/video_source_config.dart';

/// Cinema-only embed servers verified as playable in live testing.
///
/// These stay out of the shared [VideoSourceService] list on purpose:
/// anime playback and watch parties keep their existing provider sets,
/// while the cinema player merges these into its server picker.
class CinemaVideoSources {
  CinemaVideoSources._();

  static const String proxyCinemaOrigin =
      'https://everglow-stream.khentplaysmoba.workers.dev';
  static const String proxyCinemaBase = '$proxyCinemaOrigin/proxyAnime';
  static const String wrapperOrigin = 'https://everglow-1c6db.web.app';
  static const String wrapperBase = '$wrapperOrigin/embed.html';

  /// Builds the Cinema Everglow HLS player URL via our ad-free resolver.
  /// [title] is shown in the player's top bar; the Worker has no catalog to
  /// look it up, so without it the player can only say "Movie".
  static String cinemaProxyUrl({
    required String mediaType,
    required String id,
    int season = 1,
    int episode = 1,
    String? title,
  }) {
    final name = (title ?? '').trim();
    final titleParam =
        name.isEmpty ? '' : '&title=${Uri.encodeQueryComponent(name)}';
    if (mediaType == 'tv') {
      return '$proxyCinemaBase?source=cinema'
          '&type=tv&tmdbId=$id&s=$season&e=$episode$titleParam';
    }
    return '$proxyCinemaBase?source=cinema&type=movie&tmdbId=$id$titleParam';
  }

  /// CineSrc embed, opened directly from its own origin.
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

  /// First-party Everglow HLS player resolved via our Cloud Function
  /// (`proxyAnime?source=cinema`) and served inside our sandboxed
  /// in-house HLS.js player with live progress, seek, and resume support.
  static const VideoSourceConfig everglowEmbed = VideoSourceConfig(
    id: 'everglow-embed',
    name: 'Everglow',
    shortName: 'Everglow',
    desc: 'No ads — Everglow player',
    movieUrl: proxyCinemaBase,
    tvUrl: proxyCinemaBase,
    isRecommended: true,
    sandboxSafe: true,
  );

  /// Our own player shell around CineSrc. It plays from Clair's device even
  /// when the Worker's HLS upstreams are down, and bridges the progress and
  /// episode events the app already understands.
  static const VideoSourceConfig everglowShell = VideoSourceConfig(
    id: 'everglow-shell',
    name: 'Everglow Player',
    shortName: 'Everglow',
    desc: 'No ads — our player',
    movieUrl: wrapperBase,
    tvUrl: wrapperBase,
    isRecommended: true,
    sandboxSafe: true,
  );

  /// The HLS row stays in the picker. Its Worker resolve is down today
  /// (fmov.my times out, vidbolt.xyz refuses the edge), so tapping it falls
  /// through to [everglowShell]. It starts working again on its own when a
  /// cinema HLS upstream answers from Cloudflare's edge.
  static const List<VideoSourceConfig> cinemaOnly = [
    everglowShell,
    everglowEmbed,
    cineSrc,
  ];

  static const Set<String> _cinemaIds = {
    'everglow-shell',
    'everglow-embed',
    'flux-cinesrc',
  };

  static const Set<String> _noAdsIds = {
    'everglow-shell',
    'everglow-embed',
    'flux-cinesrc',
    'vidcore',
    'vidlink',
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
      if (fluxSource.id == 'everglow-embed') {
        merged.add(everglowEmbed);
        byId.remove(fluxSource.id);
        continue;
      }
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

  /// Whether an internal CineSrc episode event (`cinesrc:nextepisode`)
  /// arriving from [origin] is trusted for [providerId].
  ///
  /// The direct CineSrc embed must speak from the real upstream origin;
  /// our wrapper's forwards are already origin-checked inside embed.html,
  /// so they are accepted regardless of which origin the wrapper posts
  /// from. Anything else (other providers, stale events after a server
  /// switch) is rejected so episode state never jumps on foreign input.
  static bool trustsCinesrcEpisodeEvent(String providerId, String origin) {
    if (providerId == 'flux-cinesrc') {
      return origin == 'https://cinesrc.st';
    }
    if (providerId == 'everglow-shell') return origin == wrapperOrigin;
    if (providerId == 'everglow-embed') return true;
    return false;
  }

  /// CineSrc progress is accepted only from the provider or our own wrapper.
  static bool trustsCinesrcProgressEvent(String providerId, String origin) {
    if (providerId == 'flux-cinesrc') {
      return origin == 'https://cinesrc.st';
    }
    return (providerId == 'everglow-embed' ||
            providerId == 'everglow-shell') &&
        origin == wrapperOrigin;
  }

  /// Parses an `animex-progress` event posted by our in-house Everglow HLS
  /// player (`proxyAnime?source=cinema`).
  static (int, int)? parseEverglowHlsProgress(
    String providerId,
    String origin,
    Object? raw, {
    int? expectedEpisode,
  }) {
    if (providerId != 'everglow-embed' || origin != proxyCinemaOrigin) {
      return null;
    }
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map || decoded['type'] != 'animex-progress') return null;
      final position = decoded['position'];
      final duration = decoded['duration'];
      final episode = decoded['episode'];
      if (position is! num ||
          !position.isFinite ||
          position < 0 ||
          duration is! num ||
          !duration.isFinite ||
          duration <= 0 ||
          position > duration) {
        return null;
      }
      if (expectedEpisode != null &&
          episode is num &&
          episode.toInt() != expectedEpisode) {
        return null;
      }
      return (position.round(), duration.round());
    } catch (_) {
      return null;
    }
  }

  /// Builds the embed URL for a cinema-only server, or `null` when the
  /// provider is not part of the cinema-only registry.
  static String? buildUrl(
    VideoSourceConfig provider, {
    required String mediaType,
    required String id,
    required int season,
    required int episode,
    String? title,
  }) {
    if (!_cinemaIds.contains(provider.id)) return null;

    if (provider.id == 'everglow-embed') {
      return cinemaProxyUrl(
        mediaType: mediaType,
        id: id,
        season: season,
        episode: episode,
        title: title,
      );
    }

    if (provider.id == 'everglow-shell') {
      return mediaType == 'tv'
          ? '$wrapperBase?tmdbId=$id&type=tv&s=$season&e=$episode'
          : '$wrapperBase?tmdbId=$id&type=movie';
    }

    if (mediaType == 'tv') {
      return '${provider.tvUrl}$id?s=$season&e=$episode';
    }

    return '${provider.movieUrl}$id';
  }
}
