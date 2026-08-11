import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';import '../../domain/models/star_note.dart';
import 'package:everglow/core/theme/app_typography.dart';

class DropStarDialog extends StatefulWidget {
  const DropStarDialog({super.key});

  @override
  State<DropStarDialog> createState() => _DropStarDialogState();
}

class _DropStarDialogState extends State<DropStarDialog> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  bool _isSubmitEnabled = false;
  String _selectedCategory = 'gratitude';
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {
      _isSubmitEnabled = _controller.text.trim().isNotEmpty;
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 5) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_validateInput);
    _controller.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.blushGold.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepRose.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Drop a Star ✨",
                style: AppTypography.cormorantBold.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 16),

              // ── Category Chips ──
              Text(
                "Category",
                style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite.withValues(alpha: 0.75), letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: starCategories.map((cat) {
                  final info = starCategoryInfo[cat]!;
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.deepRose.withValues(alpha: 0.7)
                            : AppTheme.twilight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.blushGold
                              : AppTheme.blushGold.withValues(alpha: 0.15),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        "${info.$1} ${info.$2}",
                        style: AppTypography.outfitWhite.copyWith(fontSize: 12, fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500, color: isSelected
                              ? AppTheme.petalWhite
                              : AppTheme.petalWhite.withValues(alpha: 0.7)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // ── Text Input ──
              TextField(
                controller: _controller,
                maxLines: 3,
                style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite),
                decoration: InputDecoration(
                  hintText: "What are you grateful for today?",
                  hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.65)),
                  filled: true,
                  fillColor: AppTheme.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.blushGold.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.blushGold),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 12),

              // ── Tags ──
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 12),
                      onSubmitted: (_) => _addTag(),
                      decoration: InputDecoration(
                        hintText: "Add a tag…",
                        hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.55), fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.blushGold.withValues(alpha: 0.15),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.blushGold.withValues(alpha: 0.6),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addTag,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.deepRose.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppTheme.petalWhite,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag,
                            style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite),
                          ),
                          backgroundColor: AppTheme.softLavender.withValues(alpha: 0.3),
                          deleteIconColor: AppTheme.petalWhite.withValues(alpha: 0.75),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],

              const SizedBox(height: 24),

              // ── Buttons ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz.withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitEnabled
                        ? () => Navigator.pop(
                              context,
                              StarDropResult(
                                content: _controller.text,
                                category: _selectedCategory,
                                tags: List.unmodifiable(_tags),
                              ),
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepRose,
                      foregroundColor: AppTheme.petalWhite,
                      disabledBackgroundColor:
                          AppTheme.deepRose.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      "Drop it!",
                      style: AppTypography.outfitWhite.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Result returned from the DropStarDialog.
class StarDropResult {
  final String content;
  final String category;
  final List<String> tags;

  StarDropResult({
    required this.content,
    required this.category,
    required this.tags,
  });
}
