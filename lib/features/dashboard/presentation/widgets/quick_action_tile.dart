import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_keyboard_activation.dart';

class QuickAction {
  final String label;
  final String caption;
  final IconData icon;
  final String route;
  final Color hue;

  const QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    required this.hue,
    this.caption = '',
  });
}

class QuickActionTile extends StatefulWidget {
  final QuickAction action;

  const QuickActionTile({super.key, required this.action});

  @override
  State<QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<QuickActionTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return Semantics(
      button: true,
      label: action.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: EverglowKeyboardActivation(
          onActivate: () => context.push(action.route),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              context.push(action.route);
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: AppMotion.orZero(AppMotion.fast),
              curve: AppMotion.easeOutStrong,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0)
                ..scaleByDouble(
                  _pressed ? 0.94 : 1.0,
                  _pressed ? 0.94 : 1.0,
                  _pressed ? 0.94 : 1.0,
                  1.0,
                ),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              decoration: BoxDecoration(
                color: _hovered
                    ? AppColors.velvet.withValues(alpha: 0.42)
                    : AppColors.surfaceGlass,
                borderRadius: AppRadius.radiusLg,
                border: Border.all(
                  color: _hovered
                      ? action.hue.withValues(alpha: 0.32)
                      : AppColors.moonlight.withValues(alpha: 0.08),
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: action.hue.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.inkDeep.withValues(alpha: 0.22),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: action.hue.withValues(alpha: 0.10),
                          border: Border.all(
                            color: action.hue.withValues(
                              alpha: _hovered ? 0.52 : 0.32,
                            ),
                            width: 1,
                          ),
                          boxShadow: _hovered
                              ? [
                                  BoxShadow(
                                    color: action.hue.withValues(alpha: 0.22),
                                    blurRadius: 14,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(action.icon, size: 16, color: action.hue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        action.label,
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: 11,
                          color: _hovered
                              ? AppColors.petalWhite
                              : AppColors.petalWhite.withValues(alpha: 0.92),
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (action.caption.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          action.caption.toUpperCase(),
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 9,
                            letterSpacing: 0.9,
                            color: (_hovered
                                ? action.hue
                                : AppColors.textMuted),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
