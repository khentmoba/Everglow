import 'dart:ui';
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

  @override
  void paint(Canvas canvas, Size size) {
    // Phase 1: Subtle canvas tint so the drawing area is distinguishable
    final bgPaint = Paint()..color = AppTheme.velvet.withOpacity(0.25);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Phase 2: Draw blueprint dot-grid background
    final List<Offset> gridPoints = [];
    const double spacing = 28.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        gridPoints.add(Offset(x, y));
      }
    }
    if (gridPoints.isNotEmpty) {
      final gridPaint = Paint()
        ..color = AppTheme.roseQuartz.withOpacity(0.10)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPoints(PointMode.points, gridPoints, gridPaint);
    }

    // Phase 2: Draw completed strokes from Firestore
    for (var stroke in strokes) {
      _drawStroke(canvas, size, stroke);
    }

    // Phase 3: Draw the active stroke currently being drawn by the user
    if (activeStroke != null) {
      _drawStroke(canvas, size, activeStroke!);
    }
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
