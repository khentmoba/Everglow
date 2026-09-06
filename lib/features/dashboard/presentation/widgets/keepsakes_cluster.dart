import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../bucket_list/presentation/widgets/bucket_list_preview.dart';
import 'journal_preview.dart';

/// Atelier — dreams + journal, always visible, no collapse.
class KeepsakesCluster extends StatelessWidget {
  const KeepsakesCluster({super.key});

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
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 18, 0, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _ClusterHeader(),
                    ),
                    SizedBox(height: 16),
                    Column(
                      children: [
                        BucketListPreview(),
                        JournalPreview(),
                      ],
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
          'Dreams & letters, just for us',
          style: AppTypography.outfitWhite.copyWith(fontSize: 12, height: 1.4, color: AppColors.petalWhite.withValues(alpha: 0.48)),
        ),
      ],
    );
  }
}
