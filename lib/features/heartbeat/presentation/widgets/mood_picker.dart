import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../controllers/mood_controller.dart';
import 'heart_emoji.dart';
import '../../data/models/user_mood.dart';
import '../../data/services/mood_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../guardian/presentation/controllers/guardian_controller.dart';

class MoodPicker extends StatefulWidget {
  const MoodPicker({super.key});
  @override
  State<MoodPicker> createState() => _MoodPickerState();
}

class _MoodPickerState extends State<MoodPicker> {
  HeartNeed? _need;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MoodController>();
    final selectedScore = context.select<MoodController, int?>(
      (c) => c.selectedScore,
    );
    final authService = context.read<AuthService>();
    final partnerName = authService.partnerName;

    final moods = [
      {
        'emoji': '💜',
        'score': 1,
        'color': AppColors.softLavender,
        'label': 'heavy',
      },
      {
        'emoji': '☁️',
        'score': 2,
        'color': AppColors.mutedPurple,
        'label': 'low',
      },
      {
        'emoji': '🌸',
        'score': 3,
        'color': AppColors.roseQuartz,
        'label': 'okay',
      },
      {
        'emoji': '💖',
        'score': 4,
        'color': AppColors.auroraRose,
        'label': 'loved',
      },
      {
        'emoji': '✨',
        'score': 5,
        'color': AppColors.deepRose,
        'label': 'radiant',
      },
    ];

    return Semantics(
      label: 'How is your heart today? 5 moods, double tap to select',
      child: Container(
        width: (MediaQuery.sizeOf(context).width - 48).clamp(0, 360),
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height - 190).clamp(120, 600),
        ),
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
        child: SingleChildScrollView(
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
              StreamBuilder<UserMood?>(
                stream: context.read<MoodService>().watchLatestMood(
                  authService.currentUser ?? '',
                ),
                builder: (context, snapshot) {
                  final mood = snapshot.data;
                  if (mood == null ||
                      !mood.isCurrentAt(DateTime.now()) ||
                      mood.acknowledgedBy == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('$partnerName is here for you.'),
                  );
                },
              ),
              const Text('Anything you need? Optional, just for today.'),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (final need in HeartNeed.values)
                    ChoiceChip(
                      label: Text(need.label),
                      selected: _need == need,
                      onSelected: controller.isSaving
                          ? null
                          : (selected) =>
                                setState(() => _need = selected ? need : null),
                    ),
                ],
              ),
              if (controller.saveError != null)
                Text(
                  controller.saveError!,
                  style: const TextStyle(color: AppColors.error),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: moods.map((mood) {
                  final score = mood['score'] as int;
                  final label = mood['label'] as String;
                  return Semantics(
                    button: true,
                    selected: selectedScore == score,
                    label: '$label mood, $score of 5, ${mood['emoji']}',
                    child: Tooltip(
                      message: '$label • $score of 5',
                      child: HeartEmoji(
                        emoji: mood['emoji'] as String,
                        isSelected: selectedScore == score,
                        glowColor: mood['color'] as Color,
                        onTap: () async {
                          if (controller.isSaving) return;
                          final currentUsername = authService.currentUser ?? '';
                          await context.read<MoodController>().submitMood(
                            username: currentUsername,
                            score: score,
                            emoji: mood['emoji'] as String,
                            uid: authService.uid,
                            need: _need,
                          );
                          if (context.mounted && controller.saveError == null) {
                            context
                                .read<GuardianController>()
                                .dismissMoodPrompt();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Sending your love to $partnerName...',
                                  style: AppTypography.outfitWhite,
                                ),
                                backgroundColor: AppColors.deepRose,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                margin: const EdgeInsets.all(20),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
