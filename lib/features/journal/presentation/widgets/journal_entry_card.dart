import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_card.dart';
import '../../data/models/journal_entry.dart';
import 'journal_detail_sheet.dart';
import 'journal_ui.dart';

/// A journal entry rendered as a romantic love letter.
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
      radius: AppRadius.xl,
      fillColor: Colors.transparent,
      boxShadow: [
        BoxShadow(
          color: AppColors.inkDeep.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        if (entry.isPinned)
          BoxShadow(
            color: AppColors.blushGold.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelGlass,
          gradient: LinearGradient(
            colors: [
              AppColors.velvet.withValues(alpha: 0.40),
              AppColors.inkDeep.withValues(alpha: 0.70),
              hue.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: entry.isPinned
                ? AppColors.blushGold.withValues(alpha: 0.36)
                : AppColors.moonlight.withValues(alpha: 0.10),
            width: entry.isPinned ? 1.2 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category accent thread
            Container(
              height: 3.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    hue.withValues(alpha: 0.95),
                    hue.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.isPinned) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blushGold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: AppColors.blushGold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.push_pin_rounded,
                                size: 11,
                                color: AppColors.blushGold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pinned with love',
                                style: AppTypography.outfitBold.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                  color: AppColors.blushGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4.5,
                        ),
                        decoration: BoxDecoration(
                          color: hue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: hue.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(entry.category.emoji, style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 5),
                            Text(
                              entry.category.displayName,
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 10.5,
                                color: hue,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (entry.mood != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.moonlight.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: AppColors.moonlight.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Text(
                            '${entry.mood!.emoji} ${entry.mood!.name}',
                            style: AppTypography.outfitMedium.copyWith(
                              fontSize: 10.5,
                              color: AppColors.petalWhite.withValues(alpha: 0.72),
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
                            color: AppColors.warmAmber.withValues(alpha: 0.95),
                          ),
                        ),
                      Text(
                        journalRelativeDate(entry.createdAt),
                        style: AppTypography.outfitMedium.copyWith(
                          fontSize: 11,
                          color: AppColors.petalWhite.withValues(alpha: 0.52),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: AppTypography.cormorantBoldWhite.copyWith(
                      fontSize: 22,
                      height: 1.22,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (entry.isLocked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.inkDeep.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.warmAmber.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 15,
                            color: AppColors.warmAmber.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sealed with a kiss — tap to open',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              color: AppColors.petalWhite.withValues(alpha: 0.68),
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
                        fontSize: 13.5,
                        color: AppColors.petalWhite.withValues(alpha: 0.76),
                        height: 1.55,
                      ),
                      maxLines: 3,
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
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softLavender.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                              border: Border.all(
                                color: AppColors.softLavender.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                            child: Text(
                              '#$t',
                              style: AppTypography.outfitMedium.copyWith(
                                fontSize: 10.5,
                                color: AppColors.softLavender,
                              ),
                            ),
                          ),
                        ),
                        if (entry.tags.length > 3)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.5),
                            child: Text(
                              '+${entry.tags.length - 3}',
                              style: AppTypography.outfitMedium.copyWith(
                                fontSize: 10.5,
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
                  Container(
                    height: 1,
                    color: AppColors.moonlight.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      AuthorDot(author: entry.author, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        journalAuthorName(entry.author),
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 11.5,
                          color: AppColors.petalWhite.withValues(alpha: 0.85),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.petalWhite.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      Text(
                        journalReadingTime(entry.wordCount),
                        style: AppTypography.outfitMedium.copyWith(
                          fontSize: 11,
                          color: AppColors.petalWhite.withValues(alpha: 0.48),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${journalNumberFormat(entry.wordCount)} words',
                        style: AppTypography.outfitMedium.copyWith(
                          fontSize: 11,
                          color: AppColors.petalWhite.withValues(alpha: 0.45),
                        ),
                      ),
                      if (entry.isLong) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.auto_stories_rounded,
                          size: 13,
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
      ),
    );
  }
}
