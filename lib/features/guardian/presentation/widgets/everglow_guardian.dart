import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'character/cat_visuals.dart';
import 'thought_bubble.dart';
import 'package:everglow/features/guardian/presentation/controllers/guardian_controller.dart';

class EverglowGuardian extends StatefulWidget {
  const EverglowGuardian({super.key});

  @override
  State<EverglowGuardian> createState() => _EverglowGuardianState();
}

class _EverglowGuardianState extends State<EverglowGuardian> with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _reactionController;
  late Animation<double> _floatingAnimation;
  late Animation<double> _bounceAnimation;
  
  final List<Particle> _particles = [];

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
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 70),
    ]).animate(_reactionController);

    // Initial welcome
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GuardianController>().welcome();
      _reactionController.forward();
    });
  }

  void _onTap() {
    final controller = context.read<GuardianController>();
    controller.react();
    _reactionController.forward(from: 0);
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
  void dispose() {
    _idleController.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GuardianController>(
      builder: (context, controller, child) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Particles
            ..._particles.map((p) => AnimatedPositioned(
              key: ValueKey(p.angle),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              bottom: _particles.isEmpty ? 40 : 40 + 60 * math.sin(p.angle),
              right: _particles.isEmpty ? 40 : 40 + 60 * math.cos(p.angle),
              child: IgnorePointer(
                child: Opacity(
                  opacity: _particles.isEmpty ? 0 : 1,
                  child: const Icon(Icons.favorite, color: Color(0xFFFFD1DC), size: 12),
                ),
              ),
            )),
            
            // Thought Bubble
            if (controller.isMessageVisible && controller.currentMessage != null)
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
                        child: ThoughtBubble(message: controller.currentMessage!.content),
                      ),
                    );
                  },
                ),
              ),
            
            // The Guardian
            GestureDetector(
              onTap: _onTap,
              child: AnimatedBuilder(
                animation: Listenable.merge([_floatingAnimation, _bounceAnimation]),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatingAnimation.value),
                    child: Transform.scale(
                      scale: _bounceAnimation.value,
                      child: const CatVisuals(size: 80),
                    ),
                  );
                },
              ),
            ),
          ],
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
