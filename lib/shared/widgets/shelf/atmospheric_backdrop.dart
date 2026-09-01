import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';


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
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: baseColor,
            backgroundBlendMode: BlendMode.srcOver,
          ),
          child: Stack(
            children: [
              for (final g in glows)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: g.alignment,
                        radius: g.size,
                        colors: [
                          g.color.withValues(alpha: g.opacity),
                          g.color.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RadialGlow {
  final Color color;
  final Alignment alignment;
  final double size;
  final double opacity;

  const RadialGlow({
    required this.color,
    required this.alignment,
    this.size = 0.8,
    this.opacity = 0.15,
  });
}