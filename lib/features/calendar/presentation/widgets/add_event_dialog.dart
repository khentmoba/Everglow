import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../domain/models/calendar_event.dart';
import '../../data/services/calendar_service.dart';
import '../../../../core/theme/app_typography.dart';

class AddEventDialog extends StatefulWidget {
  final DateTime selectedDay;

  const AddEventDialog({super.key, required this.selectedDay});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final CalendarService _calendarService = CalendarService();
  CalendarEventType _selectedType = CalendarEventType.custom;
  String _recurring = 'none';
  bool _isSaving = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  bool _isAllDay = false;
  List<String> _attendees = []; // usernames

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.dark(primary: AppTheme.deepRose, surface: AppTheme.velvet, onSurface: AppTheme.petalWhite)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  DateTime get _combinedDate {
    final d = widget.selectedDay;
    if (_isAllDay) return DateTime(d.year, d.month, d.day);
    return DateTime(d.year, d.month, d.day, _selectedTime.hour, _selectedTime.minute);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final auth = context.read<AuthService>();
      final username = auth.currentUser ?? 'unknown';

      final event = CalendarEvent(
        id: '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        date: _combinedDate,
        type: _selectedType,
        createdBy: username,
        recurring: _recurring,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        attendees: _attendees,
        isAllDay: _isAllDay,
      );

      await _calendarService.addEvent(event);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: $e"),
            backgroundColor: AppTheme.deepRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Widget _buildAttendeeChip(String username, String label) {
    final isSel = _attendees.contains(username);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSel) {
          _attendees.remove(username);
        } else {
          _attendees.add(username);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: isSel ? AppTheme.deepRose.withValues(alpha: 0.25) : AppTheme.twilight, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSel ? AppTheme.blushGold : AppTheme.blushGold.withValues(alpha: 0.15))),
        child: Text(label, style: AppTypography.outfitWhite.copyWith(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? AppTheme.blushGold : AppTheme.petalWhite.withValues(alpha: 0.7))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel =
        "${widget.selectedDay.month}/${widget.selectedDay.day}/${widget.selectedDay.year}";

    return Center(
      child: Material(
        type: MaterialType.transparency,
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
                  "Add Event 📅",
                  style: AppTypography.cormorantBold.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 4),
                Text(
                  dayLabel,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 13,
                    color: AppTheme.blushGold,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Event Type ──
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: CalendarEventType.values.map((type) {
                    final info = calendarEventTypeInfo[type]!;
                    final isSelected = _selectedType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
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
                          ),
                        ),
                        child: Text(
                          "${info.$1} ${info.$2}",
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.petalWhite
                                : AppTheme.petalWhite.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ── Title ──
                TextField(
                  controller: _titleController,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: "Event title",
                    hintStyle: AppTypography.outfitWhite.copyWith(
                      color: AppTheme.petalWhite.withValues(alpha: 0.65),
                    ),
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

                // ── Description ──
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: "Description (optional)",
                    hintStyle: AppTypography.outfitWhite.copyWith(
                      color: AppTheme.petalWhite.withValues(alpha: 0.65),
                    ),
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
                // ── Time + All-day (Baïkal fix) ──
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isAllDay ? null : _pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isAllDay ? AppTheme.twilight.withValues(alpha: 0.5) : AppTheme.twilight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 16, color: _isAllDay ? AppTheme.petalWhite.withValues(alpha: 0.3) : AppTheme.blushGold),
                              const SizedBox(width: 8),
                              Text(_isAllDay ? 'All day' : _selectedTime.format(context), style: AppTypography.outfitWhite.copyWith(fontSize: 13, color: _isAllDay ? AppTheme.petalWhite.withValues(alpha: 0.4) : AppTheme.petalWhite)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _isAllDay = !_isAllDay),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: _isAllDay ? AppTheme.deepRose.withValues(alpha: 0.2) : AppTheme.twilight, borderRadius: BorderRadius.circular(12), border: Border.all(color: _isAllDay ? AppTheme.blushGold : AppTheme.blushGold.withValues(alpha: 0.15))),
                        child: Row(children: [Icon(_isAllDay ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 16, color: _isAllDay ? AppTheme.blushGold : AppTheme.petalWhite.withValues(alpha: 0.6)), const SizedBox(width: 6), Text('All-day', style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: _isAllDay ? AppTheme.blushGold : AppTheme.petalWhite.withValues(alpha: 0.7)))]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Location (Maps-inspired) ──
                TextField(
                  controller: _locationController,
                  style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite),
                  decoration: InputDecoration(
                    hintText: "Location (optional)",
                    prefixIcon: Icon(Icons.place_outlined, size: 18, color: AppTheme.petalWhite.withValues(alpha: 0.6)),
                    hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.65)),
                    filled: true,
                    fillColor: AppTheme.twilight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.blushGold.withValues(alpha: 0.2))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.blushGold)),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Attendees (couple) ──
                Row(
                  children: [
                    Text("With", style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppTheme.petalWhite.withValues(alpha: 0.75))),
                    const SizedBox(width: 10),
                    _buildAttendeeChip('khentsgdz', 'Khent'),
                    const SizedBox(width: 8),
                    _buildAttendeeChip('clairjassen', 'Clair'),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Recurring ──
                Row(
                  children: [
                    Text(
                      "Repeat",
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppTheme.petalWhite.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.twilight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.blushGold.withValues(alpha: 0.15),
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _recurring,
                          isExpanded: true,
                          dropdownColor: AppTheme.twilight,
                          underline: const SizedBox(),
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppTheme.petalWhite,
                            fontSize: 13,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'none',
                              child: Text('None'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'yearly',
                              child: Text('Yearly'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _recurring = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Buttons ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed:
                          _titleController.text.trim().isNotEmpty && !_isSaving
                          ? _save
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepRose,
                        foregroundColor: AppTheme.petalWhite,
                        disabledBackgroundColor: AppTheme.deepRose.withValues(
                          alpha: 0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.petalWhite,
                              ),
                            )
                          : Text(
                              "Save",
                              style: AppTypography.outfitWhite.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
