import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// Native fallback for the iframe-based multiplayer table tennis match.
class TTMultiplayerGameScreen extends StatelessWidget {
  final String roomId;
  final bool isHost;

  const TTMultiplayerGameScreen({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      appBar: AppBar(
        title: const Text('Multiplayer Table Tennis'),
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
                'Multiplayer table tennis is available in the web app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.petalWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Room $roomId · ${isHost ? 'Host' : 'Guest'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedPurple,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
