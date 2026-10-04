import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../everglow/everglow_background.dart';


/// Atmospheric background used by the four inside screens — drops
/// two soft, slowly-shifting radial gradients over the dark base so
/// the page never feels like a flat void. Honors the
/// "atmospheric, never flat" rule from the aesthetic-web guide.
class ShelfAtmosphericBackdrop extends StatelessWidget {
  final Color baseColor;
  final List<RadialGlow> glows;

  const ShelfAtmosphericBackdrop({
    super.key,
    this.baseColor = AppColors.twilight,
    this.glows = const [
      RadialGlow(
        color: AppColors.deepRose,
        alignment: Alignment(-0.7, -0.85),
        size: 0.85,
        opacity: 0.16,
      ),
      RadialGlow(
        color: AppColors.softLavender,
        alignment: Alignment(0.85, 0.95),
        size: 0.75,
        opacity: 0.10,
      ),
    ],
  });

  @override
  Widget build(BuildContext context) {
    // Each glow paints inside its own circle's bounding box instead of the
    // whole screen (same as EverglowBackground.glowRect): on Flutter Web
    // every frame replays the full canvas, so two full-screen radial
    // gradients are paid again on every scroll tick. Bounding keeps the
    // exact same centre/radius while filling far fewer pixels.
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: baseColor,
              backgroundBlendMode: BlendMode.srcOver,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return Stack(
                  children: [
                    for (final g in glows)
                      Positioned.fromRect(
                        rect: EverglowBackground.glowRect(g, size),
                        child: DecoratedBox(
                          decoration: EverglowBackground.glowDecoration(g),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// RadialGlow lives in everglow_background.dart (single definition); this
// file imports it for the default glow pairs below.