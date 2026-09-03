import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:provider/provider.dart';
import 'character/cat_visuals.dart';
import 'thought_bubble.dart';
import '../controllers/guardian_controller.dart';

class _BubbleView {
  const _BubbleView(this.visible, this.id, this.content);
  final bool visible;
  final String id;
  final String content;

  @override
  bool operator ==(Object other) =>
      other is _BubbleView &&
      visible == other.visible &&
      id == other.id &&
      content == other.content;

  @override
  int get hashCode => Object.hash(visible, id, content);
}

class EverglowGuardian extends StatefulWidget {
  const EverglowGuardian({super.key});

  @override
  State<EverglowGuardian> createState() => _EverglowGuardianState();
}

class _EverglowGuardianState extends State<EverglowGuardian>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _idleController;
  late AnimationController _reactionController;
  late Animation<double> _floatingAnimation;
  late Animation<double> _bounceAnimation;

  final List<Particle> _particles = [];
  final TextEditingController _chatController = TextEditingController();
  Timer? _particleTimer;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Idle Animation: Gentle Floating (static when reduced motion).
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (!AppMotion.reduced) {
      _idleController.repeat(reverse: true);
    }

    _floatingAnimation = Tween<double>(
      begin: 0,
      end: AppMotion.reduced ? 0 : -15,
    ).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    // Reaction Animation: Quick Jump/Bounce
    _reactionController = AnimationController(
      vsync: this,
      duration: AppMotion.orZero(const Duration(milliseconds: 600)),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 70,
      ),
    ]).animate(_reactionController);

    // Initial welcome
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GuardianController>().welcome();
      if (!AppMotion.reduced) _reactionController.forward();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final guardian = mounted ? context.read<GuardianController>() : null;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _idleController.stop();
      guardian?.pauseIdle();
    } else if (state == AppLifecycleState.resumed) {
      if (!AppMotion.reduced && mounted) {
        _idleController.repeat(reverse: true);
      }
      guardian?.resumeIdle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleController.dispose();
    _reactionController.dispose();
    _chatController.dispose();
    _particleTimer?.cancel();
    super.dispose();
  }

  void _onTap() {
    final controller = context.read<GuardianController>();
    if (controller.isAIMode) {
      // In AI mode, show chat input (guard against double sheets)
      if (!_sheetOpen) _showChatInput();
    } else {
      controller.react();
      if (!AppMotion.reduced) _reactionController.forward(from: 0);
      _createParticles();
    }
  }

  void _showChatInput() {
    _sheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        decoration: const BoxDecoration(
          color: AppColors.moonlight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.blushGold.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.blushGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Talk to Guardian',
                  style: AppTypography.outfitBold.copyWith(fontSize: 16),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    context.read<GuardianController>().toggleAIMode();
                    Navigator.pop(sheetContext);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.6),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Exit AI Mode',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    autofocus: true,
                    style: AppTypography.outfitWhite.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tell Guardian something...',
                      hintStyle: TextStyle(
                        color: AppColors.petalWhite.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: AppColors.twilight.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendChatMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendChatMessage,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.blushGold, AppColors.deepRose],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: AppColors.petalWhite,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).whenComplete(() {
      _sheetOpen = false;
    });
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();
    Navigator.pop(context);
    context.read<GuardianController>().sendAIMessage(text);
    _createParticles();
  }

  void _createParticles() {
    _particleTimer?.cancel();
    setState(() {
      _particles
        ..clear()
        ..addAll(
          List.generate(
            // 6 instead of 8: same sparkle, ~25% fewer layers.
            6,
            (i) => Particle(
              angle: math.pi * 2 * (i / 6),
              color: AppColors.roseQuartz.withValues(alpha: 0.8),
            ),
          ),
        );
    });

    _particleTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _particles.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final particlesAIMode = context.select<GuardianController, bool>(
      (c) => c.isAIMode,
    );
    return RepaintBoundary(
      child: GestureDetector(
        onLongPress: () {
          // Long press to toggle AI mode
          final controller = context.read<GuardianController>();
          controller.toggleAIMode();
          if (controller.isAIMode) {
            _createParticles();
          }
        },
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Particles (local state only — no controller rebuilds)
            ..._particles.map(
              (p) => Positioned(
                key: ValueKey(p.angle),
                bottom: 40 + 60 * math.sin(p.angle),
                right: 40 + 60 * math.cos(p.angle),
                child: IgnorePointer(
                  child: Icon(
                    particlesAIMode
                        ? Icons.auto_awesome_rounded
                        : Icons.favorite,
                    color: p.color,
                    size: 12,
                  ),
                ),
              ),
            ),

            // AI Mode indicator ring (rebuilds only on mode toggle)
            Selector<GuardianController, bool>(
              selector: (_, c) => c.isAIMode,
              builder: (context, isAIMode, _) {
                if (!isAIMode) return const SizedBox.shrink();
                return Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.blushGold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.twilight, width: 2),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.petalWhite,
                      size: 10,
                    ),
                  ),
                );
              },
            ),

            // Thought Bubble (rebuilds only when message changes)
            Selector<GuardianController, _BubbleView>(
              selector: (_, c) => _BubbleView(
                c.isMessageVisible,
                c.currentMessage?.id ?? '',
                c.currentMessage?.content ?? '',
              ),
              builder: (context, bubble, _) {
                if (!bubble.visible || bubble.content.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  bottom: 90,
                  right: 0,
                  child: TweenAnimationBuilder<double>(
                    duration: AppMotion.orZero(
                      const Duration(milliseconds: 300),
                    ),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: value,
                          alignment: Alignment.bottomRight,
                          child: child,
                        ),
                      );
                    },
                    child: ThoughtBubble(message: bubble.content),
                  ),
                );
              },
            ),

            // The Guardian
            GestureDetector(
              onTap: _onTap,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _floatingAnimation,
                  _bounceAnimation,
                ]),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatingAnimation.value),
                    child: Transform.scale(
                      scale: AppMotion.reduced ? 1.0 : _bounceAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: const CatVisuals(size: 80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Particle {
  final double angle;
  final Color color;
  Particle({required this.angle, required this.color});
}
