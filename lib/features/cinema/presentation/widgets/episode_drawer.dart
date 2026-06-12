import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/services/auth_service.dart';
import '../screens/video_player_screen.dart';

class EpisodeDrawer extends StatefulWidget {
  final MediaItem item;

  const EpisodeDrawer({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  State<EpisodeDrawer> createState() => _EpisodeDrawerState();
}

class _EpisodeDrawerState extends State<EpisodeDrawer> {
  final TMDBService _tmdbService = TMDBService();
  bool _isLoadingDetails = true;
  bool _isLoadingEpisodes = false;
  Map<String, dynamic>? _details;
  List<dynamic> _seasons = [];
  int? _selectedSeasonNumber;
  List<dynamic> _episodes = [];
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.item.status;
    _fetchMediaDetails();
  }

  Future<void> _fetchMediaDetails() async {
    setState(() => _isLoadingDetails = true);
    final details = await _tmdbService.fetchMediaDetails(widget.item.tmdbId, widget.item.mediaType);
    if (mounted) {
      setState(() {
        _details = details;
        _isLoadingDetails = false;
        if (widget.item.mediaType == 'tv' && details != null) {
          _seasons = details['seasons'] ?? [];
          // Find first valid season
          if (_seasons.isNotEmpty) {
            final firstSeason = _seasons.firstWhere(
              (s) => s['season_number'] != null && s['season_number'] > 0,
              orElse: () => _seasons.first,
            );
            _selectedSeasonNumber = firstSeason['season_number'];
            if (_selectedSeasonNumber != null) {
              _fetchSeasonEpisodes(_selectedSeasonNumber!);
            }
          }
        }
      });
    }
  }

  Future<void> _fetchSeasonEpisodes(int seasonNumber) async {
    setState(() => _isLoadingEpisodes = true);
    final episodes = await _tmdbService.fetchSeasonEpisodes(widget.item.tmdbId, seasonNumber);
    if (mounted) {
      setState(() {
        _episodes = episodes;
        _isLoadingEpisodes = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_currentStatus == newStatus) {
      setState(() => _currentStatus = '');
      await _tmdbService.removeFromWatchList(widget.item.tmdbId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from watchlist! 🍿'),
            backgroundColor: AppTheme.deepRose,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() => _currentStatus = newStatus);
      await _tmdbService.saveToWatchList(widget.item, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updated watchlist status! 🍿'),
            backgroundColor: AppTheme.deepRose,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _playMovie() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          tmdbId: widget.item.tmdbId,
          mediaType: 'movie',
          title: widget.item.title,
        ),
      ),
    );
  }

  void _playEpisode(int season, int episode, String epTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          tmdbId: widget.item.tmdbId,
          mediaType: 'tv',
          season: season,
          episode: episode,
          title: '${widget.item.title} - S${season}E${episode}: $epTitle',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rating = _details?['vote_average']?.toStringAsFixed(1) ?? 'N/A';
    final releaseDate = widget.item.mediaType == 'movie'
        ? (_details?['release_date'] ?? '')
        : (_details?['first_air_date'] ?? '');
    final year = releaseDate.isNotEmpty ? releaseDate.split('-')[0] : '';
    final backdropPath = _details?['backdrop_path'];
    final backdropUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w500$backdropPath'
        : widget.item.posterPath;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.twilight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: CustomScrollView(
          slivers: [
            // Backdrop Image
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(backdropUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppTheme.twilight,
                          AppTheme.twilight.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 15,
                    right: 15,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Metadata & Overview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.roseQuartz,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (year.isNotEmpty) ...[
                          Text(
                            year,
                            style: GoogleFonts.outfit(
                              color: AppTheme.petalWhite.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 15),
                        ],
                        const Icon(Icons.star_rounded, color: AppTheme.warmAmber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$rating / 10',
                          style: GoogleFonts.outfit(
                            color: AppTheme.blushGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.petalWhite.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.item.mediaType.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: AppTheme.petalWhite.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // Status Actions: Want to watch / Watched by Khent / Clair / Both
                    Text(
                      'Watchlist Status',
                      style: GoogleFonts.outfit(
                        color: AppTheme.roseQuartz.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip('Want to Watch', 'to-watch'),
                          const SizedBox(width: 8),
                          _buildStatusChip('Khent Watched', 'watched-khent'),
                          const SizedBox(width: 8),
                          _buildStatusChip('Clair Watched', 'watched-clair'),
                          const SizedBox(width: 8),
                          _buildStatusChip('Both Watched', 'watched-both'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description / Overview
                    Text(
                      _details?['overview'] ?? widget.item.title,
                      style: GoogleFonts.outfit(
                        color: AppTheme.petalWhite.withOpacity(0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Movie Button or TV Layout
                    if (widget.item.mediaType == 'movie')
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _playMovie,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.deepRose,
                            foregroundColor: AppTheme.petalWhite,
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                          label: Text(
                            'PLAY MOVIE',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      )
                    else ...[
                      // Season Selector Dropdown
                      if (_seasons.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Episodes',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.roseQuartz,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.velvet,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.roseQuartz.withOpacity(0.3)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedSeasonNumber,
                                  dropdownColor: AppTheme.velvet,
                                  icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.roseQuartz),
                                  style: GoogleFonts.outfit(color: AppTheme.petalWhite, fontWeight: FontWeight.bold),
                                  onChanged: (int? value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedSeasonNumber = value;
                                      });
                                      _fetchSeasonEpisodes(value);
                                    }
                                  },
                                  items: _seasons
                                      .where((s) => s['season_number'] != null)
                                      .map<DropdownMenuItem<int>>((s) {
                                    return DropdownMenuItem<int>(
                                      value: s['season_number'],
                                      child: Text(s['name'] ?? 'Season ${s['season_number']}'),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Episodes List (only for TV series)
            if (widget.item.mediaType == 'tv') ...[
              if (_isLoadingEpisodes)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: AppTheme.deepRose),
                    ),
                  ),
                )
              else if (_episodes.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        'No episodes found for this season.',
                        style: GoogleFonts.outfit(color: AppTheme.petalWhite.withOpacity(0.5)),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final ep = _episodes[index];
                      final epNum = ep['episode_number'] ?? (index + 1);
                      final epName = ep['name'] ?? 'Episode $epNum';
                      final epOverview = ep['overview'] ?? 'No description available.';
                      final epStillPath = ep['still_path'];
                      final epStillUrl = epStillPath != null
                          ? 'https://image.tmdb.org/t/p/w300$epStillPath'
                          : null;

                      return InkWell(
                        onTap: () => _playEpisode(_selectedSeasonNumber ?? 1, epNum, epName),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Episode Thumbnail or placeholder
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 120,
                                  height: 70,
                                  color: AppTheme.velvet,
                                  child: epStillUrl != null
                                      ? Image.network(epStillUrl, fit: BoxFit.cover)
                                      : const Center(
                                          child: Icon(Icons.tv_rounded, color: AppTheme.roseQuartz),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Episode Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$epNum. $epName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.petalWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      epOverview,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.petalWhite.withOpacity(0.6),
                                        fontSize: 12,
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
                    childCount: _episodes.length,
                  ),
                ),
            ],
            // Padding bottom
            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String status) {
    final isSelected = _currentStatus == status;
    return GestureDetector(
      onTap: () => _updateStatus(status),
      child: Chip(
        label: Text(label),
        labelStyle: GoogleFonts.outfit(
          color: isSelected ? AppTheme.petalWhite : AppTheme.roseQuartz,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: isSelected ? AppTheme.deepRose : AppTheme.velvet,
        side: BorderSide(
          color: isSelected ? AppTheme.deepRose : AppTheme.roseQuartz.withOpacity(0.3),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}
