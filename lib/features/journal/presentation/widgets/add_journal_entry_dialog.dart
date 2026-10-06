import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/draft_text_controller.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../xp/data/services/xp_service.dart';
import '../../data/models/journal_entry.dart';
import '../../data/services/journal_service.dart';
import '../widgets/journal_ui.dart';

class AddJournalEntryDialog extends StatefulWidget {
  final String author;
  final JournalEntry? existing;
  final JournalService? service;

  const AddJournalEntryDialog({
    super.key,
    required this.author,
    this.existing,
    this.service,
  });

  @override
  State<AddJournalEntryDialog> createState() => _AddJournalEntryDialogState();
}

class _AddJournalEntryDialogState extends State<AddJournalEntryDialog> {
  late DraftTextController _titleController;
  late DraftTextController _contentController;
  late final TextEditingController _tagController = TextEditingController();
  late JournalCategory _category;
  late DateTime _memoryDate;
  JournalMood? _mood;
  bool _isPinned = false;
  bool _isLocked = false;
  List<String> _tags = [];
  bool _saving = false;
  String? _saveError;
  final _saveErrorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _titleController = DraftTextController(
      'journal:new:title',
      text: widget.existing?.title ?? '',
    );
    _contentController = DraftTextController(
      'journal:new:content',
      text: widget.existing?.content ?? '',
    );
    if (widget.existing == null) {
      // New page: bring back half-written words after a killed tab/PWA.
      // Edits always start from the saved entry — never from a draft.
      _titleController.loadDraft();
      _contentController.loadDraft();
    }
    _category = widget.existing?.category ?? JournalCategory.daily;
    _memoryDate = widget.existing?.createdAt ?? DateTime.now();
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

