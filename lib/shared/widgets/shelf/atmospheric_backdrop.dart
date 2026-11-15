import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../everglow/everglow_background.dart';


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
