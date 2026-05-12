import 'dart:ui';
import 'package:flutter/material.dart';

class GlassJar extends StatelessWidget {
  final double width;
  final double height;
  final Animation<double>? shakeAnimation;

  const GlassJar({
    super.key,
    this.width = 280,
    this.height = 350,
    this.shakeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shakeAnimation ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Transform.rotate(
          angle: shakeAnimation?.value ?? 0.0,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Frosty Glass Body
          ClipPath(
            clipper: JarClipper(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
              ),
            ),
          ),
          
          // Glossy Highlight
          Positioned(
            left: 40,
            top: 60,
            child: Container(
              width: 20,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Jar Lid (Frosty Pink)
          Positioned(
            top: 0,
            child: Container(
              width: width * 0.6,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.pink[100]!.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class JarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, size.width, size.height),
        bottomLeft: const Radius.circular(80),
        bottomRight: const Radius.circular(80),
        topLeft: const Radius.circular(40),
        topRight: const Radius.circular(40),
      ));
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
