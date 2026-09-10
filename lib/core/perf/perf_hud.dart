import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'frame_stats.dart';
import 'perf_probe.dart';
import 'perf_settings.dart';

/// Mounts [PerfHud] over the whole app, but only while the meter switch is on,
/// so it costs nothing for Clair.
class PerfMeterOverlay extends StatelessWidget {
  const PerfMeterOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PerfSettings.frameMeter,
      builder: (context, enabled, _) {
        if (!enabled) return child;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [child, const ExcludeSemantics(child: PerfHud())],
          ),
        );
      },
    );
  }
}

/// Small on-device frame meter: FPS, jank share, and build/raster cost.
///
/// Why it exists: Flutter Web has no retained layers, so build and raster share
/// one thread and one 16.7ms budget. "It feels heavy" is therefore always
/// either *build* (widgets re-running every frame) or *raster* (too many pixels,
/// blurs and shadows). This panel tells those apart on the actual phone, which
/// is the only place the answer matters.
///
/// Cost control: it reads frame timings (free) and only repaints itself ~2.5
/// times a second, so the meter can stay on while profiling.
///
/// Tap to reset the window — reset, scroll the screen you care about, then read
/// (or screenshot) the numbers.
class PerfHud extends StatefulWidget {
  const PerfHud({super.key});

  @override
  State<PerfHud> createState() => _PerfHudState();
}

class _PerfHudState extends State<PerfHud> {
  static const Duration _refresh = Duration(milliseconds: 400);

  final FrameStats _stats = FrameStats();
  final Stopwatch _since = Stopwatch()..start();
  Timer? _timer;
  int _lastFrameCount = 0;
  double _fps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
    _timer = Timer.periodic(_refresh, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) => _stats.addTimings(timings);

  void _tick() {
    if (!mounted) return;
    final frames = _stats.frameCount - _lastFrameCount;
    _lastFrameCount = _stats.frameCount;
    _fps = framesPerSecond(frames, _since.elapsed);
    _since
      ..reset()
      ..start();
    publishPerfSnapshot(
      PerfSnapshot.of(
        fps: _fps,
        stats: _stats,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ).toMap(),
    );
    setState(() {});
  }

  void _reset() {
    _stats.reset();
    _lastFrameCount = 0;
    _since
      ..reset()
      ..start();
    setState(() {});
  }

  /// Green when the frame fits the 60fps budget, amber when it is close, red
  /// when it is not — so a screenshot reads without doing arithmetic.
  Color _tone(double value, double good, double ok) {
    if (value <= good) return AppColors.success;
    if (value <= ok) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final fpsTone = _fps >= 55
        ? AppColors.success
        : (_fps >= 40 ? AppColors.warning : AppColors.error);
    final rasterTone = _tone(_stats.avgRasterMs, 8, 14);
    final buildTone = _tone(_stats.avgBuildMs, 6, 12);

    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: _reset,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.inkDeep.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.35),
              ),
            ),
            child: DefaultTextStyle(
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 11,
                height: 1.35,
                color: AppColors.petalWhite,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_fps.toStringAsFixed(0)} fps · jank '
                    '${_stats.jankPercent.toStringAsFixed(0)}% · drop '
                    '${_stats.droppedPercent.toStringAsFixed(0)}%',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 12,
                      color: fpsTone,
                    ),
                  ),
                  Text(
                    'build  ${_stats.avgBuildMs.toStringAsFixed(1)} / '
                    '${_stats.worstBuildMs.toStringAsFixed(1)} ms',
                    style: _line(buildTone),
                  ),
                  Text(
                    'raster ${_stats.avgRasterMs.toStringAsFixed(1)} / '
                    '${_stats.worstRasterMs.toStringAsFixed(1)} ms',
                    style: _line(rasterTone),
                  ),
                  Text(
                    'worst ${_stats.worstTotalMs.toStringAsFixed(1)} ms · '
                    'dpr ${dpr.toStringAsFixed(2)} · ${_stats.frameCount}f',
                    style: _line(AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _line(Color color) => AppTypography.outfitWhite.copyWith(
    fontSize: 11,
    height: 1.35,
    color: color,
  );
}
