import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../../../core/theme/app_colors.dart';
import 'roaming_guardian_cat.dart';

/// Default visual for the roaming Guardian on native platforms: the same
/// bundled GLB cat used by the web three.js renderer.
Widget buildRoamingCatVisual(BuildContext context, RoamingCatFrame frame) {
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
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
      Positioned.fill(child: RoamingCat3DView(frame: frame)),
    ],
  );
}

/// 3D roaming cat view backed by `model_viewer_plus`.
class RoamingCat3DView extends StatelessWidget {
  const RoamingCat3DView({super.key, required this.frame});

  final RoamingCatFrame frame;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: frame.scale * (0.92 + frame.breath * 0.06),
      child: IgnorePointer(
        child: ClipOval(
          child: ModelViewer(
            src: 'assets/models/chibi_cat.glb',
            alt: 'Everglow Roaming Cat',
            backgroundColor: Colors.transparent,
            autoRotate: true,
            autoRotateDelay: 2000,
            rotationPerSecond: '18deg',
            cameraControls: false,
            disablePan: true,
            disableTap: true,
            disableZoom: true,
            autoPlay: true,
            shadowIntensity: 0.8,
            shadowSoftness: 1.0,
            interactionPrompt: InteractionPrompt.none,
            loading: Loading.eager,
            reveal: Reveal.auto,
          ),
        ),
      ),
    );
  }
}
