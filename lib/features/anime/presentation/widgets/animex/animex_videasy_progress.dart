import 'dart:convert';

class VideasyProgress {
  final double positionSeconds;
  final double durationSeconds;
  final int? episode;

  const VideasyProgress({
    required this.positionSeconds,
    required this.durationSeconds,
    this.episode,
  });
}

const videasyProgressOrigins = {
  'https://player.videasy.to',
  'https://player.videasy.net',
};

VideasyProgress? parseVideasyProgress(String origin, String data) {
  if (!videasyProgressOrigins.contains(origin)) return null;
  try {
    final json = jsonDecode(data);
    if (json is! Map) return null;
    final position = (json['timestamp'] as num?)?.toDouble();
    final duration = (json['duration'] as num?)?.toDouble();
    if (position == null ||
        !position.isFinite ||
        position < 0 ||
        duration == null ||
        !duration.isFinite ||
        duration <= 0 ||
        position > duration) {
      return null;
    }
    return VideasyProgress(
      positionSeconds: position,
      durationSeconds: duration,
      episode: (json['episode'] as num?)?.toInt(),
    );
  } catch (_) {
    return null;
  }
}

const animeXProxyOrigin =
    'https://everglow-stream.khentplaysmoba.workers.dev';

bool isAnimeXProxyPlayerUrl(String url) {
  try {
    final uri = Uri.tryParse(url);
    final source = uri?.queryParameters['source'];
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.origin == animeXProxyOrigin &&
        uri.path == '/proxyAnime' &&
        (source == 'megavid' ||
            source == 'megaplay' ||
            source == 'everglow' ||
            source == 'yumezone');
  } on FormatException {
    return false;
  }
}

bool animeXPlayerMessageOriginAllowed(String frameUrl, String origin) {
  final uri = Uri.tryParse(frameUrl);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return false;
  }
  if (videasyProgressOrigins.contains(uri.origin)) {
    return videasyProgressOrigins.contains(origin);
  }
  return origin == uri.origin;
}

VideasyProgress? parseAnimeXProgress(
  String origin,
  String frameUrl,
  Object? data,
) {
  if (origin != animeXProxyOrigin || !isAnimeXProxyPlayerUrl(frameUrl)) {
    return null;
  }
  try {
    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is! Map || decoded['type'] != 'animex-progress') return null;
    final position = decoded['position'];
    final duration = decoded['duration'];
    final episode = decoded['episode'];
    final expectedEpisode = int.tryParse(
      Uri.parse(frameUrl).queryParameters['ep'] ?? '',
    );
    if (position is! num ||
        !position.isFinite ||
        position < 0 ||
        duration is! num ||
        !duration.isFinite ||
        duration <= 0 ||
        position > duration ||
        episode is! num ||
        !episode.isFinite ||
        episode <= 0 ||
        episode != expectedEpisode) {
      return null;
    }
    return VideasyProgress(
      positionSeconds: position.toDouble(),
      durationSeconds: duration.toDouble(),
      episode: episode.toInt(),
    );
  } catch (_) {
    return null;
  }
}

double? parseEverglowEmbedScrollDelta(Object? data) {
  try {
    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is! Map || decoded['type'] != 'everglow-embed-scroll') {
      return null;
    }
    final rawY = decoded['deltaY'];
    if (rawY is! num || !rawY.isFinite) return null;
    final rawMode = decoded['deltaMode'];
    final mode = rawMode is num && rawMode.isFinite ? rawMode.toInt() : 0;
    final scale = switch (mode) {
      1 => 40.0,
      2 => 600.0,
      _ => 1.0,
    };
    final dy = rawY.toDouble() * scale;
    if (dy == 0 || !dy.isFinite) return null;
    return dy;
  } catch (_) {
    return null;
  }
}
