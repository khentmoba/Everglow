import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Hairline divider — token-driven.
///
/// Two variants:
/// - Default: `AppColors.divider` (moonlight @ 0.18)
/// - Accent: `AppColors.blushGold` @ 0.15 (for flanking section headers)
class EverglowDivider extends StatelessWidget {
  final bool accent;
  final double thickness;
  final double indent;
  final double endIndent;

  const EverglowDivider({
    super.key,
    this.accent = false,
    this.thickness = 1.0,
    this.indent = 0,
    this.endIndent = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: accent
          ? AppColors.blushGold.withValues(alpha: 0.15)
          : AppColors.divider,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      height: thickness,
    );
  }
}
