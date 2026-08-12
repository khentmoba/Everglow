import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_colors.dart';
import '../character/cat_visuals.dart';
import 'roaming_guardian_cat.dart';
import 'roaming_guardian_controller.dart';

/// Default 3D visual for the roaming Guardian (a `<model-viewer>` platform
/// view), plus its ground shadow, held glow and directional mirror.
///
/// Lives in a web-only file so the interaction layer in
/// [RoamingGuardianCat] stays testable on the VM.
Widget buildRoamingCatVisual(BuildContext context, RoamingCatFrame frame) {
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      // Ground shadow.
      Positioned(
        bottom: 0,
        child: Container(
          width: frame.catSize * (frame.held ? 0.64 : 0.56),
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: RadialGradient(
              colors: [
                AppColors.inkDeep.withValues(alpha: frame.held ? 0.5 : 0.36),
                AppColors.inkDeep.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
      // Held glow so the user can see the cat is picked up.
      if (frame.held)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.auroraRose.withValues(alpha: 0.22),
                  AppColors.auroraRose.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          frame.scale * (frame.turning ? 1 : frame.facing),
          frame.scale * frame.breath,
          1,
        ),
        child: Transform.translate(
          offset: Offset(0, frame.bob),
          child: CatVisuals(
            size: frame.catSize,
            clip: false,
            autoRotate: frame.activity == RoamingActivity.idle,
            orientation: frame.turning ? '0deg 180deg 0deg' : null,
          ),
        ),
      ),
    ],
  );
}
