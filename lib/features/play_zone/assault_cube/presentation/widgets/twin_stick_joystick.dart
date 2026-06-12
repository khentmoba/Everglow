import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';

class JoystickAxis {
  double x = 0.0;
  double y = 0.0;

  bool get isActive => x.abs() > 0.05 || y.abs() > 0.05;
  double get magnitude => math.sqrt(x * x + y * y);

  void reset() {
    x = 0.0;
    y = 0.0;
  }
}

class TwinStickJoystick extends StatefulWidget {
  final ValueChanged<JoystickAxis> onMove;
  final double size;
  final Color color;
  final IconData icon;

  const TwinStickJoystick({
    super.key,
    required this.onMove,
    this.size = 140,
    this.color = AppTheme.roseQuartz,
    this.icon = Icons.radio_button_unchecked,
  });

  @override
  State<TwinStickJoystick> createState() => _TwinStickJoystickState();
}

class _TwinStickJoystickState extends State<TwinStickJoystick> {
  Offset? _touchOffset;
  final JoystickAxis _axis = JoystickAxis();
  int? _activePointer;

  void _updateAxis(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = local - center;
    final maxR = widget.size / 2;
    final distance = delta.distance.clamp(0.0, maxR);
    final angle = delta.direction == 0 ? 0.0 : delta.direction;

    _axis.x = (math.cos(angle) * distance) / maxR;
    _axis.y = (math.sin(angle) * distance) / maxR;
    widget.onMove(_axis);
  }

  void _reset() {
    _axis.reset();
    _touchOffset = null;
    _activePointer = null;
    widget.onMove(_axis);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_activePointer != null) return;
          _activePointer = event.pointer;
          _touchOffset = event.localPosition;
          _updateAxis(event.localPosition);
        },
        onPointerMove: (event) {
          if (event.pointer != _activePointer) return;
          _touchOffset = event.localPosition;
          _updateAxis(event.localPosition);
        },
        onPointerUp: (event) {
          if (event.pointer != _activePointer) return;
          _reset();
        },
        onPointerCancel: (event) {
          if (event.pointer != _activePointer) return;
          _reset();
        },
        child: CustomPaint(
          painter: _JoystickPainter(
            axis: _axis,
            color: widget.color,
            size: widget.size,
            icon: widget.icon,
            touchOffset: _touchOffset,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final JoystickAxis axis;
  final Color color;
  final double size;
  final IconData icon;
  final Offset? touchOffset;

  _JoystickPainter({
    required this.axis,
    required this.color,
    required this.size,
    required this.icon,
    required this.touchOffset,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(size / 2, size / 2);
    final maxR = size / 2;

    final baseFill = Paint()
      ..color = AppTheme.moonlight.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final baseStroke = Paint()
      ..color = AppTheme.moonlight.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, maxR, baseFill);
    canvas.drawCircle(center, maxR, baseStroke);

    final crossPaint = Paint()
      ..color = AppTheme.moonlight.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - maxR * 0.6, center.dy),
      Offset(center.dx + maxR * 0.6, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxR * 0.6),
      Offset(center.dx, center.dy + maxR * 0.6),
      crossPaint,
    );

    final knobCenter = touchOffset == null
        ? center
        : Offset(
            (center.dx + axis.x * maxR).clamp(center.dx - maxR, center.dx + maxR),
            (center.dy + axis.y * maxR).clamp(center.dy - maxR, center.dy + maxR),
          );

    final knobGlow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(knobCenter, size * 0.18, knobGlow);

    final knobFill = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCenter, size * 0.15, knobFill);

    final knobStroke = Paint()
      ..color = AppTheme.petalWhite.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(knobCenter, size * 0.15, knobStroke);

    final iconColor = AppTheme.twilight;
    final iconSize = size * 0.10;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: iconColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      knobCenter - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) =>
      old.axis.x != axis.x ||
      old.axis.y != axis.y ||
      old.touchOffset != touchOffset;
}
