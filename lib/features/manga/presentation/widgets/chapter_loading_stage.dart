import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

/// The waiting screen both manga readers show while a chapter is
/// still being fetched.
///
/// Why this exists: resolving a chapter can take 10-20 seconds (we
/// race every source with a 15s timeout), and a bare
/// `CircularProgressIndicator` made that wait feel like the app had
/// frozen. This paints the wait instead — a stack of manga pages
/// where panels ink themselves in one by one, a shine sweeping across
/// the top page, and a warm line of copy that changes as the wait
/// goes on.
///
/// Everything runs on one [AnimationController] and one
/// [CustomPainter], so it costs nothing while it spins. With
/// `disableAnimations` set (reduced motion) it paints a single static
/// frame instead of animating.
class ChapterLoadingStage extends StatefulWidget {
  /// Chapter title shown above the animation, e.g. "Chapter 12".
  final String? title;

  /// Sub-heading under the title, usually the manga name.
  final String? subtitle;

  final Color accentColor;
  final Color surfaceColor;
  final Color pageColor;
  final Color mutedColor;

  const ChapterLoadingStage({
    super.key,
    this.title,
    this.subtitle,
    required this.accentColor,
    required this.surfaceColor,
    required this.pageColor,
    required this.mutedColor,
  });

  /// One line of copy per slice of the loop, in order.
  static const List<String> hints = <String>[
    'Opening the chapter…',
    'Finding the fastest server…',
    'Inking the panels…',
    'Almost there, one moment…',
  ];

  @override
  State<ChapterLoadingStage> createState() => _ChapterLoadingStageState();
}

