import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'roaming_cat_3d_engine.dart';
import 'roaming_guardian_cat.dart';

/// Default visual for the roaming Guardian on web: the real 3D model rendered
/// offscreen by three.js and composited into the Flutter canvas.
///
/// Because it is painted as canvas content (not a DOM platform view), the same
/// 3D model can sit both in front of and behind dashboard widgets.
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
      Positioned.fill(child: RoamingCat3DView(frame: frame)),
    ],
  );
}

/// Displays the latest 3D frame from the shared offscreen renderer.
class RoamingCat3DView extends StatefulWidget {
  const RoamingCat3DView({super.key, required this.frame});

  final RoamingCatFrame frame;

  @override
  State<RoamingCat3DView> createState() => _RoamingCat3DViewState();
}

class _RoamingCat3DViewState extends State<RoamingCat3DView> {
  @override
  void initState() {
    super.initState();
    final engine = RoamingCat3DEngine.instance;
    engine.ensureRunning();
    engine.setParams(widget.frame);
    engine.addListener(_onFrame);
  }

  @override
  void didUpdateWidget(covariant RoamingCat3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    RoamingCat3DEngine.instance.setParams(widget.frame);
  }

  @override
  void dispose() {
    RoamingCat3DEngine.instance.removeListener(_onFrame);
    super.dispose();
  }

  void _onFrame() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final image = RoamingCat3DEngine.instance.image;
    if (image == null) {
      // Soft placeholder while the GLB is loading.
      return Center(
        child: Container(
          width: widget.frame.catSize * 0.5,
          height: widget.frame.catSize * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.deepRose.withValues(alpha: 0.18),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
        ),
      );
    }
    return RawImage(
      image: image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
