import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import 'starlight_jar_widget.dart';

/// Page shell for the standalone Starlight Jar route so it keeps the
/// shared atmospheric background (the widget itself is also embedded
/// directly inside the dashboard).
class StarlightPage extends StatelessWidget {
  const StarlightPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraLilac,
                  alignment: Alignment(-0.6, -0.9),
                  size: 0.9,
                  opacity: 0.14,
                ),
                RadialGlow(
                  color: AppColors.blushGold,
                  alignment: Alignment(0.9, 0.8),
                  size: 0.7,
                  opacity: 0.10,
                ),
              ],
              showPetals: true,
            ),
          ),
          StarlightJarWidget(),
        ],
      ),
    );
  }
}
