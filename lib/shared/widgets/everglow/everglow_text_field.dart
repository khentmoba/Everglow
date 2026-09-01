import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_motion.dart';

/// Styled text input with label, focus ring, error text.
///
/// 44px min height. Token-driven colors. Reduced-motion-aware focus transition.
class EverglowTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final IconData? prefixIcon;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final FocusNode? focusNode;

  const EverglowTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.prefixIcon,
    this.prefixText,
    this.inputFormatters,
    this.autofocus = false,
    this.keyboardType,
    this.maxLength,
    this.maxLines,
    this.minLines,
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<EverglowTextField> createState() => _EverglowTextFieldState();
}

class _EverglowTextFieldState extends State<EverglowTextField> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(widget.label!, style: AppTypography.labelMedium()),
          ),
        AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          curve: AppMotion.easeOutStrong,
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: AppColors.velvet.withValues(alpha: 0.5),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: widget.errorText != null
                  ? AppColors.error
                  : _focused
                  ? AppColors.deepRose
                  : AppColors.border,
              width: _focused ? 1.5 : 1.0,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      blurRadius: 12,
                      color: AppColors.deepRose.withValues(alpha: 0.2),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            focusNode: _focusNode,
            controller: widget.controller,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            enabled: widget.enabled,
            style: AppTypography.bodyMedium().copyWith(fontSize: 16),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTypography.bodyMedium().copyWith(
                color: AppColors.textDisabled,
                fontSize: 16,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 20,
                      color: AppColors.textMuted,
                    )
                  : null,
              prefixText: widget.prefixText,
              prefixStyle: widget.prefixText != null
                  ? AppTypography.labelLarge().copyWith(
                      color: AppColors.warmAmber,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              counterText: '',
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              widget.errorText!,
              style: AppTypography.bodySmall().copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
