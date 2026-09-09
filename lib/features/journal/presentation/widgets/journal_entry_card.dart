import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_card.dart';
import '../../data/models/journal_entry.dart';
import 'journal_detail_sheet.dart';
import 'journal_ui.dart';

/// A journal entry rendered as a love letter.
///
/// Warm paper feel: category accent thread on top, serif title, author
/// avatar footer. Locked entries stay sealed until opened. Tapping opens
/// the shared [JournalDetailSheet] (or [onTap] when the list overrides).
class JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback? onTap;

  const JournalEntryCard({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hue = journalCategoryColor(entry.category);
    final title = entry.title.isEmpty ? 'Untitled' : entry.title;
    final semanticLabel = entry.isLocked
        ? 'Locked entry — $title by ${journalAuthorName(entry.author)}'
        : '$title by ${journalAuthorName(entry.author)}, '
              '${entry.category.displayName}';
    return EverglowCard(
      onTap: onTap ?? () => showJournalDetailSheet(context: context, entry: entry),
      semanticLabel: semanticLabel,
      padding: EdgeInsets.zero,
      radius: AppRadius.lg,
      fillColor: AppColors.panelGlass,
      boxShadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category accent thread
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  hue.withValues(alpha: 0.85),
                  hue.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.isPinned) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 12,
                        color: AppColors.blushGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pinned with love',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: AppColors.blushGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: hue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: hue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${entry.category.emoji} ${entry.category.displayName}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: hue,
                        ),
                      ),
                    ),
                    if (entry.mood != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.moonlight.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${entry.mood!.emoji} ${entry.mood!.name}',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 10,
                            color: AppColors.petalWhite.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (entry.isLocked)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: AppColors.warmAmber.withValues(alpha: 0.9),
                        ),
                      ),
                    Text(
                      journalRelativeDate(entry.createdAt),
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.petalWhite.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 21,
                    height: 1.15,
                    color: AppColors.petalWhite,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (entry.isLocked)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.inkDeep.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.warmAmber.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: AppColors.petalWhite.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sealed with a kiss — tap to open',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            color: AppColors.petalWhite.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    entry.preview.isEmpty ? 'No content' : entry.preview,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 13,
                      color: AppColors.textMedium,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (!entry.isLocked && entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...entry.tags.take(3).map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softLavender.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '#$t',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 10,
                              color: AppColors.softLavender,
                            ),
                          ),
                        ),
                      ),
                      if (entry.tags.length > 3)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '+${entry.tags.length - 3}',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 10,
                              color: AppColors.petalWhite.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    AuthorDot(author: entry.author, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      journalAuthorName(entry.author),
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.petalWhite.withValues(alpha: 0.75),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.petalWhite.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    Text(
                      journalReadingTime(entry.wordCount),
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 10,
                        color: AppColors.petalWhite.withValues(alpha: 0.45),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entry.wordCount} words',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 10,
                        color: AppColors.petalWhite.withValues(alpha: 0.4),
                      ),
                    ),
                    if (entry.isLong) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.auto_stories_rounded,
                        size: 11,
                        color: AppColors.blushGold,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
