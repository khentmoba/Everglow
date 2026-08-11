import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import '../controllers/mood_controller.dart';
import 'heart_emoji.dart';
import '../../../../services/auth_service.dart';
import '../../../guardian/presentation/controllers/guardian_controller.dart';

class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MoodController>();
    final authService = context.read<AuthService>();
    final partnerName = authService.partnerName;

    final moods = [
      {'emoji': '💜', 'score': 1, 'color': Colors.purple[200]!},
      {'emoji': '☁️', 'score': 2, 'color': Colors.blueGrey[100]!},
      {'emoji': '🌸', 'score': 3, 'color': Colors.pink[100]!},
      {'emoji': '💖', 'score': 4, 'color': Colors.pink[300]!},
      {'emoji': '✨', 'score': 5, 'color': Colors.pinkAccent},
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // Prevent taps from passing through
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.velvet.withValues(alpha: 0.95),
              AppColors.inkDeep.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: AppRadius.radiusX3,
          border: Border.all(
            color: AppColors.auroraGold.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRose.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: AppColors.auroraGold.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: -6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'How is your heart today?',
                style: AppTypography.cormorantBold.copyWith(
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: moods.map((mood) {
                final score = mood['score'] as int;
                return HeartEmoji(
                  emoji: mood['emoji'] as String,
                  isSelected: controller.selectedScore == score,
                  glowColor: mood['color'] as Color,
                  onTap: () async {
                    final currentUsername = authService.currentUser ?? '';
                    await controller.submitMood(
                      username: currentUsername,
                      score: score,
                      emoji: mood['emoji'] as String,
                    );
                    if (context.mounted) {
                      context.read<GuardianController>().dismissMoodPrompt();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sending your love to $partnerName...',
                            style: AppTypography.outfitWhite,
                          ),
                          backgroundColor: AppTheme.deepRose,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          margin: const EdgeInsets.all(20),
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
