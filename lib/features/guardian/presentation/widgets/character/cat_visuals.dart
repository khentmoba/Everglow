import 'package:flutter/material.dart';

class CatVisuals extends StatelessWidget {
  final double size;
  final Color primaryColor;

  const CatVisuals({
    super.key,
    this.size = 80,
    this.primaryColor = const Color(0xFFFFD1DC), // Soft Pink
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Body
          Positioned(
            bottom: size * 0.1,
            child: Container(
              width: size * 0.7,
              height: size * 0.6,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(size * 0.3),
              ),
            ),
          ),
          // Head
          Positioned(
            top: size * 0.15,
            child: Container(
              width: size * 0.65,
              height: size * 0.55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.25),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          // Left Ear
          Positioned(
            top: size * 0.05,
            left: size * 0.18,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: size * 0.2,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(size * 0.1),
                    topRight: Radius.circular(size * 0.1),
                  ),
                ),
              ),
            ),
          ),
          // Right Ear
          Positioned(
            top: size * 0.05,
            right: size * 0.18,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: size * 0.2,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(size * 0.1),
                    topRight: Radius.circular(size * 0.1),
                  ),
                ),
              ),
            ),
          ),
          // Eyes
          Positioned(
            top: size * 0.35,
            left: size * 0.32,
            child: _buildEye(size),
          ),
          Positioned(
            top: size * 0.35,
            right: size * 0.32,
            child: _buildEye(size),
          ),
          // Nose
          Positioned(
            top: size * 0.45,
            child: Container(
              width: size * 0.08,
              height: size * 0.06,
              decoration: BoxDecoration(
                color: Colors.pink[200],
                borderRadius: BorderRadius.circular(size * 0.03),
              ),
            ),
          ),
          // Whiskers
          Positioned(
            top: size * 0.48,
            left: size * 0.2,
            child: _buildWhisker(size, -0.1),
          ),
          Positioned(
            top: size * 0.52,
            left: size * 0.2,
            child: _buildWhisker(size, 0.1),
          ),
          Positioned(
            top: size * 0.48,
            right: size * 0.2,
            child: _buildWhisker(size, 0.1),
          ),
          Positioned(
            top: size * 0.52,
            right: size * 0.2,
            child: _buildWhisker(size, -0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildEye(double size) {
    return Container(
      width: size * 0.06,
      height: size * 0.06,
      decoration: const BoxDecoration(
        color: Color(0xFF4A4A4A),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildWhisker(double size, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size * 0.15,
        height: 1.5,
        color: Colors.pink[100]!.withValues(alpha: 0.5),
      ),
    );
  }
}
