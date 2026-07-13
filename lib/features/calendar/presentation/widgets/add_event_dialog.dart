import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../domain/models/calendar_event.dart';
import '../../data/services/calendar_service.dart';

class AddEventDialog extends StatefulWidget {
  final DateTime selectedDay;

  const AddEventDialog({super.key, required this.selectedDay});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final CalendarService _calendarService = CalendarService();
  CalendarEventType _selectedType = CalendarEventType.custom;
  String _recurring = 'none';
  bool _isSaving = false;

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
        date: widget.selectedDay,
        type: _selectedType,
        createdBy: username,
        recurring: _recurring,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel =
        "${widget.selectedDay.month}/${widget.selectedDay.day}/${widget.selectedDay.year}";

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.roseQuartz,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dayLabel,
                style: GoogleFonts.outfit(
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
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
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
                style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                decoration: InputDecoration(
                  hintText: "Event title",
                  hintStyle: GoogleFonts.outfit(
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
                style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                decoration: InputDecoration(
                  hintText: "Description (optional)",
                  hintStyle: GoogleFonts.outfit(
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

              // ── Recurring ──
              Row(
                children: [
                  Text(
                    "Repeat",
                    style: GoogleFonts.outfit(
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
                        style: GoogleFonts.outfit(
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
                      style: GoogleFonts.outfit(
                        color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _titleController.text.trim().isNotEmpty &&
                            !_isSaving
                        ? _save
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
                            style:
                                GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
