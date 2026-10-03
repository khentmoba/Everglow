import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/cinema_preferences.dart';

/// Shared by My List and the player; no Provider registration needed.
class CinemaViewingPreferences extends StatelessWidget {
  final CinemaPreferences? preferences;

  const CinemaViewingPreferences({super.key, this.preferences});

  @override
  Widget build(BuildContext context) {
    final prefs = preferences ?? CinemaPreferences.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Material(
        color: AppColors.deepBlack,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Hide spoilers'),
              subtitle: const Text(
                'Keep episode titles, stories and pictures hidden',
              ),
              value: prefs.hideSpoilers,
              onChanged: prefs.setHideSpoilers,
              activeThumbColor: AppColors.deepRose,
            ),
            SwitchListTile(
              title: const Text('Autoplay next episode'),
              subtitle: const Text(
                'Only after a supported player confirms the episode has ended',
              ),
              value: prefs.autoplayNext,
              onChanged: prefs.setAutoplayNext,
              activeThumbColor: AppColors.deepRose,
            ),
          ],
        ),
      ),
    );
  }
}
