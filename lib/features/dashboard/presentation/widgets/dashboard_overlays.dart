import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/features/guardian/presentation/widgets/everglow_guardian.dart';
import 'package:everglow/features/guardian/presentation/controllers/guardian_controller.dart';
import 'package:everglow/features/heartbeat/presentation/widgets/partner_status_indicator.dart';
import 'package:everglow/features/heartbeat/presentation/widgets/mood_picker.dart';
import '../widgets/creator_modal.dart';
import '../widgets/dashboard_actions.dart';

/// Floating overlay buttons and indicators on top of the dashboard.
///
/// Includes: Mochi AI button, Guardian mascot, Creator mode (admin),
/// Canvas, Chat, and the mood picker prompt.
class DashboardOverlays extends StatelessWidget {
  const DashboardOverlays({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // AI Assistant & Guardian — bottom-right
        Positioned(
          bottom: 24,
          right: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Consumer<AIService>(
                builder: (context, ai, _) {
                  return Semantics(
                    label: 'Open Mochi AI assistant',
                    button: true,
                    child: GestureDetector(
                      onTap: () => context.push('/mochi'),
                      child: Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.blushGold.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.deepRose.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ExcludeSemantics(
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/mochi_avatar.png',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const EverglowGuardian(),
            ],
          ),
        ),

        // Creator Mode Button (Admin Only)
        if (context.watch<AuthService>().currentUser == 'khentsgdz')
          Positioned(
            top: 24,
            left: 24,
            child: FadeInDown(
              delay: const Duration(milliseconds: 1500),
              child: Semantics(
                label: 'Open creator tools',
                button: true,
                child: GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CreatorModal(),
                  ),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.blushGold.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.deepRose.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppTheme.roseQuartz,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Canvas + Partner status + Actions — top-right, offset left of chat
        Positioned(
          top: 24,
          right: 96,
          child: FadeInDown(
            delay: const Duration(milliseconds: 1500),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PartnerStatusIndicator(),
                const SizedBox(width: 16),
                const DashboardActions(),
                const SizedBox(width: 16),
                Semantics(
                  label: 'Open Everglow Canvas',
                  button: true,
                  child: GestureDetector(
                    onTap: () => context.push('/canvas'),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.blushGold.withValues(alpha: 0.65),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.deepRose.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.brush_rounded,
                        color: AppTheme.roseQuartz,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sanctuary Chat Button — top-right
        Positioned(
          top: 24,
          right: 24,
          child: FadeInDown(
            delay: const Duration(milliseconds: 1500),
            child: Semantics(
              label: 'Open Sanctuary chat',
              button: true,
              child: GestureDetector(
                onTap: () => context.push('/sanctuary'),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.deepRose,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.deepRose.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppTheme.petalWhite,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Mood Picker prompt
        Positioned(
          top: 100,
          right: 24,
          child: Consumer<GuardianController>(
            builder: (context, controller, child) {
              if (!controller.isMoodPromptVisible) return const SizedBox.shrink();
              return const MoodPicker();
            },
          ),
        ),
      ],
    );
  }
}
