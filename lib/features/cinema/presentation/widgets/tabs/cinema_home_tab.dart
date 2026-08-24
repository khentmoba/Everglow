import 'package:flutter/material.dart' hide FilterChip;

import '../../../../../core/theme/app_breakpoints.dart';
import '../../../../ai/presentation/widgets/ai_recommendations.dart';
import '../../../data/models/media_item.dart';
import '../netflix/netflix_billboard.dart';
import '../netflix/netflix_colors.dart';
import '../netflix/netflix_row.dart';
import '../../../../../shared/widgets/shelf/shimmer_box.dart';

/// Featured genre definitions used for both data fetching (in the parent
/// screen) and display (in this tab). Made public so the parent can import.
const List<Map<String, dynamic>> featuredGenres = [
  {'id': 28, 'name': 'Action', 'type': 'movie'},
  {'id': 35, 'name': 'Comedy', 'type': 'movie'},
  {'id': 27, 'name': 'Horror', 'type': 'movie'},
  {'id': 10749, 'name': 'Romance', 'type': 'movie'},
  {'id': 18, 'name': 'Drama', 'type': 'movie'},
  {'id': 16, 'name': 'Animation', 'type': 'movie'},
  {'id': 9648, 'name': 'Mystery', 'type': 'movie'},
  {'id': 878, 'name': 'Sci-Fi', 'type': 'movie'},
  {'id': 10765, 'name': 'Sci-Fi & Fantasy', 'type': 'tv'},
  {'id': 10759, 'name': 'Action & Adventure', 'type': 'tv'},
];

/// Cinema home - a Netflix-style billboard followed by content rails.
class CinemaHomeTab extends StatelessWidget {
  final bool isLoadingHome;
  final List<MediaItem> trendingCarousel;
  final List<MediaItem> topRatedMovies;
  final List<MediaItem> popularTVShows;
  final List<MediaItem> nowShowing;
  final List<MediaItem> newlyReleased;
  final List<MediaItem> popularMovies;
  final List<MediaItem> topRatedTV;
  final List<MediaItem> airingToday;
  final List<MediaItem> onTheAir;
  final Map<String, List<MediaItem>> discoveryRows;
  final Map<String, List<MediaItem>> genreLists;
  final List<MediaItem> watchingList;
  final List<MediaItem> watchedList;
  final List<MediaItem> trendingGlobal;
  final List<MediaItem> trendingPH;
  final VoidCallback onRefresh;
  final void Function(MediaItem) onMediaTap;
  final void Function(MediaItem) onPlay;
  final void Function(MediaItem)? onPlayItem;
  final void Function(MediaItem, bool add)? onToggleListItem;
  final void Function(MediaItem, double? rating)? onRateItem;
  final bool Function(MediaItem)? isInList;
  final void Function(int) onSwitchTab;

  const CinemaHomeTab({
    super.key,
    required this.isLoadingHome,
    required this.trendingCarousel,
    required this.topRatedMovies,
    required this.popularTVShows,
    required this.nowShowing,
    required this.newlyReleased,
    required this.popularMovies,
    required this.topRatedTV,
    required this.airingToday,
    required this.onTheAir,
    required this.discoveryRows,
    required this.genreLists,
    required this.watchingList,
    required this.watchedList,
    required this.trendingGlobal,
    required this.trendingPH,
    required this.onRefresh,
    required this.onMediaTap,
    required this.onPlay,
    this.onPlayItem,
    this.onToggleListItem,
    this.onRateItem,
    this.isInList,
    required this.onSwitchTab,
  });

  double? _continueProgress(MediaItem item) {
    final position = item.currentTimestamp ?? 0;
    final duration = item.durationSeconds ?? 0;
    if (position <= 0 || duration <= 0) return null;
    return (position / duration).clamp(0.0, 1.0);
  }

