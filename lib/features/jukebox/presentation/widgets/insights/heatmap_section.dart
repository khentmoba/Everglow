import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../providers/music_insights_provider.dart';

class HeatmapSection extends StatelessWidget {
  const HeatmapSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicInsightsProvider>(
      builder: (context, p, _) {
        if (p.isLoading && p.khentHeatmap == null) {
          return Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: AppRadius.radiusX2,
            ),
          );
        }
        final khent = p.khentHeatmap;
        final clair = p.clairHeatmap;
        if (khent == null || clair == null) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(
              colors: [
                AppColors.velvet.withValues(alpha: 0.88),
                AppColors.inkDeep.withValues(alpha: 0.92),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.auroraTeal, AppColors.success],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LISTENING HEATMAP',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.8,
                            color: AppColors.blushGold,
                          ),
                        ),
                        Text(
                          '84 days • like GitHub for your ears',
                          style: AppTypography.outfitMedium.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, c) {
                  final isNarrow = c.maxWidth < 620;
                  if (isNarrow) {
                    return Column(
                      children: [
                        _HeatmapBlock(
                          name: 'Khent',
                          data: khent,
                          color: AppColors.auroraTeal,
                        ),
                        const SizedBox(height: 16),
                        _HeatmapBlock(
                          name: 'Clair',
                          data: clair,
                          color: AppColors.cinemaPink,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _HeatmapBlock(
                          name: 'Khent',
                          data: khent,
                          color: AppColors.auroraTeal,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _HeatmapBlock(
                          name: 'Clair',
                          data: clair,
                          color: AppColors.cinemaPink,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Less',
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  for (var i = 0; i < 5; i++)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _levelColor(i, AppColors.auroraTeal),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: AppColors.petalWhite.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    'More',
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 12,
                    color: AppColors.warmAmber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Streaks keep your garden blooming',
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Color _levelColor(int level, Color base) {
  switch (level) {
    case 0:
      return AppColors.petalWhite.withValues(alpha: 0.06);
    case 1:
      return base.withValues(alpha: 0.22);
    case 2:
      return base.withValues(alpha: 0.40);
    case 3:
      return base.withValues(alpha: 0.65);
    case 4:
      return base;
    default:
      return base;
  }
}

class _HeatmapBlock extends StatelessWidget {
  final String name;
  final HeatmapData data;
  final Color color;
  const _HeatmapBlock({
    required this.name,
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // build 12 weeks x 7 days grid
    final days = <DateTime>[];
    for (var i = 83; i >= 0; i--) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      days.add(d);
    }
    // organize by week
    final weeks = <List<DateTime>>[];
    for (var i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.petalWhite.withValues(alpha: 0.03),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(color: color.withValues(alpha: 0.32)),
                ),
                child: Icon(Icons.person_rounded, size: 12, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: AppColors.petalWhite,
                ),
              ),
              const Spacer(),
              _StreakBadge(
                icon: Icons.bolt_rounded,
                label: '${data.currentStreak}d streak',
                color: AppColors.warmAmber,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SmallStat(label: 'total', value: '${data.totalPlays}'),
              const SizedBox(width: 10),
              _SmallStat(label: 'best day', value: '${data.maxDaily}'),
              const SizedBox(width: 10),
              _SmallStat(label: 'longest', value: '${data.longestStreak}d'),
            ],
          ),
          const SizedBox(height: 10),
          // grid
          AspectRatio(
            aspectRatio: 7.2,
            child: Row(
              children: [
                for (final week in weeks)
                  Expanded(
                    child: Column(
                      children: [
                        for (final d in week)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(1.5),
                              child: Tooltip(
                                message:
                                    '${d.month}/${d.day} • ${data.counts[d] ?? 0} plays',
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _colorForCount(
                                      data.counts[d] ?? 0,
                                      data.maxDaily,
                                      color,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: AppColors.petalWhite.withValues(
                                        alpha: 0.04,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${weeks.first.first.month}/${weeks.first.first.day}',
                style: AppTypography.outfitMedium.copyWith(
                  fontSize: 9,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                'Today',
                style: AppTypography.outfitMedium.copyWith(
                  fontSize: 9,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorForCount(int count, int max, Color base) {
    if (count == 0) return AppColors.petalWhite.withValues(alpha: 0.06);
    if (max == 0) return base.withValues(alpha: 0.25);
    final ratio = count / max;
    if (ratio < 0.25) return base.withValues(alpha: 0.25);
    if (ratio < 0.5) return base.withValues(alpha: 0.45);
    if (ratio < 0.75) return base.withValues(alpha: 0.70);
    return base;
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const _SmallStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.petalWhite.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.outfitBold.copyWith(
            fontSize: 10,
            color: AppColors.petalWhite,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.outfitMedium.copyWith(
            fontSize: 9,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

class _StreakBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StreakBadge({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTypography.outfitBold.copyWith(fontSize: 9, color: color),
        ),
      ],
    ),
  );
}
