import 'dart:async';

import '../../../../core/utils/logger.dart';

/// Throttles cloud progress without postponing every save on every tick.
/// Each callback captures its own profile/episode/position; writes are ordered
/// so a slow old-episode save cannot overwrite the next episode's progress.
class PlaybackProgressWriter {
  Timer? _timer;
  Future<void> Function()? _pending;
  Future<void> _writes = Future.value();

  void schedule(Future<void> Function() write) {
    _pending = write;
    if (_timer?.isActive ?? false) return;
    _timer = Timer(const Duration(seconds: 15), flush);
  }

  Future<void> writeNow(Future<void> Function() write) {
    flush();
    _writes = _writes.then((_) => write()).catchError((
      Object e,
      StackTrace st,
    ) {
      Logger.e('Cinema: progress save failed', error: e, stackTrace: st);
    });
    return _writes;
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final write = _pending;
    _pending = null;
    if (write != null) return writeNow(write);
    return _writes;
  }
}

/// Never infer completion from wall-clock time or a credits estimate.
/// Silent embeds keep the manual Next button instead.
bool shouldAutoplayNext({
  required bool enabled,
  required int positionSeconds,
  required int durationSeconds,
}) => enabled && durationSeconds > 60 && positionSeconds >= durationSeconds;
