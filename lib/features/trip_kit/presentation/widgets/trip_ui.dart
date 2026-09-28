import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/trip.dart';

/// Shared Trip Kit formatting + row widgets (list + detail screens).

String tripPeso(double amount) =>
    '₱${NumberFormat.decimalPattern().format(amount.round())}';

String tripDateRange(Trip trip) {
  final fmt = DateFormat.MMMd();
  if (trip.startDate == null && trip.endDate == null) return 'Dates TBD';
  if (trip.startDate != null && trip.endDate != null) {
    return '${fmt.format(trip.startDate!)} – ${fmt.format(trip.endDate!)}';
  }
  final d = trip.startDate ?? trip.endDate!;
  return fmt.format(d);
}

/// Section heading: icon + title + optional trailing (e.g. "3/8").
class TripSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final Color hue;

  const TripSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.hue,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: hue),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 13,
              letterSpacing: 1.2,
              color: AppColors.petalWhite.withValues(alpha: 0.85),
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 12,
                color: hue,
              ),
            ),
        ],
      ),
    );
  }
}

/// One checklist row: tap toggles, × deletes.
class TripCheckRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool checked;
  final Color hue;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final String toggleLabel;

  const TripCheckRow({
    super.key,
    required this.label,
    required this.checked,
    required this.hue,
    required this.onToggle,
    required this.onDelete,
    required this.toggleLabel,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.moonlight.withValues(alpha: 0.05),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: checked
                ? hue.withValues(alpha: 0.35)
                : AppColors.moonlight.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Semantics(
              button: true,
              toggled: checked,
              label: toggleLabel,
              child: GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: checked ? hue : Colors.transparent,
                      border: Border.all(
                        color: checked
                            ? hue
                            : AppColors.petalWhite.withValues(alpha: 0.35),
                        width: 1.6,
                      ),
                    ),
                    child: checked
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: AppColors.inkDeep,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 14,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AppColors.petalWhite.withValues(
                            alpha: 0.5,
                          ),
                          color: checked
                              ? AppColors.petalWhite.withValues(alpha: 0.45)
                              : AppColors.petalWhite,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              color: AppColors.petalWhite.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.petalWhite.withValues(alpha: 0.35),
              ),
              tooltip: 'Remove',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Add-new row: text field + round add button, optional second field
/// (expense amount / place note).
class TripAddRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;
  final TextEditingController? secondController;
  final String? secondHint;
  final TextInputType secondKeyboardType;
  final Color hue;

  const TripAddRow({
    super.key,
    required this.controller,
    required this.hint,
    required this.onAdd,
    required this.hue,
    this.secondController,
    this.secondHint,
    this.secondKeyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _field(controller, hint, TextInputType.text),
        ),
        if (secondController != null) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _field(
              secondController!,
              secondHint ?? '',
              secondKeyboardType,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Add $hint',
          child: GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hue.withValues(alpha: 0.16),
                border: Border.all(color: hue.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.add_rounded, size: 20, color: hue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String h,
    TextInputType keyboardType,
  ) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.06),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.12),
        ),
      ),
      child: Center(
        child: TextField(
          controller: c,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onAdd(),
          style: AppTypography.outfitWhite.copyWith(fontSize: 14),
          decoration: InputDecoration.collapsed(
            hintText: h,
            hintStyle: AppTypography.outfitWhite.copyWith(
              fontSize: 14,
              color: AppColors.petalWhite.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
