import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../guardian/presentation/controllers/guardian_controller.dart';
import '../../../heartbeat/presentation/controllers/mood_controller.dart';

class DashboardActions extends StatefulWidget {
  const DashboardActions({super.key});

  @override
  State<DashboardActions> createState() => _DashboardActionsState();
}

class _DashboardActionsState extends State<DashboardActions> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final moodController = context.watch<MoodController>();
    final guardianController = context.watch<GuardianController>();

    if (moodController.hasSubmittedToday) {
      return const SizedBox.shrink();
    }

    final isVisible = guardianController.isMoodPromptVisible;

    return Tooltip(
      message: isVisible ? 'Dismiss mood picker' : 'Open mood picker',
      child: Semantics(
        label: isVisible ? 'Dismiss mood picker' : 'Open mood picker',
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              if (isVisible) {
                context.read<GuardianController>().dismissMoodPrompt();
              } else {
                context.read<GuardianController>().triggerMoodPrompt();
              }
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: AppMotion.orZero(AppMotion.fast),
              curve: AppMotion.easeOutStrong,
              width: 54,
              height: 54,
              transform: Matrix4.identity()
                ..scaleByDouble(
                  _pressed ? 0.9 : (_hovered ? 1.08 : 1.0),
                  _pressed ? 0.9 : (_hovered ? 1.08 : 1.0),
                  _pressed ? 0.9 : (_hovered ? 1.08 : 1.0),
                  1.0,
                ),
              decoration: BoxDecoration(
                color: AppColors.moonlight.withValues(
                  alpha: _hovered ? 0.22 : 0.12,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.blushGold.withValues(
                    alpha: _hovered ? 0.85 : 0.55,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  if (_hovered)
                    BoxShadow(
                      color: AppColors.blushGold.withValues(alpha: 0.4),
                      blurRadius: 22,
                      spreadRadius: -2,
                    ),
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                isVisible
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: AppColors.roseQuartz,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
