import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';

/// Dashboard-only ambient motion — "dusk bloom."
///
/// A painter-driven full-screen layer that renders slow aurora ribbons,
/// rising petal embers with motion-blur ghost trails, twinkling sparkles,
/// and an occasional bloom pulse. All of it is drawn by one [CustomPainter]
/// that repaints off a single [AnimationController], so no widget rebuilds
/// or layout passes happen per frame.
///
/// Honors `AppMotion.reduced` by rendering nothing.
class DashboardAmbience extends StatefulWidget {
  const DashboardAmbience({super.key});

  @override
  State<DashboardAmbience> createState() => _DashboardAmbienceState();
}

class _DashboardAmbienceState extends State<DashboardAmbience>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  _AmbiencePainter? _painter;

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 24),
      )..repeat();
      _painter = _AmbiencePainter(_controller!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = _painter;
    if (painter == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(child: CustomPaint(painter: painter)),
      ),
    );
  }
}

/// A soft ember trail that follows the mouse across the dashboard.
///
/// A short light streak plus a fading glow dot paints directly on a
/// [CustomPainter]; hover updates only a [ValueNotifier], so the frame cost
/// stays near zero. Honored only for pointer devices and when
/// `AppMotion.reduced` is off.
class DashboardCursorGlow extends StatefulWidget {
  const DashboardCursorGlow({super.key});

  @override
  State<DashboardCursorGlow> createState() => _DashboardCursorGlowState();
}

class _DashboardCursorGlowState extends State<DashboardCursorGlow>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  final ValueNotifier<_CursorSample?> _sample = ValueNotifier(null);
  _CursorGlowPainter? _painter;
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 24),
      )..repeat();
      _painter = _CursorGlowPainter(_controller!, _sample);
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _controller?.dispose();
    _sample.dispose();
    super.dispose();
  }

  void _handleHover(PointerHoverEvent event) {
    _sample.value = _CursorSample(
      event.localPosition,
      DateTime.now(),
      _sample.value?.position,
    );
    final controller = _controller;
    if (controller != null && !controller.isAnimating) {
      controller.repeat();
    }
  }

  void _handleExit(PointerExitEvent event) {
    // Keep the last sample so the ember fades out, then stop repainting.
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _controller?.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final painter = _painter;
    if (painter == null) return const SizedBox.shrink();
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      onHover: _handleHover,
      onExit: _handleExit,
      child: IgnorePointer(
        child: RepaintBoundary(child: CustomPaint(painter: painter)),
      ),
    );
  }
}

const List<Color> _petalPalette = [
  AppColors.roseQuartz,
  AppColors.auroraRose,
  AppColors.blushGold,
  AppColors.softLavender,
  AppColors.moonlight,
];

const List<Color> _sparklePalette = [
  AppColors.auroraGold,
  AppColors.blushGold,
  AppColors.moonlight,
  AppColors.auroraRose,
  AppColors.softLavender,
];

/// Breathing emblem ring: a slowly rotating gold-rose halo around the logo,
/// a gentle scale breath, and a soft radial bloom behind it.
class BreathingEmblem extends StatefulWidget {
  const BreathingEmblem({super.key, required this.child});

  final Widget child;

  @override
  State<BreathingEmblem> createState() => _BreathingEmblemState();
}

class _BreathingEmblemState extends State<BreathingEmblem>
    with TickerProviderStateMixin {
  AnimationController? _breath;
  AnimationController? _halo;
  _HaloPainter? _haloPainter;

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced) {
      _breath = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3400),
      )..repeat(reverse: true);
      _halo = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 14),
      )..repeat();
      _haloPainter = _HaloPainter(_halo!);
    }
  }

  @override
  void dispose() {
    _breath?.dispose();
    _halo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breath = _breath;
    final haloPainter = _haloPainter;
    if (breath == null || haloPainter == null) return widget.child;
    return AnimatedBuilder(
      animation: breath,
      builder: (context, _) {
        final scale = 1 + 0.032 * (breath.value * 2 - 1);
        return SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: CustomPaint(painter: haloPainter)),
              Transform.scale(scale: scale, child: widget.child),
            ],
          ),
        );
      },
    );
  }
}

