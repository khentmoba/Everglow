import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';
import '../../../../core/theme/app_typography.dart';

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
  BucketPriority _priority = BucketPriority.medium;
  String? _assignedTo; // null = unassigned, else username
  DateTime? _dueDate;
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
      priority: _priority,
      assignedTo: _assignedTo,
      dueDate: _dueDate,
    );

    await BucketListService().add(item);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.deepRose,
            surface: AppTheme.velvet,
            onSurface: AppTheme.petalWhite,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(
        () => _dueDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Widget _buildAssignChip(String? value, String label, IconData icon) {
    final isSelected = _assignedTo == value;
    return GestureDetector(
      onTap: () => setState(() => _assignedTo = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.deepRose.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.blushGold
                : AppTheme.blushGold.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AppTheme.blushGold
                  : AppTheme.petalWhite.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppTheme.blushGold
                    : AppTheme.petalWhite.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
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
              const SizedBox(height: 16),
              // Priority picker (Vikunja)
              Text(
                'Priority',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: AppTheme.petalWhite.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BucketPriority.values.map((p) {
                  final isSelected = _priority == p;
                  return GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.deepRose.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.blushGold
                              : AppTheme.blushGold.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        '${p.emoji} ${p.displayName}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.blushGold
                              : AppTheme.petalWhite.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Assignee picker (Donetick-style chores)
              Text(
                'Assigned to',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: AppTheme.petalWhite.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildAssignChip(null, 'Unassigned', Icons.person_outline),
                  _buildAssignChip('khentsgdz', 'Khent', Icons.person_rounded),
                  _buildAssignChip(
                    'clairjassen',
                    'Clair',
                    Icons.favorite_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Due date (Grocy/Vikunja)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Due date',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppTheme.petalWhite.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickDueDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _dueDate == null
                            ? AppTheme.twilight
                            : AppTheme.deepRose.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.blushGold.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: AppTheme.blushGold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _dueDate == null
                                ? 'No date'
                                : '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              color: AppTheme.petalWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_dueDate != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _dueDate = null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.petalWhite.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
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
