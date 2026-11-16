import 'dart:convert';

import '../models/video_source_config.dart';

class CinemaVideoSources {
  CinemaVideoSources._();

  static const String proxyCinemaOrigin =
      'https://everglow-stream.khentplaysmoba.workers.dev';
  static const String proxyCinemaBase = '$proxyCinemaOrigin/proxyAnime';
  static const String wrapperOrigin = 'https://everglow-1c6db.web.app';
  static const String wrapperBase = '$wrapperOrigin/embed.html';

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

  static const VideoSourceConfig everglowShell = VideoSourceConfig(
    id: 'everglow-shell',
    name: 'Celestia',
    shortName: 'Celestia',
    desc: 'No ads — our player',
    movieUrl: wrapperBase,
    tvUrl: wrapperBase,
    isRecommended: true,
    sandboxSafe: true,
  );

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
  };

  static bool _isNoAds(VideoSourceConfig p) =>
      p.sandboxSafe || _noAdsIds.contains(p.id);

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

  static bool trustsCinesrcEpisodeEvent(String providerId, String origin) {
    if (providerId == 'flux-cinesrc') {
      return origin == 'https://cinesrc.st';
    }
    if (providerId == 'everglow-shell') return origin == wrapperOrigin;
    if (providerId == 'everglow-embed') return true;
    return false;
  }

  static bool trustsCinesrcProgressEvent(String providerId, String origin) {
    if (providerId == 'flux-cinesrc') {
      return origin == 'https://cinesrc.st';
    }
    return (providerId == 'everglow-embed' ||
            providerId == 'everglow-shell') &&
        origin == wrapperOrigin;
  }

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
