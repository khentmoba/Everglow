import 'dart:ui' show Picture, PictureRecorder, PointMode;
import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../domain/models/doodle_stroke.dart';

class CanvasPainter extends CustomPainter {
  final List<DoodleStroke> strokes;
  final DoodleStroke? activeStroke;

  CanvasPainter({
    required this.strokes,
    this.activeStroke,
  });

  // ── Grid cache ──────────────────────────────────────────────────
  // The dot-grid is pre-rendered into a Picture and reused across
  // repaints. It only rebuilds on canvas resize, not on every stroke
  // change. This eliminates the O(n²) point-allocation loop from the
  // hot path (drawing strokes).

  Picture? _gridPicture;
  Size? _lastGridSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Phase 1: Subtle canvas tint so the drawing area is distinguishable
    final bgPaint = Paint()..color = AppTheme.velvet.withOpacity(0.25);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Phase 2: Draw blueprint dot-grid background from cached Picture
    if (_gridPicture == null || _lastGridSize != size) {
      _gridPicture?.dispose();
      _gridPicture = _createGridPicture(size);
      _lastGridSize = size;
    }
    canvas.drawPicture(_gridPicture!);

    // Phase 3: Draw completed strokes from Firestore
    for (var stroke in strokes) {
      _drawStroke(canvas, size, stroke);
    }

    // Phase 4: Draw the active stroke currently being drawn by the user
    if (activeStroke != null) {
      _drawStroke(canvas, size, activeStroke!);
    }
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
        ..color = AppTheme.roseQuartz.withOpacity(0.10)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      gridCanvas.drawPoints(PointMode.points, points, gridPaint);
    }

    return recorder.endRecording();
  }

  void _drawStroke(Canvas canvas, Size size, DoodleStroke stroke) {
    if (stroke.points.length < 2) return;

    final color = _parseColor(stroke.color);
    final List<Offset> offsets = stroke.points.map((p) {
      return Offset(
        p['x']! * size.width,
        p['y']! * size.height,
      );
    }).toList();

    // 1. Draw glowing background shadow
    final shadowPaint = Paint()
      ..color = color.withOpacity(0.3)
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

  Color _parseColor(String hex) {
    try {
      final colorStr = hex.replaceFirst('#', '');
      if (colorStr.length == 6) {
        return Color(int.parse('FF$colorStr', radix: 16));
      }
      return Color(int.parse(colorStr, radix: 16));
    } catch (e) {
      return AppTheme.roseQuartz; // Fallback to roseQuartz instead of basic pink
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.activeStroke != activeStroke;
  }
}
