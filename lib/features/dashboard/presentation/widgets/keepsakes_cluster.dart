import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../bucket_list/presentation/widgets/bucket_list_preview.dart';
import 'journal_preview.dart';
import 'cookbook_preview.dart';
import 'wellness_preview.dart';
import 'vault_preview.dart';
import 'travel_preview.dart';
import 'wiki_preview.dart';
import 'budget_preview.dart';
import 'rag_preview.dart';

/// Atelier — distilled: 4 featured keepsakes visible, 5 more behind
/// a soft expand. Previously 9 cards always visible + 1800px stack
/// with no hierarchy. Now the dashboard breathes.
class KeepsakesCluster extends StatefulWidget {
  const KeepsakesCluster({super.key});

  @override
  State<KeepsakesCluster> createState() => _KeepsakesClusterState();
}

class _KeepsakesClusterState extends State<KeepsakesCluster> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.velvet.withValues(alpha: 0.28),
          borderRadius: AppRadius.radiusX2,
          border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkDeep.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.radiusX2,
          child: Stack(
            children: [
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
                        AppColors.blushGold.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.blushGold.withValues(alpha: 0.24),
                        AppColors.auroraLilac.withValues(alpha: 0.16),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 720;
                        return Column(
                          children: [
                            // Always visible: 4 editorial picks
                            if (isWide) ...[
                              const BucketListPreview(),
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: JournalPreview()),
                                  Expanded(child: CookbookPreview()),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(child: TravelPreview()),
                                  Expanded(
                                    child: _expanded
                                        ? VaultPreview()
                                        : _MoreCard(onTap: _toggle),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const BucketListPreview(),
                              const JournalPreview(),
                              const CookbookPreview(),
                              const TravelPreview(),
                              _expanded
                                  ? const Column(
                                      children: [
                                        VaultPreview(),
                                        WellnessPreview(),
                                        WikiPreview(),
                                        BudgetPreview(),
                                        RagPreview(),
                                      ],
                                    )
                                  : _MoreCard(onTap: _toggle),
                            ],
                            // Expanded extras
                            if (_expanded && isWide) ...[
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: WellnessPreview()),
                                  Expanded(child: WikiPreview()),
                                ],
                              ),
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: BudgetPreview()),
                                  Expanded(child: RagPreview()),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Expand affordance
                    Center(
                      child: _ExpandPill(expanded: _expanded, onTap: _toggle),
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

  void _toggle() => setState(() => _expanded = !_expanded);
}

class _MoreCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MoreCard({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.moonlight.withValues(alpha: 0.06),
            borderRadius: AppRadius.radiusX2,
            border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.blushGold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '5 more worlds',
                      style: AppTypography.cormorantBold.copyWith(fontSize: 16, color: AppColors.petalWhite),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Wellness, Vault, Universe & more — tap to reveal',
                      style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.52)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: AppColors.blushGold, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandPill extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _ExpandPill({required this.expanded, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.orZero(const Duration(milliseconds: 200)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: expanded ? AppColors.deepRose.withValues(alpha: 0.14) : AppColors.petalWhite.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: expanded ? AppColors.deepRose.withValues(alpha: 0.30) : AppColors.petalWhite.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 16,
              color: expanded ? AppColors.roseQuartz : AppColors.blushGold.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 6),
            Text(
              expanded ? 'Show less' : 'Show all keepsakes',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 11,
                letterSpacing: 0.3,
                color: expanded ? AppColors.roseQuartz : AppColors.petalWhite.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterHeader extends StatelessWidget {
  const _ClusterHeader();

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
                    AppColors.blushGold.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.blushGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_mosaic_rounded, size: 11, color: AppColors.blushGold),
                  const SizedBox(width: 6),
                  Text(
                    'ATELIER  •  KEEPSAKES',
                    style: AppTypography.outfitHeading.copyWith(fontSize: 10, letterSpacing: 1.1, color: AppColors.blushGold),
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
                      AppColors.blushGold.withValues(alpha: 0.14),
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
          style: AppTypography.cormorantBold.copyWith(fontSize: 24, height: 1.0, color: AppColors.petalWhite),
        ),
        const SizedBox(height: 6),
        Text(
          'Dreams, recipes, maps — 4 favorites now, 5 more when you linger.',
          style: AppTypography.outfitWhite.copyWith(fontSize: 12, height: 1.4, color: AppColors.petalWhite.withValues(alpha: 0.48)),
        ),
      ],
    );
  }
}
