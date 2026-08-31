import 'package:flutter/material.dart';

import '../../data/services/tmdb_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';

/// Horizontal scrollable season selector + episode grid for TV content.
/// Fetches season/episode data from TMDB and lets the user pick an episode
/// to play. Uses TMDB still images (w400) for episode thumbnails.
class EpisodeNavigator extends StatefulWidget {
  final int tmdbId;
  final int initialSeason;
  final int initialEpisode;
  final ValueChanged<int> onSeasonChanged;
  final ValueChanged<int> onEpisodeChanged;

  const EpisodeNavigator({
    super.key,
    required this.tmdbId,
    required this.initialSeason,
    required this.initialEpisode,
    required this.onSeasonChanged,
    required this.onEpisodeChanged,
  });

  @override
  State<EpisodeNavigator> createState() => _EpisodeNavigatorState();
}

class _EpisodeNavigatorState extends State<EpisodeNavigator> {
  final TMDBService _tmdbService = TMDBService();

  late int _selectedSeason;
  late int _selectedEpisode;
  List<Map<String, dynamic>> _seasons = [];
  List<Map<String, dynamic>> _episodes = [];
  bool _isLoadingSeasons = true;
  bool _isLoadingEpisodes = true;
  bool _expanded = false;

  static const _imageBase = 'https://image.tmdb.org/t/p/w400';

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.initialSeason;
    _selectedEpisode = widget.initialEpisode;
    _fetchSeasons();
  }

  Future<void> _fetchSeasons() async {
    setState(() => _isLoadingSeasons = true);
    final details = await _tmdbService.fetchTVShowDetails(widget.tmdbId);
    if (!mounted) return;
    if (details != null) {
      final rawSeasons = (details['seasons'] as List?) ?? [];
      _seasons = rawSeasons.map((s) => s as Map<String, dynamic>).where((s) {
        final seasonNum = s['season_number'];
        // Filter out season 0 (specials) unless it's the only one
        return seasonNum is int && seasonNum > 0;
      }).toList();
    }
    setState(() => _isLoadingSeasons = false);
    if (_seasons.isNotEmpty) {
      _fetchEpisodes(_selectedSeason);
    }
  }

  Future<void> _fetchEpisodes(int seasonNumber) async {
    setState(() => _isLoadingEpisodes = true);
    final raw = await _tmdbService.fetchSeasonEpisodes(
      widget.tmdbId,
      seasonNumber,
    );
    if (!mounted) return;
    _episodes = raw.map((e) => e as Map<String, dynamic>).toList();
    setState(() => _isLoadingEpisodes = false);
  }

  void _selectSeason(int seasonNum) {
    if (seasonNum == _selectedSeason) return;
    setState(() => _selectedSeason = seasonNum);
    _fetchEpisodes(seasonNum);
    widget.onSeasonChanged(seasonNum);
  }

  void _selectEpisode(int episodeNum) {
    if (episodeNum == _selectedEpisode) return;
    setState(() => _selectedEpisode = episodeNum);
    widget.onEpisodeChanged(episodeNum);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle bar
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D14),
              border: Border(
                top: BorderSide(color: Colors.grey[900]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Episodes',
                  style: AppTypography.outfitHeading.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                if (!_isLoadingSeasons && _seasons.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'S$_selectedSeason',
                      style: AppTypography.outfitBold.copyWith(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Expanded content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildContent(),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Container(
      color: const Color(0xFF0A0A12),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Season selector
          if (_isLoadingSeasons)
            _buildLoadingSkeleton()
          else if (_seasons.isEmpty)
            _buildNoSeasons()
          else ...[
            _buildSeasonSelector(),
            const SizedBox(height: 8),
            // Episode grid
            if (_isLoadingEpisodes)
              _buildLoadingSkeleton()
            else if (_episodes.isEmpty)
              _buildNoEpisodes()
            else
              _buildEpisodeGrid(),
          ],
        ],
      ),
    );
  }

  Widget _buildSeasonSelector() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _seasons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final season = _seasons[index];
          final seasonNum = season['season_number'] as int? ?? 1;
          final name = season['name'] as String? ?? 'Season $seasonNum';
          final isSelected = seasonNum == _selectedSeason;
          return GestureDetector(
            onTap: () => _selectSeason(seasonNum),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.deepRose.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.deepRose.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                name,
                style: AppTypography.outfitHeading.copyWith(
                  color: isSelected ? AppColors.deepRose : Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeGrid() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _episodes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final ep = _episodes[index];
          final epNum = ep['episode_number'] as int? ?? index + 1;
          final name = ep['name'] as String? ?? 'Episode $epNum';
          final stillPath = ep['still_path'] as String?;
          final isSelected = epNum == _selectedEpisode;
          return GestureDetector(
            onTap: () => _selectEpisode(epNum),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 180,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.deepRose.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.deepRose.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(9),
                    ),
                    child: SizedBox(
                      width: 180,
                      height: 76,
                      child: stillPath != null && stillPath.isNotEmpty
                          ? Image.network(
                              '$_imageBase$stillPath',
                              fit: BoxFit.cover,
                              cacheWidth: 360,
                              errorBuilder: (_, _, _) =>
                                  _buildPlaceholder(epNum),
                            )
                          : _buildPlaceholder(epNum),
                    ),
                  ),
                  // Info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFFC2185B,
                                      ).withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'E$epNum',
                                style: AppTypography.outfitHeading.copyWith(
                                  fontSize: 8,
                                  color: isSelected
                                      ? AppColors.deepRose
                                      : Colors.white54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder(int epNum) {
    return Container(
      color: AppColors.shimmerBase,
      alignment: Alignment.center,
      child: Text(
        'E$epNum',
        style: AppTypography.outfitWhite.copyWith(
          color: Colors.white24,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return const SizedBox(
      height: 80,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.deepRose,
          ),
        ),
      ),
    );
  }

  Widget _buildNoSeasons() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'No season data available',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildNoEpisodes() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'No episode data available',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }
}