class _ChapterLoadingStageState extends State<ChapterLoadingStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool get _animationsOff =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Reduced motion is a MediaQuery value, so the controller starts
  /// and stops here rather than in initState.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationsOff) {
      _controller.stop();
      _controller.value = 0.62;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The whole stage rebuilds from the controller, not just the
    // painter: otherwise the waiting copy freezes on the first line
    // while the pages keep animating.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _buildStage(
        // A stopped controller would leave the copy on the first line
        // forever, so reduced motion lands mid-loop instead.
        t: _animationsOff ? 0.62 : _controller.value,
      ),
    );
  }

  Widget _buildStage({required double t}) {
    final hint =
        ChapterLoadingStage.hints[(t * ChapterLoadingStage.hints.length)
                .floor() %
            ChapterLoadingStage.hints.length];

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = math.min(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 420.0,
        );
        final stage = shortest.clamp(150.0, 260.0);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.subtitle != null) ...[
                  Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      color: widget.mutedColor,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (widget.title != null) ...[
                  Text(
                    widget.title!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                SizedBox(
                  width: stage,
                  height: stage * 1.16,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _PageInkPainter(
                        t: t,
                        accent: widget.accentColor,
                        surface: widget.surfaceColor,
                        page: widget.pageColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: Text(
                    hint,
                    key: ValueKey(hint),
                    textAlign: TextAlign.center,
                    style: AppTypography.outfitWhite.copyWith(
                      color: widget.mutedColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A fanned stack of pages; the top one inks its panels in sequence
/// while a shine sweeps across it.
class _PageInkPainter extends CustomPainter {
  final double t;
  final Color accent;
  final Color surface;
  final Color page;

  _PageInkPainter({
    required this.t,
    required this.accent,
    required this.surface,
    required this.page,
  });

  /// Rising ease for the panel fills so they "print" instead of fade.
  double _ramp(double start, double end, double v) {
    final x = ((v - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(x);
  }

  /// Triangle wave in [0,1) — a cheap ping-pong for back-and-forth
  /// motion (page float, stack sway).
  double _pingPong(double v) {
    final x = v % 1.0;
    return x < 0.5 ? x * 2 : 2 - x * 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pageW = size.width * 0.62;
    final pageH = size.height * 0.86;
    final left = (size.width - pageW) / 2;
    final top = (size.height - pageH) / 2;
    final float = Curves.easeInOut.transform(_pingPong(t));

    // Pages are lifted towards white so a sheet reads as paper against
    // the dark reader, and each step of the stack gets lighter.
    Color paper(double amount) => Color.lerp(page, Colors.white, amount)!;

    // Two pages peeking from behind, fanned up and to the right.
    for (final back in <double>[0.16, 0.32]) {
      final offset = Offset(pageW * 0.16 * back, -pageH * 0.10 * back);
      _drawPageFrame(
        canvas,
        Rect.fromLTWH(left + offset.dx, top + offset.dy, pageW, pageH),
        rotate: 0.05 * back + math.sin((t + back) * math.pi * 2) * 0.012,
        fill: paper(0.04 + 0.06 * back),
        border: accent.withValues(alpha: 0.12 + 0.14 * back),
      );
    }

    // Top page: lifts and sways gently, like it is being held.
    final rect = Rect.fromLTWH(
      left + math.sin(t * math.pi * 2) * size.width * 0.014,
      top - float * size.height * 0.02,
      pageW,
      pageH,
    );

    canvas.save();
    final pivot = rect.center;
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(math.sin(t * math.pi * 2) * 0.014);
    canvas.translate(-pivot.dx, -pivot.dy);
    _drawPageFrame(
      canvas,
      rect,
      rotate: 0,
      fill: paper(0.14),
      border: accent.withValues(alpha: 0.55),
    );
    _drawPanels(canvas, rect);
    _drawShine(canvas, rect);
    canvas.restore();
  }

  void _drawPageFrame(
    Canvas canvas,
    Rect rect, {
    required double rotate,
    required Color fill,
    required Color border,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.save();
    if (rotate != 0) {
      final pivot = rect.center;
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(rotate);
      canvas.translate(-pivot.dx, -pivot.dy);
    }
    canvas.drawRRect(
      rrect.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = border,
    );
    canvas.restore();
  }

  /// Panel rectangle measured from the page's own top-left corner.
  static Rect _slot(Rect page, double x, double y, double w, double h) =>
      Rect.fromLTWH(page.left + x, page.top + y, w, h);

  /// Three panels that ink in sequence over the first 75% of the loop,
  /// each with a little overshoot so it feels drawn, not faded.
  void _drawPanels(Canvas canvas, Rect rect) {
    const gap = 7.0;
    final pad = rect.width * 0.09;
    final innerW = rect.width - pad * 2;
    final topH = rect.height * 0.3;
    final bottomH = rect.height - topH - gap - pad * 2;
    final leftW = innerW * 0.56;

    final slots = <Rect>[
      _slot(rect, pad, pad, innerW, topH),
      _slot(rect, pad, pad + topH + gap, leftW, bottomH),
      _slot(
        rect,
        pad + leftW + gap,
        pad + topH + gap,
        innerW - leftW - gap,
        bottomH,
      ),
    ];

    for (var i = 0; i < slots.length; i++) {
      final start = 0.06 + i * 0.17;
      final fill = _ramp(start, start + 0.16, t);
      // Once printed, a panel holds its ink and just breathes.
      final breathe = 1.0 + math.sin((t - start) * math.pi * 2) * 0.02;
      final rrect = RRect.fromRectAndRadius(slots[i], const Radius.circular(5));
      // Ink pools from the centre outward as a deep rose wash, so a
      // fresh panel grows rather than fades in, and an unprinted one
      // still reads as an empty slot on the paper.
      final core = Color.lerp(surface, accent, 0.10 + 0.30 * fill)!;
      final edge = Color.lerp(surface, accent, 0.03 + 0.12 * fill)!;
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.radial(rrect.center, rrect.longestSide / 2, [
            core,
            edge,
          ]),
      );
      if (fill <= 0.01) continue;

      // The panel outline snaps in with the ink.
      final inset = (1 - fill) * slots[i].width * 0.5 * breathe;
      final grown = slots[i].deflate(inset);
      if (grown.width <= 0 || grown.height <= 0) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(grown, const Radius.circular(5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 + 0.6 * fill
          ..color = accent.withValues(alpha: 0.35 + 0.45 * fill),
      );

      // A stroke of "speed lines" sweeping across the fresh panel.
      final sweep = _ramp(start, start + 0.16, t);
      final lineY = grown.top + grown.height * (0.25 + 0.5 * sweep);
      final lineW = grown.width * 0.55 * fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(grown.left + 5, lineY, lineW, 2.4),
          const Radius.circular(2),
        ),
        Paint()..color = accent.withValues(alpha: 0.45 * fill),
      );
    }
  }

  /// Diagonal shine band travelling down the top page.
  void _drawShine(Canvas canvas, Rect rect) {
    final travel = Curves.easeInOut.transform(_pingPong(t * 1.0));
    final bandCenter = rect.left - rect.width * 0.3 + rect.width * 1.6 * travel;
    final band = Rect.fromCenter(
      center: rect.center.translate(bandCenter - rect.center.dx, 0),
      width: rect.width * 0.34,
      height: rect.height,
    );
    final shader = LinearGradient(
      colors: [
        accent.withValues(alpha: 0),
        accent.withValues(alpha: 0.18),
        accent.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(band);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)));
    canvas.drawRect(band, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PageInkPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.accent != accent ||
      oldDelegate.surface != surface ||
      oldDelegate.page != page;
}
