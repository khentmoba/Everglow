import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/services/auth_service.dart';
import '../../../ai/data/services/ai_service.dart';
import '../../../guardian/presentation/widgets/everglow_guardian.dart';
import '../../../guardian/presentation/controllers/guardian_controller.dart';
import '../../../heartbeat/presentation/widgets/partner_status_indicator.dart';
import '../../../heartbeat/presentation/widgets/mood_picker.dart';
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
        // AI Assistant & Guardian - bottom-right
        Positioned(
          bottom: 24,
          right: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Consumer<AIService>(
                builder: (context, ai, _) {
                  return _FloatingAction(
                    tooltip: 'Open Mochi AI assistant',
                    onTap: () => context.push('/mochi'),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/mochi_avatar.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
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
              child: _FloatingAction(
                tooltip: 'Open creator tools',
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CreatorModal(),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.roseQuartz,
                  size: 26,
                ),
              ),
            ),
          ),

        // Canvas + Partner status + Actions - top-right
        Positioned(
          top: 24,
          right: 96,
          child: FadeInDown(
            delay: const Duration(milliseconds: 1500),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PartnerStatusIndicator(),
                const SizedBox(width: 14),
                const DashboardActions(),
                const SizedBox(width: 14),
                _FloatingAction(
                  tooltip: 'Open Everglow Canvas',
                  onTap: () => context.push('/canvas'),
                  child: const Icon(
                    Icons.brush_rounded,
                    color: AppColors.roseQuartz,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sanctuary Chat Button - top-right
        Positioned(
          top: 24,
          right: 24,
          child: FadeInDown(
            delay: const Duration(milliseconds: 1500),
            child: _FloatingAction(
              tooltip: 'Open Sanctuary chat',
              filled: true,
              onTap: () => context.push('/sanctuary'),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.petalWhite,
                size: 26,
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
              if (!controller.isMoodPromptVisible) {
                return const SizedBox.shrink();
              }
              return const MoodPicker();
            },
          ),
        ),
      ],
    );
  }
}

/// Shared glass circle action with hover glow, tooltip and press feedback.
class _FloatingAction extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;

  const _FloatingAction({
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
  });

  @override
  State<_FloatingAction> createState() => _FloatingActionState();
}

class _FloatingActionState extends State<_FloatingAction> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: AppMotion.orZero(AppMotion.fast),
              curve: AppMotion.easeOutStrong,
              width: 54,
              height: 54,
              margin: const EdgeInsets.only(bottom: 12),
              transform: Matrix4.identity()
                ..scaleByDouble(
                  _pressed ? 0.9 : (_hovered ? 1.08 : 1.0),
                  _pressed ? 0.9 : (_hovered ? 1.08 : 1.0),
                  _pressed ? 0.9 : (_hovered ? 1.08 : 1.0),
                  1.0,
                ),
              decoration: BoxDecoration(
                color: widget.filled
                    ? AppColors.deepRose
                    : AppColors.moonlight.withValues(
                        alpha: _hovered ? 0.22 : 0.12,
                      ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.filled
                      ? AppColors.auroraRose.withValues(alpha: 0.7)
                      : AppColors.blushGold.withValues(
                          alpha: _hovered ? 0.85 : 0.55,
                        ),
                  width: 1.5,
                ),
                boxShadow: [
                  if (_hovered)
                    BoxShadow(
                      color:
                          (widget.filled
                                  ? AppColors.auroraRose
                                  : AppColors.blushGold)
                              .withValues(alpha: 0.4),
                      blurRadius: 22,
                      spreadRadius: -2,
                    ),
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
