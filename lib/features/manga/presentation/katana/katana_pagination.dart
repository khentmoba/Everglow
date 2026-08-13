import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import './katana_theme.dart';

/// Manga Katana style pagination: prev / page number / next.
class KatanaPagination extends StatelessWidget {
  final int page;
  final bool hasPrev;
  final bool hasNext;
  final ValueChanged<int> onPageChanged;

  const KatanaPagination({
    super.key,
    required this.page,
    required this.hasPrev,
    required this.hasNext,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _PageButton(
          label: '‹',
          tooltip: 'Previous page',
          enabled: hasPrev,
          onTap: () => onPageChanged(page - 1),
        ),
        Container(
          width: 46,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: KatanaColors.accent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '$page',
            style: AppTypography.outfitBold.copyWith(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        _PageButton(
          label: '›',
          tooltip: 'Next page',
          enabled: hasNext,
          onTap: () => onPageChanged(page + 1),
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _PageButton({
    required this.label,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 46,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? KatanaColors.surface : KatanaColors.surfaceAlt,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: enabled ? KatanaColors.border : KatanaColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.outfitBold.copyWith(
              color: enabled ? KatanaColors.text : KatanaColors.textLight,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
