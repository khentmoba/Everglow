import 'package:flutter/material.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/core/theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final bool animate;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Text(
                value.toString().padLeft(2, '0'),
                key: ValueKey<int>(value),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.peachyMagenta,
                  shadows: [
                    Shadow(
                      color: AppTheme.peachyMagenta,
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
