import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';

/// A card displaying a single bucket list item.
class BucketItemCard extends StatelessWidget {
  final BucketItem item;
  final String currentUsername;

  const BucketItemCard({
    super.key,
    required this.item,
    required this.currentUsername,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == BucketStatus.completed;
    final service = BucketListService();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: isCompleted
            ? DismissDirection.endToStart
            : DismissDirection.startToEnd,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: AppTheme.deepRose.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isCompleted ? Icons.undo_rounded : Icons.check_circle_rounded,
            color: AppTheme.blushGold,
            size: 28,
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 28),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Delete
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.velvet,
                title: Text('Delete "${item.title}"?', style: GoogleFonts.outfit(color: AppTheme.roseQuartz)),
                content: Text('This cannot be undone.', style: GoogleFonts.outfit(color: AppTheme.petalWhite.withValues(alpha: 0.7))),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.petalWhite.withValues(alpha: 0.6)))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.outfit(color: Colors.redAccent))),
                ],
              ),
            );
          }
          // Complete/Uncomplete
          if (isCompleted) {
            await service.markUncomplete(item.id);
          } else {
            await service.markComplete(item.id, currentUsername);
          }
          return false;
        },
        child: Semantics(
          label: '${item.title}, ${item.category.displayName}, ${item.status.displayName}',
          button: true,
          child: GestureDetector(
            onTap: () => _showDetail(context),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCompleted
                      ? AppTheme.blushGold.withValues(alpha: 0.3)
                      : AppTheme.blushGold.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  // Category emoji
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(item.category.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? AppTheme.petalWhite.withValues(alpha: 0.5)
                                : AppTheme.petalWhite,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (item.description.isNotEmpty)
                          Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppTheme.petalWhite.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(item.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.status.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(BucketStatus status) {
    switch (status) {
      case BucketStatus.wish:
        return AppTheme.blushGold;
      case BucketStatus.planned:
        return Colors.blueAccent;
      case BucketStatus.completed:
        return Colors.green;
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.petalWhite.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text(item.category.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.roseQuartz,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.description.isNotEmpty) ...[
              Text(
                item.description,
                style: GoogleFonts.outfit(
                  color: AppTheme.petalWhite.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Added by ${item.createdBy} · ${DateFormat.yMMMd().format(item.createdAt)}',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppTheme.petalWhite.withValues(alpha: 0.5),
              ),
            ),
            if (item.completedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '✅ Completed by ${item.completedBy} · ${DateFormat.yMMMd().format(item.completedAt!)}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.green.withValues(alpha: 0.8),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                if (item.status != BucketStatus.completed)
                  Expanded(
                    child: _buildActionButton(
                      label: item.status == BucketStatus.wish ? 'Mark Planned' : 'Mark Complete',
                      icon: item.status == BucketStatus.wish ? Icons.event_rounded : Icons.check_circle_rounded,
                      onTap: () async {
                        final service = BucketListService();
                        if (item.status == BucketStatus.wish) {
                          await service.markPlanned(item.id);
                        } else {
                          await service.markComplete(item.id, currentUsername);
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                if (item.status == BucketStatus.completed) ...[
                  Expanded(
                    child: _buildActionButton(
                      label: 'Undo Complete',
                      icon: Icons.undo_rounded,
                      onTap: () async {
                        await BucketListService().markUncomplete(item.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.deepRose, Color(0xFF8E1444)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.petalWhite),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: AppTheme.petalWhite,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
