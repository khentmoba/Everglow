import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import 'drawer_helpers.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/utils/tmdb_images.dart';
import '../../../../../shared/widgets/app_network_image.dart';

/// Data class for anime season navigation entries. Each entry represents one
/// season of a multi-season anime series, built from AniList SEQUEL/PREQUEL
/// relations. The current season is marked with [isCurrent].
class SeasonNavItem {
  final int id;
  final int? malId;
  final String title;
  final String? coverImageUrl;
  final bool isCurrent;
  final String relationType;

  const SeasonNavItem({
    required this.id,
    this.malId,
    required this.title,
    this.coverImageUrl,
    required this.isCurrent,
    required this.relationType,
  });
}

/// Renders the episodes section: season header with dropdown, loading state,
/// empty state, and the list of episode tiles.
class EpisodeListSection extends StatelessWidget {
  final List<dynamic> episodes;
  final List<dynamic> seasons;
  final int? selectedSeasonNumber;
  final bool isLoadingEpisodes;
  final int? tmdbMatchedSeason;
  final void Function(int season, int episode, String title) onPlayEpisode;
  final void Function(int seasonNumber) onSeasonChanged;

  /// Opt-in for Cinema only; anime keeps its existing metadata behavior.
  final bool hideSpoilers;

  const EpisodeListSection({
    super.key,
    required this.episodes,
    required this.seasons,
    this.selectedSeasonNumber,
    required this.isLoadingEpisodes,
    this.tmdbMatchedSeason,
    required this.onPlayEpisode,
    required this.onSeasonChanged,
    this.hideSpoilers = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (seasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _buildEpisodeHeader(),
          ),
        if (isLoadingEpisodes)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.deepRose,
                strokeWidth: 2,
              ),
            ),
          )
        else if (episodes.isEmpty)
          buildEmptySection('No episodes for this season')
        else
          ...List.generate(
            episodes.length,
            (index) => _buildEpisodeTile(episodes[index], index),
          ),
      ],
    );
  }

  Widget _buildEpisodeHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Episodes',
              style: AppTypography.cormorantExtraBoldWhite.copyWith(
                fontSize: 22,
              ),
            ),
            Text(
              'SELECT AN EPISODE TO PLAY',
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 9,
                color: AppColors.mutedPurple,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        // Season dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.shimmerBase,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.roseQuartz.withValues(alpha: 0.2),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedSeasonNumber,
              dropdownColor: AppColors.shimmerBase,
              isDense: true,
              icon: const Icon(
                Icons.expand_more_rounded,
                color: AppColors.deepRose,
                size: 18,
              ),
              style: AppTypography.outfitBold.copyWith(fontSize: 13),
              onChanged: (int? value) {
                if (value != null) {
                  onSeasonChanged(value);
                }
              },
              items: seasons
                  .where((s) => s['season_number'] is int)
                  .map<DropdownMenuItem<int>>((s) {
                    return DropdownMenuItem<int>(
                      value: s['season_number'] as int,
                      child: Text(s['name'] ?? 'Season ${s['season_number']}'),
                    );
                  })
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeTile(dynamic ep, int index) {
    final epSeason =
        (ep['season_number'] as int?) ??
        tmdbMatchedSeason ??
        selectedSeasonNumber ??
        1;
    final epNum = ep['episode_number'] ?? (index + 1);
    final epName = ep['name'] ?? 'Episode $epNum';
    final epOverview = ep['overview'] ?? '';

    final epStillPath = ep['still_path'];
    final isFullUrl =
        epStillPath != null &&
        (epStillPath.startsWith('http://') ||
            epStillPath.startsWith('https://'));
    final epStillUrl = epStillPath != null
        ? (isFullUrl
              ? _proxyIfBlocked(epStillPath)
              : TmdbImages.stillFor(epStillPath))
        : null;

    return EpisodeTile(
      key: ValueKey('$epSeason/$epNum'),
      hideSpoilers: hideSpoilers,
      epNum: epNum,
      epName: epName,
      epOverview: epOverview,
      stillUrl: epStillUrl,
      onTap: () => onPlayEpisode(
        epSeason,
        epNum,
        hideSpoilers ? 'Episode $epNum' : epName,
      ),
    );
  }

  String? _proxyIfBlocked(String url) {
    // Crunchyroll and other streaming CDNs don't send CORS headers, so
    // the browser drops these image loads. Route them through the
    // server-side proxy that adds permissive CORS headers.
    try {
      final parsed = Uri.parse(url);
      if (parsed.host.endsWith('.crunchyroll.com') ||
          parsed.host.endsWith('.funimation.com')) {
        return '$proxyAnimeImageUrl?url=${Uri.encodeComponent(url)}';
      }
    } catch (e) {
      debugPrint('[EpisodeDrawer] Failed to proxy blocked image URL: $e');
    }
    return url;
  }
}

// ═══════════════════════════════════════════════════════════════
// EPISODE TILE WIDGET
// ═══════════════════════════════════════════════════════════════

class EpisodeTile extends StatefulWidget {
  final int epNum;
  final String epName;
  final String epOverview;
  final String? stillUrl;
  final VoidCallback onTap;

  /// Highlights the tile as the currently playing episode (player use).
  final bool selected;
  final bool hideSpoilers;

  const EpisodeTile({
    super.key,
    required this.epNum,
    required this.epName,
    required this.epOverview,
    this.stillUrl,
    required this.onTap,
    this.selected = false,
    this.hideSpoilers = false,
  });