  String _continueSubtitle(MediaItem item) {
    if (item.mediaType == 'tv' && item.currentSeason != null) {
      return 'S${item.currentSeason} · E${item.currentEpisode ?? 1}';
    }
    if ((item.currentTimestamp ?? 0) > 0) {
      final minutes = item.currentTimestamp! ~/ 60;
      final remaining =
          item.durationSeconds != null &&
              item.durationSeconds! > item.currentTimestamp!
          ? ' · ${((item.durationSeconds! - item.currentTimestamp!) / 60).ceil()}m left'
          : '';
      return 'Resume at ${minutes}m$remaining';
    }
    return item.mediaType == 'tv' ? 'Next episode ready' : 'Play from start';
  }

  List<Widget> _genreRows() {
    final rows = <Widget>[];
    genreLists.forEach((genreName, items) {
      if (items.isEmpty) return;
      rows.add(
        SliverToBoxAdapter(
          child: NetflixRow(
            title: genreName,
            items: items,
            onTapItem: onMediaTap,
            onPlayItem: onPlayItem,
            onToggleListItem: onToggleListItem,
            onRateItem: onRateItem,
            isInList: isInList,
          ),
        ),
      );
    });
    return rows;
  }

  List<Widget> _discoveryRows() {
    final specs = <String, String>{
      'korean_dramas': 'Korean Dramas',
      'bollywood': 'Bollywood',
      'spanish_cinema': 'Spanish Cinema',
      'french_cinema': 'French Cinema',
      'decade_2010s': 'Best of the 2010s',
      'decade_2000s': 'Best of the 2000s',
      'classic_films': 'Classic Films',
    };
    final rows = <Widget>[];
    specs.forEach((key, title) {
      final items = discoveryRows[key];
      if (items == null || items.isEmpty) return;
      rows.add(
        SliverToBoxAdapter(
          child: NetflixRow(
            title: title,
            items: items,
            onTapItem: onMediaTap,
            onPlayItem: onPlayItem,
            onToggleListItem: onToggleListItem,
            onRateItem: onRateItem,
            isInList: isInList,
          ),
        ),
      );
    });
    return rows;
  }

  Widget _row({
    required String title,
    required List<MediaItem> items,
    bool ranked = false,
  }) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
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
    if (isLoadingHome) return const _HomeShimmer();

    return RefreshIndicator(
      color: NetflixColors.accent,
      backgroundColor: NetflixColors.surface,
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: NetflixBillboard(
              items: trendingCarousel.take(5).toList(),
              onPlay: onPlay,
              onInfo: onMediaTap,
            ),
          ),

          if (watchingList.isNotEmpty)
            SliverToBoxAdapter(
              child: NetflixContinueRow(
                items: watchingList.take(10).toList(),
                subtitleOf: _continueSubtitle,
                progressOf: _continueProgress,
                onTapItem: onMediaTap,
                onPlayContinue: onPlayItem,
              ),
            ),

          SliverToBoxAdapter(
            child: AIRecommendations(
              title: "Mochi's Picks",
              autoLoad: true,
              netflixStyle: true,
              onTapItem: onMediaTap,
            ),
          ),

          _row(title: 'Trending Now', items: trendingGlobal),
          _row(
            title: 'Top 10 Today',
            items: trendingGlobal.take(10).toList(),
            ranked: true,
          ),
          _row(title: 'New Releases', items: newlyReleased),
          _row(title: 'Now Showing', items: nowShowing),
          _row(title: 'Popular Movies', items: popularMovies),
          _row(title: 'Top Rated TV', items: topRatedTV),
          _row(title: 'Airing Today', items: airingToday),
          _row(title: 'Currently Airing', items: onTheAir),

          ..._genreRows(),
          ..._discoveryRows(),

          _row(title: 'Top Rated', items: topRatedMovies),
          _row(title: 'Popular Series', items: popularTVShows),

          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}

/// Netflix-style skeleton while the home payload loads.
class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final pad = isDesktop ? 48.0 : 16.0;
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: ShimmerBox(height: 520, radius: 0)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 32, pad, 14),
            child: const ShimmerBox(height: 22, width: 220, radius: 4),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Row(
              children: List.generate(
                isDesktop ? 6 : 3,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ShimmerBox(
                    height: isDesktop ? 258 : 186,
                    width: isDesktop ? 172 : 124,
                    radius: 6,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}
