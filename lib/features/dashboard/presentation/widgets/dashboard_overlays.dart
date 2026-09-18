import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Geometry of the pinned top-action row (creator / canvas / mood /
/// chat). The buttons float above the scroll view, so whatever scrolls
/// under them can never be read.
///
/// The dashboard header reserves [kTopActionsReserve] at the top of the
/// scroll view: on phones the centered "EST. FEBRUARY 14, 2026" pill is
/// wider than the free space between the left and right buttons, so it
/// used to run behind the canvas and chat circles on first launch. Keep
/// the three values in step with the 54px buttons above.
const double kTopActionsInset = 24; // gap under the status bar / safe area
const double kTopActionsSize = 54; // button diameter
const double kTopActionsGap = 14; // even spacing between the circles
const double kTopActionsReserve =
    kTopActionsInset + kTopActionsSize + 20; // clear of the row's bottom edge
// Right edge of the (partner / mood / canvas) row: chat sits at right:24
// with a 54px circle, so the row starts one gap left of it. Keeps all
// four gaps at exactly 14px instead of 14/14/18.
const double kTopActionsRowRight = 24 + kTopActionsSize + kTopActionsGap;

/// Top of the mood prompt card: clear of the pinned row *and* of the
/// header pill, which starts at [kTopActionsReserve].
const double kMoodPromptTop = kTopActionsReserve + 34;

/// Floating overlay buttons and indicators on top of the dashboard.
///
/// Includes: Motchi AI button, Guardian mascot, Creator mode (admin),
/// Canvas, Chat, and the mood picker prompt.
class DashboardOverlays extends StatelessWidget {
  const DashboardOverlays({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // AI Assistant & Guardian - bottom-right (safe-area aware)
        Positioned(
          bottom: 24,
          right: 24,
          // respect notches/home-indicator via MediaQuery padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Consumer<AIService>(
                builder: (context, ai, _) {
                  return _FloatingAction(
                    tooltip: 'Open Motchi AI assistant',
                    onTap: () => context.push('/motchi'),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/motchi_avatar.webp',
                        width: 48,
                        height: 48,
                        cacheWidth: kIsWeb ? null : 144,
                        cacheHeight: kIsWeb ? null : 144,
                        filterQuality: FilterQuality.high,
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
            top: kTopActionsInset,
            left: 24,
            child: AppMotion.reduced
                ? _FloatingAction(
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
                  )
                : FadeInDown(
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
          top: kTopActionsInset,
          right: kTopActionsRowRight,
          child: AppMotion.reduced
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const PartnerStatusIndicator(),
                    const SizedBox(width: kTopActionsGap),
                    const DashboardActions(),
                    const SizedBox(width: kTopActionsGap),
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
                )
              : FadeInDown(
                  delay: const Duration(milliseconds: 1500),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const PartnerStatusIndicator(),
                      const SizedBox(width: kTopActionsGap),
                      const DashboardActions(),
                      const SizedBox(width: kTopActionsGap),
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
          top: kTopActionsInset,
          right: 24,
          child: AppMotion.reduced
              ? _FloatingAction(
                  tooltip: 'Open Sanctuary chat',
                  filled: true,
                  onTap: () => context.push('/sanctuary'),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.petalWhite,
                    size: 26,
                  ),
                )
              : FadeInDown(
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
          top: kMoodPromptTop,
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
              width: kTopActionsSize,
              height: kTopActionsSize,
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
