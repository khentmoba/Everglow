import 'package:flutter/material.dart';

import '../../../../../core/theme/app_breakpoints.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/app_motion.dart';
import '../../../data/models/media_item.dart';
import '../netflix/netflix_billboard.dart';
import '../netflix/netflix_colors.dart';
import '../netflix/netflix_nav_bar.dart';
import '../netflix/netflix_row.dart';
import '../netflix/netflix_loading.dart';

/// A small personal home. The rest of the catalogue lives in Browse.
class CinemaHomeTab extends StatelessWidget {
  final bool isLoadingHome;
  final List<MediaItem> trendingCarousel;
  final List<MediaItem> popularTVShows;
  final List<MediaItem> newlyReleased;
  final List<MediaItem> watchingList;
  final List<MediaItem> savedList;
  final List<MediaItem> trendingGlobal;
  final List<MediaItem> topTenToday;
  final Future<void> Function() onRefresh;
  final void Function(MediaItem) onMediaTap;
  final void Function(MediaItem) onPlay;
  final void Function(MediaItem)? onPlayItem;
  final void Function(MediaItem)? onRestart;
  final void Function(MediaItem, bool add)? onToggleListItem;
  final void Function(MediaItem, double? rating)? onRateItem;
  final bool Function(MediaItem)? isInList;
  final void Function(MediaItem)? onRemoveProgress;
  final void Function(int) onSwitchTab;

  const CinemaHomeTab({
    super.key,
    required this.isLoadingHome,
    required this.trendingCarousel,
    required this.popularTVShows,
    required this.newlyReleased,
    required this.watchingList,
    this.savedList = const [],
    required this.trendingGlobal,
    required this.topTenToday,
    required this.onRefresh,
    required this.onMediaTap,
    required this.onPlay,
    this.onPlayItem,
    this.onRestart,
    this.onToggleListItem,
    this.onRateItem,
    this.isInList,
    this.onRemoveProgress,
    required this.onSwitchTab,
  });

  double? _continueProgress(MediaItem item) {
    final position = item.currentTimestamp ?? 0;
    final duration = item.durationSeconds ?? 0;
    if (position <= 0 || duration <= 0) return null;
    return (position / duration).clamp(0.0, 1.0);
  }

  String _continueSubtitle(MediaItem item) {
    final position = item.resumeSeconds ?? 0;
    final duration = item.durationSeconds ?? 0;
    final remaining = duration > position && position > 0
        ? ' · ${((duration - position) / 60).ceil()}m left'
        : '';
    if (item.hasEpisodeProgress && item.currentSeason != null) {
      return 'S${item.currentSeason} · E${item.currentEpisode ?? 1}$remaining';
    }
    return position > 0
        ? 'Resume at ${position ~/ 60}m$remaining'
        : 'Play from start';
  }

  Widget _row(String title, List<MediaItem> items, {bool ranked = false}) {
    if (items.isEmpty && isLoadingHome) {
      return SliverToBoxAdapter(child: NetflixLoadingRow(title: title));
    }
    return SliverToBoxAdapter(
      child: NetflixRow(
        title: title,
        items: items,
        ranked: ranked,
        onTapItem: onMediaTap,
        onPlayItem: onPlayItem,
        onToggleListItem: onToggleListItem,
        onRateItem: onRateItem,
        isInList: isInList,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = AppBreakpoint.isDesktop(context);
    final continueRow = SliverToBoxAdapter(
      child: NetflixContinueRow(
        items: watchingList.take(10).toList(),
        subtitleOf: _continueSubtitle,
        progressOf: _continueProgress,
        onTapItem: onMediaTap,
        onPlayContinue: onPlayItem,
        onPlayItem: onPlayItem,
        onRestart: onRestart,
        onToggleListItem: onToggleListItem,
        onRateItem: onRateItem,
        isInList: isInList,
        onRemoveItem: onRemoveProgress,
      ),
    );
    final hero = SliverToBoxAdapter(
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.orZero(AppMotion.page),
        switchInCurve: AppMotion.easeOutExpo,
        child: trendingCarousel.isEmpty && isLoadingHome
            ? const NetflixLoadingBillboard(key: ValueKey('loading'))
            : NetflixBillboard(
                key: const ValueKey('featured'),
                items: trendingCarousel.take(5).toList(),
                onPlay: onPlay,
                onInfo: onMediaTap,
              ),
      ),
    );
    final emptyCatalogue =
        !isLoadingHome &&
        trendingGlobal.isEmpty &&
        topTenToday.isEmpty &&
        newlyReleased.isEmpty &&
        popularTVShows.isEmpty;
    return RefreshIndicator(
      color: NetflixColors.accent,
      backgroundColor: NetflixColors.surface,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (!desktop && watchingList.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.only(
                top: cinemaTopContentInset(context) + 48,
              ),
              sliver: continueRow,
            ),
          hero,
          if (desktop && watchingList.isNotEmpty) continueRow,
          if (savedList.isNotEmpty)
            _row('Your picks', savedList.take(10).toList()),
          ...[
            if (emptyCatalogue)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'The catalogue could not load.',
                        style: AppTypography.outfitWhite.copyWith(
                          color: NetflixColors.textSecondary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            if (isLoadingHome || trendingGlobal.isNotEmpty)
              _row('Trending Now', trendingGlobal),
            if (isLoadingHome || topTenToday.isNotEmpty)
              _row(
                'Top 10 in $topTenCountryLabel',
                topTenToday.take(10).toList(),
                ranked: true,
              ),
            if (isLoadingHome || newlyReleased.isNotEmpty)
              _row('Coming Soon', newlyReleased),
            if (isLoadingHome || popularTVShows.isNotEmpty)
              _row('Popular Series', popularTVShows),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: NetflixColors.textPrimary,
                  ),
                  onPressed: () => onSwitchTab(2),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Explore more in Browse'),
                ),
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}
