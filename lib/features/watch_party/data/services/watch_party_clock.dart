class WatchPartyClock {
  WatchPartyClock({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static const Duration maxOffset = Duration(minutes: 5);

  static const Duration maxSampleAge = Duration(minutes: 10);

  static const Duration _pendingEpsilon = Duration(milliseconds: 100);

  Duration _offset = Duration.zero;
  DateTime? _sampledAt;

  Duration get offset => _offset;

  DateTime get serverNow => _now().add(_offset);

  void observe(DateTime serverTime, {DateTime? receivedAt}) {
    final received = receivedAt ?? _now();
    final sample = serverTime.difference(received);
    if (sample.abs() <= _pendingEpsilon) return;
    final stale =
        _sampledAt == null ||
        received.difference(_sampledAt!) > maxSampleAge;

    if (stale || sample > _offset) {
      _offset = _clamp(sample);
    }
    _sampledAt = received;
  }

  static Duration _clamp(Duration value) {
    if (value > maxOffset) return maxOffset;
    if (value < -maxOffset) return -maxOffset;
    return value;
  }
}
