import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import 'everglow_icon_button.dart';

/// Slim custom app bar — back button + title + actions.
///
/// Replaces bare `IconButton`/`GestureDetector` headers and `AppBar`.
class EverglowAppBar extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showBack;
  final VoidCallback? onBackPressed;
  final List<Widget> actions;
  final double height;
  final Color? backgroundColor;

  const EverglowAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBack = true,
    this.onBackPressed,
    this.actions = const [],
    this.height = 56,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Back button
            if (showBack)
              EverglowIconButton.back(
                onPressed: onBackPressed ?? () => Navigator.maybePop(context),
              ),

            // Title
            if (title != null || titleWidget != null) ...[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child:
                    titleWidget ??
                    Text(
                      title!,
                      style: AppTypography.titleMedium(),
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
            ] else
              const Spacer(),

            // Actions
            ...actions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: a,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
