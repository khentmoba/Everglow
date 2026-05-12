import 'dart:math';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

class CelebrationDialog extends StatelessWidget {
  final String title;

  const CelebrationDialog({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Background Sparkles/Confetti
          for (int i = 0; i < 15; i++) _buildSparkle(i),

          // Main Card
          ElasticIn(
            duration: const Duration(milliseconds: 1000),
            child: Container(
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Colors.pinkAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "You should...",
                    style: TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF4A4A4A),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[50],
                      foregroundColor: Colors.pinkAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Perfect!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSparkle(int index) {
    final random = Random(index); // Use index as seed for consistent randomness
    final angle = (index / 15) * 2 * pi;
    final distance = 160.0 + random.nextDouble() * 60;
    final icon = index % 2 == 0 ? Icons.star : Icons.circle;
    final color = index % 3 == 0 
        ? Colors.pink[200] 
        : (index % 3 == 1 ? Colors.yellow[300] : Colors.blue[100]);

    return FadeIn(
      delay: Duration(milliseconds: index * 50),
      child: ZoomIn(
        delay: Duration(milliseconds: index * 50),
        child: Transform.translate(
          offset: Offset(cos(angle) * distance, sin(angle) * distance),
          child: Icon(
            icon,
            color: color,
            size: 12 + random.nextDouble() * 24,
          ),
        ),
      ),
    );
  }
}
