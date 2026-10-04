part of 'motchi_sidebar.dart';

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMedium,
        minimumSize: const Size(44, 52),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        textStyle: AppTypography.bodySmall().copyWith(
          fontFamily: AppTypography.reading,
          fontWeight: FontWeight.w400,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.textMuted),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
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
    final now = DateTime.now();
    final isToday =
        now.day == session.createdAt.day &&
        now.month == session.createdAt.month &&
        now.year == session.createdAt.year;
    final dateStr = isLive
        ? 'Active now'
        : DateFormat(isToday ? 'h:mm a' : 'MMM d').format(session.createdAt);
    final hasPreview = session.summary?.trim().isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? AppColors.glassSoft : Colors.transparent,
        borderRadius: AppRadius.radiusSm,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
          title: Text(
            session.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium().copyWith(
              fontFamily: AppTypography.reading,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
              color: AppColors.textHigh,
              height: 1.4,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasPreview)
                Text(
                  session.summary!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall().copyWith(
                    fontFamily: AppTypography.reading,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              Text(
                '$dateStr · ${session.messageCount} msg${session.messageCount == 1 ? '' : 's'}${session.hasSummary && !hasPreview ? ' · summary' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall().copyWith(
                  fontFamily: AppTypography.reading,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textDisabled,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            tooltip: 'Delete conversation',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
