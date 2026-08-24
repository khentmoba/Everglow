import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_motion.dart';

/// Unified search field for all feature screens.
///
/// Glass, 44px min height, token-driven, with clear action and focus ring.
/// Replaces duplicated TextField(InputDecoration) blocks across journal,
/// cookbook, vault, travel, etc.
class EverglowSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const EverglowSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onClear,
  });

  @override
  State<EverglowSearchField> createState() => _EverglowSearchFieldState();
}

class _EverglowSearchFieldState extends State<EverglowSearchField> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: AppMotion.orZero(AppMotion.fast),
      curve: AppMotion.easeOutStrong,
      decoration: BoxDecoration(
        color: AppColors.velvet.withValues(alpha: 0.38),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: _focused ? AppColors.blushGold.withValues(alpha: 0.42) : AppColors.moonlight.withValues(alpha: 0.10),
          width: _focused ? 1.3 : 1,
        ),
        boxShadow: _focused
            ? [BoxShadow(blurRadius: 14, color: AppColors.blushGold.withValues(alpha: 0.10))]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        style: AppTypography.outfitWhite.copyWith(
          fontSize: 14,
          color: AppColors.petalWhite,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppTypography.outfitWhite.copyWith(
            fontSize: 13.5,
            color: AppColors.petalWhite.withValues(alpha: 0.38),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: _focused
                ? AppColors.blushGold.withValues(alpha: 0.85)
                : AppColors.petalWhite.withValues(alpha: 0.42),
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.petalWhite.withValues(alpha: 0.52),
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                    widget.onClear?.call();
                  },
                  tooltip: 'Clear',
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

