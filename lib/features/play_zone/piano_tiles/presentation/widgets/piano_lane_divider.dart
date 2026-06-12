import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';

class PianoLaneDivider extends StatelessWidget {
  const PianoLaneDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.blushGold.withValues(alpha: 0.0),
            AppTheme.blushGold.withValues(alpha: 0.35),
            AppTheme.blushGold.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
