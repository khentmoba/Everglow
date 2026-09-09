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
        position < 0 ||
        duration == null ||
        duration <= 0) {
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