  static int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  Future<void> _pickMemoryDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final memoryDay = DateUtils.dateOnly(_memoryDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: memoryDay.isAfter(today) ? today : memoryDay,
      firstDate: DateTime(1900),
      lastDate: today,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.deepRose,
            surface: AppColors.velvet,
            onSurface: AppColors.petalWhite,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _memoryDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _memoryDate.hour,
        _memoryDate.minute,
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (_saving || (title.isEmpty && content.isEmpty)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final now = DateTime.now();
    final wordCount = _countWords(content);

    try {
      if (widget.existing != null) {
        final updated = widget.existing!.copyWith(
          title: title.isEmpty ? 'Untitled' : title,
          content: content,
          createdAt: _memoryDate,
          category: _category,
          mood: _mood,
          clearMood: _mood == null,
          tags: _tags,
          isPinned: _isPinned,
          isLocked: _isLocked,
          updatedAt: now,
          wordCount: wordCount,
        );
        await (widget.service ?? JournalService()).update(updated);
      } else {
        final entry = JournalEntry(
          id: '',
          title: title.isEmpty ? 'Untitled' : title,
          content: content,
          author: widget.author,
          createdAt: _memoryDate,
          updatedAt: now,
          category: _category,
          mood: _mood,
          tags: _tags,
          isPinned: _isPinned,
          isLocked: _isLocked,
          wordCount: wordCount,
        );
        await (widget.service ?? JournalService()).add(entry);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          try {
            await XPService().awardJournal(uid);
          } catch (e) {
            Logger.e('Journal: XP award failed', error: e);
          }
        }
      }
      if (widget.existing == null) {
        // Words are saved now — forget the draft so it never comes back
        // stale. (Edit-saves leave new-entry drafts alone.)
        await _titleController.clearDraft();
        await _contentController.clearDraft();
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Logger.e('Journal save failed; keeping draft', error: e);
      if (mounted) {
        setState(
          () => _saveError =
              'Could not save your page. Your words are still here — please try again.',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final errorContext = _saveErrorKey.currentContext;
          if (mounted && errorContext != null) {
            Scrollable.ensureVisible(errorContext, alignment: 0.5);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600;
    final sectionGap = compact ? AppSpacing.sm : AppSpacing.md;
    return Dialog(
      backgroundColor: AppColors.velvet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.2)),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.lg,
        vertical: compact ? AppSpacing.sm : AppSpacing.lg,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: (size.height * 0.92).clamp(0.0, 820.0).toDouble(),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.xl,
          vertical: compact ? AppSpacing.lg : AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existing == null
                              ? 'A new page'
                              : 'Edit this page',
                          style: AppTypography.handwrittenTitle().copyWith(
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          'for us, by ${journalAuthorName(widget.author)}',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11,
                            color: AppColors.petalWhite.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  EverglowIconButton.close(
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: sectionGap),
              InkWell(
                onTap: _saving ? null : _pickMemoryDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.twilight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: AppColors.blushGold,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Memory date',
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 11,
                                color: AppColors.petalWhite.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatFullDate(_memoryDate),
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 14,
                                color: AppColors.petalWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.edit_calendar_rounded,
                        size: 18,
                        color: AppColors.petalWhite.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: sectionGap),
              // Category
              Text(
                'Category',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppColors.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: JournalCategory.values.map((c) {
                  final sel = _category == c;
                  final hue = journalCategoryColor(c);
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? hue.withValues(alpha: 0.22)
                            : AppColors.twilight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? hue : hue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${c.emoji} ${c.displayName}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                          color: sel
                              ? hue
                              : AppColors.petalWhite.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: sectionGap),
              // Title
              TextField(
                controller: _titleController,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.petalWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Title (e.g., Our first roadtrip)',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.35),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
              SizedBox(height: sectionGap),
              // Content
              TextField(
                controller: _contentController,
                maxLines: compact ? 6 : 8,
                minLines: compact ? 4 : 5,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.petalWhite,
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Write your heart out... ✨\n\nA date, a fight, a laugh — keep it forever.',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.35),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(
                    compact ? AppSpacing.md : AppSpacing.lg,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Live word count — a little encouragement as they write.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _contentController,
                builder: (context, value, _) {
                  final words = _countWords(value.text);
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      words == 0
                          ? 'Every love story deserves ink ✨'
                          : '$words ${words == 1 ? 'word' : 'words'} • ${journalReadingTime(words)}',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        color: AppColors.blushGold.withValues(alpha: 0.8),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              // Mood row (heartbeat link)
              Text(
                'Mood (optional)',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppColors.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _buildMoodChip(null, 'None'),
                  ...JournalMood.values.map(
                    (m) => _buildMoodChip(m, '${m.emoji} ${m.name}'),
                  ),
                ],
              ),
              SizedBox(height: sectionGap),
              // Tags
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      onSubmitted: (_) => _addTag(),
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppColors.petalWhite,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add tag (press enter)',
                        hintStyle: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: AppColors.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
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
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
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
                            color: AppColors.petalWhite.withValues(alpha: 0.7),
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
              SizedBox(height: sectionGap),
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
                                  : AppColors.petalWhite.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isPinned ? 'Pinned' : 'Pin',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 12,
                                color: _isPinned
                                    ? AppColors.blushGold
                                    : AppColors.petalWhite.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
                                  : AppColors.petalWhite.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isLocked ? 'Locked' : 'Lock',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 12,
                                color: _isLocked
                                    ? AppColors.warmAmber
                                    : AppColors.petalWhite.withValues(
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
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
              if (_saveError != null) ...[
                Text(
                  _saveError!,
                  key: _saveErrorKey,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _saving
                            ? [AppColors.moonlight, AppColors.moonlight]
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
                                color: AppColors.petalWhite,
                              ),
                            )
                          : Text(
                              widget.existing == null
                                  ? 'Save Entry ✨'
                                  : 'Update Entry',
                              style: AppTypography.outfitBold.copyWith(
                                color: AppColors.petalWhite,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
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
                : AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
