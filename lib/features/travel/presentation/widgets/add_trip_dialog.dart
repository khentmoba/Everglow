import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/trip.dart';
import '../../data/services/travel_service.dart';

class AddTripDialog extends StatefulWidget {
  final String author;
  const AddTripDialog({super.key, required this.author});

  @override
  State<AddTripDialog> createState() => _AddTripDialogState();
}

class _AddTripDialogState extends State<AddTripDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  DateTime _start = DateTime.now().add(const Duration(days: 7));
  DateTime _end = DateTime.now().add(const Duration(days: 10));
  TripStatus _status = TripStatus.planning;
  bool _saving = false;

  Future<void> _pickStart() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.deepRose,
            surface: AppColors.velvet,
          ),
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => _start = p);
  }

  Future<void> _pickEnd() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.deepRose,
            surface: AppColors.velvet,
          ),
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => _end = p);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final trip = Trip(
      id: '',
      title: title,
      description: _descCtrl.text.trim(),
      startDate: _start,
      endDate: _end,
      status: _status,
      createdBy: widget.author,
      createdAt: DateTime.now(),
      budgetEstimate: double.tryParse(_budgetCtrl.text.trim()) ?? 0,
    );
    await TravelService().addTrip(trip);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.velvet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.2)),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Trip ✈️',
                style: AppTypography.cormorantBold.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                'Surmai × AdventureLog',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppColors.petalWhite.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.petalWhite,
                ),
                decoration: InputDecoration(
                  hintText: 'Trip title — e.g., Palawan Dec 2026',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.petalWhite,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Description',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.twilight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.flight_takeoff_rounded,
                              size: 14,
                              color: AppColors.auroraTeal,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_start.month}/${_start.day}/${_start.year}',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 12,
                                color: AppColors.petalWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickEnd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.twilight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.flight_land_rounded,
                              size: 14,
                              color: AppColors.warmAmber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_end.month}/${_end.day}/${_end.year}',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 12,
                                color: AppColors.petalWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _budgetCtrl,
                keyboardType: TextInputType.number,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.petalWhite,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Budget estimate (PHP)',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.4),
                  ),
                  prefixIcon: const Icon(
                    Icons.payments_rounded,
                    size: 16,
                    color: AppColors.warmAmber,
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Status',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppColors.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: TripStatus.values.map((s) {
                  final sel = _status == s;
                  return GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.auroraTeal.withValues(alpha: 0.2)
                            : AppColors.twilight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.auroraTeal : AppColors.border,
                        ),
                      ),
                      child: Text(
                        s.name,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                          color: sel
                              ? AppColors.auroraTeal
                              : AppColors.petalWhite.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                            ? [AppColors.moonlight, AppColors.moonlight]
                            : [AppColors.auroraTeal, AppColors.deepRose],
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
                              'Create Trip 🗺️',
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
}
