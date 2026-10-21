import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/models/media_item.dart';

class CinemaPlaybackSheet extends StatelessWidget {
  final MediaItem item;
  const CinemaPlaybackSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final seconds = item.resumeSeconds ?? item.currentTimestamp ?? 0;
    final position =
        '${seconds ~/ 3600}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.title, style: AppTypography.outfitHeading),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(
                  seconds > 0 ? 'Resume at $position' : 'Continue watching',
                ),
                subtitle: Text(
                  item.mediaType == 'tv'
                      ? 'Season ${item.currentSeason ?? 1}, episode ${item.currentEpisode ?? 1}'
                      : 'Your saved place',
                ),
                onTap: () => Navigator.pop(context, 'resume'),
              ),
              ListTile(
                leading: const Icon(Icons.replay),
                title: Text(
                  item.mediaType == 'tv'
                      ? 'Restart this episode'
                      : 'Start from the beginning',
                ),
                onTap: () => Navigator.pop(context, 'restart'),
              ),
              if (item.mediaType == 'tv')
                ListTile(
                  leading: const Icon(Icons.format_list_numbered),
                  title: const Text('Choose a different episode'),
                  onTap: () => Navigator.pop(context, 'episodes'),
                ),
              ListTile(
                leading: const Icon(Icons.done_all),
                title: Text(
                  item.mediaType == 'tv'
                      ? 'Mark series finished'
                      : 'Mark movie finished',
                ),
                onTap: () => Navigator.pop(context, 'finished'),
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove from Continue Watching'),
                subtitle: const Text(
                  'Clears the saved place; keeps the title in My List.',
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
