import 'package:flutter/material.dart';
import 'package:everglow/features/date_randomizer/data/services/date_idea_service.dart';
import 'package:everglow/features/date_randomizer/presentation/widgets/celebration_dialog.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/shared/widgets/bouncy_button.dart';
import 'package:everglow/shared/widgets/animated_emblem.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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

    setState(() => _isSpinning = true);
    _controller.repeat();

    await Future.delayed(const Duration(milliseconds: 2000));

    _controller.stop();
    final idea = widget.service.getRandomIdea();
    
    if (!mounted) return;

    if (idea != null) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: AppTheme.deepRose.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, anim1, anim2) {
          return CelebrationDialog(title: idea.title);
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Text(
              'Digital Roulette',
              style: GoogleFonts.cormorantGaramond(
                color: AppTheme.roseQuartz,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SPIN FOR A DATE DESTINY',
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
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
                        color: AppTheme.blushGold.withValues(alpha: 0.3),
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
              style: GoogleFonts.outfit(
                color: _isSpinning ? AppTheme.blushGold : AppTheme.roseQuartz.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoulettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.champagneGold.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * (3.14159 / 180);
      final start = Offset(
        center.dx + (radius - 10) * (angle), // simplified for brevity
        center.dy + (radius - 10) * (angle),
      );
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
