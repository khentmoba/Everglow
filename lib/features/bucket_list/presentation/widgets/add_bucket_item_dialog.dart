import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// Dialog for adding a new bucket list item.
class AddBucketItemDialog extends StatefulWidget {
  final String createdBy;

  const AddBucketItemDialog({super.key, required this.createdBy});

  @override
  State<AddBucketItemDialog> createState() => _AddBucketItemDialogState();
}

class _AddBucketItemDialogState extends State<AddBucketItemDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  BucketCategory _category = BucketCategory.experience;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);

    final item = BucketItem(
      id: '', // Firestore will generate
      title: title,
      description: _descController.text.trim(),
      category: _category,
      status: BucketStatus.wish,
      createdBy: widget.createdBy,
      createdAt: DateTime.now(),
    );

    await BucketListService().add(item);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.velvet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.blushGold.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a Dream',
                style: AppTypography.cormorantBold.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 16),

              // Title
              TextField(
                controller: _titleController,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                ),
                decoration: InputDecoration(
                  hintText: 'What do you want to do together?',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppTheme.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),

              // Description
              TextField(
                controller: _descController,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                ),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Details (optional)',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppTheme.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category picker
              Text(
                'Category',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: AppTheme.petalWhite.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BucketCategory.values.map((cat) {
                  final isSelected = _category == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: Semantics(
                      button: true,
                      label: '${cat.displayName} category',
                      toggled: isSelected,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.deepRose.withValues(alpha: 0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.blushGold
                                : AppTheme.blushGold.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cat.emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.displayName,
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.blushGold
                                    : AppTheme.petalWhite.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Save button
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
                            : [AppTheme.deepRose, const Color(0xFF8E1444)],
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
                                color: AppTheme.petalWhite,
                              ),
                            )
                          : Text(
                              'Add to Bucket List 🌟',
                              style: AppTypography.outfitBold.copyWith(
                                color: AppTheme.petalWhite,
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
}