/// A slow gold shimmer sweep across the dashboard title.
class ShimmerTitle extends StatefulWidget {
  const ShimmerTitle({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerTitle> createState() => _ShimmerTitleState();
}

class _ShimmerTitleState extends State<ShimmerTitle>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4200),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offset = controller.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              AppColors.petalWhite,
              AppColors.blushGold,
              AppColors.petalWhite,
            ],
            stops: const [0.0, 0.5, 1.0],
            transform: _SlideGradientTransform(bounds.width * 1.6 * offset),
          ).createShader(bounds),
          child: widget.child,
        );
      },
    );
  }
}

/// A soft heartbeat pulse for the divider heart.
class PulseHeart extends StatefulWidget {
  const PulseHeart({super.key, required this.child});

  final Widget child;

  @override
  State<PulseHeart> createState() => _PulseHeartState();
}

class _PulseHeartState extends State<PulseHeart>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final p = controller.value;
        final beat = p < 0.45 ? Curves.easeOutBack.transform(p / 0.45) : 1.0;
        final glow = p < 0.45 ? (1 - p / 0.45) * 0.45 : 0.0;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.auroraRose.withValues(alpha: glow),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Transform.scale(scale: 1 + 0.22 * beat, child: widget.child),
          ],
        );
      },
    );
  }
}

class _CursorSample {
  const _CursorSample(this.position, this.time, this.previous);

  final Offset position;
  final DateTime time;
  final Offset? previous;
}

class _AmbiencePainter extends CustomPainter {
  _AmbiencePainter(this._controller) : super(repaint: _controller) {
    _initParticles();
  }

  final AnimationController _controller;

  static const int _auroraSegments = 28;

  final List<_AuroraBand> _bands = [];
  final List<_Petal> _petals = [];
  final List<_Sparkle> _sparkles = [];

  // Unit petal pointing up, tip at (0, -1), base at (0, 0.6).
  final Path _unitPetal = Path()
    ..moveTo(0, -1)
    ..cubicTo(0.42, -0.52, 0.36, 0.02, 0, 0.6)
    ..cubicTo(-0.36, 0.02, -0.42, -0.52, 0, -1)
    ..close();

  void _initParticles() {
    _bands
      ..add(
        const _AuroraBand(
          baseY: 0.24,
          amp: 0.10,
          wave: 0.55,
          speed: 0.16,
          drift: 0.05,
          width: 0.16,
          alpha: 0.05,
          color: AppColors.auroraRose,
        ),
      )
      ..add(
        const _AuroraBand(
          baseY: 0.52,
          amp: 0.11,
          wave: 0.35,
          speed: 0.10,
          drift: 0.03,
          width: 0.20,
          alpha: 0.045,
          color: AppColors.softLavender,
        ),
      )
      ..add(
        const _AuroraBand(
          baseY: 0.80,
          amp: 0.08,
          wave: 0.70,
          speed: 0.20,
          drift: 0.04,
          width: 0.13,
          alpha: 0.05,
          color: AppColors.auroraGold,
        ),
      );

    for (var i = 0; i < 14; i++) {
      _petals.add(_Petal.fromSeed(i));
    }
    for (var i = 0; i < 8; i++) {
      _sparkles.add(_Sparkle.fromSeed(i));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final t = _controller.value;
    _paintAuroras(canvas, size, t);
    _paintBloomPulse(canvas, size, t);
    _paintSparkles(canvas, size, t);
    _paintPetals(canvas, size, t);
  }

  void _paintAuroras(Canvas canvas, Size size, double t) {
    for (final band in _bands) {
      final path = Path();
      final step = size.width / _auroraSegments;
      final driftX = t * size.width * band.drift;
      for (var i = 0; i <= _auroraSegments; i++) {
        final x = i * step + driftX;
        final nx = x / size.width;
        final y =
            band.baseY * size.height +
            math.sin(
                  nx * math.pi * 2 * band.wave + t * math.pi * 2 * band.speed,
                ) *
                band.amp *
                size.height +
            math.sin(
                  nx * math.pi * 4 * band.wave +
                      t * math.pi * 2 * band.speed * 1.7,
                ) *
                band.amp *
                size.height *
                0.45;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final strokeWidth = band.width * size.height;
      final bandRect = Rect.fromLTWH(
        0,
        band.baseY * size.height - strokeWidth,
        size.width,
        strokeWidth * 2,
      );
      final outer = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            band.color.withValues(alpha: 0),
            band.color.withValues(alpha: band.alpha),
            band.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bandRect);
      canvas.drawPath(path, outer);

      final inner = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.30
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            band.color.withValues(alpha: 0),
            band.color.withValues(alpha: band.alpha * 1.8),
            band.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bandRect);
      canvas.drawPath(path, inner);
    }
  }

