import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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
    return Semantics(
      label: 'Glass jar containing gratitude notes',
      image: true,
      child: AnimatedBuilder(
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
            // No BackdropFilter here: on Flutter Web the blur renders as an
            // opaque gray/white rectangle instead of a frosted panel.
            ClipPath(
              clipper: JarClipper(),
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.petalWhite.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.22),
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

            // Glossy Highlight
            Positioned(
              left: 40,
              top: 60,
              child: Container(
                width: 20,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.petalWhite.withValues(alpha: 0.2),
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
                  color: AppColors.roseQuartz.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, size.width, size.height),
        bottomLeft: const Radius.circular(80),
        bottomRight: const Radius.circular(80),
        topLeft: const Radius.circular(40),
        topRight: const Radius.circular(40),
      ),
    );
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class JarClipperAtOffset extends CustomClipper<Path> {
  final Offset offset;
  final Size size;
  final double topRadius;
  final double bottomRadius;

  const JarClipperAtOffset({
    required this.offset,
    required this.size,
    this.topRadius = 40,
    this.bottomRadius = 80,
  });

  @override
  Path getClip(Size _) {
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
        topLeft: Radius.circular(topRadius),
        topRight: Radius.circular(topRadius),
        bottomLeft: Radius.circular(bottomRadius),
        bottomRight: Radius.circular(bottomRadius),
      ),
    );
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    if (oldClipper is JarClipperAtOffset) {
      return oldClipper.offset != offset || oldClipper.size != size;
    }
    return true;
  }
}