import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/journal_entry.dart';
import '../../data/services/journal_service.dart';

class AddJournalEntryDialog extends StatefulWidget {
  final String author;
  final JournalEntry? existing;

  const AddJournalEntryDialog({super.key, required this.author, this.existing});

  @override
  State<AddJournalEntryDialog> createState() => _AddJournalEntryDialogState();
}

class _AddJournalEntryDialogState extends State<AddJournalEntryDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late final TextEditingController _tagController = TextEditingController();
  late JournalCategory _category;
  JournalMood? _mood;
  bool _isPinned = false;
  bool _isLocked = false;
  List<String> _tags = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existing?.content ?? '',
    );
    _category = widget.existing?.category ?? JournalCategory.daily;
    _mood = widget.existing?.mood;
    _isPinned = widget.existing?.isPinned ?? false;
    _isLocked = widget.existing?.isLocked ?? false;
    _tags = List<String>.from(widget.existing?.tags ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final t = _tagController.text.trim().toLowerCase().replaceAll('#', '');
    if (t.isEmpty || _tags.contains(t) || _tags.length >= 5) return;
    setState(() {
      _tags.add(t);
      _tagController.clear();
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final wordCount = content.trim().isEmpty
        ? 0
        : content
              .trim()
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .length;

    if (widget.existing != null) {
      final updated = widget.existing!.copyWith(
        title: title.isEmpty ? 'Untitled' : title,
        content: content,
        category: _category,
        mood: _mood,
        clearMood: _mood == null,
        tags: _tags,
        isPinned: _isPinned,
        isLocked: _isLocked,
        updatedAt: now,
        wordCount: wordCount,
      );
      await JournalService().update(updated);
    } else {
      final entry = JournalEntry(
        id: '',
        title: title.isEmpty ? 'Untitled' : title,
        content: content,
        author: widget.author,
        createdAt: now,
        updatedAt: now,
        category: _category,
        mood: _mood,
        tags: _tags,
        isPinned: _isPinned,
        isLocked: _isLocked,
        wordCount: wordCount,
      );
      await JournalService().add(entry);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.velvet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.2)),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.existing == null ? 'New Entry 📔' : 'Edit Entry',
                    style: AppTypography.cormorantBold.copyWith(fontSize: 22),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppTheme.petalWhite.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Category
              Text(
                'Category',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppTheme.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: JournalCategory.values.map((c) {
                  final sel = _category == c;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.deepRose.withValues(alpha: 0.3)
                            : AppColors.twilight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.blushGold : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '${c.emoji} ${c.displayName}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                          color: sel
                              ? AppColors.blushGold
                              : AppTheme.petalWhite.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // Title
              TextField(
                controller: _titleController,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Title (e.g., Our first roadtrip)',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.35),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Content
              TextField(
                controller: _contentController,
                maxLines: 8,
                minLines: 5,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Write your heart out... markdown supported ✨\n\nMemos-style quick capture, DailyTxT-style private diary.',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.35),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 14),
              // Mood row (heartbeat link)
              Text(
                'Mood (optional)',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppTheme.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildMoodChip(null, 'None'),
                  ...JournalMood.values.map(
                    (m) => _buildMoodChip(m, '${m.emoji} ${m.name}'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Tags
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      onSubmitted: (_) => _addTag(),
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppTheme.petalWhite,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add tag (press enter)',
                        hintStyle: AppTypography.outfitWhite.copyWith(
                          color: AppTheme.petalWhite.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: AppColors.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _addTag,
                          icon: const Icon(
                            Icons.add_rounded,
                            color: AppColors.blushGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _tags
                      .map(
                        (t) => Chip(
                          label: Text(
                            '#$t',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: AppColors.softLavender.withValues(
                            alpha: 0.15,
                          ),
                          deleteIcon: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppTheme.petalWhite.withValues(alpha: 0.7),
                          ),
                          onDeleted: () => setState(() => _tags.remove(t)),
                          side: BorderSide(
                            color: AppColors.softLavender.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              // Toggles lock/pin
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isPinned = !_isPinned),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isPinned
                              ? AppColors.blushGold.withValues(alpha: 0.15)
                              : AppColors.twilight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isPinned
                                ? AppColors.blushGold
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isPinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              size: 16,
                              color: _isPinned
                                  ? AppColors.blushGold
                                  : AppTheme.petalWhite.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isPinned ? 'Pinned' : 'Pin',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 12,
                                color: _isPinned
                                    ? AppColors.blushGold
                                    : AppTheme.petalWhite.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLocked = !_isLocked),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isLocked
                              ? AppColors.warmAmber.withValues(alpha: 0.15)
                              : AppColors.twilight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isLocked
                                ? AppColors.warmAmber
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 16,
                              color: _isLocked
                                  ? AppColors.warmAmber
                                  : AppTheme.petalWhite.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isLocked ? 'Locked' : 'Lock',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 12,
                                color: _isLocked
                                    ? AppColors.warmAmber
                                    : AppTheme.petalWhite.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _saving
                            ? [AppTheme.moonlight, AppTheme.moonlight]
                            : [AppColors.deepRose, AppColors.rosePressed],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.existing == null
                                  ? 'Save Entry ✨'
                                  : 'Update Entry',
                              style: AppTypography.outfitBold.copyWith(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodChip(JournalMood? mood, String label) {
    final isSel = _mood == mood;
    return GestureDetector(
      onTap: () => setState(() => _mood = mood),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel
              ? AppColors.deepRose.withValues(alpha: 0.25)
              : AppColors.twilight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? AppColors.blushGold : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel
                ? AppColors.blushGold
                : AppTheme.petalWhite.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
