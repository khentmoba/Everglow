part of 'motchi_sidebar.dart';

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
              width: 0.9,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTypography.labelSmall().copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionItem extends StatelessWidget {
  final AISession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionItem({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = session.id == '__live__';
    final timeStr = DateFormat('h:mm a').format(session.createdAt);
    final now = DateTime.now();
    final isToday =
        now.day == session.createdAt.day &&
        now.month == session.createdAt.month &&
        now.year == session.createdAt.year;
    final dateStr = isLive
        ? 'Active now'
        : (isToday ? timeStr : DateFormat('MMM d').format(session.createdAt));

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLg,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.blushGold.withValues(alpha: 0.13)
                  : (isLive ? AppColors.surfaceGlass : Colors.transparent),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: isActive
                    ? AppColors.blushGold.withValues(alpha: 0.35)
                    : (isLive
                          ? AppColors.blushGold.withValues(alpha: 0.18)
                          : Colors.transparent),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive)
                  Container(
                    width: 3,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6, top: 2),
                    decoration: BoxDecoration(
                      color: AppColors.blushGold,
                      borderRadius: AppRadius.radiusFull,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blushGold.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.blushGold.withValues(alpha: 0.16)
                        : (isActive
                              ? AppColors.blushGold.withValues(alpha: 0.12)
                              : AppColors.surfaceGlass),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLive
                        ? Icons.auto_awesome_rounded
                        : (session.hasSummary
                              ? Icons.summarize_rounded
                              : Icons.chat_bubble_outline_rounded),
                    size: 14,
                    color: isLive
                        ? AppColors.blushGold
                        : (isActive
                              ? AppColors.blushGold
                              : AppColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              style: AppTypography.bodySmall().copyWith(
                                color: isActive
                                    ? AppColors.textHigh
                                    : AppColors.textMedium,
                                fontWeight: isActive || isLive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLive) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: AppRadius.radiusFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'LIVE',
                                    style: AppTypography.labelSmall().copyWith(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (session.summary != null &&
                          session.summary!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          session.summary!.trim(),
                          style: AppTypography.bodySmall().copyWith(
                            color: AppColors.textMuted.withValues(alpha: 0.7),
                            fontSize: 10.5,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (session.hasSummary &&
                              (session.summary == null ||
                                  session.summary!.trim().isEmpty))
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.blushGold.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'summary',
                                style: AppTypography.bodySmall().copyWith(
                                  color: AppColors.blushGold,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              '$dateStr · ${session.messageCount} msg${session.messageCount == 1 ? '' : 's'}',
                              style: AppTypography.bodySmall().copyWith(
                                color: AppColors.textDisabled,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Delete conversation',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onDelete,
                      borderRadius: AppRadius.radiusSm,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.textDisabled,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
