import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import 'drawer_helpers.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/utils/tmdb_images.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../netflix/netflix_colors.dart';

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

/// True when saved progress means this episode's details are already safe.
bool shouldRevealEpisodeDetails({
  required int season,
  required int episode,
  int? currentSeason,
  int? currentEpisode,
  int currentPositionSeconds = 0,
  int currentDurationSeconds = 0,
  bool allEpisodesWatched = false,
  bool currentEpisodeCompleted = false,
}) {
  if (allEpisodesWatched) return true;
  final savedSeason = currentSeason;
  final savedEpisode = currentEpisode;
  if (savedSeason == null || savedEpisode == null) return false;
  if (season < savedSeason) return true;
  if (season > savedSeason || episode > savedEpisode) return false;
  if (episode < savedEpisode) return true;
  return currentEpisodeCompleted ||
      (currentDurationSeconds > 0 &&
          currentPositionSeconds / currentDurationSeconds >= 0.95);
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
  final int? currentSeason;
  final int? currentEpisode;
  final int currentPositionSeconds;
  final int currentDurationSeconds;
  final bool allEpisodesWatched;

  /// When true, renders Netflix-style wide episode rows with index numbers,
  /// 16:9 thumbnail previews, title + duration, and overview snippets.
  final bool netflixStyle;

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
    this.currentSeason,
    this.currentEpisode,
    this.currentPositionSeconds = 0,
    this.currentDurationSeconds = 0,
    this.allEpisodesWatched = false,
    this.netflixStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (seasons.isNotEmpty || netflixStyle)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _buildEpisodeHeader(),
          ),
        if (isLoadingEpisodes)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(
                color: netflixStyle ? NetflixColors.accent : AppColors.deepRose,
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
    if (netflixStyle) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Episodes',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          if (seasons.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: NetflixColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedSeasonNumber,
                  dropdownColor: NetflixColors.surfaceElevated,
                  isDense: true,
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  onChanged: (int? value) {
                    if (value != null) {
                      onSeasonChanged(value);
                    }
                  },
                  items: seasons
                      .where((s) => s['season_number'] is int)
                      .map<DropdownMenuItem<int>>((s) {
                        final epCount = s['episode_count'];
                        final countStr = epCount != null
                            ? ' ($epCount Episodes)'
                            : '';
                        return DropdownMenuItem<int>(
                          value: s['season_number'] as int,
                          child: Text(
                            '${s['name'] ?? 'Season ${s['season_number']}'}$countStr',
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
            ),
        ],
      );
    }

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
    final epNum = ep['episode_number'] as int? ?? index + 1;
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
    final revealDetails =
        hideSpoilers &&
        shouldRevealEpisodeDetails(
          season: epSeason,
          episode: epNum,
          currentSeason: currentSeason,
          currentEpisode: currentEpisode,
          currentPositionSeconds: currentPositionSeconds,
          currentDurationSeconds: currentDurationSeconds,
          allEpisodesWatched: allEpisodesWatched,
        );

    final durationMin = ep['runtime'] as int?;
    final durationStr = durationMin != null && durationMin > 0
        ? '${durationMin}m'
        : '';

    final isCurrentEpisode =
        currentSeason == epSeason && currentEpisode == epNum;
    final epProgress = isCurrentEpisode && currentDurationSeconds > 0
        ? (currentPositionSeconds / currentDurationSeconds).clamp(0.0, 1.0)
        : (allEpisodesWatched ||
              (currentSeason != null &&
                  currentEpisode != null &&
                  (epSeason < currentSeason! ||
                      (epSeason == currentSeason! && epNum < currentEpisode!))))
        ? 1.0
        : 0.0;

    return EpisodeTile(
      key: ValueKey('$epSeason/$epNum'),
      hideSpoilers: hideSpoilers,
      revealedByProgress: revealDetails,
      epNum: epNum,
      epName: epName,
      epOverview: epOverview,
      stillUrl: epStillUrl,
      durationStr: durationStr,
      progress: epProgress,
      netflixStyle: netflixStyle,
      onTap: () => onPlayEpisode(
        epSeason,
        epNum,
        hideSpoilers && !revealDetails ? 'Episode $epNum' : epName,
      ),
    );
  }

  String? _proxyIfBlocked(String url) {
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

// ══════════════════════════════════════════════════════════════════════════════
// EPISODE TILE WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class EpisodeTile extends StatefulWidget {
  final int epNum;
  final String epName;
  final String epOverview;
  final String? stillUrl;
  final VoidCallback onTap;

  /// Highlights the tile as the currently playing episode (player use).
  final bool selected;
  final bool hideSpoilers;
  final bool revealedByProgress;
  final String durationStr;
  final double progress;
  final bool netflixStyle;

  const EpisodeTile({
    super.key,
    required this.epNum,
    required this.epName,
    required this.epOverview,
    this.stillUrl,
    required this.onTap,
    this.selected = false,
    this.hideSpoilers = false,
    this.revealedByProgress = false,
    this.durationStr = '',
    this.progress = 0.0,
    this.netflixStyle = false,
  });

  @override
  State<EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<EpisodeTile> {
  bool _pressed = false;
  bool _hovered = false;

  /// Revealed inline on this row — no drawer. Scoped to the tile so
  /// expanding one episode leaves its neighbours closed.
  bool _revealed = false;

  static const double _tileHeight = 80;

  @override
  void didUpdateWidget(covariant EpisodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hideSpoilers && !widget.hideSpoilers) {
      _revealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasThumb = widget.stillUrl != null && widget.stillUrl!.isNotEmpty;
    final expanded = _revealed || widget.revealedByProgress;
    final hidden = widget.hideSpoilers && !expanded;

    if (widget.netflixStyle) {
      return _buildNetflixEpisodeRow(
        context,
        hasThumb: hasThumb,
        hidden: hidden,
        expanded: expanded,
      );
    }

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
          height: expanded ? null : _tileHeight,
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
                      padding: EdgeInsets.symmetric(vertical: hidden ? 0 : 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hidden ? 'Episode ${widget.epNum}' : widget.epName,
                            maxLines: expanded ? 2 : 1,
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
                                maxLines: expanded ? 3 : 2,
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

  Widget _buildNetflixEpisodeRow(
    BuildContext context, {
    required bool hasThumb,
    required bool hidden,
    required bool expanded,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.07)
                : (_pressed
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.transparent),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Episode number
              SizedBox(
                width: 32,
                child: Text(
                  '${widget.epNum}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.selected
                        ? NetflixColors.accent
                        : Colors.white.withValues(alpha: 0.65),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 14),
              // Thumbnail (16:9)
              SizedBox(
                width: 130,
                height: 74,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasThumb)
                        AppNetworkImage(
                          imageUrl: widget.stillUrl!,
                          fit: BoxFit.cover,
                          placeholder: const ColoredBox(
                            color: NetflixColors.surface,
                          ),
                          errorWidget: const ColoredBox(
                            color: NetflixColors.surface,
                          ),
                        )
                      else
                        Container(
                          color: NetflixColors.surface,
                          child: const Icon(
                            Icons.movie_creation_outlined,
                            color: Colors.white38,
                            size: 28,
                          ),
                        ),
                      // Play icon overlay on hover
                      if (_hovered)
                        Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      // Progress bar along bottom
                      if (widget.progress > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: widget.progress,
                            minHeight: 3.5,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              NetflixColors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Details: title + duration on top line, overview below
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            hidden ? 'Episode ${widget.epNum}' : widget.epName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 14.5,
                              color: widget.selected
                                  ? NetflixColors.accent
                                  : Colors.white,
                            ),
                          ),
                        ),
                        if (widget.durationStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            widget.durationStr,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (hidden)
                      GestureDetector(
                        onTap: () => setState(() => _revealed = true),
                        child: Text(
                          'Reveal details',
                          style: AppTypography.outfitWhite.copyWith(
                            color: NetflixColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (widget.epOverview.isNotEmpty)
                      Text(
                        widget.epOverview,
                        maxLines: expanded ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          color: NetflixColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildThumbnailRail() {
    return SizedBox(
      width: 100,
      height: _tileHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppNetworkImage(
            imageUrl: widget.stillUrl!,
            fit: BoxFit.cover,
            cacheWidth: 300,
            placeholder: const ColoredBox(color: AppColors.shimmerBase),
            errorWidget: const ColoredBox(color: AppColors.shimmerBase),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 6,
            child: Text(
              'EP ${widget.epNum}',
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 11,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
