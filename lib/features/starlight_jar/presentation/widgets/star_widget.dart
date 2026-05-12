import 'dart:math';
import 'package:flutter/material.dart';

class StarWidget extends StatelessWidget {
  final Color color;
  final double size;
  final double rotation;
  final Animation<double>? animation;
  final Offset position;

  const StarWidget({
    super.key,
    required this.color,
    this.size = 24,
    this.rotation = 0,
    this.animation,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Transform.rotate(
        angle: rotation,
        child: Icon(
          Icons.star_rounded,
          color: color,
          size: size,
          shadows: [
            Shadow(
              color: color.withOpacity(0.8),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
