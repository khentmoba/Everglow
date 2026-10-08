import 'package:flutter/material.dart';

import '../../../../cinema/data/models/media_item.dart';

import 'animex_poster_card.dart';
import 'animex_skeleton.dart';
import 'animex_tokens.dart';
import '../../../../../core/theme/app_motion.dart';

/// Responsive auto-fill poster grid with a staggered entrance animation.
class AnimeXGrid extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem) onTap;
  final bool loading;
  final bool sliver;
  final int skeletonCount;
  final Map<int, double>? progressByIndex;
  final Map<int, double>? scoreByIndex;
  final Widget Function(MediaItem)? hoverActionBuilder;

  const AnimeXGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.loading = false,
    this.sliver = false,
    this.skeletonCount = 12,
    this.progressByIndex,
    this.scoreByIndex,
    this.hoverActionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (sliver) {
      if (loading) {
        return SliverToBoxAdapter(
          child: AnimeXSkeletonGrid(count: skeletonCount),
        );
      }
      return SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.crossAxisExtent / 140).floor().clamp(
            2,
            8,
          );
          final width =
              (constraints.crossAxisExtent - 14 * (columns - 1)) / columns;
          return SliverGrid.builder(
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 28,
              childAspectRatio:
                  width / (width * 1.5 + AnimeXTokens.posterDetailsHeight),
            ),
            itemBuilder: (context, i) => _card(i, width),
          );
        },
      );
    }
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
            childAspectRatio:
                tileWidth /
                (tileWidth * 1.5 + AnimeXTokens.posterDetailsHeight),
          ),
          itemBuilder: (context, i) => _card(i, tileWidth),
        );
      },
    );
  }

  Widget _card(int i, double width) {
    final item = items[i];
    return _Staggered(
      index: i,
      child: AnimeXPosterCard(
        item: item,
        width: width,
        onTap: () => onTap(item),
        progress: progressByIndex?[i],
        score: scoreByIndex?[i],
        hoverAction: hoverActionBuilder?.call(item),
      ),
    );
  }
}

class _Staggered extends StatelessWidget {
  final int index;
  final Widget child;

  const _Staggered({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceAmbientMotion(context)) return child;
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
