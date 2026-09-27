import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/subscription.dart';
import '../../data/services/subs_service.dart';
import 'sub_card.dart';

/// Bottom-sheet composer for adding (or editing) a subscription.
///
/// Name, price in pesos, renewal date, cycle, who pays — nothing else.
class AddSubSheet extends StatefulWidget {
  final String createdBy;
  final Subscription? existing;

  const AddSubSheet({super.key, required this.createdBy, this.existing});

  @override
  State<AddSubSheet> createState() => _AddSubSheetState();
}

class _AddSubSheetState extends State<AddSubSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  SubCycle _cycle = SubCycle.monthly;
  SubPayer _payer = SubPayer.shared;
  DateTime? _renewalDate;
  bool _saving = false;
  bool _canSave = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _priceController.text = _trimPrice(existing.price);
      _cycle = existing.cycle;
      _payer = existing.payer;
      _renewalDate = existing.renewalDate;
    }
    _nameController.addListener(_validate);
    _priceController.addListener(_validate);
    _validate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _validate() {
    final ok =
        _nameController.text.trim().isNotEmpty &&
        _parsePrice() != null &&
        _renewalDate != null;
    if (ok != _canSave) setState(() => _canSave = ok);
  }

  double? _parsePrice() {
    final raw = _priceController.text.trim().replaceAll(',', '');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  String _trimPrice(double price) =>
      price == price.truncateToDouble() ? '${price.toInt()}' : '$price';

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = _parsePrice();
    final renewal = _renewalDate;
    if (name.isEmpty || price == null || renewal == null || _saving) return;

    setState(() => _saving = true);

    final service = SubsService();
    final existing = widget.existing;
    if (existing != null) {
      await service.update(
        existing.copyWith(
          name: name,
          price: price,
          renewalDate: renewal,
          cycle: _cycle,
          payer: _payer,
        ),
      );
    } else {
      await service.add(
        Subscription(
          id: '', // Firestore generates the id.
          name: name,
          price: price,
          renewalDate: renewal,
          cycle: _cycle,
          payer: _payer,
          createdBy: widget.createdBy,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null || _saving) return;
    setState(() => _saving = true);
    await SubsService().delete(existing.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickRenewalDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewalDate ?? today,
      firstDate: today.subtract(const Duration(days: 366)),
      lastDate: today.add(const Duration(days: 366 * 3)),
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
        () => _renewalDate = DateTime(picked.year, picked.month, picked.day),
      );
      _validate();
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
                            _editing ? 'Edit subscription 💳' : 'New subscription 💳',
                            style: AppTypography.cormorantBold.copyWith(
                              fontSize: 26,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Netflix, Spotify, iCloud — all in pesos',
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
                  controller: _nameController,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite,
                    fontSize: 15,
                  ),
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration('Name — Netflix, Spotify…'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite,
                          fontSize: 15,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                        decoration: _fieldDecoration('Price — 549').copyWith(
                          prefixText: '₱ ',
                          prefixStyle: AppTypography.outfitBold.copyWith(
                            color: AppColors.blushGold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _pickRenewalDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _renewalDate == null
                              ? AppColors.twilight
                              : AppColors.deepRose.withValues(alpha: 0.2),
                          borderRadius: AppRadius.radiusMd,
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
                              _renewalDate == null
                                  ? 'Renews…'
                                  : DateFormat.MMMd().format(_renewalDate!),
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 13,
                                color: AppColors.petalWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel(label: 'Bills every'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: SubCycle.values.map((c) {
                    final selected = _cycle == c;
                    return _ChoicePill(
                      label: c.displayName,
                      hue: AppColors.blushGold,
                      selected: selected,
                      onTap: () => setState(() => _cycle = c),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const _SectionLabel(label: 'Who pays?'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: SubPayer.values.map((p) {
                    final selected = _payer == p;
                    final hue = subPayerHue(p);
                    return _ChoicePill(
                      label: p.displayName,
                      dot: hue,
                      hue: hue,
                      selected: selected,
                      onTap: () => setState(() => _payer = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                _SaveButton(
                  editing: _editing,
                  enabled: _canSave,
                  saving: _saving,
                  onTap: _save,
                ),
                if (_editing) ...[
                  const SizedBox(height: 10),
                  _DeleteButton(saving: _saving, onTap: _delete),
                ],
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

class _ChoicePill extends StatelessWidget {
  final String label;
  final Color? dot;
  final Color hue;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.hue,
    required this.selected,
    required this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  final bool editing;
  final bool enabled;
  final bool saving;
  final VoidCallback onTap;

  const _SaveButton({
    required this.editing,
    required this.enabled,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !saving;
    return Semantics(
      button: true,
      label: editing ? 'Save changes' : 'Add subscription',
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
                    editing ? 'Save changes 💾' : 'Track it 💳',
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

class _DeleteButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onTap;
  const _DeleteButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Delete subscription',
      enabled: !saving,
      child: GestureDetector(
        onTap: saving ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              'Stop tracking',
              style: AppTypography.outfitBold.copyWith(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
