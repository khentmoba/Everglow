import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Native fallback for the WebGL table tennis game.
class TableTennisGameScreen extends StatelessWidget {
  const TableTennisGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      appBar: AppBar(
        title: const Text('Table Tennis'),
        backgroundColor: AppColors.velvet,
        foregroundColor: AppColors.petalWhite,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sports_tennis,
                size: 72,
                color: AppColors.auroraRose,
              ),
              const SizedBox(height: 20),
              const Text(
                'Table tennis is available in the web app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.petalWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open Everglow in a browser to play with the full WebGL experience.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedPurple, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
