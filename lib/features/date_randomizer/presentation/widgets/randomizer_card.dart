import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/date_idea_service.dart';
import '../../data/models/date_idea.dart';
import './celebration_dialog.dart';
import '../../data/services/ai_date_idea_generator.dart';
import '../../../ai/data/services/ai_service.dart';
import '../../../../shared/widgets/bouncy_button.dart';
import '../../../../shared/widgets/animated_emblem.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

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
      final generator = AIDateIdeaGenerator(aiService);
      idea = await generator.generatePersonalizedIdea();
    }

    idea ??= widget.service.getRandomIdea();

    if (!mounted) return;

    if (idea != null) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: AppColors.deepRose.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, anim1, anim2) {
          return CelebrationDialog(title: idea!.title);
        },
        transitionBuilder: (context, anim1, anim2, child) {
          return ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
            child: child,
          );
        },
      );
    }

    if (mounted) setState(() => _isSpinning = false);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.velvet.withValues(alpha: 0.52),
                AppColors.inkDeep.withValues(alpha: 0.58),
              ],
            ),
            borderRadius: AppRadius.radiusX2,
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.12),
                blurRadius: 26,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                left: 22,
                right: 22,
                child: Container(
                  height: 1.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.auroraGold.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    'Digital Roulette',
                    style: AppTypography.cormorantBlack.copyWith(
                      fontSize: 26,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SPIN FOR A DATE DESTINY',
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.petalWhite.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    label: _useAI
                        ? 'AI mode enabled. Tap to switch to random.'
                        : 'Random mode. Tap to enable AI.',
                    button: true,
                    toggled: _useAI,
                    child: GestureDetector(
                      onTap: () => setState(() => _useAI = !_useAI),
                      child: AnimatedContainer(
                        duration: AppMotion.orZero(AppMotion.medium),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _useAI
                              ? AppColors.auroraGold.withValues(alpha: 0.18)
                              : AppColors.moonlight.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _useAI
                                ? AppColors.auroraGold.withValues(alpha: 0.7)
                                : AppColors.moonlight.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _useAI
                                  ? Icons.auto_awesome_rounded
                                  : Icons.shuffle_rounded,
                              size: 14,
                              color: _useAI
                                  ? AppColors.auroraGold
                                  : AppColors.petalWhite.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _useAI ? 'AI Powered' : 'Random',
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 11,
                                color: _useAI
                                    ? AppColors.auroraGold
                                    : AppColors.petalWhite.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  RotationTransition(
                    turns: _controller,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Roulette ring with gradient rim.
                        Container(
                          width: 156,
                          height: 156,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(
                              colors: [
                                AppColors.deepRose,
                                AppColors.auroraGold,
                                AppColors.softLavender,
                                AppColors.deepRose,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.deepRose.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.inkDeep,
                            ),
                            child: const CustomPaint(
                              painter: _RoulettePainter(),
                            ),
                          ),
                        ),
                        // Center heart button.
                        BouncyButton(
                          onTap: _handleSpin,
                          child: const AnimatedEmblem(
                            icon: Icons.favorite_rounded,
                            size: 62,
                            color: AppColors.deepRose,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    _isSpinning ? 'DECIDING YOUR FATE...' : 'TAP THE HEART',
                    style: AppTypography.outfitWhite.copyWith(
                      color: _isSpinning
                          ? AppColors.auroraGold
                          : AppColors.roseQuartz.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoulettePainter extends CustomPainter {
  const _RoulettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.auroraGold.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 16; i++) {
      final angle = (i * 22.5) * (math.pi / 180);
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      canvas.drawLine(
        Offset(center.dx + (radius - 14) * dx, center.dy + (radius - 14) * dy),
        Offset(center.dx + (radius - 2) * dx, center.dy + (radius - 2) * dy),
        paint,
      );
    }

    // Inner ring.
    canvas.drawCircle(
      center,
      radius - 18,
      Paint()
        ..color = AppColors.blushGold.withValues(alpha: 0.28)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
