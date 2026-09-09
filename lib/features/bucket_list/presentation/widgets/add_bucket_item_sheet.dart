import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';
import '../widgets/bucket_ui.dart';

/// Bottom-sheet composer for planting a new dream.
///
/// Warm prompts, big category tiles, and one-tap meta — built for Clair's
/// thumbs on phone and tablet.
class AddBucketItemSheet extends StatefulWidget {
  final String createdBy;

  const AddBucketItemSheet({super.key, required this.createdBy});

  @override
  State<AddBucketItemSheet> createState() => _AddBucketItemSheetState();
}

class _AddBucketItemSheetState extends State<AddBucketItemSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  BucketCategory _category = BucketCategory.experience;
  BucketPriority _priority = BucketPriority.medium;
  String? _assignedTo; // null = unassigned, else username
  DateTime? _dueDate;
  bool _saving = false;
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(
      () => setState(() => _canSave = _titleController.text.trim().isNotEmpty),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() => _saving = true);

    final item = BucketItem(
      id: '', // Firestore generates the id.
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
            primary: AppColors.deepRose,
            surface: AppColors.velvet,
            onSurface: AppColors.petalWhite,
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
          decoration: BoxDecoration(
            color: AppColors.velvet,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.x3),
            ),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.2),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.petalWhite.withValues(alpha: 0.3),
                      borderRadius: AppRadius.radiusFull,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plant a new dream ✨',
                            style: AppTypography.cormorantBold.copyWith(
                              fontSize: 26,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Something for just the two of you',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              color: AppColors.petalWhite.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CloseButton(onTap: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _titleController,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite,
                    fontSize: 15,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDecoration(
                    'Japan together, a Persian cat, slow Sundays…',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descController,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDecoration(
                    'Little details, places, secret plans… (optional)',
                  ),
                ),
                const SizedBox(height: 18),
                const _SectionLabel(label: 'What kind of dream?'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.55,
                  children: BucketCategory.values
                      .map(
                        (cat) => _CategoryTile(
                          category: cat,
                          selected: _category == cat,
                          onTap: () => setState(() => _category = cat),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                const _SectionLabel(label: 'What pace?'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BucketPriority.values.map((p) {
                    final selected = _priority == p;
                    final hue = bucketPriorityHue(p);
                    return _ChoicePill(
                      label: p.displayName,
                      dot: hue,
                      hue: hue,
                      selected: selected,
                      onTap: () => setState(() => _priority = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const _SectionLabel(label: 'Whose dream is it?'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _assigneePill(null),
                    _assigneePill(bucketAssigneeKhent),
                    _assigneePill(bucketAssigneeClair),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: _SectionLabel(label: 'Dream date')),
                    GestureDetector(
                      onTap: _pickDueDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _dueDate == null
                              ? AppColors.twilight
                              : AppColors.deepRose.withValues(alpha: 0.2),
                          borderRadius: AppRadius.radiusLg,
                          border: Border.all(
                            color: AppColors.blushGold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: AppColors.blushGold,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _dueDate == null
                                  ? 'Someday'
                                  : DateFormat.yMMMd().format(_dueDate!),
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 12,
                                color: AppColors.petalWhite,
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
                        child: Semantics(
                          button: true,
                          label: 'Clear dream date',
                          child: Icon(
                            Icons.cancel_rounded,
                            size: 20,
                            color: AppColors.petalWhite.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                _SaveButton(enabled: _canSave, saving: _saving, onTap: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.outfitWhite.copyWith(
        color: AppColors.petalWhite.withValues(alpha: 0.35),
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppColors.twilight,
      border: OutlineInputBorder(
        borderRadius: AppRadius.radiusMd,
        borderSide: BorderSide(
          color: AppColors.blushGold.withValues(alpha: 0.15),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMd,
        borderSide: BorderSide(
          color: AppColors.blushGold.withValues(alpha: 0.15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMd,
        borderSide: const BorderSide(color: AppColors.blushGold),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _assigneePill(String? username) {
    final selected = _assignedTo == username;
    final hue = bucketAssigneeHue(username);
    return _ChoicePill(
      label: username == null ? 'Both of us' : bucketAssigneeLabel(username),
      icon: bucketAssigneeIcon(username),
      hue: hue,
      selected: selected,
      onTap: () => setState(() => _assignedTo = username),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.outfitBold.copyWith(
        fontSize: 10,
        letterSpacing: 1.4,
        color: AppColors.petalWhite.withValues(alpha: 0.5),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final BucketCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hue = bucketCategoryHue(category);
    return Semantics(
      button: true,
      label: '${category.displayName} category',
      toggled: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [hue.withValues(alpha: 0.28), hue.withValues(alpha: 0.08)]
                  : [
                      AppColors.moonlight.withValues(alpha: 0.05),
                      AppColors.moonlight.withValues(alpha: 0.02),
                    ],
            ),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: selected
                  ? hue.withValues(alpha: 0.7)
                  : AppColors.moonlight.withValues(alpha: 0.10),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: hue.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                category.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 10.5,
                  color: selected
                      ? hue
                      : AppColors.petalWhite.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? dot;
  final Color hue;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.hue,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dot,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      toggled: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? hue.withValues(alpha: 0.16)
                : AppColors.moonlight.withValues(alpha: 0.05),
            borderRadius: AppRadius.radiusFull,
            border: Border.all(
              color: selected
                  ? hue.withValues(alpha: 0.6)
                  : AppColors.moonlight.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
                ),
                const SizedBox(width: 7),
              ],
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected
                      ? hue
                      : AppColors.petalWhite.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: selected
                      ? hue
                      : AppColors.petalWhite.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.moonlight.withValues(alpha: 0.07),
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final VoidCallback onTap;

  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !saving;
    return Semantics(
      button: true,
      label: 'Add to our story',
      enabled: active,
      child: GestureDetector(
        onTap: active ? onTap : null,
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [AppColors.deepRose, AppColors.rosePressed],
                  )
                : null,
            color: active ? null : AppColors.moonlight.withValues(alpha: 0.06),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: active
                  ? AppColors.blushGold.withValues(alpha: 0.35)
                  : AppColors.moonlight.withValues(alpha: 0.10),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.glowRose,
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.petalWhite,
                    ),
                  )
                : Text(
                    enabled ? 'Add to our story 🌟' : 'Name your dream first ✨',
                    style: AppTypography.outfitBold.copyWith(
                      color: enabled
                          ? AppColors.petalWhite
                          : AppColors.petalWhite.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
