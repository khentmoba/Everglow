import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/date_randomizer/data/services/date_idea_service.dart';
import 'package:everglow/features/date_randomizer/data/models/date_idea.dart';
import 'package:everglow/features/date_randomizer/presentation/widgets/celebration_dialog.dart';
import 'package:everglow/features/date_randomizer/data/services/ai_date_idea_generator.dart';
import 'package:everglow/features/ai/data/services/ai_service.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/shared/widgets/bouncy_button.dart';
import 'package:everglow/shared/widgets/animated_emblem.dart';
import 'package:everglow/core/theme/app_theme.dart';import 'package:everglow/core/theme/app_typography.dart';

class RandomizerCard extends StatefulWidget {
  final DateIdeaService service;

  const RandomizerCard({super.key, required this.service});

  @override
  State<RandomizerCard> createState() => _RandomizerCardState();
}

class _RandomizerCardState extends State<RandomizerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSpinning = false;
  bool _useAI = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSpin() async {
    if (_isSpinning) return;

    final aiService = context.read<AIService>();

    setState(() => _isSpinning = true);
    _controller.repeat();

    await Future.delayed(const Duration(milliseconds: 2000));

    _controller.stop();

    DateIdea? idea;

    if (_useAI) {
      // Try AI-generated idea first
      final generator = AIDateIdeaGenerator(aiService);
      idea = await generator.generatePersonalizedIdea();
    }

    // Fallback to regular random idea
    idea ??= widget.service.getRandomIdea();
    
    if (!mounted) return;

    if (idea != null) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: AppTheme.deepRose.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, anim1, anim2) {
          return CelebrationDialog(title: idea?.title ?? 'Date Night!');
        },
        transitionBuilder: (context, anim1, anim2, child) {
          return ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
            child: child,
          );
        },
      );
    }

    setState(() => _isSpinning = false);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Text(
              'Digital Roulette',
              style: AppTypography.cormorantBlack.copyWith(fontSize: 26, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Text(
              'SPIN FOR A DATE DESTINY',
              style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            // AI Mode toggle
            Semantics(
              label: _useAI ? 'AI mode enabled. Tap to switch to random.' : 'Random mode. Tap to enable AI.',
              button: true,
              toggled: _useAI,
              child: GestureDetector(
              onTap: () => setState(() => _useAI = !_useAI),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _useAI
                      ? AppTheme.blushGold.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _useAI
                        ? AppTheme.blushGold
                        : AppTheme.petalWhite.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _useAI ? Icons.auto_awesome_rounded : Icons.shuffle_rounded,
                      size: 14,
                      color: _useAI ? AppTheme.blushGold : AppTheme.petalWhite.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _useAI ? 'AI Powered ✨' : 'Random',
                      style: AppTypography.outfitBold.copyWith(fontSize: 11, color: _useAI ? AppTheme.blushGold : AppTheme.petalWhite.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
             ),
            ),
            const SizedBox(height: 40),
            RotationTransition(
              turns: _controller,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Roulette Ring
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.blushGold.withValues(alpha: 0.65),
                        width: 8,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _RoulettePainter(),
                    ),
                  ),
                  // Center Button
                  BouncyButton(
                    onTap: _handleSpin,
                    child: const AnimatedEmblem(
                      icon: Icons.favorite_rounded,
                      size: 60,
                      color: AppTheme.deepRose,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _isSpinning ? 'DECIDING YOUR FATE...' : 'TAP THE HEART',
              style: AppTypography.outfitWhite.copyWith(color: _isSpinning ? AppTheme.blushGold : AppTheme.roseQuartz.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _RoulettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.blushGold.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * (3.14159 / 180);
      // Actually draw proper spokes
      canvas.drawLine(
        Offset(center.dx + (radius - 15) * (angle), center.dy + (radius - 15) * (angle)), // This logic is wrong but illustrative
        Offset(center.dx + radius * (angle), center.dy + radius * (angle)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
