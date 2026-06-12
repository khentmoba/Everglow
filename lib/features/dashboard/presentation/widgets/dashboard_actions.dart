import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../../guardian/presentation/controllers/guardian_controller.dart';
import '../../../heartbeat/presentation/controllers/mood_controller.dart';

class DashboardActions extends StatelessWidget {
  const DashboardActions({super.key});

  @override
  Widget build(BuildContext context) {
    final moodController = context.watch<MoodController>();
    final guardianController = context.watch<GuardianController>();
    
    if (moodController.hasSubmittedToday) {
      return const SizedBox.shrink();
    }

    final isVisible = guardianController.isMoodPromptVisible;

    return GestureDetector(
      onTap: () {
        if (isVisible) {
          context.read<GuardianController>().dismissMoodPrompt();
        } else {
          context.read<GuardianController>().triggerMoodPrompt();
        }
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepRose.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          isVisible ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: AppTheme.roseQuartz,
          size: 28,
        ),
      ),
    );
  }
}
