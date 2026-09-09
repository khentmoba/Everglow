import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/bucket_item.dart';
import '../widgets/bucket_item_card.dart';
import '../widgets/bucket_ui.dart';

/// Kanban board — Wish / Planned / Fulfilled columns.
///
/// Tap-to-move via each card's detail sheet (no drag, for web + touch
/// reliability). Cards render swipe-free here so gestures never fight
/// the horizontal column scroll.
class BucketKanbanBoard extends StatelessWidget {
  final List<BucketItem> items;
  final String currentUsername;
  final VoidCallback onAdd;

  const BucketKanbanBoard({
    super.key,
    required this.items,
    required this.currentUsername,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final byStatus = {
      for (final s in BucketStatus.values)
        s: items.where((i) => i.status == s).toList(),
    };

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: BucketStatus.values
          .map(
            (status) => _DreamColumn(
              status: status,
              items: byStatus[status] ?? [],
              currentUsername: currentUsername,
              onAdd: status == BucketStatus.wish ? onAdd : null,
            ),
          )
          .toList(),
    );
  }
}

class _DreamColumn extends StatelessWidget {
  final BucketStatus status;
  final List<BucketItem> items;
  final String currentUsername;
  final VoidCallback? onAdd;

  const _DreamColumn({
    required this.status,
    required this.items,
    required this.currentUsername,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<BucketItem>.from(items)
      ..sort((a, b) {
        final pr = b.priority.rank.compareTo(a.priority.rank);
        if (pr != 0) return pr;
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        if (a.dueDate != null) return -1;
        if (b.dueDate != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    final hue = bucketStatusHue(status);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnWidth = screenWidth < 560 ? screenWidth * 0.78 : 300.0;

    return Container(
      width: columnWidth,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.panelGlass,
        borderRadius: AppRadius.radiusX2,
        border: Border.all(color: hue.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  hue.withValues(alpha: 0.16),
                  hue.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.x2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hue.withValues(alpha: 0.14),
                    border: Border.all(color: hue.withValues(alpha: 0.4)),
                  ),
                  child: Icon(bucketStatusIcon(status), size: 15, color: hue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bucketStatusLabel(status),
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 13,
                      color: hue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hue.withValues(alpha: 0.14),
                    borderRadius: AppRadius.radiusFull,
                  ),
                  child: Text(
                    '${sorted.length}',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 11,
                      color: hue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (sorted.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      bucketStatusIcon(status),
                      size: 28,
                      color: hue.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == BucketStatus.completed
                          ? 'None fulfilled yet'
                          : 'No ${bucketStatusLabel(status).toLowerCase()} dreams',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.petalWhite.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                itemCount: sorted.length,
                itemBuilder: (context, idx) => BucketItemCard(
                  item: sorted[idx],
                  currentUsername: currentUsername,
                  enableSwipe: false,
                ),
              ),
            ),
          if (onAdd != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Semantics(
                button: true,
                label: 'Plant a new dream',
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.moonlight.withValues(alpha: 0.05),
                      borderRadius: AppRadius.radiusLg,
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 15,
                          color: AppColors.blushGold.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Plant a dream',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 12,
                            color: AppColors.blushGold.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
