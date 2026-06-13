import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:everglow/core/theme/app_theme.dart';
import '../../models/piano_note.dart';

/// A single, GPU-friendly [CustomPainter] that draws every visible falling
/// tile across all four lanes in one pass.
///
/// All movement is derived from the [currentBeat] listenable; the painter
/// repaints automatically when the value changes, so the whole widget tree
/// can stay `const` and avoids per-frame rebuilds.
class PianoBoardPainter extends CustomPainter {
  PianoBoardPainter({
    required this.currentBeat,
    required this.notes,
    required this.pixelsPerBeat,
    required this.judgmentY,
    required this.laneCount,
    required this.tapPulses,
    required this.missFlashLane,
  }) : super(repaint: Listenable.merge([currentBeat, tapPulses, missFlashLane]));

  final ValueListenable<double> currentBeat;
  final List<PianoNote> notes;
  final double pixelsPerBeat;
  final double judgmentY;
  final int laneCount;

  /// Brief tap-ripple animations keyed by lane.
  final ValueListenable<List<LanePulse>> tapPulses;

  /// Which lane just produced a miss (for the red glow), or -1.
  final ValueListenable<int> missFlashLane;

  static const double _hPad = 5.0;
  static const double _vGap = 4.0;
  static const double _radius = 16.0;

  // Cached paints — built once per paint() call to avoid allocations in the
  // tight per-tile loop.
  static final Paint _tileShadow = Paint()
    ..color = AppTheme.deepRose.withValues(alpha: 0.32)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

  static final Paint _tileBorder = Paint()
    ..color = AppTheme.blushGold.withValues(alpha: 0.30)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  static final Paint _missBorder = Paint()
    ..color = AppTheme.roseQuartz
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final beat = currentBeat.value;
    final laneWidth = size.width / laneCount;

    _drawJudgmentBar(canvas, size);

    // Tile loop ----------------------------------------------------------
    for (final note in notes) {
      if (note.state == PianoNoteState.tapped) continue;
      if (note.line < 0 || note.line >= laneCount) continue;

      final tileHeight = note.duration * pixelsPerBeat;
      final bottomY = judgmentY - (note.hitBeat - beat) * pixelsPerBeat;
      final topY = bottomY - tileHeight;

      // Viewport cull: outside the visible window? skip entirely.
      if (bottomY < -8 || topY > size.height + 8) continue;

      final laneX = note.line * laneWidth;
      final rect = Rect.fromLTRB(
        laneX + _hPad,
        topY + _vGap / 2,
        laneX + laneWidth - _hPad,
        bottomY - _vGap / 2,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_radius));

      if (note.state == PianoNoteState.missed) {
        _paintMissedTile(canvas, rect, rrect);
      } else {
        _paintReadyTile(canvas, rect, rrect, beat, note);
      }
    }

    _drawTapPulses(canvas, size, laneWidth);
    _drawMissFlash(canvas, size, laneWidth);
  }

  void _paintReadyTile(
    Canvas canvas,
    Rect rect,
    RRect rrect,
    double currentBeatValue,
    PianoNote note,
  ) {
    // Soft drop shadow — moved up 6px.
    canvas.drawRRect(rrect.shift(const Offset(0, 6)), _tileShadow);

    // Body gradient. As the tile approaches the judgment line, brighten
    // its lower edge slightly to "telegraph" the upcoming tap.
    final progressToHit = (1.0 -
            ((note.hitBeat - currentBeatValue) / note.duration).clamp(0.0, 1.0))
        .clamp(0.0, 1.0);

    final bottomTint = Color.lerp(
      const Color(0xFF1E1226),
      AppTheme.deepRose.withValues(alpha: 0.85),
      progressToHit * 0.6,
    )!;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3E1F3D),
          bottomTint,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    canvas.drawRRect(rrect, _tileBorder);

    // Subtle accent bar at the bottom of the tile so the player can see
    // exactly where the tap edge is.
    final accentRect = Rect.fromLTWH(
      rect.left + 14,
      rect.bottom - 8,
      rect.width - 28,
      3,
    );
    final accentPaint = Paint()
      ..color = AppTheme.blushGold.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(accentRect, const Radius.circular(2)),
      accentPaint,
    );
  }

  void _paintMissedTile(Canvas canvas, Rect rect, RRect rrect) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.deepRose.withValues(alpha: 0.95),
          AppTheme.velvet,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    // Stronger shadow on miss.
    final shadow = Paint()
      ..color = AppTheme.deepRose.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawRRect(rrect, shadow);
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, _missBorder);
  }

  void _drawJudgmentBar(Canvas canvas, Size size) {
    // Subtle band at the judgment line so players see exactly where to tap.
    final band = Rect.fromLTWH(0, judgmentY - 28, size.width, 32);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppTheme.blushGold.withValues(alpha: 0.18),
        ],
      ).createShader(band);
    canvas.drawRect(band, paint);

    // Crisp line.
    final linePaint = Paint()
      ..color = AppTheme.blushGold.withValues(alpha: 0.55)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(0, judgmentY),
      Offset(size.width, judgmentY),
      linePaint,
    );
  }

  void _drawTapPulses(Canvas canvas, Size size, double laneWidth) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final pulse in tapPulses.value) {
      final age = now - pulse.startMs;
      if (age < 0 || age > LanePulse.lifetimeMs) continue;
      final t = age / LanePulse.lifetimeMs;
      final laneX = pulse.lane * laneWidth;
      final rect = Rect.fromLTWH(
        laneX + 4,
        judgmentY - 70 - (20 * t),
        laneWidth - 8,
        70 + (20 * t),
      );
      final opacity = (1.0 - t) * 0.55;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppTheme.blushGold.withValues(alpha: opacity),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(_radius)),
        paint,
      );
    }
  }

  void _drawMissFlash(Canvas canvas, Size size, double laneWidth) {
    final lane = missFlashLane.value;
    if (lane < 0 || lane >= laneCount) return;
    final laneX = lane * laneWidth;
    final rect = Rect.fromLTWH(laneX, 0, laneWidth, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.deepRose.withValues(alpha: 0.05),
          AppTheme.deepRose.withValues(alpha: 0.30),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant PianoBoardPainter old) {
    // Most repaints are driven by the `repaint:` listenable. We only need
    // to repaint when the underlying data identity changes (e.g. after a
    // game restart with a fresh notes list).
    return old.notes != notes ||
        old.pixelsPerBeat != pixelsPerBeat ||
        old.judgmentY != judgmentY;
  }
}

/// A short-lived tap ripple displayed at the judgment line.
class LanePulse {
  static const int lifetimeMs = 220;
  final int lane;
  final int startMs;
  const LanePulse(this.lane, this.startMs);
}
