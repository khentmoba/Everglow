import 'dart:ui' show Picture, PictureRecorder, PointMode;
import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../domain/models/doodle_stroke.dart';

class CanvasPainter extends CustomPainter {
  final List<DoodleStroke> strokes;
  final DoodleStroke? activeStroke;

  CanvasPainter({required this.strokes, this.activeStroke});

  // ── Grid cache ──────────────────────────────────────────────────
  Picture? _gridPicture;
  Size? _lastGridSize;

  // ── Completed strokes cache ─────────────────────────────────────
  // Pre-renders all completed (non-active) strokes into a Picture.
  // Only rebuilds when the strokes list changes, not on every frame.
  Picture? _strokesPicture;
  int _lastStrokesHash = 0;
  Size? _lastStrokesSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Phase 1: Subtle canvas tint
    final bgPaint = Paint()..color = AppTheme.velvet.withValues(alpha: 0.25);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Phase 2: Draw blueprint dot-grid background from cached Picture
    if (_gridPicture == null || _lastGridSize != size) {
      _gridPicture?.dispose();
      _gridPicture = _createGridPicture(size);
      _lastGridSize = size;
    }
    canvas.drawPicture(_gridPicture!);

    // Phase 3: Draw completed strokes from cache
    final strokesHash = _hashStrokes(strokes);
    if (_strokesPicture == null ||
        _lastStrokesHash != strokesHash ||
        _lastStrokesSize != size) {
      _strokesPicture?.dispose();
      _strokesPicture = _createStrokesPicture(size, strokes);
      _lastStrokesHash = strokesHash;
      _lastStrokesSize = size;
    }
    canvas.drawPicture(_strokesPicture!);

    // Phase 4: Draw the active stroke (changes every frame during drawing)
    if (activeStroke != null) {
      _drawStroke(canvas, size, activeStroke!);
    }
  }

  /// Hash of strokes list for cache invalidation.
  int _hashStrokes(List<DoodleStroke> strokes) {
    int hash = strokes.length;
    for (final s in strokes) {
      hash =
          hash * 31 +
          s.points.length +
          (s.color.hashCode ^ s.strokeWidth.round());
    }
    return hash;
  }

  /// Pre-renders all completed strokes into a Picture for efficient replay.
  Picture _createStrokesPicture(Size size, List<DoodleStroke> strokes) {
    final recorder = PictureRecorder();
    final strokesCanvas = Canvas(recorder);
    for (var stroke in strokes) {
      _drawStroke(strokesCanvas, size, stroke);
    }
    return recorder.endRecording();
  }

  /// Pre-renders the dot grid into a [Picture] so every frame just
  /// replays it instead of building offset lists from scratch.
  Picture _createGridPicture(Size size) {
    final recorder = PictureRecorder();
    final gridCanvas = Canvas(recorder);
    const double spacing = 28.0;

    final points = <Offset>[];
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        points.add(Offset(x, y));
      }
    }

    if (points.isNotEmpty) {
      final gridPaint = Paint()
        ..color = AppTheme.roseQuartz.withValues(alpha: 0.10)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      gridCanvas.drawPoints(PointMode.points, points, gridPaint);
    }

    return recorder.endRecording();
  }

  void _drawStroke(Canvas canvas, Size size, DoodleStroke stroke) {
    // Handle text annotations
    if (stroke.isTextAnnotation) {
      _drawTextAnnotation(canvas, size, stroke);
      return;
    }

    if (stroke.points.length < 2) return;

    final color = _parseColor(stroke.color);
    final List<Offset> offsets = stroke.points.map((p) {
      return Offset(p['x']! * size.width, p['y']! * size.height);
    }).toList();

    // 1. Draw glowing background shadow
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = stroke.strokeWidth * 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawPoints(PointMode.polygon, offsets, shadowPaint);

    // 2. Draw sharp foreground stroke
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPoints(PointMode.polygon, offsets, paint);
  }

  void _drawTextAnnotation(Canvas canvas, Size size, DoodleStroke stroke) {
    if (stroke.points.isEmpty) return;
    final pos = Offset(
      stroke.points.first['x']! * size.width,
      stroke.points.first['y']! * size.height,
    );
    final color = _parseColor(stroke.color);
    final fontSize = stroke.strokeWidth * 5.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: stroke.text,
        style: TextStyle(
          color: color,
          fontSize: fontSize.clamp(12.0, 48.0),
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, pos);
  }

  Color _parseColor(String hex) {
    try {
      final colorStr = hex.replaceFirst('#', '');
      if (colorStr.length == 6) {
        return Color(int.parse('FF$colorStr', radix: 16));
      }
      return Color(int.parse(colorStr, radix: 16));
    } catch (e) {
      return AppTheme
          .roseQuartz; // Fallback to roseQuartz instead of basic pink
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke;
  }
}
