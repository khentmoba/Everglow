import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../data/models/journal_entry.dart';
import '../../data/services/journal_service.dart';
import 'journal_ui.dart';

/// Opens the journal reading sheet — the ONE full-entry view.
///
/// Used by the journal list and by [JournalEntryCard]'s fallback tap.
/// [onEdit] opens the edit dialog; null hides the edit button (the card
/// fallback has no auth context, so it passes null).
Future<void> showJournalDetailSheet({
  required BuildContext context,
  required JournalEntry entry,
  VoidCallback? onEdit,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => JournalDetailSheet(entry: entry, onEdit: onEdit),
  );
}

class JournalDetailSheet extends StatefulWidget {
  final JournalEntry entry;
  final VoidCallback? onEdit;

  const JournalDetailSheet({super.key, required this.entry, this.onEdit});

  @override
  State<JournalDetailSheet> createState() => _JournalDetailSheetState();
}

class _JournalDetailSheetState extends State<JournalDetailSheet> {
  bool _revealed = false;

  JournalEntry get _entry => widget.entry;

  @override
  Widget build(BuildContext context) {
    final hue = journalCategoryColor(_entry.category);
    final locked = _entry.isLocked && !_revealed;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.velvet, AppColors.inkDeep],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.x2),
          ),
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.22),
          ),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.petalWhite.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Category + mood + actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hue.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: hue.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '${_entry.category.emoji} ${_entry.category.displayName}',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hue,
                    ),
                  ),
                ),
                if (_entry.mood != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.moonlight.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${_entry.mood!.emoji} ${_entry.mood!.name}',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        color: AppColors.petalWhite.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.onEdit != null)
                  EverglowIconButton(
                    icon: Icons.edit_rounded,
                    onPressed: widget.onEdit,
                    semanticLabel: 'Edit entry',
                    tooltip: 'Edit',
                    iconColor: AppColors.blushGold,
                  ),
                EverglowIconButton(
                  icon: _entry.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  onPressed: () async {
                    await JournalService().togglePin(
                      _entry.id,
                      !_entry.isPinned,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  semanticLabel: _entry.isPinned ? 'Unpin entry' : 'Pin entry',
                  tooltip: _entry.isPinned ? 'Unpin' : 'Pin',
                  iconColor: AppColors.blushGold,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _entry.title.isEmpty ? 'Untitled' : _entry.title,
              style: AppTypography.cormorantBold.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 10),
            // Byline: avatar + author + date + reading time
            Row(
              children: [
                AuthorDot(author: _entry.author, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${journalAuthorName(_entry.author)} • '
                    '${DateFormat.yMMMd().add_jm().format(_entry.createdAt)} • '
                    '${journalReadingTime(_entry.wordCount)}',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 11,
                      color: AppColors.petalWhite.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            if (_entry.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _entry.tags
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softLavender.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '#$t',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11,
                            color: AppColors.softLavender,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            // Heart divider
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.blushGold.withValues(alpha: 0.18),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 14,
                    color: AppColors.deepRose,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.blushGold.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (locked)
              _LockedBox(onReveal: () => setState(() => _revealed = true))
            else
              SelectableText(
                _entry.content.isEmpty ? 'No content.' : _entry.content,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 15,
                  height: 1.7,
                  color: AppColors.textHigh,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await JournalService().toggleLock(
                        _entry.id,
                        !_entry.isLocked,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      _entry.isLocked
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                      size: 16,
                    ),
                    label: Text(_entry.isLocked ? 'Unlock' : 'Lock'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warmAmber,
                      side: BorderSide(
                        color: AppColors.warmAmber.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.velvet,
        title: Text(
          'Delete entry?',
          style: AppTypography.outfitBold.copyWith(
            color: AppColors.petalWhite,
          ),
        ),
        content: Text(
          'This cannot be undone.',
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await JournalService().delete(_entry.id);
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }
}

class _LockedBox extends StatelessWidget {
  final VoidCallback onReveal;
  const _LockedBox({required this.onReveal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.warmAmber.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warmAmber.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.warmAmber.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 24,
              color: AppColors.warmAmber,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sealed with a kiss',
            style: AppTypography.cormorantBold.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'A private page, just between us.\nTap reveal to open it.',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 12,
              color: AppColors.petalWhite.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onReveal,
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Reveal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepRose,
                foregroundColor: AppColors.petalWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Author avatar dot — shared by the sheet and the entry cards.
class AuthorDot extends StatelessWidget {
  final String author;
  final double size;

  const AuthorDot({super.key, required this.author, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final hue = journalAuthorHue(author);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hue.withValues(alpha: 0.16),
        border: Border.all(color: hue.withValues(alpha: 0.45)),
      ),
      child: Center(
        child: Text(
          journalAuthorInitial(author),
          style: AppTypography.outfitBold.copyWith(
            fontSize: size * 0.42,
            color: hue,
          ),
        ),
      ),
    );
  }
}
