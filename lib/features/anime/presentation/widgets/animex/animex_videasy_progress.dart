import 'dart:convert';

/// Playback position reported by the Videasy player.
///
/// The player posts JSON-string progress events to the parent window with
/// `timestamp` (position seconds), `duration` (total seconds) and `episode`
/// (see Videasy docs, "Watch Progress Tracking").
/// Top-level and pure so unit tests cover it without a browser.
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

/// Origins accepted for progress events. `player.videasy.net` 301s to
/// `player.videasy.to`, so live iframes report the latter — both are
/// accepted; anything else is dropped to avoid cross-provider noise.
const videasyProgressOrigins = {
  'https://player.videasy.to',
  'https://player.videasy.net',
};

/// Parses one Videasy progress postMessage. Returns null for foreign
/// origins, malformed JSON, or impossible numbers — never throws.
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
    'https://us-central1-everglow-1c6db.cloudfunctions.net';

/// Only our Megavid HTML implements the seek/progress protocol.
bool isAnimeXProxyPlayerUrl(String url) {
  try {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.origin == animeXProxyOrigin &&
        uri.path == '/proxyAnime' &&
        uri.queryParameters['source'] == 'megavid';
  } on FormatException {
    return false;
  }
}

/// Called only after the web bridge has checked event.source as well.
/// Videasy's documented redirect is the only cross-origin exception.
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

/// Our object progress events use strict numeric seconds and an episode
/// matching the loaded URL. Never accept another function on our origin.
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
