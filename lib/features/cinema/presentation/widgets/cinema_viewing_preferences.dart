import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/cinema_preferences.dart';
import 'netflix/netflix_colors.dart';

/// Shared by My List and the player; no Provider registration needed.
class CinemaViewingPreferences extends StatelessWidget {
  final CinemaPreferences? preferences;
  final bool compact;

  const CinemaViewingPreferences({
    super.key,
    this.preferences,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = preferences ?? CinemaPreferences.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Material(
        color: NetflixColors.surface,
        child: compact
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _compactChip(
                      'Hide spoilers',
                      prefs.hideSpoilers,
                      prefs.setHideSpoilers,
                    ),
                    _compactChip(
                      'Autoplay next episode',
                      prefs.autoplayNext,
                      prefs.setAutoplayNext,
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Hide spoilers'),
                    subtitle: const Text(
                      'Keep episode titles, stories and pictures hidden',
                    ),
                    value: prefs.hideSpoilers,
                    onChanged: prefs.setHideSpoilers,
                    activeThumbColor: NetflixColors.accent,
                  ),
                  SwitchListTile(
                    title: const Text('Autoplay next episode'),
                    subtitle: const Text(
                      'Only after a supported player confirms the episode has ended',
                    ),
                    value: prefs.autoplayNext,
                    onChanged: prefs.setAutoplayNext,
                    activeThumbColor: NetflixColors.accent,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _compactChip(
    String label,
    bool selected,
    ValueChanged<bool> onChanged,
  ) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: AppTypography.outfitHeading.copyWith(
        color: selected ? NetflixColors.textPrimary : AppColors.textMedium,
        fontSize: 12,
      ),
      backgroundColor: NetflixColors.surfaceElevated,
      selectedColor: NetflixColors.accent.withValues(alpha: 0.16),
      side: BorderSide(
        color: selected ? NetflixColors.accent : NetflixColors.hairline,
      ),
      shape: const StadiumBorder(),
    );
  }
}
