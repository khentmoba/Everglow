import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';

import '../system/app_update_browser.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'frame_stats.dart';
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
            // PerfHud is a direct child on purpose: it returns a `Positioned`
            // once dragged, and a Positioned only works directly under a Stack.
            children: [child, const PerfHud()],
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
/// Interactions, kept on the card so the tool never needs another screen:
/// * drag it anywhere (it starts bottom-left, where no app control lives —
///   it used to sit at top-left over Khent's Creator Studio button),
/// * double-tap resets the window: reset, scroll the screen you care about,
///   then read the numbers,
/// * tap the `dpr` line to cycle the render scale (device → 2.0x → 1.5x →
///   device); it reloads so the change applies immediately.
///
/// Cost control: it reads frame timings (free) and only repaints itself ~2.5
/// times a second, so the meter can stay on while profiling.
class PerfHud extends StatefulWidget {
  const PerfHud({super.key});

  @override
  State<PerfHud> createState() => _PerfHudState();
}

class _PerfHudState extends State<PerfHud> {
  static const Duration _refresh = Duration(milliseconds: 400);

  final FrameStats _stats = FrameStats();
  final Stopwatch _since = Stopwatch()..start();

  /// Lets the drag read where the card actually is.
  final GlobalKey _cardKey = GlobalKey();

  /// Set once the card has been dragged; null means "default corner".
  Offset? _position;
  Offset? _dragFrom;
  Offset _dragDelta = Offset.zero;
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

  /// Next render scale in the cycle: device → 2.0x → 1.5x → device.
  ///
  /// Reloads straight away because the engine only reads the scale when the
  /// view is created, so a tap here is "change and apply" in one gesture.
  void _cycleRenderScale() {
    PerfSettings.setRenderScale(
      PerfSettings.nextRenderScale(PerfSettings.renderScale.value),
    );
    AppUpdateBrowser.instance.reload();
  }

  /// Current top-left of the card, for the drag origin.
  Offset? _cardTopLeft() {
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero);
  }

  Size get _cardSize {
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Size.zero;
    return box.size;
  }

  /// Keeps a dragged meter fully on screen — losing it off an edge would mean
  /// losing the only way to read (or turn off) the numbers.
  Offset _clampToScreen(Offset position, Size cardSize) {
    final screen = MediaQuery.sizeOf(context);
    return Offset(
      position.dx.clamp(0.0, math.max(0.0, screen.width - cardSize.width)),
      position.dy.clamp(0.0, math.max(0.0, screen.height - cardSize.height)),
    );
  }

  void _onPanStart(DragStartDetails details) {
    _dragFrom = _cardTopLeft();
    _dragDelta = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final from = _dragFrom;
    if (from == null) return;
    _dragDelta += details.delta;
    setState(() {
      _position = _clampToScreen(from + _dragDelta, _cardSize);
    });
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

    final card = ExcludeSemantics(
      child: GestureDetector(
        onDoubleTap: _reset,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        child: Container(
          key: _cardKey,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'worst ${_stats.worstTotalMs.toStringAsFixed(1)} ms · '
                      '${_stats.frameCount}f',
                      style: _line(AppColors.textMuted),
                    ),
                    const SizedBox(width: 8),
                    // The render-scale switch lives here too, so testing it never
                    // depends on reaching another screen (it used to).
                    if (AppUpdateBrowser.instance.supported)
                      GestureDetector(
                        onTap: _cycleRenderScale,
                        child: Text(
                          'dpr ${dpr.toStringAsFixed(2)}›',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 11,
                            color: AppColors.blushGold,
                          ),
                        ),
                      )
                    else
                      Text(
                        'dpr ${dpr.toStringAsFixed(2)}',
                        style: _line(AppColors.textMuted),
                      ),
                  ],
                ),
                Text(
                  'drag · dbl-tap reset',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 9.5,
                    height: 1.3,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final positioned = _position;
    // Bottom-left by default: every corner of the app has real controls
    // (creator button top-left, partner status top-right, Motchi bottom-right),
    // and the dashboard has nothing anchored bottom-left.
    if (positioned == null) {
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(padding: const EdgeInsets.all(8), child: card),
        ),
      );
    }
    return Positioned(left: positioned.dx, top: positioned.dy, child: card);
  }

  TextStyle _line(Color color) => AppTypography.outfitWhite.copyWith(
    fontSize: 11,
    height: 1.35,
    color: color,
  );
}
