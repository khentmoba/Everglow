import 'package:flutter/material.dart';

import '../../../data/models/media_item.dart';

import 'animex_poster_card.dart';
import 'animex_tokens.dart';

/// Horizontal scrolling row of poster cards with hidden scrollbars.
class AnimeXPosterRow extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem) onTap;
  final double cardWidth;
  final Map<int, double>? progressByIndex;
  final Map<int, String>? episodeLabels;

  const AnimeXPosterRow({
    super.key,
    required this.items,
    required this.onTap,
    this.cardWidth = AnimeXTokens.rowPosterWidthDesktop,
    this.progressByIndex,
    this.episodeLabels,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: cardWidth * 1.5 + 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final item = items[i];
          return AnimeXPosterCard(
            item: item,
            width: cardWidth,
            onTap: () => onTap(item),
            progress: progressByIndex?[i],
            episodeLabel: episodeLabels?[i],
          );
        },
      ),
    );
  }
}
