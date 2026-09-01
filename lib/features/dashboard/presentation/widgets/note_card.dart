import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/hidden_note.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../core/theme/app_typography.dart';

class NoteCard extends StatelessWidget {
  final HiddenNote note;
  final VoidCallback onTap;

  const NoteCard({super.key, required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool unlocked = note.isUnlocked;

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          width: 150,
          height: 180,
          borderRadius: BorderRadius.circular(24.0),
          border: unlocked && !note.isRead
              ? Border.all(color: AppColors.blushGold, width: 1.5)
              : Border.all(
                  color: AppColors.moonlight.withValues(alpha: 0.15),
                  width: 1.0,
                ),
          opacity: unlocked && !note.isRead ? 0.22 : 0.12,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  unlocked
                      ? (note.isRead ? Icons.drafts_outlined : Icons.favorite)
                      : Icons.lock_outline,
                  size: 36,
                  color: unlocked
                      ? (note.isRead ? AppColors.roseQuartz : AppColors.deepRose)
                      : AppColors.blushGold,
                  shadows: [
                    if (unlocked && !note.isRead)
                      BoxShadow(
                        color: AppColors.deepRose.withValues(alpha: 0.5),
                        blurRadius: 15,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  note.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.petalWhite,
                    letterSpacing: 0.5,
                  ),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 8),
                  Text(
                    _getCountdownText(note.unlockDate),
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 11,
                      color: AppColors.petalWhite.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCountdownText(DateTime unlockDate) {
    final diff = unlockDate.difference(DateTime.now());
    if (diff.inDays > 0) {
      return 'Opens in ${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return 'Opens in ${diff.inHours}h';
    } else {
      return 'Opens soon';
    }
  }
}