import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';
import '../../../../core/theme/app_typography.dart';

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
          child: const Icon(
            Icons.delete_rounded,
            color: Colors.redAccent,
            size: 28,
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Delete
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.velvet,
                title: Text(
                  'Delete "${item.title}"?',
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.roseQuartz,
                  ),
                ),
                content: Text(
                  'This cannot be undone.',
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.7),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'Cancel',
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppTheme.petalWhite.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Delete',
                      style: AppTypography.outfitWhite.copyWith(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
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
          label:
              '${item.title}, ${item.category.displayName}, ${item.status.displayName}',
          button: true,
          child: GestureDetector(
            onTap: () => _showDetail(context),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.moonlight.withValues(
                  alpha: AppTheme.glassOpacity,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCompleted
                      ? AppTheme.blushGold.withValues(alpha: 0.3)
                      : AppTheme.blushGold.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  // Category emoji with priority dot
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.deepRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            item.category.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      if (item.priority == BucketPriority.urgent ||
                          item.priority == BucketPriority.high)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _priorityColor(item.priority),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.velvet,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: AppTypography.outfitBold.copyWith(
                                  fontSize: 14,
                                  color: isCompleted
                                      ? AppTheme.petalWhite.withValues(
                                          alpha: 0.5,
                                        )
                                      : AppTheme.petalWhite,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (item.priority != BucketPriority.medium)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _priorityColor(
                                    item.priority,
                                  ).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.priority.emoji} ${item.priority.displayName}',
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: _priorityColor(item.priority),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (item.description.isNotEmpty)
                          Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 11,
                              color: AppTheme.petalWhite.withValues(alpha: 0.5),
                            ),
                          ),
                        const SizedBox(height: 4),
                        // Meta row: assignee + due date
                        Row(
                          children: [
                            if (item.assignedTo != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.auroraTeal.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.assignedTo == 'khentsgdz'
                                          ? Icons.person_rounded
                                          : Icons.favorite_rounded,
                                      size: 10,
                                      color: AppColors.auroraTeal,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      item.assignedTo == 'khentsgdz'
                                          ? 'Khent'
                                          : 'Clair',
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 10,
                                        color: AppColors.auroraTeal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (item.dueDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: item.isOverdue
                                      ? Colors.redAccent.withValues(alpha: 0.15)
                                      : item.isDueSoon
                                      ? AppTheme.warmAmber.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppTheme.moonlight.withValues(
                                          alpha: 0.08,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: item.isOverdue
                                        ? Colors.redAccent.withValues(
                                            alpha: 0.3,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.isOverdue
                                          ? Icons.warning_rounded
                                          : Icons.calendar_today_rounded,
                                      size: 10,
                                      color: item.isOverdue
                                          ? Colors.redAccent
                                          : item.isDueSoon
                                          ? AppTheme.warmAmber
                                          : AppTheme.petalWhite.withValues(
                                              alpha: 0.6,
                                            ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      item.isOverdue
                                          ? 'Overdue ${DateFormat.MMMd().format(item.dueDate!)}'
                                          : DateFormat.MMMd().format(
                                              item.dueDate!,
                                            ),
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 10,
                                        color: item.isOverdue
                                            ? Colors.redAccent
                                            : item.isDueSoon
                                            ? AppTheme.warmAmber
                                            : AppTheme.petalWhite.withValues(
                                                alpha: 0.6,
                                              ),
                                        fontWeight: item.isOverdue
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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

  Color _priorityColor(BucketPriority p) {
    switch (p) {
      case BucketPriority.low:
        return AppTheme.softLavender;
      case BucketPriority.medium:
        return AppTheme.blushGold;
      case BucketPriority.high:
        return AppTheme.warmAmber;
      case BucketPriority.urgent:
        return Colors.redAccent;
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.2)),
        ),
        child: SingleChildScrollView(
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
                  Text(
                    item.category.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: AppTypography.cormorantBold.copyWith(fontSize: 22),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(item.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.status.emoji} ${item.status.displayName}',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(item.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (item.description.isNotEmpty) ...[
                Text(
                  item.description,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _priorityColor(
                        item.priority,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _priorityColor(
                          item.priority,
                        ).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${item.priority.emoji} ${item.priority.displayName}',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        color: _priorityColor(item.priority),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (item.assignedTo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.auroraTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.assignedTo == 'khentsgdz'
                            ? '👤 Khent'
                            : '💕 Clair',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: AppColors.auroraTeal,
                        ),
                      ),
                    ),
                  if (item.dueDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: item.isOverdue
                            ? Colors.redAccent.withValues(alpha: 0.12)
                            : AppTheme.moonlight.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.isOverdue
                            ? '⚠️ Overdue ${DateFormat.yMMMd().format(item.dueDate!)}'
                            : '📅 ${DateFormat.yMMMd().format(item.dueDate!)}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: item.isOverdue
                              ? Colors.redAccent
                              : AppTheme.petalWhite.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Added by ${item.createdBy} · ${DateFormat.yMMMd().format(item.createdAt)}',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppTheme.petalWhite.withValues(alpha: 0.5),
                ),
              ),
              if (item.completedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '✅ Completed by ${item.completedBy} · ${DateFormat.yMMMd().format(item.completedAt!)}',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    color: Colors.green.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Kanban move row (Vikunja)
              Text(
                'Move to',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppTheme.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: BucketStatus.values.map((s) {
                  final isCurrent = item.status == s;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: isCurrent
                            ? null
                            : () async {
                                await BucketListService().moveStatus(
                                  item.id,
                                  s,
                                  completedBy: currentUsername,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? _statusColor(s).withValues(alpha: 0.25)
                                : AppTheme.twilight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? _statusColor(s)
                                  : AppTheme.blushGold.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                s.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.displayName,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 10,
                                  color: isCurrent
                                      ? _statusColor(s)
                                      : AppTheme.petalWhite.withValues(
                                          alpha: 0.7,
                                        ),
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Quick edits row
              Row(
                children: [
                  Expanded(
                    child: _buildMiniEditButton(
                      label: item.assignedTo == null ? 'Assign' : 'Unassign',
                      icon: Icons.person_rounded,
                      onTap: () async {
                        final svc = BucketListService();
                        if (item.assignedTo == null) {
                          // assign to current user
                          await svc.assign(
                            item.id,
                            currentUsername.isEmpty
                                ? 'khentsgdz'
                                : currentUsername,
                          );
                        } else {
                          await svc.assign(item.id, null);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniEditButton(
                      label: 'Due date',
                      icon: Icons.calendar_today_rounded,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: item.dueDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                          builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.deepRose,
                                surface: AppTheme.velvet,
                                onSurface: AppTheme.petalWhite,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          await BucketListService().setDueDate(
                            item.id,
                            DateTime(picked.year, picked.month, picked.day),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniEditButton(
                      label: item.dueDate == null ? 'No due' : 'Clear due',
                      icon: Icons.clear_rounded,
                      onTap: item.dueDate == null
                          ? null
                          : () async {
                              await BucketListService().setDueDate(
                                item.id,
                                null,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Priority quick switch
              Wrap(
                spacing: 8,
                children: BucketPriority.values.map((p) {
                  final isSel = item.priority == p;
                  return GestureDetector(
                    onTap: isSel
                        ? null
                        : () async {
                            await BucketListService().setPriority(item.id, p);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSel
                            ? _priorityColor(p).withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel
                              ? _priorityColor(p)
                              : AppTheme.blushGold.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        '${p.emoji} ${p.displayName}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: isSel
                              ? _priorityColor(p)
                              : AppTheme.petalWhite.withValues(alpha: 0.6),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniEditButton({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: onTap == null
              ? AppTheme.twilight.withValues(alpha: 0.5)
              : AppTheme.moonlight.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: onTap == null
                  ? AppTheme.petalWhite.withValues(alpha: 0.3)
                  : AppTheme.blushGold,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 11,
                color: onTap == null
                    ? AppTheme.petalWhite.withValues(alpha: 0.3)
                    : AppTheme.petalWhite.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
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
              style: AppTypography.outfitBold.copyWith(
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
