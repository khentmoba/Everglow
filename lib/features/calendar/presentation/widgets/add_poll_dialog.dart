import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/date_poll.dart';
import '../../data/services/calendar_poll_service.dart';

class AddPollDialog extends StatefulWidget {
  const AddPollDialog({super.key});

  @override
  State<AddPollDialog> createState() => _AddPollDialogState();
}

class _AddPollDialogState extends State<AddPollDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<DateTime> _dates = [];
  bool _saving = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.deepRose,
            surface: AppColors.velvet,
            onSurface: AppColors.petalWhite,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.deepRose,
            surface: AppColors.velvet,
            onSurface: AppColors.petalWhite,
          ),
        ),
        child: child!,
      ),
    );
    final dt = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time?.hour ?? 19,
      time?.minute ?? 0,
    );
    if (_dates.any((d) => d.isAtSameMomentAs(dt))) return;
    setState(() => _dates.add(dt));
    _dates.sort();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _dates.length < 2 || _saving) return;
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    final username = auth.currentUser ?? 'unknown';
    final poll = DatePoll(
      id: '',
      title: title,
      description: _descController.text.trim(),
      createdBy: username,
      createdAt: DateTime.now(),
      options: _dates
          .map(
            (d) => DatePollOption(
              id: d.millisecondsSinceEpoch.toString(),
              date: d,
              label:
                  '${d.month}/${d.day} ${TimeOfDay.fromDateTime(d).format(context)}',
            ),
          )
          .toList(),
    );
    await CalendarPollService().create(poll);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'New Date Poll 📊',
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
              const SizedBox(height: 4),
              Text(
                'Rallly-style: propose dates, vote together',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppTheme.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                ),
                decoration: InputDecoration(
                  hintText: 'What are we scheduling? e.g., Anniversary dinner',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.4),
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
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 2,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Details (optional)',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Proposed dates',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 12,
                      color: AppTheme.petalWhite.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: AppColors.blushGold,
                    ),
                    label: Text(
                      'Add date',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_dates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.twilight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 18,
                        color: AppTheme.petalWhite.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add at least 2 dates to vote',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          color: AppTheme.petalWhite.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _dates
                      .map(
                        (d) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.moonlight.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.blushGold.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: AppColors.blushGold,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${d.month}/${d.day}/${d.year}  ${TimeOfDay.fromDateTime(d).format(context)}',
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 13,
                                  color: AppTheme.petalWhite,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(() => _dates.remove(d)),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppTheme.petalWhite.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap:
                      _saving ||
                          _titleController.text.trim().isEmpty ||
                          _dates.length < 2
                      ? null
                      : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _saving
                            ? [AppColors.moonlight, AppColors.moonlight]
                            : [AppColors.deepRose, const Color(0xFF8E1444)],
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
                              'Create Poll ✨',
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
}
