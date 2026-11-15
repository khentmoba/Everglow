import 'package:flutter/foundation.dart';

const Duration kAmbienceRepaintInterval = Duration(milliseconds: 32);

class RepaintThrottle extends ChangeNotifier {
  RepaintThrottle({
    required this.interval,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration interval;
  final DateTime Function() _clock;

  DateTime? _lastForwarded;

  int forwardedCount = 0;

  int droppedCount = 0;

  bool _sourceRunning = true;

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

  void stopSource() {
    _sourceRunning = false;
  }

  void resumeSourceIfStopped() {
    if (_sourceRunning) return;
    _sourceRunning = true;
    _lastForwarded = null;
  }

  bool get isForwarding => _sourceRunning;
}
