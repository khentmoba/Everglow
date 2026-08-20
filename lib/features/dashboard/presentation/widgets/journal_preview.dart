import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/journal/data/models/journal_entry.dart';
import '../../../../features/journal/data/services/journal_service.dart';

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
        final recent = entries.take(3).toList();
        return GestureDetector(
          onTap: () => context.push('/journal'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.menu_book_rounded, size: 18, color: AppColors.softLavender), const SizedBox(width: 8), Text('Our Journal', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppColors.petalWhite)), const Spacer(), Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.softLavender)]),
                const SizedBox(height: 6),
                Text(count == 0 ? 'No entries yet — write your first memory' : '$count ${count == 1 ? 'entry' : 'entries'} • ${entries.where((e) => e.isPinned).length} pinned', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.6))),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...recent.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Text(e.category.emoji, style: const TextStyle(fontSize: 12)), const SizedBox(width: 6), Expanded(child: Text(e.title, style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppColors.petalWhite.withValues(alpha: 0.85)), maxLines: 1, overflow: TextOverflow.ellipsis)), Text('${e.wordCount}w', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.petalWhite.withValues(alpha: 0.5))) ]))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
