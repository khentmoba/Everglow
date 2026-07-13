import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'character/cat_visuals.dart';
import 'thought_bubble.dart';
import 'package:everglow/features/guardian/presentation/controllers/guardian_controller.dart';
import 'package:everglow/core/theme/app_theme.dart';

class EverglowGuardian extends StatefulWidget {
  const EverglowGuardian({super.key});

  @override
  State<EverglowGuardian> createState() => _EverglowGuardianState();
}

class _EverglowGuardianState extends State<EverglowGuardian>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _reactionController;
  late Animation<double> _floatingAnimation;
  late Animation<double> _bounceAnimation;

  final List<Particle> _particles = [];
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Idle Animation: Gentle Floating
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: 0, end: -15).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    // Reaction Animation: Quick Jump/Bounce
    _reactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween:
              Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 1.3, end: 1.0)
              .chain(CurveTween(curve: Curves.bounceOut)),
          weight: 70),
    ]).animate(_reactionController);

    // Initial welcome
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GuardianController>().welcome();
      _reactionController.forward();
    });
  }

  @override
  void dispose() {
    _idleController.dispose();
    _reactionController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _onTap() {
    final controller = context.read<GuardianController>();
    if (controller.isAIMode) {
      // In AI mode, show chat input
      _showChatInput();
    } else {
      controller.react();
      _reactionController.forward(from: 0);
      _createParticles();
    }
  }

  void _showChatInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.moonlight,
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
                color: AppTheme.blushGold.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.blushGold, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Talk to Guardian',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.petalWhite,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    context.read<GuardianController>().toggleAIMode();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.blushGold.withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Exit AI Mode',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.blushGold,
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
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppTheme.petalWhite,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tell Guardian something...',
                      hintStyle: TextStyle(
                        color: AppTheme.petalWhite.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: AppTheme.twilight.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
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
                        colors: [AppTheme.blushGold, AppTheme.deepRose],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: AppTheme.petalWhite,
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
    );
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
    setState(() {
      for (int i = 0; i < 8; i++) {
        _particles.add(Particle(
          angle: math.pi * 2 * (i / 8),
          color: Colors.pink[100]!.withValues(alpha: 0.8),
        ));
      }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _particles.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GuardianController>(
      builder: (context, controller, child) {
        return GestureDetector(
          onLongPress: () {
            // Long press to toggle AI mode
            controller.toggleAIMode();
            if (controller.isAIMode) {
              _createParticles();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Particles
              ..._particles.map((p) => AnimatedPositioned(
                    key: ValueKey(p.angle),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    bottom: _particles.isEmpty
                        ? 40
                        : 40 + 60 * math.sin(p.angle),
                    right: _particles.isEmpty
                        ? 40
                        : 40 + 60 * math.cos(p.angle),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _particles.isEmpty ? 0 : 1,
                        child: Icon(
                          controller.isAIMode
                              ? Icons.auto_awesome_rounded
                              : Icons.favorite,
                          color: controller.isAIMode
                              ? AppTheme.blushGold
                              : const Color(0xFFFFD1DC),
                          size: 12,
                        ),
                      ),
                    ),
                  )),

              // AI Mode indicator ring
              if (controller.isAIMode)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.blushGold,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.twilight, width: 2),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.petalWhite,
                      size: 10,
                    ),
                  ),
                ),

              // Thought Bubble
              if (controller.isMessageVisible &&
                  controller.currentMessage != null)
                Positioned(
                  bottom: 90,
                  right: 0,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: value,
                          alignment: Alignment.bottomRight,
                          child: ThoughtBubble(
                              message: controller.currentMessage!.content),
                        ),
                      );
                    },
                  ),
                ),

              // The Guardian
              GestureDetector(
                onTap: _onTap,
                child: AnimatedBuilder(
                  animation:
                      Listenable.merge([_floatingAnimation, _bounceAnimation]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatingAnimation.value),
                      child: Transform.scale(
                        scale: _bounceAnimation.value,
                        child: CatVisuals(
                          size: 80,
                          primaryColor: controller.isAIMode
                              ? AppTheme.blushGold
                              : const Color(0xFFFFD1DC),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class Particle {
  final double angle;
  final Color color;
  Particle({required this.angle, required this.color});
}
