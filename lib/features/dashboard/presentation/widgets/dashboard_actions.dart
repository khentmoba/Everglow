import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          color: Colors.pink[50],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.pink.shade100, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isVisible ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: Colors.pink[300],
          size: 28,
        ),
      ),
    );
  }
}
