import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/animex_models.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/anilist_service.dart';
import '../../../data/services/animex_stores.dart';

import 'animex_badges.dart';
import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_player.dart';
import 'animex_poster_row.dart';
import 'animex_section_header.dart';
import 'animex_skeleton.dart';
import 'animex_spotlight.dart';
import 'animex_ticker.dart';
import 'animex_tokens.dart';

class _HomeRow {
  final String id;
  final String title;
  final IconData icon;
  final bool loading;
  final List<MediaItem> items;
  final bool isHero;

  const _HomeRow({
    required this.id,
    required this.title,
    required this.icon,
    required this.loading,
    required this.items,
    this.isHero = false,
  });
}

/// Home page of the anime section: spotlight hero, airing ticker, curated
/// rows, continue-watching rail and the airing schedule call-to-action.
class AnimeXHomePage extends StatefulWidget {
  final AnimeXController controller;

  const AnimeXHomePage({super.key, required this.controller});

  @override
  State<AnimeXHomePage> createState() => _AnimeXHomePageState();
}

class _AnimeXHomePageState extends State<AnimeXHomePage> {
  final AniListService _aniList = AniListService();
  final Map<String, _HomeRow> _rows = {};

  @override
  void initState() {
    super.initState();
    _buildSections();
    _load();
  }

  void _buildSections() {
    final season = _currentSeason();
    _rows['trending'] = _HomeRow(
      id: 'trending',
      title: 'Trending This Week',
      icon: Icons.trending_up_rounded,
      loading: true,
      items: const [],
      isHero: true,
    );
    _rows['airing'] = _HomeRow(
      id: 'airing',
      title: 'Top Airing',
      icon: Icons.local_fire_department_rounded,
      loading: true,
      items: const [],
    );
    _rows['seasonal'] = _HomeRow(
      id: 'seasonal',
      title: '${season.$1} ${season.$2}',
      icon: Icons.bolt_rounded,
      loading: true,
      items: const [],
    );
    _rows['popular'] = _HomeRow(
      id: 'popular',
      title: 'Most Popular',
      icon: Icons.star_rounded,
      loading: true,
      items: const [],
    );
    _rows['completed'] = _HomeRow(
      id: 'completed',
      title: 'Recently Completed',
      icon: Icons.check_circle_outline_rounded,
      loading: true,
      items: const [],
    );
  }

