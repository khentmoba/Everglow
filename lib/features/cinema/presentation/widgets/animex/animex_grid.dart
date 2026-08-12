import 'package:flutter/material.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';

import 'animex_poster_card.dart';
import 'animex_skeleton.dart';

/// Responsive auto-fill poster grid with a staggered entrance animation.
class AnimeXGrid extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem) onTap;
  final bool loading;
  final int skeletonCount;
  final Map<int, double>? progressByIndex;
  final Map<int, double>? scoreByIndex;
  final Widget Function(MediaItem)? hoverActionBuilder;

  const AnimeXGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.loading = false,
    this.skeletonCount = 12,
    this.progressByIndex,
    this.scoreByIndex,
    this.hoverActionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return AnimeXSkeletonGrid(count: skeletonCount);
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final minTile = 140.0;
        final columns = (constraints.maxWidth / minTile).floor().clamp(2, 8);
        final spacing = 14.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing * 2,
            childAspectRatio: tileWidth / (tileWidth * 1.5 + 58),
          ),
          itemBuilder: (context, i) {
            final item = items[i];
            return _Staggered(
              index: i,
              child: AnimeXPosterCard(
                item: item,
                width: tileWidth,
                onTap: () => onTap(item),
                progress: progressByIndex?[i],
                score: scoreByIndex?[i],
                hoverAction: hoverActionBuilder?.call(item),
              ),
            );
          },
        );
      },
    );
  }
}

class _Staggered extends StatelessWidget {
  final int index;
  final Widget child;

  const _Staggered({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('stagger-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index.clamp(0, 12) * 40)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