  @override
  State<EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<EpisodeTile> {
  bool _pressed = false;

  /// Revealed inline on this row — no drawer. Scoped to the tile so
  /// expanding one episode leaves its neighbours closed.
  bool _revealed = false;

  /// Fixed tile height. Set explicitly because the parent SliverList
  /// provides unbounded vertical space — without an explicit height
  /// the Row collapses to the title's one-line intrinsic height and
  /// the rail + play button render at zero visible height. The
  /// title is clipped to 1 line so 80px always fits.
  static const double _tileHeight = 80;

  @override
  void didUpdateWidget(covariant EpisodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un-hiding spoilers shows everything anyway; don't carry the
    // expansion back when the switch goes on again.
    if (oldWidget.hideSpoilers && !widget.hideSpoilers) {
      _revealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stills are atmosphere, not plot: a frame from the episode gives
    // nothing away, so they stay visible while the name/story wait to
    // be asked for.
    final hasThumb = widget.stillUrl != null && widget.stillUrl!.isNotEmpty;
    final hidden = widget.hideSpoilers && !_revealed;
    return Semantics(
      button: true,
      label: 'Play episode ${widget.epNum}',
      onTap: widget.onTap,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: SizedBox(
          // Compact rows are a fixed 80px; a revealed row grows to fit
          // whatever it shows. Both are snapped, not animated: the
          // revealed text lands in full on the first frame, so a
          // growing box would flash an overflow stripe on its way up.
          height: _revealed ? null : _tileHeight,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: _pressed
                  ? AppColors.shimmerBase.withValues(alpha: 0.8)
                  : AppColors.shimmerBase.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.selected
                    ? AppColors.deepRose.withValues(alpha: 0.65)
                    : AppColors.roseQuartz.withValues(alpha: 0.08),
                width: widget.selected ? 1.4 : 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Row(
                children: [
                  // Left rail: thumbnail (when available) or numbered
                  // accent. Kept at tile height so an expanded row grows
                  // the story, not a tall crop of the same frame.
                  SizedBox(
                    height: _tileHeight,
                    child: hasThumb
                        ? _buildThumbnailRail()
                        : _buildNumberedRail(),
                  ),
                  const SizedBox(width: 12),
                  // Title + overview
                  Expanded(
                    child: Padding(
                      // 80px minus the tile's own 5px margins, 1px
                      // border each side and this padding leaves 56px
                      // of text: a 1-line title plus a 2-line story
                      // fits with room to spare. 10px padding did not.
                      padding: EdgeInsets.symmetric(vertical: hidden ? 0 : 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hidden ? 'Episode ${widget.epNum}' : widget.epName,
                            // 1 line unless expanded: a 2-line title plus a
                            // 2-line story does not fit the 80px row and used
                            // to overflow it instead of ellipsizing.
                            maxLines: _revealed ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitHeading.copyWith(
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                          if (hidden)
                            SizedBox(
                              height: 48,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: AppColors.deepRose,
                                ),
                                onPressed: () =>
                                    setState(() => _revealed = true),
                                child: const Text('Reveal details'),
                              ),
                            )
                          else ...[
                            if (widget.epOverview.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.epOverview,
                                maxLines: _revealed ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitWhite.copyWith(
                                  color: AppColors.mutedPurple,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (_revealed)
                              GestureDetector(
                                onTap: () => setState(() => _revealed = false),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Hide details',
                                    style: AppTypography.outfitWhite.copyWith(
                                      color: AppColors.deepRose,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Right side action column: solo play (top) + Watch
                  // Together (bottom). Two stacked 32px circles fit
                  // within the 80px tile height with vertical padding.
                  // The solo play preserves the existing tap behaviour;
                  // the heart opens a watch-party directly.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: widget.selected
                                ? AppColors.deepRose
                                : AppColors.deepRose.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.deepRose.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            widget.selected
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: widget.selected
                                ? Colors.white
                                : AppColors.deepRose,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Typography rail — 64px wide so the episode number is large
  /// enough to read at a glance, filling the full 80px height of
  /// the row.
  Widget _buildNumberedRail() {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.deepRose.withValues(alpha: _pressed ? 0.2 : 0.12),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          bottomLeft: Radius.circular(15),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.epNum.toString().padLeft(2, '0'),
        style: AppTypography.cormorantBlack.copyWith(
          fontSize: 28,
          height: 1,
          color: AppColors.deepRose,
        ),
      ),
    );
  }

  /// Thumbnail rail. 96px wide so a 16:9 still crops to roughly
  /// the same vertical footprint as the numbered rail at 80px.
  /// The episode number sits bottom-left over a dark gradient so
  /// it's legible on bright frames.
  Widget _buildThumbnailRail() {
    return Container(
      width: 96,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          bottomLeft: Radius.circular(15),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          bottomLeft: Radius.circular(15),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              imageUrl: widget.stillUrl!,
              fit: BoxFit.cover,
              cacheWidth: 300,
              placeholder: _buildThumbSkeleton(),
              errorWidget: _buildNumberedRail(),
            ),
            // Dark gradient on the left so the number stays legible
            // on bright frames.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x99000000), Colors.transparent],
                  stops: [0.0, 0.55],
                ),
              ),
            ),
            // Episode number, bottom-left.
            Positioned(
              left: 10,
              bottom: 6,
              child: Text(
                widget.epNum.toString().padLeft(2, '0'),
                style: AppTypography.cormorantBlackWhite.copyWith(
                  fontSize: 20,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbSkeleton() {
    // Static, not a spinner: the rail is 96px wide, a spinner there is
    // noise, and it would keep the list animating forever.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.shimmerBase, AppColors.deepBlack],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_outlined,
        size: 22,
        color: AppColors.deepRose.withValues(alpha: 0.4),
      ),
    );
  }
}
