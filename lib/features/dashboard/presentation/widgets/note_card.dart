import 'package:flutter/material.dart';
import 'package:everglow/features/dashboard/domain/models/hidden_note.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/core/theme/app_theme.dart';

class NoteCard extends StatelessWidget {
  final HiddenNote note;
  final VoidCallback onTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool unlocked = note.isUnlocked;

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: 160,
        height: 180,
        borderRadius: BorderRadius.circular(32.0),
        border: unlocked && !note.isRead
            ? Border.all(color: AppTheme.neonTeal, width: 2)
            : Border.all(color: Colors.white24, width: 0.5),
        opacity: unlocked && !note.isRead ? 0.3 : 0.15,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                unlocked
                    ? (note.isRead ? Icons.drafts_outlined : Icons.favorite)
                    : Icons.lock_outline,
                size: 40,
                color: unlocked 
                    ? (note.isRead ? AppTheme.primaryPink : AppTheme.peachyMagenta)
                    : AppTheme.champagneGold,
                shadows: [
                  if (unlocked && !note.isRead)
                    const Shadow(
                      color: AppTheme.peachyMagenta,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
              if (!unlocked) ...[
                const SizedBox(height: 8),
                Text(
                  _getCountdownText(note.unlockDate),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
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