  Future<void> _load() async {
    await Future.wait([
      _loadRow(
        'trending',
        () => _aniList.fetchAnimexPage(sort: 'TRENDING_DESC', perPage: 18),
      ),
      _loadRow(
        'airing',
        () => _aniList.fetchAnimexPage(
          sort: 'SCORE_DESC',
          status: 'RELEASING',
          perPage: 18,
        ),
      ),
      _loadRow(
        'seasonal',
        () {
          final season = _currentSeason();
          return _aniList.fetchAnimexPage(
            season: season.$1,
            seasonYear: season.$2,
            sort: 'POPULARITY_DESC',
            perPage: 18,
          );
        },
      ),
      _loadRow(
        'popular',
        () => _aniList.fetchAnimexPage(sort: 'POPULARITY_DESC', perPage: 18),
      ),
      _loadRow(
        'completed',
        () => _aniList.fetchAnimexPage(
          sort: 'END_DATE_DESC',
          status: 'FINISHED',
          perPage: 18,
        ),
      ),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _loadRow(
    String id,
    Future<AnimexMediaPage> Function() builder,
  ) async {
    try {
      final page = await builder();
      if (!mounted) return;
      setState(() {
        _rows[id] = _HomeRow(
          id: id,
          title: _rows[id]!.title,
          icon: _rows[id]!.icon,
          loading: false,
          items: page.items,
          isHero: _rows[id]!.isHero,
        );
      });
    } catch (e) {
      debugPrint('[AnimeXHome] row $id failed: $e');
      if (!mounted) return;
      setState(() {
        _rows[id] = _HomeRow(
          id: id,
          title: _rows[id]!.title,
          icon: _rows[id]!.icon,
          loading: false,
          items: const [],
          isHero: _rows[id]!.isHero,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AnimexStores>().history;
    final trending = _rows['trending']!;
    final airing = _rows['airing']!;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 64),
      children: [
        AnimeXSpotlight(
          items: trending.items.take(5).toList(),
          loading: trending.loading,
          onWatch: (item) => widget.controller.openWatch(item),
          onMoreInfo: (item) => widget.controller.openWatch(item),
          onTrailer: (item) => showAnimexTrailer(
            context,
            anilistId: item.anilistId,
            malId: item.tmdbId,
            title: item.title,
          ),
        ),
        AnimeXTicker(
          items: airing.items.take(14).toList(),
          onTap: (item) => widget.controller.openWatch(item),
        ),
        const SizedBox(height: 40),
        for (final row in [
          _rows['trending']!,
          _rows['airing']!,
          _rows['seasonal']!,
          _rows['popular']!,
          _rows['completed']!,
        ])
          _buildRowSection(context, row),
        if (history.isNotEmpty) ...[
          _buildContinueWatching(context, history),
        ],
        const SizedBox(height: 24),
        _buildScheduleCta(context),
        const SizedBox(height: 40),
        AnimeXFooter(controller: widget.controller),
      ],
    );
  }

  Widget _buildRowSection(BuildContext context, _HomeRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimeXSectionHeader(
              icon: row.icon,
              title: row.title,
              onViewAll: () => _viewAll(row.id),
            ),
          ),
          if (row.loading)
            const AnimeXSkeletonRow(count: 8)
          else if (row.items.isEmpty)
            const SizedBox.shrink()
          else
            AnimeXPosterRow(
              items: row.items,
              onTap: (item) => widget.controller.openWatch(item),
            ),
        ],
      ),
    );
  }

  void _viewAll(String id) {
    switch (id) {
      case 'trending':
        widget.controller.presetBrowse(sort: 'TRENDING_DESC');
      case 'airing':
        widget.controller.presetBrowse(sort: 'SCORE_DESC', status: 'RELEASING');
      case 'seasonal':
        final season = _currentSeason();
        widget.controller.presetBrowse(
          season: season.$1,
          year: season.$2,
          sort: 'POPULARITY_DESC',
        );
      case 'popular':
        widget.controller.presetBrowse(sort: 'POPULARITY_DESC');
      case 'completed':
        widget.controller.presetBrowse(
          sort: 'END_DATE_DESC',
          status: 'FINISHED',
        );
    }
  }

  Widget _buildContinueWatching(
    BuildContext context,
    List<AnimexHistoryEntry> history,
  ) {
    final entries = history.take(12).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimeXSectionHeader(
              icon: Icons.play_circle_fill_rounded,
              title: 'Continue Watching',
              onViewAll: () => widget.controller.goTo(AnimexPage.history),
              viewAllLabel: 'History',
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final e = entries[i];
                return _ContinueCard(
                  entry: e,
                  onTap: () => widget.controller.openWatch(
                    mediaItemFromHistory(e),
                    episode: e.episode,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.controller.goTo(AnimexPage.schedule),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: AnimeXTokens.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
                border: Border.all(
                  color: AnimeXTokens.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AnimeXTokens.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Airing Schedule',
                          style: dmSansStyle(
                            size: 15,
                            color: AnimeXTokens.textPrimary,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "See what's airing this week — all 7 days",
                          style: dmSansStyle(
                            size: 12.5,
                            color: AnimeXTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AnimeXTokens.accent,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final AnimexHistoryEntry entry;
  final VoidCallback onTap;

  const _ContinueCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = entry.episodeMinutes > 0
        ? (entry.durationSeconds / (entry.episodeMinutes * 60)).clamp(0.0, 1.0)
        : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnimeXTokens.radius2xl),
            border: Border.all(color: AnimeXTokens.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (entry.coverUrl.isNotEmpty)
                Image.network(
                  entry.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: AnimeXTokens.surfaceRaised),
                )
              else
                Container(color: AnimeXTokens.surfaceRaised),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xE6000000),
                      Color(0x66000000),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimeXBadge(
                      label: 'EP ${entry.episode}',
                      kind: AnimeXBadgeKind.airing,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: bebasStyle(size: 24, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AnimeXTokens.accent),
                      ),
                    ),
                  ],
                ),
              ),
              const Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AnimeXTokens.accent,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(String, int) _currentSeason() {
  final now = DateTime.now();
  final month = now.month;
  final String season;
  if (month >= 3 && month <= 5) {
    season = 'SPRING';
  } else if (month >= 6 && month <= 8) {
    season = 'SUMMER';
  } else if (month >= 9 && month <= 11) {
    season = 'FALL';
  } else {
    season = 'WINTER';
  }
  return (season, now.year);
}
