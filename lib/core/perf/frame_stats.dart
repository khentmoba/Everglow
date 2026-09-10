import 'package:flutter/scheduler.dart' show FrameTiming;

/// Rolling window of frame costs for the on-device frame meter.
///
/// Why this exists: Flutter Web keeps no retained (cached bitmap) layers — the
/// draw lists are cached, but every frame re-draws the whole visible canvas, and
/// build + raster run on the *same* thread. So "is this screen smooth?" is
/// literally "does build + raster fit inside 16.7ms, every frame?", and the only
/// honest place to read that answer is the phone.
///
/// The numbers come from [FrameTiming], which the web engine reports through
/// `WidgetsBinding.addTimingsCallback` in release builds too.
///
/// Keep this class pure (numbers in, numbers out): the HUD owns timers and
/// widgets, this owns the maths, so the maths stays unit-testable.
class FrameStats {
  FrameStats({this.capacity = 240}) : assert(capacity > 0);

  /// How many recent frames the averages cover. 240 ≈ 4 seconds at 60fps —
  /// long enough to smooth out a single hitch, short enough that a screenshot
  /// still describes what just happened on screen.
  final int capacity;

  /// One smooth 60fps frame. Missing this budget drops a frame on a 60Hz
  /// phone (iOS Safari drives Flutter at 60fps even on ProMotion displays).
  static const double frameBudgetMs = 1000 / 60;

  final List<_FrameSample> _samples = <_FrameSample>[];

  /// Adds one frame's cost. [buildMs] and [rasterMs] are wall-clock ms.
  void add(double buildMs, double rasterMs) {
    _samples.add(_FrameSample(buildMs, rasterMs));
    if (_samples.length > capacity) _samples.removeAt(0);
  }

  /// Adds every frame the engine reported since the last batch.
  void addTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      add(
        timing.buildDuration.inMicroseconds / 1000,
        timing.rasterDuration.inMicroseconds / 1000,
      );
    }
  }

  void reset() => _samples.clear();

  /// Frames currently in the window.
  int get frameCount => _samples.length;

  double get avgBuildMs => _avg((s) => s.buildMs);
  double get worstBuildMs => _max((s) => s.buildMs);
  double get avgRasterMs => _avg((s) => s.rasterMs);
  double get worstRasterMs => _max((s) => s.rasterMs);

  /// Worst single frame ("slowest frame you will feel").
  double get worstTotalMs {
    if (_samples.isEmpty) return 0;
    var worst = 0.0;
    for (final s in _samples) {
      if (s.totalMs > worst) worst = s.totalMs;
    }
    return worst;
  }

  /// Share of windowed frames that missed the 60fps budget.
  double get jankPercent {
    if (_samples.isEmpty) return 0;
    var over = 0;
    for (final s in _samples) {
      if (s.totalMs > frameBudgetMs) over++;
    }
    return over * 100 / _samples.length;
  }

  /// Share of windowed frames that missed by a whole frame or more — these are
  /// the ones that read as "laggy" rather than "slightly heavy".
  double get droppedPercent {
    if (_samples.isEmpty) return 0;
    var over = 0;
    for (final s in _samples) {
      if (s.totalMs > frameBudgetMs * 2) over++;
    }
    return over * 100 / _samples.length;
  }

  double _avg(double Function(_FrameSample) pick) {
    if (_samples.isEmpty) return 0;
    var sum = 0.0;
    for (final s in _samples) {
      sum += pick(s);
    }
    return sum / _samples.length;
  }

  double _max(double Function(_FrameSample) pick) {
    if (_samples.isEmpty) return 0;
    var worst = 0.0;
    for (final s in _samples) {
      final value = pick(s);
      if (value > worst) worst = value;
    }
    return worst;
  }
}

/// Frames per second from a frame-count delta over [elapsed].
///
/// Returns 0 for a zero-length window so a fast timer tick can never divide by
/// zero or report an infinite rate.
double framesPerSecond(int frames, Duration elapsed) {
  final micros = elapsed.inMicroseconds;
  if (micros <= 0 || frames <= 0) return 0;
  return frames * Duration.microsecondsPerSecond / micros;
}

/// One reading of the meter.
///
/// Exists so the same numbers can go to the on-screen overlay *and*, on web, to
/// `window.__everglowPerf` — the overlay paints into a canvas, which leaves a
/// screenshot or nothing; the JS global makes the numbers readable by tooling
/// and automation.
class PerfSnapshot {
  const PerfSnapshot({
    required this.fps,
    required this.buildAvgMs,
    required this.buildWorstMs,
    required this.rasterAvgMs,
    required this.rasterWorstMs,
    required this.worstFrameMs,
    required this.jankPercent,
    required this.droppedPercent,
    required this.frames,
    required this.devicePixelRatio,
  });

  factory PerfSnapshot.of({
    required double fps,
    required FrameStats stats,
    required double devicePixelRatio,
  }) => PerfSnapshot(
    fps: fps,
    buildAvgMs: stats.avgBuildMs,
    buildWorstMs: stats.worstBuildMs,
    rasterAvgMs: stats.avgRasterMs,
    rasterWorstMs: stats.worstRasterMs,
    worstFrameMs: stats.worstTotalMs,
    jankPercent: stats.jankPercent,
    droppedPercent: stats.droppedPercent,
    frames: stats.frameCount,
    devicePixelRatio: devicePixelRatio,
  );

  final double fps;
  final double buildAvgMs;
  final double buildWorstMs;
  final double rasterAvgMs;
  final double rasterWorstMs;
  final double worstFrameMs;
  final double jankPercent;
  final double droppedPercent;
  final int frames;
  final double devicePixelRatio;

  /// Rounded to 2 decimals: these get read by a human or a script, they are not
  /// fed back into further maths, and full doubles are unreadable.
  Map<String, double> toMap() => <String, double>{
    'fps': _round(fps),
    'buildAvgMs': _round(buildAvgMs),
    'buildWorstMs': _round(buildWorstMs),
    'rasterAvgMs': _round(rasterAvgMs),
    'rasterWorstMs': _round(rasterWorstMs),
    'worstFrameMs': _round(worstFrameMs),
    'jankPercent': _round(jankPercent),
    'droppedPercent': _round(droppedPercent),
    'frames': frames.toDouble(),
    'devicePixelRatio': _round(devicePixelRatio),
  };

  static double _round(double value) => (value * 100).roundToDouble() / 100;
}

class _FrameSample {
  const _FrameSample(this.buildMs, this.rasterMs);

  final double buildMs;
  final double rasterMs;

  double get totalMs => buildMs + rasterMs;
}
