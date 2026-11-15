import 'dart:ui' show Picture, PictureRecorder, PointMode;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/doodle_stroke.dart';
import '../../data/services/canvas_point_utils.dart';

class CanvasPainter extends CustomPainter {
  final List<DoodleStroke> strokes;
  final DoodleStroke? activeStroke;

  CanvasPainter({required this.strokes, this.activeStroke, super.repaint});

  void disposePictures() {
    _gridPicture?.dispose();
    _strokesPicture?.dispose();
  }

  Picture? _gridPicture;
  Size? _lastGridSize;

  Picture? _strokesPicture;
  int _lastStrokesHash = 0;
  Size? _lastStrokesSize;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.velvet.withValues(alpha: 0.25);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (_gridPicture == null || _lastGridSize != size) {
      _gridPicture?.dispose();
      _gridPicture = _createGridPicture(size);
      _lastGridSize = size;
    }
    canvas.drawPicture(_gridPicture!);

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

    if (activeStroke != null) {
      _drawStroke(canvas, size, activeStroke!);
    }
  }

  int _hashStrokes(List<DoodleStroke> strokes) {
    int hash = strokes.length;
    for (final s in strokes) {
      hash =
          hash * 31 +
          s.points.length +
          (s.color.hashCode ^
              s.strokeWidth.round() ^
              s.canvasAspectRatio.hashCode);
    }
    return hash;
  }

  Picture _createStrokesPicture(Size size, List<DoodleStroke> strokes) {
    final recorder = PictureRecorder();
    final strokesCanvas = Canvas(recorder);
    for (var stroke in strokes) {
      _drawStroke(strokesCanvas, size, stroke);
    }
    return recorder.endRecording();
  }

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
        ..color = AppColors.roseQuartz.withValues(alpha: 0.10)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      gridCanvas.drawPoints(PointMode.points, points, gridPaint);
    }

    return recorder.endRecording();
  }

  void _drawStroke(Canvas canvas, Size size, DoodleStroke stroke) {
    if (stroke.isTextAnnotation) {
      _drawTextAnnotation(canvas, size, stroke);
      return;
    }

    if (stroke.points.length < 2) return;

    final color = _parseColor(stroke.color);
    final offsets = stroke.points
        .map(
          (p) => mapCanvasPointToViewport(
            x: p['x']!,
            y: p['y']!,
            viewportSize: size,
            canvasAspectRatio: stroke.canvasAspectRatio,
          ),
        )
        .toList();

    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = stroke.strokeWidth * 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = kIsWeb
          ? null
          : const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawPoints(PointMode.polygon, offsets, shadowPaint);

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
    final pos = mapCanvasPointToViewport(
      x: stroke.points.first['x']!,
      y: stroke.points.first['y']!,
      viewportSize: size,
      canvasAspectRatio: stroke.canvasAspectRatio,
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
          .roseQuartz;
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke;
  }
}

class CanvasSurface extends StatefulWidget {
  const CanvasSurface({
    super.key,
    required this.strokes,
    required this.active,
    this.live = const [],
  });
  final List<DoodleStroke> strokes;
  final List<DoodleStroke> live;
  final ValueListenable<DoodleStroke?> active;

  @override
  State<CanvasSurface> createState() => _CanvasSurfaceState();
}

class _CanvasSurfaceState extends State<CanvasSurface> {
  late CanvasPainter _history = CanvasPainter(strokes: widget.strokes);
  late _ActiveStrokePainter _pen = _ActiveStrokePainter(
    widget.active,
    widget.live,
  );

  @override
  void didUpdateWidget(CanvasSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.strokes, oldWidget.strokes)) {
      _history.disposePictures();
      _history = CanvasPainter(strokes: widget.strokes);
    }
    if (widget.active != oldWidget.active || widget.live != oldWidget.live) {
      _pen = _ActiveStrokePainter(widget.active, widget.live);
    }
  }

  @override
  void dispose() {
    _history.disposePictures();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(child: CustomPaint(painter: _history)),
      CustomPaint(painter: _pen),
    ],
  );
}

class _ActiveStrokePainter extends CanvasPainter {
  _ActiveStrokePainter(this.active, this.live)
    : super(strokes: const [], repaint: active);
  final ValueListenable<DoodleStroke?> active;
  final List<DoodleStroke> live;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in live) {
      _drawStroke(canvas, size, stroke);
    }
    final stroke = active.value;
    if (stroke != null) _drawStroke(canvas, size, stroke);
  }

  @override
  bool shouldRepaint(covariant _ActiveStrokePainter oldDelegate) =>
      active != oldDelegate.active || live != oldDelegate.live;
}
