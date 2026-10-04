import 'package:flutter/scheduler.dart' show FrameTiming;

/// Reported Flutter frame timings, not display presentation or dropped frames.
/// Averages use a bounded window; session peaks and counts survive that window.
/// Other main-thread tasks and frames never reported by Flutter need a browser
/// trace. Even [FrameTiming.totalSpan] is not a complete interaction measurement.
class FrameStats {
  FrameStats({this.capacity = 240}) : assert(capacity > 0);

  final int capacity;

  /// A reference 60Hz budget, not a measurement of the device's refresh rate.
  static const double frameBudgetMs = 1000 / 60;

  final List<_FrameSample> _samples = <_FrameSample>[];
  int _totalFrames = 0;
  int _overBudgetFrames = 0;
  int _slowFrames = 0;
  int _over200ms = 0;
  double _sessionWorstBuildMs = 0;
  double _sessionWorstRasterMs = 0;
  double _sessionWorstFrameMs = 0;

  /// Adds work durations and, when available, the full reported frame span.
  void add(double buildMs, double rasterMs, {double? totalMs}) {
    final sample = _FrameSample(
      buildMs,
      rasterMs,
      totalMs ?? buildMs + rasterMs,
    );
    _totalFrames++;
    if (sample.totalMs > frameBudgetMs) _overBudgetFrames++;
    if (sample.totalMs > frameBudgetMs * 2) _slowFrames++;
    if (sample.totalMs > 200) _over200ms++;
    if (buildMs > _sessionWorstBuildMs) _sessionWorstBuildMs = buildMs;
    if (rasterMs > _sessionWorstRasterMs) _sessionWorstRasterMs = rasterMs;
    if (sample.totalMs > _sessionWorstFrameMs) {
      _sessionWorstFrameMs = sample.totalMs;
    }
    _samples.add(sample);
    if (_samples.length > capacity) _samples.removeAt(0);
  }

  void addTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      add(
        timing.buildDuration.inMicroseconds / 1000,
        timing.rasterDuration.inMicroseconds / 1000,
        totalMs: timing.totalSpan.inMicroseconds / 1000,
      );
    }
  }

  void reset() {
    _samples.clear();
    _totalFrames = 0;
    _overBudgetFrames = 0;
    _slowFrames = 0;
    _over200ms = 0;
    _sessionWorstBuildMs = 0;
    _sessionWorstRasterMs = 0;
    _sessionWorstFrameMs = 0;
  }

  int get frameCount => _samples.length;

  /// Uncapped since reset: differencing a capped window gives a false zero FPS.
  int get totalFrames => _totalFrames;
  int get sessionOver200ms => _over200ms;
  double get sessionWorstBuildMs => _sessionWorstBuildMs;
  double get sessionWorstRasterMs => _sessionWorstRasterMs;
  double get sessionWorstFrameMs => _sessionWorstFrameMs;
  double get sessionOverBudgetPercent =>
      _percent(_overBudgetFrames, totalFrames);
  double get sessionSlowFramePercent => _percent(_slowFrames, totalFrames);

  double get avgBuildMs => _avg((s) => s.buildMs);
  double get worstBuildMs => _max((s) => s.buildMs);
  double get avgRasterMs => _avg((s) => s.rasterMs);
  double get worstRasterMs => _max((s) => s.rasterMs);
  double get worstTotalMs => _max((s) => s.totalMs);

  /// Diagnostic window share above the reference budget, not observed jank.
  double get jankPercent => _percent(
    _samples.where((s) => s.totalMs > frameBudgetMs).length,
    frameCount,
  );

  /// Timings exceeding two reference budgets, NOT measured presentation skips.
  double get slowFramePercent => _percent(
    _samples.where((s) => s.totalMs > frameBudgetMs * 2).length,
    frameCount,
  );

  static double _percent(int count, int total) =>
      total == 0 ? 0 : count * 100 / total;

  double _avg(double Function(_FrameSample) pick) {
    if (_samples.isEmpty) return 0;
    var sum = 0.0;
    for (final s in _samples) {
      sum += pick(s);
    }
    return sum / _samples.length;
  }

  double _max(double Function(_FrameSample) pick) {
    var worst = 0.0;
    for (final s in _samples) {
      final value = pick(s);
      if (value > worst) worst = value;
    }
    return worst;
  }
}

/// Rate of reported frames, not necessarily presented FPS (especially headless).
double framesPerSecond(int frames, Duration elapsed) {
  final micros = elapsed.inMicroseconds;
  if (micros <= 0 || frames <= 0) return 0;
  return frames * Duration.microsecondsPerSecond / micros;
}

/// The same rounded values feed the HUD and the opt-in browser mirror.
class PerfSnapshot {
  PerfSnapshot.of({
    required double fps,
    required FrameStats stats,
    required double devicePixelRatio,
    required int sampleSequence,
  }) : _values = <String, double>{
         'fps': fps,
         'buildAvgMs': stats.avgBuildMs,
         'buildWorstMs': stats.worstBuildMs,
         'rasterAvgMs': stats.avgRasterMs,
         'rasterWorstMs': stats.worstRasterMs,
         'worstFrameMs': stats.worstTotalMs,
         'jankPercent': stats.jankPercent,
         'slowFramePercent': stats.slowFramePercent,
         'frames': stats.frameCount.toDouble(),
         'devicePixelRatio': devicePixelRatio,
         'sampleSequence': sampleSequence.toDouble(),
         'sessionFrames': stats.totalFrames.toDouble(),
         'sessionWorstBuildMs': stats.sessionWorstBuildMs,
         'sessionWorstRasterMs': stats.sessionWorstRasterMs,
         'sessionWorstFrameMs': stats.sessionWorstFrameMs,
         'sessionOver200ms': stats.sessionOver200ms.toDouble(),
         'sessionOverBudgetPercent': stats.sessionOverBudgetPercent,
         'sessionSlowFramePercent': stats.sessionSlowFramePercent,
       };

  final Map<String, double> _values;

  Map<String, double> toMap() => _values.map(
    (key, value) => MapEntry(key, (value * 100).roundToDouble() / 100),
  );
}

class _FrameSample {
  const _FrameSample(this.buildMs, this.rasterMs, this.totalMs);

  final double buildMs;
  final double rasterMs;
  final double totalMs;
}
