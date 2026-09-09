import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../bucket_list/data/models/bucket_item.dart';
import '../../../bucket_list/presentation/widgets/bucket_list_preview.dart';
import '../../../journal/data/models/journal_entry.dart';
import 'journal_preview.dart';

/// Atelier — dreams + journal cluster with atmospheric depth and responsive layout.
class KeepsakesCluster extends StatelessWidget {
  final Stream<List<BucketItem>>? bucketStream;
  final Stream<List<JournalEntry>>? journalStream;

  const KeepsakesCluster({
    super.key,
    this.bucketStream,
    this.journalStream,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.velvet.withValues(alpha: 0.32),
          borderRadius: AppRadius.radiusX3,
          border: Border.all(
            color: AppColors.petalWhite.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkDeep.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppColors.blushGold.withValues(alpha: 0.04),
              blurRadius: 32,
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.radiusX3,
          child: Stack(
            children: [
              // Top-right starlight atmospheric glow
              Positioned(
                top: -80,
                right: -50,
                child: Container(
                  width: 260,
                  height: 260,
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
              // Bottom-left twilight violet atmospheric glow
              Positioned(
                bottom: -80,
                left: -50,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.auroraLilac.withValues(alpha: 0.07),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Top glowing hairline
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.blushGold.withValues(alpha: 0.40),
                        AppColors.auroraLilac.withValues(alpha: 0.30),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ClusterHeader(),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 680;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: BucketListPreview(itemsStream: bucketStream),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: JournalPreview(entriesStream: journalStream),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            BucketListPreview(itemsStream: bucketStream),
                            const SizedBox(height: 14),
                            JournalPreview(entriesStream: journalStream),
                          ],
                        );
                      },
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: AppColors.blushGold.withValues(alpha: 0.08),
                borderRadius: AppRadius.radiusFull,
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 11,
                    color: AppColors.blushGold,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'ATELIER  •  KEEPSAKES',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 9.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
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
                      AppColors.blushGold.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Little worlds, just for us',
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 24,
                    height: 1.1,
                    color: AppColors.petalWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dreams to chase together & quiet words kept close.',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.petalWhite.withValues(alpha: 0.52),
                  ),
                ),
              ],
            );

            if (!isWide) return titleBlock;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: titleBlock),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.petalWhite.withValues(alpha: 0.04),
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(
                      color: AppColors.petalWhite.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.blushGold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Dreams',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.blushGold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.petalWhite.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.softLavender,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Letters',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.softLavender,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
