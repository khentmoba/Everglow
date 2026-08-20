import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/bucket_item.dart';
import 'bucket_item_card.dart';

/// Kanban board — Vikunja inspired, 3 columns for Wish/Planned/Completed.
///
/// Uses tap-to-move (no drag for web reliability) with progress counts.
class BucketKanbanBoard extends StatelessWidget {
  final List<BucketItem> items;
  final String currentUsername;

  const BucketKanbanBoard({super.key, required this.items, required this.currentUsername});

  @override
  Widget build(BuildContext context) {
    final byStatus = {
      for (final s in BucketStatus.values) s: items.where((i) => i.status == s).toList(),
    };

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: BucketStatus.values.map((status) => _buildColumn(context, status, byStatus[status] ?? [])).toList(),
    );
  }

  Widget _buildColumn(BuildContext context, BucketStatus status, List<BucketItem> colItems) {
    // Sort by priority rank desc, then dueDate asc, then createdAt desc.
    final sorted = List<BucketItem>.from(colItems)
      ..sort((a, b) {
        final pr = b.priority.rank.compareTo(a.priority.rank);
        if (pr != 0) return pr;
        if (a.dueDate != null && b.dueDate != null) return a.dueDate!.compareTo(b.dueDate!);
        if (a.dueDate != null) return -1;
        if (b.dueDate != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    final hue = _statusHue(status);
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppTheme.velvet.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hue.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(status.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(status.displayName, style: AppTypography.outfitBold.copyWith(fontSize: 13, color: hue)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: hue.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                  child: Text('${sorted.length}', style: AppTypography.outfitWhite.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: hue)),
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
                    Icon(_statusIcon(status), size: 28, color: hue.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text('No ${status.displayName.toLowerCase()}', style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppTheme.petalWhite.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: sorted.length,
                itemBuilder: (context, idx) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BucketItemCard(item: sorted[idx], currentUsername: currentUsername),
                ),
              ),
            ),
          // Quick add hint for wish column
          if (status == BucketStatus.wish)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: GestureDetector(
                onTap: () {
                  // Parent screen handles add; no-op here but keeps layout.
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.moonlight.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.1), style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: AppTheme.petalWhite.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text('Add dream', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusHue(BucketStatus s) {
    switch (s) {
      case BucketStatus.wish:
        return AppTheme.blushGold;
      case BucketStatus.planned:
        return AppColors.auroraTeal;
      case BucketStatus.completed:
        return Colors.greenAccent;
    }
  }

  IconData _statusIcon(BucketStatus s) {
    switch (s) {
      case BucketStatus.wish:
        return Icons.auto_awesome_outlined;
      case BucketStatus.planned:
        return Icons.event_note_outlined;
      case BucketStatus.completed:
        return Icons.check_circle_outline_rounded;
    }
  }
}
