import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../bucket_list/presentation/widgets/bucket_list_preview.dart';
import 'journal_preview.dart';
import 'cookbook_preview.dart';
import 'wellness_preview.dart';
import 'vault_preview.dart';
import 'travel_preview.dart';
import 'wiki_preview.dart';
import 'budget_preview.dart';
import 'rag_preview.dart';

/// "Atelier" — clustered presentation for the 9 keepsake previews.
///
/// Replaces 9 monotonous full-width cards with a cohesive ensemble:
/// section header + bento-responsive grid.
class KeepsakesCluster extends StatelessWidget {
  const KeepsakesCluster({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.05),
              AppColors.velvet.withValues(alpha: 0.52),
              AppColors.inkDeep.withValues(alpha: 0.68),
            ],
          ),
          borderRadius: AppRadius.radiusX2,
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.radiusX2,
          child: Stack(
            children: [
              // Soft radial glow behind header
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.blushGold.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -40,
                left: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.auroraLilac.withValues(alpha: 0.09),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Top hairline
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.blushGold.withValues(alpha: 0.32),
                        AppColors.auroraLilac.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 18, 0, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _ClusterHeader(),
                    ),
                    const SizedBox(height: 16),
                    // Bento-responsive grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 720;
                        if (!isWide) {
                          return const Column(
                            children: [
                              const BucketListPreview(),
                              const JournalPreview(),
                              const CookbookPreview(),
                              const WellnessPreview(),
                              const VaultPreview(),
                              const TravelPreview(),
                              const WikiPreview(),
                              const BudgetPreview(),
                              const RagPreview(),
                            ],
                          );
                        }
                        // Wide: 2-col bento, bucket spans full width
                        return Column(
                          children: [
                            const BucketListPreview(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: JournalPreview()),
                                Expanded(child: CookbookPreview()),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: WellnessPreview()),
                                Expanded(child: VaultPreview()),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: TravelPreview()),
                                Expanded(child: WikiPreview()),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: BudgetPreview()),
                                Expanded(child: RagPreview()),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Footer hint
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.07)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 10,
                                color:
                                    AppColors.blushGold.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Text(
                              'Tap any card to open its world',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 10,
                                letterSpacing: 0.4,
                                color:
                                    AppColors.petalWhite.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClusterHeader extends StatelessWidget {
  const _ClusterHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.blushGold.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.blushGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_mosaic_rounded,
                      size: 11, color: AppColors.blushGold),
                  const SizedBox(width: 6),
                  Text(
                    'ATELIER  •  KEEPSAKES',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      color: AppColors.blushGold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.blushGold.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Little worlds, just for us',
          style: AppTypography.cormorantBold.copyWith(
            fontSize: 24,
            height: 1.0,
            color: AppColors.petalWhite,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dreams, recipes, maps & murmurs — the small universes you built together.',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 12,
            height: 1.4,
            color: AppColors.petalWhite.withValues(alpha: 0.50),
          ),
        ),
        const SizedBox(height: 14),
        // Category filter chips — non-interactive legend
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _LegendChip(
                dot: AppColors.blushGold, label: 'Dreams', count: 'Bucket'),
            _LegendChip(
                dot: AppColors.softLavender, label: 'Stories', count: 'Journal'),
            _LegendChip(dot: AppColors.warmAmber, label: 'Tastes', count: 'Cookbook'),
            _LegendChip(
                dot: AppColors.auroraRose, label: 'Rituals', count: 'Wellness'),
            _LegendChip(dot: AppColors.auroraTeal, label: 'Archive', count: 'Vault'),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color dot;
  final String label;
  final String count;
  const _LegendChip({required this.dot, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 10,
                letterSpacing: 0.5,
                color: AppColors.petalWhite.withValues(alpha: 0.68),
              )),
          const SizedBox(width: 4),
          Text('·  $count',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 10,
                color: AppColors.petalWhite.withValues(alpha: 0.32),
              )),
        ],
      ),
    );
  }
}
