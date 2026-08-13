import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_theme.dart';

class PulsingHeartLoader extends StatelessWidget {
  const PulsingHeartLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Pulse(
          infinite: true,
          duration: const Duration(milliseconds: 1500),
          child: const Icon(
            Icons.favorite_rounded,
            color: AppTheme.deepRose,
            size: 60,
          ),
        ),
        const SizedBox(height: 16),
        FadeIn(
          delay: const Duration(milliseconds: 500),
          child: Text(
            'Opening our sanctuary...',
            style: AppTypography.outfitWhite.copyWith(
              color: AppTheme.roseQuartz,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
