import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

/// Glass page header for feature screens: back control, title, subtitle
/// and trailing actions, all in one consistent shell.
class EverglowFeatureHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color hue;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const EverglowFeatureHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.hue = AppColors.blushGold,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 360 ? 19.0 : 22.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.moonlight.withValues(alpha: 0.10),
              AppColors.inkDeep.withValues(alpha: 0.45),
            ],
          ),
          borderRadius: AppRadius.radiusXl,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkDeep.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _BackButton(onBack: onBack),
            const SizedBox(width: 8),
            if (icon != null) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      hue.withValues(alpha: 0.26),
                      hue.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: hue.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, color: hue, size: 19),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.cormorantBold.copyWith(
                      fontSize: titleSize,
                      height: 1.0,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.petalWhite.withValues(alpha: 0.55),
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            ...actions.map(
              (a) => Padding(padding: const EdgeInsets.only(left: 6), child: a),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback? onBack;

  const _BackButton({this.onBack});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back to dashboard',
      child: Semantics(
        button: true,
        label: 'Back',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap:
                onBack ??
                () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/dashboard');
                  }
                },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.moonlight.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppColors.moonlight.withValues(alpha: 0.22),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.roseQuartz,
                size: 17,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
