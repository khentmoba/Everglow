import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/journal_entry.dart';
import '../../data/services/journal_service.dart';

class JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback? onTap;

  const JournalEntryCard({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLocked = entry.isLocked;
    return GestureDetector(
      onTap: onTap ?? () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: entry.isPinned ? AppColors.blushGold.withValues(alpha: 0.35) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _categoryColor(entry.category).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${entry.category.emoji} ${entry.category.displayName}', style: AppTypography.outfitWhite.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: _categoryColor(entry.category))),
                ),
                const SizedBox(width: 8),
                if (entry.mood != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                    child: Text(entry.mood!.emoji, style: const TextStyle(fontSize: 12)),
                  ),
                const Spacer(),
                if (entry.isPinned) Icon(Icons.push_pin_rounded, size: 14, color: AppColors.blushGold),
                if (entry.isLocked) ...[const SizedBox(width: 6), Icon(Icons.lock_rounded, size: 14, color: AppColors.warmAmber)],
                const SizedBox(width: 6),
                Text(DateFormat.MMMd().add_jm().format(entry.createdAt), style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.5))),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.title.isEmpty ? 'Untitled' : entry.title,
              style: AppTypography.cormorantBold.copyWith(fontSize: 18, color: AppTheme.petalWhite),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (isLocked)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.petalWhite.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text('Locked entry — tap to reveal', style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppTheme.petalWhite.withValues(alpha: 0.6), fontStyle: FontStyle.italic)),
                  ],
                ),
              )
            else
              Text(
                entry.preview.isEmpty ? 'No content' : entry.preview,
                style: AppTypography.outfitWhite.copyWith(fontSize: 13, color: AppTheme.petalWhite.withValues(alpha: 0.72), height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if (!isLocked && entry.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: entry.tags.take(5).map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.softLavender.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text('#$t', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.softLavender)),
                    )).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 12, color: AppTheme.petalWhite.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text(entry.author, style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.5))),
                const Spacer(),
                Text('${entry.wordCount} words', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.4))),
                if (entry.isLong) ...[const SizedBox(width: 6), Icon(Icons.auto_stories_rounded, size: 10, color: AppColors.blushGold)],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(JournalCategory c) {
    switch (c) {
      case JournalCategory.daily:
        return AppColors.softLavender;
      case JournalCategory.gratitude:
        return AppColors.blushGold;
      case JournalCategory.memory:
        return AppColors.auroraTeal;
      case JournalCategory.letter:
        return AppColors.deepRose;
      case JournalCategory.dream:
        return AppColors.auroraLilac;
      case JournalCategory.idea:
        return AppColors.warmAmber;
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _JournalDetailSheet(entry: entry),
    );
  }
}

class _JournalDetailSheet extends StatefulWidget {
  final JournalEntry entry;
  const _JournalDetailSheet({required this.entry});

  @override
  State<_JournalDetailSheet> createState() => _JournalDetailSheetState();
}

class _JournalDetailSheetState extends State<_JournalDetailSheet> {
  late JournalEntry _entry = widget.entry;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final isLocked = _entry.isLocked && !_revealed;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(color: AppTheme.velvet, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.2))),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.petalWhite.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(_entry.category.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(child: Text(_entry.title.isEmpty ? 'Untitled' : _entry.title, style: AppTypography.cormorantBold.copyWith(fontSize: 24))),
                IconButton(
                  onPressed: () async {
                    await JournalService().togglePin(_entry.id, !_entry.isPinned);
                    if (mounted) Navigator.pop(context);
                  },
                  icon: Icon(_entry.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: AppColors.blushGold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Text(DateFormat.yMMMd().add_jm().format(_entry.createdAt), style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.6))),
                if (_entry.mood != null) Text('• ${_entry.mood!.emoji} ${_entry.mood!.name}', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.7))),
                Text('• by ${_entry.author}', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.6))),
              ],
            ),
            if (_entry.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: _entry.tags.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.softLavender.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Text('#$t', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.softLavender)))).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            if (isLocked)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.2))),
                child: Column(
                  children: [
                    Icon(Icons.lock_rounded, size: 32, color: AppColors.warmAmber),
                    const SizedBox(height: 12),
                    Text('This entry is locked', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppTheme.petalWhite)),
                    const SizedBox(height: 6),
                    Text('DailyTxT-style private entry. Tap reveal to unlock for this view.', style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppTheme.petalWhite.withValues(alpha: 0.6)), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _revealed = true),
                        icon: const Icon(Icons.visibility_rounded, size: 18),
                        label: const Text('Reveal'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepRose, foregroundColor: AppColors.petalWhite, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
              )
            else
              SelectableText(
                _entry.content.isEmpty ? 'No content.' : _entry.content,
                style: AppTypography.outfitWhite.copyWith(fontSize: 15, height: 1.6, color: AppColors.textHigh),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await JournalService().toggleLock(_entry.id, !_entry.isLocked);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    icon: Icon(_entry.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 16),
                    label: Text(_entry.isLocked ? 'Unlock' : 'Lock'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.warmAmber, side: BorderSide(color: AppColors.warmAmber.withValues(alpha: 0.3))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(backgroundColor: AppTheme.velvet, title: Text('Delete entry?', style: AppTypography.outfitBold.copyWith(color: AppTheme.petalWhite)), content: Text('This cannot be undone.', style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.7))), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent)))]));
                      if (confirm == true) {
                        await JournalService().delete(_entry.id);
                        if (!mounted) return;
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
