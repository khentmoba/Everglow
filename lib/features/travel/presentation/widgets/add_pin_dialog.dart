import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/trip.dart';
import '../../data/services/travel_service.dart';

class AddPinDialog extends StatefulWidget {
  final String tripId;
  const AddPinDialog({super.key, required this.tripId});

  @override
  State<AddPinDialog> createState() => _AddPinDialogState();
}

class _AddPinDialogState extends State<AddPinDialog> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  PinCategory _cat = PinCategory.sight;
  bool _saving = false;

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (title.isEmpty || lat == null || lng == null || _saving) return;
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    // Determine order: count existing pins
    final existing = await TravelService().watchPins(widget.tripId).first;
    final order = existing.length;
    final pin = TripPin(
      id: '',
      tripId: widget.tripId,
      title: title,
      note: _noteCtrl.text.trim(),
      lat: lat,
      lng: lng,
      category: _cat,
      order: order,
      createdBy: auth.currentUser ?? 'unknown',
    );
    await TravelService().addPin(pin);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
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
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Pin 📍',
                style: AppTypography.cormorantBold.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                'Dawarich • pin your memories',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppTheme.petalWhite.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                ),
                decoration: InputDecoration(
                  hintText: 'Place — e.g., Kayangan Lake',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Note — why it matters',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppTheme.petalWhite,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Latitude',
                        hintStyle: AppTypography.outfitWhite.copyWith(
                          color: AppTheme.petalWhite.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: AppColors.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppTheme.petalWhite,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Longitude',
                        hintStyle: AppTypography.outfitWhite.copyWith(
                          color: AppTheme.petalWhite.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: AppColors.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Category',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppTheme.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: PinCategory.values.map((c) {
                  final sel = _cat == c;
                  return GestureDetector(
                    onTap: () => setState(() => _cat = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
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
                        '${_pinEmoji(c)} ${c.name}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: sel
                              ? AppColors.auroraTeal
                              : AppTheme.petalWhite.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
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
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Add Pin ✨',
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

  String _pinEmoji(PinCategory c) {
    switch (c) {
      case PinCategory.stay:
        return '🏨';
      case PinCategory.eat:
        return '🍽️';
      case PinCategory.sight:
        return '📍';
      case PinCategory.activity:
        return '🎭';
      case PinCategory.transit:
        return '✈️';
    }
  }
}
