import 'package:flutter/material.dart';
import '../../../../shared/utils/tmdb_images.dart';

import '../../data/services/tmdb_service.dart';
import 'episode_drawer_sections/episode_list_section.dart';
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
              _buildEpisodeList(),
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

  /// Vertical episode list shared with the details drawer ([EpisodeTile]).
  ///
  /// The player used to render its own horizontal thumbnail grid, so the
  /// same episodes looked different in two places. Reusing the drawer tile
  /// keeps one episode UI everywhere, with the playing episode highlighted.
  Widget _buildEpisodeList() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            for (var i = 0; i < _episodes.length; i++)
              Builder(
                builder: (context) {
                  final ep = _episodes[i];
                  final epNum = ep['episode_number'] as int? ?? i + 1;
                  final name = ep['name'] as String? ?? 'Episode $epNum';
                  final overview = ep['overview'] as String? ?? '';
                  final stillPath = ep['still_path'] as String?;
                  return EpisodeTile(
                    epNum: epNum,
                    epName: name,
                    epOverview: overview,
                    stillUrl:
                        (stillPath != null && stillPath.isNotEmpty)
                        ? TmdbImages.stillFor(stillPath)
                        : null,
                    selected: epNum == _selectedEpisode,
                    onTap: () => _selectEpisode(epNum),
                  );
                },
              ),
          ],
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
