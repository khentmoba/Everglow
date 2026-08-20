import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/wellness/data/services/wellness_service.dart';
import 'feature_section.dart';

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
        final avg = data['avgStreak'] ?? 0;
        final pct = total == 0 ? 0.0 : done / total;

        final subtitle = total == 0
            ? 'No habits yet — start a streak together'
            : '$done/$total done today • avg ${avg}d streak';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FeatureSection(
            icon: Icons.favorite_rounded,
            hue: AppColors.auroraRose,
            title: 'Wellness',
            subtitle: subtitle,
            trailing: const SectionChevron(hue: AppColors.auroraRose),
            onTap: () => context.push('/wellness'),
            child: total == 0
                ? _EmptyWellness(hue: AppColors.auroraRose)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.auroraRose),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ...List.generate(7, (i) {
                            final filled = i < done;
                            return Container(
                              margin: EdgeInsets.only(right: i == 6 ? 0 : 6),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? AppColors.auroraRose.withValues(alpha: 0.92)
                                    : Colors.white.withValues(alpha: 0.07),
                                border: Border.all(
                                  color: filled
                                      ? AppColors.auroraRose
                                      : Colors.white.withValues(alpha: 0.10),
                                ),
                                boxShadow: filled
                                    ? [
                                        BoxShadow(
                                          color: AppColors.auroraRose
                                              .withValues(alpha: 0.35),
                                          blurRadius: 8,
                                        )
                                      ]
                                    : null,
                              ),
                              child: filled
                                  ? const Icon(Icons.check_rounded,
                                      size: 12, color: Colors.white)
                                  : null,
                            );
                          }),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.auroraRose.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color:
                                      AppColors.auroraRose.withValues(alpha: 0.22)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department_rounded,
                                    size: 12, color: AppColors.auroraRose),
                                const SizedBox(width: 4),
                                Text('${avg}d',
                                    style: AppTypography.outfitBold.copyWith(
                                      fontSize: 11,
                                      color: AppColors.auroraRose,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _EmptyWellness extends StatelessWidget {
  final Color hue;
  const _EmptyWellness({required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.07),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Row(
            children: List.generate(
                3,
                (i) => Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Icon(
                        [Icons.self_improvement_rounded, Icons.water_drop_rounded, Icons.bedtime_rounded][i],
                        size: 13,
                        color: hue.withValues(alpha: 0.85),
                      ),
                    )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Build habits together — small wins, every day.',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppColors.petalWhite.withValues(alpha: 0.60),
                )),
          ),
        ],
      ),
    );
  }
}
