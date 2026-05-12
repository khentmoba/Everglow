import 'dart:ui';
import 'package:flutter/material.dart';
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
    // Phase 1: Draw completed strokes from Firestore
    for (var stroke in strokes) {
      _drawStroke(canvas, size, stroke);
    }

    // Phase 2: Draw the active stroke currently being drawn by the user
    if (activeStroke != null) {
      _drawStroke(canvas, size, activeStroke!);
    }
  }

  void _drawStroke(Canvas canvas, Size size, DoodleStroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = _parseColor(stroke.color)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final List<Offset> offsets = stroke.points.map((p) {
      return Offset(
        p['x']! * size.width,
        p['y']! * size.height,
      );
    }).toList();

    // Use drawPoints for better performance
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
      return Colors.pink; // Fallback to default pink
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.activeStroke != activeStroke;
  }
}
