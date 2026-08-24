import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

/// Glass page header for feature screens — cleaner v2.
///
/// Lighter, more breathable: flatter glass, subtler border, softer shadow,
/// tighter vertical rhythm. Keeps Dusk Petal identity while removing the
/// heavy gradient + hard shadow of v1.
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
    final titleSize = width < 360 ? 18.0 : 21.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.panelGlass,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.11),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkDeep.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _BackButton(onBack: onBack),
            const SizedBox(width: 10),
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hue.withValues(alpha: 0.13),
                  border: Border.all(color: hue.withValues(alpha: 0.34)),
                ),
                child: Icon(icon, color: hue, size: 18),
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
                      letterSpacing: 0.3,
                      color: AppColors.petalWhite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.petalWhite.withValues(alpha: 0.52),
                        letterSpacing: 0.35,
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
    final canPop = context.canPop();
    return Tooltip(
      message: canPop ? 'Back' : 'Dashboard',
      child: Semantics(
        button: true,
        label: 'Back',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap:
                onBack ??
                () {
                  if (canPop) {
                    context.pop();
                  } else {
                    context.go('/dashboard');
                  }
                },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.moonlight.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.moonlight.withValues(alpha: 0.16),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.roseQuartz,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
