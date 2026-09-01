import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/journal/data/models/journal_entry.dart';
import '../../../../features/journal/data/services/journal_service.dart';
import 'feature_section.dart';

class JournalPreview extends StatelessWidget {
  const JournalPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = JournalService();
    return StreamBuilder<List<JournalEntry>>(
      stream: service.watchAll(),
      builder: (context, snap) {
        final entries = snap.data ?? [];
        final count = entries.length;
        final pinned = entries.where((e) => e.isPinned).length;
        final recent = entries.take(3).toList();

        final subtitle = count == 0
            ? 'No entries yet — write your first memory'
            : '$count ${count == 1 ? 'entry' : 'entries'}'
                  '${pinned > 0 ? ' • $pinned pinned' : ''}';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FeatureSection(
            icon: Icons.menu_book_rounded,
            hue: AppColors.softLavender,
            title: 'Our Journal',
            subtitle: subtitle,
            trailing: const SectionChevron(hue: AppColors.softLavender),
            onTap: () => context.push('/journal'),
            child: recent.isEmpty
                ? const _EmptyRow(
                    hue: AppColors.softLavender,
                    icon: Icons.edit_note_rounded,
                    text: 'Capture a date, a fight, a laugh — keep it forever.',
                  )
                : Column(
                    children: recent.map((e) => _JournalRow(entry: e)).toList(),
                  ),
          ),
        );
      },
    );
  }
}

class _JournalRow extends StatelessWidget {
  final JournalEntry entry;
  const _JournalRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.softLavender.withValues(alpha: 0.14),
              borderRadius: AppRadius.radiusSm,
              border: Border.all(
                color: AppColors.softLavender.withValues(alpha: 0.22),
              ),
            ),
            child: Center(
              child: Text(
                entry.category.emoji,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.petalWhite.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    if (entry.isPinned) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.push_pin_rounded,
                        size: 11,
                        color: AppColors.auroraGold.withValues(alpha: 0.9),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _relativeDate(entry.createdAt),
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10,
                    color: AppColors.petalWhite.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.petalWhite.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.08)),
            ),
            child: Text(
              '${entry.wordCount}w',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.petalWhite.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return '${d.month}/${d.day}/${d.year}';
  }
}

class _EmptyRow extends StatelessWidget {
  final Color hue;
  final IconData icon;
  final String text;
  const _EmptyRow({required this.hue, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.08),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: hue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 11,
                color: AppColors.petalWhite.withValues(alpha: 0.60),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
