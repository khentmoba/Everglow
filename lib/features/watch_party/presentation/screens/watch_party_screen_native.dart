import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/watch_party_room.dart';

/// Native fallback for the synchronized iframe watch party screen.
class WatchPartyScreen extends StatelessWidget {
  final WatchPartyRoom initialRoom;
  final bool isHost;

  const WatchPartyScreen({
    super.key,
    required this.initialRoom,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      appBar: AppBar(
        title: const Text('Watch Party'),
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
                Icons.movie_filter_outlined,
                size: 72,
                color: AppColors.auroraRose,
              ),
              const SizedBox(height: 20),
              Text(
                initialRoom.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.petalWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Synchronized watch parties are available in the web app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedPurple, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                isHost ? 'You are the host' : 'Joining as a partner',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.blushGold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