  void _paintBloomPulse(Canvas canvas, Size size, double t) {
    const cycleFraction = 0.375;
    final q = _frac(t / cycleFraction);
    if (q >= 0.55) return;
    final eased = Curves.easeOutCubic.transform(q / 0.55);
    final short = math.min(size.width, size.height);
    final center = Offset(size.width * 0.5, size.height * 0.17);
    final radius = short * (0.06 + (0.34 - 0.06) * eased);
    final alpha = (1 - eased) * 0.14;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.blushGold.withValues(alpha: alpha),
    );
    canvas.drawCircle(
      center,
      radius * 1.05,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = AppColors.deepRose.withValues(alpha: alpha * 0.35),
    );
  }

  void _paintSparkles(Canvas canvas, Size size, double t) {
    final scale = (size.shortestSide / 900).clamp(0.6, 1.6);
    for (final sparkle in _sparkles) {
      final p = _frac(t * sparkle.speed + sparkle.phase);
      final y = size.height * (1 - p) - 40;
      final x =
          sparkle.baseX * size.width +
          math.sin(t * math.pi * 2 * sparkle.swayFreq + sparkle.phase * 7) *
              sparkle.swayAmp *
              size.width;
      final twinkle = 0.72 + 0.28 * math.sin(t * math.pi * 2 * sparkle.twinkle);
      final fade = p < 0.06 ? p / 0.06 : (p > 0.94 ? (1 - p) / 0.06 : 1.0);
      final k = twinkle * fade;
      if (k <= 0.02) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(k, k);
      canvas.drawCircle(Offset.zero, sparkle.radius * scale, sparkle.paint);
      canvas.restore();
    }
  }

  void _paintPetals(Canvas canvas, Size size, double t) {
    for (final petal in _petals) {
      for (var g = 0; g < 3; g++) {
        final dt = g == 0 ? 0.0 : (g == 1 ? 0.006 : 0.013);
        final p = _frac(t * petal.speed + petal.phase - dt);
        final y = size.height * (1 - p) - petal.size;
        final x =
            _wrap(petal.baseX + t * petal.drift) * size.width +
            math.sin(t * math.pi * 2 * petal.swayFreq + petal.swayPhase) *
                petal.swayAmp *
                size.width;
        final angle = petal.tilt + p * petal.rotTurns * math.pi * 2;
        final petalScale = petal.size * (g == 0 ? 1.0 : 1.0 - g * 0.22);
        var alpha = petal.alpha * (g == 0 ? 1.0 : math.pow(0.45, g).toDouble());
        final edgeFade = p < 0.05
            ? p / 0.05
            : (p > 0.95 ? (1 - p) / 0.05 : 1.0);
        alpha *= edgeFade;
        if (alpha <= 0.01) continue;

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        canvas.scale(petalScale, petalScale);
        canvas.drawPath(
          _unitPetal,
          Paint()..color = petal.color.withValues(alpha: alpha),
        );
        if (g == 0) {
          canvas.drawLine(
            const Offset(0, -0.9),
            const Offset(0, 0.3),
            Paint()
              ..strokeWidth = 0.14
              ..strokeCap = StrokeCap.round
              ..color = AppColors.petalWhite.withValues(alpha: alpha * 0.45),
          );
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbiencePainter oldDelegate) => false;
}

class _AuroraBand {
  const _AuroraBand({
    required this.baseY,
    required this.amp,
    required this.wave,
    required this.speed,
    required this.drift,
    required this.width,
    required this.alpha,
    required this.color,
  });

  final double baseY;
  final double amp;
  final double wave;
  final double speed;
  final double drift;
  final double width;
  final double alpha;
  final Color color;
}

class _Petal {
  _Petal.fromSeed(int i) {
    phase = _rand(i + 7);
    speed = 0.50 + _rand(i + 11) * 0.40;
    drift = 0.02 + _rand(i + 13) * 0.05;
    swayFreq = 1.0 + _rand(i + 17) * 2.0;
    swayAmp = 0.02 + _rand(i + 19) * 0.05;
    swayPhase = _rand(i + 23) * math.pi * 2;
    tilt = _rand(i + 29) * math.pi * 2;
    rotTurns = 0.5 + _rand(i + 31) * 1.2;
    size = 9 + _rand(i + 37) * 13;
    alpha = 0.11 + _rand(i + 41) * 0.09;
    baseX = 0.04 + _rand(i + 43) * 0.92;
    color = _petalPalette[i % _petalPalette.length];
  }

  late final double phase;
  late final double speed;
  late final double drift;
  late final double swayFreq;
  late final double swayAmp;
  late final double swayPhase;
  late final double tilt;
  late final double rotTurns;
  late final double size;
  late final double alpha;
  late final double baseX;
  late final Color color;
}

class _Sparkle {
  _Sparkle.fromSeed(int i) {
    phase = _rand(i + 5);
    speed = 0.35 + _rand(i + 9) * 0.30;
    baseX = 0.06 + _rand(i + 15) * 0.88;
    swayFreq = 1.5 + _rand(i + 21) * 2.0;
    swayAmp = 0.01 + _rand(i + 25) * 0.04;
    twinkle = 6 + _rand(i + 31) * 10;
    final radius = 2.5 + _rand(i + 33) * 3.0;
    final peak = 0.10 + _rand(i + 47) * 0.14;
    final color = _sparklePalette[i % _sparklePalette.length];
    paint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withValues(alpha: peak),
              color.withValues(alpha: peak * 0.35),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius * 1.6),
          );
    this.radius = radius;
  }

  late final double phase;
  late final double speed;
  late final double baseX;
  late final double swayFreq;
  late final double swayAmp;
  late final double twinkle;
  late final double radius;
  late final Paint paint;
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this._halo) : super(repaint: _halo);

  final AnimationController _halo;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = AppColors.blushGold.withValues(alpha: 0.22),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_halo.value * math.pi * 2);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [
            Colors.transparent,
            AppColors.auroraRose,
            AppColors.blushGold,
            Colors.transparent,
          ],
          stops: [0.0, 0.18, 0.42, 0.6],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.deepRose.withValues(alpha: 0.07),
            AppColors.deepRose.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter oldDelegate) => false;
}

