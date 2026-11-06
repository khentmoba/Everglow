/// Estimates the server's clock from Firestore server timestamps.
///
/// The couple's shared playback position is anchored to a server time
/// (`positionAt`), not to whichever browser happened to press play. To
/// read that anchor both clients need to know roughly what the server
/// clock says right now. Firestore has no "server time" call, but every
/// server timestamp it hands back is a sample: the server wrote it, and
/// we received it a moment later. The largest sample we have seen is the
/// one with the least network delay, so it is the closest to the truth.
///
/// Samples are dropped after [maxSampleAge] so a laptop that slept for an
/// hour re-learns the offset instead of trusting a stale one.
class WatchPartyClock {
  WatchPartyClock({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// A clock skew larger than this is almost certainly a bad sample (or a
  /// device clock that is wildly wrong). Clamp rather than jump the video.
  static const Duration maxOffset = Duration(minutes: 5);

  /// How long a sample stays trustworthy.
  static const Duration maxSampleAge = Duration(minutes: 10);

  Duration _offset = Duration.zero;
  DateTime? _sampledAt;

  /// Estimated `serverNow - localNow`.
  Duration get offset => _offset;

  /// Best estimate of the server's current time.
  DateTime get serverNow => _now().add(_offset);

  /// Feed a server timestamp received from Firestore. [receivedAt]
  /// defaults to now and exists so tests can pin the receipt time.
  void observe(DateTime serverTime, {DateTime? receivedAt}) {
    final received = receivedAt ?? _now();
    final sample = serverTime.difference(received);
    final stale =
        _sampledAt == null ||
        received.difference(_sampledAt!) > maxSampleAge;

    if (stale || sample > _offset) {
      _offset = _clamp(sample);
    }
    _sampledAt = received;
  }

  /// Seconds to add to a local playback position before writing it as the
  /// room's new anchor, so the anchor matches the server commit time.
  double get offsetSeconds => _offset.inMilliseconds / 1000.0;

  static Duration _clamp(Duration value) {
    if (value > maxOffset) return maxOffset;
    if (value < -maxOffset) return -maxOffset;
    return value;
  }
}
