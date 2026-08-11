import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_typography.dart';

class ScoreTracker extends StatelessWidget {
  final int khentScore;
  final int clairScore;
  final int questionIndex;

  const ScoreTracker({
    super.key,
    required this.khentScore,
    required this.clairScore,
    required this.questionIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.85),
            AppColors.inkDeep.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: AppRadius.radiusX2,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkDeep.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPlayerScore('Khent', khentScore, AppColors.softLavender),
          Column(
            children: [
              Text(
                'VS',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.auroraRose,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 5,
                width: 64,
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (questionIndex / 10).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.roseGoldGradient,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.auroraGold.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildPlayerScore('Clair', clairScore, AppColors.auroraRose),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(String name, int score, Color color) {
    return Column(
      children: [
        Text(
          name,
          style: AppTypography.outfitBold.copyWith(
            fontSize: 15,
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        Text(
          score.toString(),
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.5), blurRadius: 12),
            ],
          ),
        ),
      ],
    );
  }
}