class _CursorGlowPainter extends CustomPainter {
  _CursorGlowPainter(AnimationController controller, this._sample)
    : super(repaint: Listenable.merge([controller, _sample]));

  final ValueNotifier<_CursorSample?> _sample;

  @override
  void paint(Canvas canvas, Size size) {
    final sample = _sample.value;
    if (sample == null || size.width <= 0 || size.height <= 0) return;
    final now = DateTime.now();
    final ageMs = now.difference(sample.time).inMilliseconds;

    if (ageMs < 650) {
      final k = 1 - ageMs / 650;
      final eased = Curves.easeOutCubic.transform(k);
      final radius = 10 + (1 - eased) * 26;
      canvas.drawCircle(
        sample.position,
        radius,
        Paint()
          ..color = AppColors.auroraRose.withValues(alpha: 0.10 * eased)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(
        sample.position,
        radius * 0.45,
        Paint()
          ..color = AppColors.blushGold.withValues(alpha: 0.14 * eased)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    final previous = sample.previous;
    if (previous != null && ageMs < 140) {
      final distance = (sample.position - previous).distance;
      if (distance > 1 && distance < 420) {
        final k = 1 - ageMs / 140;
        canvas.drawLine(
          previous,
          sample.position,
          Paint()
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..shader = LinearGradient(
              colors: [
                AppColors.auroraRose.withValues(alpha: 0.18 * k),
                AppColors.blushGold.withValues(alpha: 0.05 * k),
              ],
            ).createShader(Rect.fromPoints(previous, sample.position)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CursorGlowPainter oldDelegate) => false;
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.offset);

  final double offset;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(offset, 0, 0);
}

double _frac(double value) => value - value.floorToDouble();

double _wrap(double value) => value - value.floorToDouble();

double _rand(int seed) {
  final x = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
  return _frac(x);
}
