import 'package:flutter/foundation.dart';

/// Repaint ceiling for the dashboard's ambient "dusk bloom" layer.
///
/// 32 ms is chosen deliberately: it caps a 60 Hz display at ~30 fps while
/// still passing every *other* 16 ms tick. At 33 ms the next eligible tick
/// would land 48 ms later and the layer would actually run at 20 fps, not 30.
const Duration kAmbienceRepaintInterval = Duration(milliseconds: 32);

/// Rate-limits repaint notifications coming from a continuous animation.
///
/// Flutter Web re-rasterizes the whole visible canvas every frame, so a
/// decorative layer that repaints at the display rate costs real frame time
/// even when the motion it draws is imperceptible. This gates a controller's
/// ticks down to a fixed ceiling while still stopping instantly when the
/// underlying animation stops (that is the idle-freeze path).
///
/// The clock is injectable so tests can drive it deterministically instead of
/// racing wall-clock time.
class RepaintThrottle extends ChangeNotifier {
  /// Create a throttle that forwards at most one notification per [interval].
  RepaintThrottle({
    required this.interval,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration interval;
  final DateTime Function() _clock;

  DateTime? _lastForwarded;

  /// How many notifications this throttle has let through. Exposed so the
  /// dashboard's own benchmark can report a real rate rather than infer one.
  int forwardedCount = 0;

  /// How many source ticks were dropped.
  int droppedCount = 0;

  bool _sourceRunning = true;

  /// Call from the source animation's listener.
  void onSourceTick() {
    if (!_sourceRunning) return;
    final now = _clock();
    final last = _lastForwarded;
    if (last != null && now.difference(last) < interval) {
      droppedCount++;
      return;
    }
    _lastForwarded = now;
    forwardedCount++;
    notifyListeners();
  }

  /// Stop forwarding immediately — used when the animation pauses so an
  /// idle screen schedules no frames at all.
  void stopSource() {
    _sourceRunning = false;
  }

  /// Resume forwarding, but only if it was previously stopped, so a steady
  /// animation is not reset on every tick.
  void resumeSourceIfStopped() {
    if (_sourceRunning) return;
    _sourceRunning = true;
    _lastForwarded = null;
  }

  /// Whether the source is currently allowed to forward.
  bool get isForwarding => _sourceRunning;
}
