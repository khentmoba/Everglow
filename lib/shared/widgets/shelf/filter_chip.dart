import 'package:flutter/material.dart';
import '../../../../core/system/tv_mode.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class FilterChip extends StatefulWidget {
  final IconData icon;

  final String label;

  final Color color;

  final bool selected;

  final VoidCallback onTap;

  const FilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.color;
    final selected = widget.selected;

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (show) => setState(() => _hovered = show),
      onFocusChange: (f) {
        if (f) TvMode.ensureFocusedVisible(context);
        setState(() => _hovered = f);
      },
      shortcuts: TvMode.activateShortcuts,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? tint.withValues(alpha: 0.2)
                  : _hovered
                  ? AppColors.petalWhite.withValues(alpha: 0.06)
                  : AppColors.petalWhite.withValues(alpha: 0.03),
              border: Border.all(
                color: selected
                    ? tint.withValues(alpha: 0.6)
                    : _hovered
                    ? tint.withValues(alpha: 0.25)
                    : AppColors.petalWhite.withValues(alpha: 0.12),
                width: selected ? 1.2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: tint.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: selected ? tint : AppColors.petalWhite.withValues(alpha: 0.54),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    color: selected
                        ? tint
                        : AppColors.petalWhite.withValues(alpha: 0.85),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}