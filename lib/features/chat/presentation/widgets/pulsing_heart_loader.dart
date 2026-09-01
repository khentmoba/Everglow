import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

class PulsingHeartLoader extends StatelessWidget {
  const PulsingHeartLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppMotion.reduced
            ? const Icon(
                Icons.favorite_rounded,
                color: AppColors.deepRose,
                size: 60,
              )
            : Pulse(
                infinite: true,
                duration: const Duration(milliseconds: 1500),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.deepRose,
                  size: 60,
                ),
              ),
        const SizedBox(height: 16),
        AppMotion.reduced
            ? Text(
                'Opening our sanctuary...',
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.roseQuartz,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              )
            : FadeIn(
                delay: const Duration(milliseconds: 500),
                child: Text(
                  'Opening our sanctuary...',
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.roseQuartz,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
      ],
    );
  }
}