import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_motion.dart';
import 'everglow_button.dart';

/// Budget month stepper — replaces IconButton chevrons + ghost Today.
///
/// Unified 44px targets, pill Today active state, tap label opens month picker.
class EverglowMonthStepper extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final String Function(int) monthName;
  const EverglowMonthStepper({super.key, required this.month, required this.onChanged, required this.monthName});

  @override
  Widget build(BuildContext context) {
    final isCurrent = month.year == DateTime.now().year && month.month == DateTime.now().month;
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Previous month',
          child: _StepperButton(icon: Icons.chevron_left_rounded, onTap: () => onChanged(DateTime(month.year, month.month - 1))),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Pick month and year',
            child: GestureDetector(
              onTap: () => _pickMonth(context),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.moonlight.withValues(alpha: 0.06),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(' ', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppColors.petalWhite)),
                        const SizedBox(width: 6),
                        Icon(Icons.expand_more_rounded, size: 16, color: AppColors.petalWhite.withValues(alpha: 0.52)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Next month',
          child: _StepperButton(icon: Icons.chevron_right_rounded, onTap: () => onChanged(DateTime(month.year, month.month + 1))),
        ),
        const SizedBox(width: 8),
        EverglowButton.pill(
          label: 'Today',
          onPressed: isCurrent ? null : () => onChanged(DateTime(DateTime.now().year, DateTime.now().month)),
        ),
      ],
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    DateTime temp = month;
    final result = await showDialog<DateTime>(
      context: context,
      barrierColor: AppColors.inkDeep.withValues(alpha: 0.72),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.velvet,
        title: Text('Pick month', style: AppTypography.cormorantBold.copyWith(color: AppColors.petalWhite)),
        content: SizedBox(
          width: 300,
          child: StatefulBuilder(builder: (ctx, setS) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: () => setS(() => temp = DateTime(temp.year - 1, temp.month)), icon: const Icon(Icons.chevron_left_rounded, color: AppColors.blushGold)),
                    Text('', style: AppTypography.outfitBold.copyWith(color: AppColors.petalWhite, fontSize: 16)),
                    IconButton(onPressed: () => setS(() => temp = DateTime(temp.year + 1, temp.month)), icon: const Icon(Icons.chevron_right_rounded, color: AppColors.blushGold)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final sel = temp.month == m;
                    return GestureDetector(
                      onTap: () => setS(() => temp = DateTime(temp.year, m)),
                      child: Container(
                        width: 72,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.deepRose.withValues(alpha: 0.20) : AppColors.moonlight.withValues(alpha: 0.06),
                          borderRadius: AppRadius.radiusFull,
                          border: Border.all(color: sel ? AppColors.deepRose : AppColors.border),
                        ),
                        child: Center(child: Text(monthName(m), style: AppTypography.outfitBold.copyWith(fontSize: 12, color: sel ? AppColors.blushGold : AppColors.petalWhite.withValues(alpha: 0.72)))),
                      ),
                    );
                  }),
                ),
              ],
            );
          }),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: AppTypography.outfitBold.copyWith(color: AppColors.textMuted))),
          FilledButton(onPressed: () => Navigator.pop(ctx, temp), style: FilledButton.styleFrom(backgroundColor: AppColors.deepRose), child: Text('Go', style: AppTypography.outfitBold.copyWith(color: AppColors.petalWhite))),
        ],
      ),
    );
    if (result != null) onChanged(DateTime(result.year, result.month));
  }
}

class _StepperButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});
  @override
  State<_StepperButton> createState() => _StepperButtonState();
}
class _StepperButtonState extends State<_StepperButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); HapticFeedback.selectionClick(); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed ? AppColors.moonlight.withValues(alpha: 0.14) : AppColors.moonlight.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.16)),
          ),
          child: Icon(widget.icon, color: AppColors.blushGold, size: 20),
        ),
      ),
    );
  }
}
