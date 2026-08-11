import 'package:flutter/material.dart';import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// Dashboard preview widget showing bucket list progress + recent wishes.
class BucketListPreview extends StatelessWidget {
  const BucketListPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = BucketListService();

    return StreamBuilder<List<BucketItem>>(
      stream: service.watchAll(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        if (all.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () => context.push('/bucket-list'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.blushGold.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🌟', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your bucket list is empty — add your first dream!',
                        style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppTheme.petalWhite.withValues(alpha: 0.6)),
                      ),
                    ),
                    Icon(
                      Icons.add_circle_outline,
                      color: AppTheme.blushGold.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final completed = all.where((i) => i.status == BucketStatus.completed).length;
        final total = all.length;
        final progress = total > 0 ? completed / total : 0.0;
        final recentWishes = all
            .where((i) => i.status == BucketStatus.wish)
            .take(3)
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            onTap: () => context.push('/bucket-list'),
            child: Semantics(
              label: 'Bucket List: $completed of $total dreams fulfilled. Tap to open.',
              button: true,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.blushGold.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Progress ring
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                backgroundColor: AppTheme.petalWhite.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(AppTheme.blushGold),
                              ),
                              Text(
                                '🌟',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Our Bucket List',
                                style: AppTypography.cormorantBold.copyWith(fontSize: 18),
                              ),
                              Text(
                                '$completed of $total dreams fulfilled',
                                style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.blushGold.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                    if (recentWishes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...recentWishes.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(item.category.emoji, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppTheme.petalWhite.withValues(alpha: 0.7)),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
