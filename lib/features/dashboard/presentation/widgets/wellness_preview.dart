import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/wellness/data/services/wellness_service.dart';

class WellnessPreview extends StatelessWidget {
  const WellnessPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = WellnessService();
    return FutureBuilder<Map<String, int>>(
      future: service.getWeeklyStreaks(),
      builder: (context, snap) {
        final data = snap.data ?? {'total': 0, 'completedToday': 0, 'avgStreak': 0};
        final total = data['total'] ?? 0;
        final done = data['completedToday'] ?? 0;
        return GestureDetector(
          onTap: () => context.push('/wellness'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.auroraRose.withValues(alpha: 0.18))),
            child: Row(
              children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.auroraRose.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.favorite_rounded, color: AppColors.auroraRose, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wellness', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppColors.petalWhite)),
                      const SizedBox(height: 4),
                      Text(total == 0 ? 'No habits yet — start a streak together' : '$done/$total done today • avg ${data['avgStreak']}d streak', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.auroraRose, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
