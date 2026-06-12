import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
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
  bool _isLoadingEpisodes = false;
  bool _isLoadingCast = true;
  bool _isLoadingReviews = true;
  bool _isLoadingSimilar = true;
  Map<String, dynamic>? _details;
  List<dynamic> _seasons = [];
  int? _selectedSeasonNumber;
  List<dynamic> _episodes = [];
  List<Map<String, dynamic>> _cast = [];
  List<Map<String, dynamic>> _reviews = [];
  List<MediaItem> _similar = [];
  late String _currentStatus;
  List<String> _genreNames = [];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.item.status;
    _fetchMediaDetails();
    _fetchCast();
    _fetchReviews();
    _fetchSimilar();
  }

  Future<void> _fetchMediaDetails() async {
    final details = await _tmdbService.fetchMediaDetails(widget.item.tmdbId, widget.item.mediaType);
    if (mounted) {
      setState(() {
        _details = details;
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
        // Parse genre names
        if (details != null && details['genres'] != null) {
          _genreNames = (details['genres'] as List)
              .map<String>((g) => g['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
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

  Future<void> _fetchCast() async {
    setState(() => _isLoadingCast = true);
    final cast = await _tmdbService.fetchCredits(widget.item.tmdbId, widget.item.mediaType);
    if (mounted) {
      setState(() {
        _cast = cast;
        _isLoadingCast = false;
      });
    }
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoadingReviews = true);
    final reviews = await _tmdbService.fetchReviews(widget.item.tmdbId, widget.item.mediaType);
    if (mounted) {
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _fetchSimilar() async {
    setState(() => _isLoadingSimilar = true);
    final similar = await _tmdbService.fetchSimilar(widget.item.tmdbId, widget.item.mediaType);
    if (mounted) {
      setState(() {
        _similar = similar;
        _isLoadingSimilar = false;
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
            content: Text('Removed from watchlist!'),
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
            content: Text('Updated watchlist status!'),
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

  void _showSimilarItem(MediaItem item) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpisodeDrawer(item: item),
    );
  }

  String _getReviewerInitial(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      AppTheme.deepRose,
      AppTheme.warmAmber,
      AppTheme.softLavender,
      AppTheme.blushGold,
      AppTheme.roseQuartz,
    ];
    if (name.isEmpty) return AppTheme.deepRose;
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final rating = _details?['vote_average']?.toStringAsFixed(1) ?? 'N/A';
    final releaseDate = widget.item.mediaType == 'movie'
        ? (_details?['release_date'] ?? '')
        : (_details?['first_air_date'] ?? '');
    final year = releaseDate.isNotEmpty ? releaseDate.split('-')[0] : widget.item.year;
    final runtime = _details?['runtime'] ?? _details?['episode_run_time']?[0];
    final backdropPath = _details?['backdrop_path'];
    final backdropUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w500$backdropPath'
        : widget.item.posterPath;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
                              fontWeight: FontWeight.w500,
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
                        if (runtime != null) ...[
                          const SizedBox(width: 15),
                          Text(
                            '${runtime}m',
                            style: GoogleFonts.outfit(
                              color: AppTheme.petalWhite.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Genre chips
                    if (_genreNames.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _genreNames.map((g) => _buildGenreChip(g)).toList(),
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

            // CAST section
            SliverToBoxAdapter(
              child: _buildSectionHeader('Cast', icon: Icons.people_rounded),
            ),
            SliverToBoxAdapter(
              child: _buildCastSection(),
            ),

            // USER REVIEWS section
            SliverToBoxAdapter(
              child: _buildSectionHeader('User Reviews', icon: Icons.rate_review_rounded),
            ),
            SliverToBoxAdapter(
              child: _buildReviewsSection(),
            ),

            // MORE LIKE THIS section
            SliverToBoxAdapter(
              child: _buildSectionHeader('More Like This', icon: Icons.movie_filter_rounded),
            ),
            SliverToBoxAdapter(
              child: _buildSimilarSection(),
            ),

            // Padding bottom
            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppTheme.roseQuartz, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.deepRose.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.deepRose.withOpacity(0.4)),
      ),
      child: Text(
        name,
        style: GoogleFonts.outfit(
          color: AppTheme.petalWhite,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCastSection() {
    if (_isLoadingCast) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(color: AppTheme.deepRose, strokeWidth: 2),
          ),
        ),
      );
    }
    if (_cast.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          'No cast information available.',
          style: GoogleFonts.outfit(color: AppTheme.petalWhite.withOpacity(0.5), fontSize: 13),
        ),
      );
    }
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final member = _cast[index];
          return SizedBox(
            width: 90,
            child: Column(
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.velvet,
                    border: Border.all(color: AppTheme.roseQuartz.withOpacity(0.3), width: 1.5),
                  ),
                  child: ClipOval(
                    child: (member['profilePath'] ?? '').toString().isNotEmpty
                        ? Image.network(
                            member['profilePath'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                _getReviewerInitial(member['name'] ?? '?'),
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.roseQuartz,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _getReviewerInitial(member['name'] ?? '?'),
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.roseQuartz,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  member['name'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: AppTheme.petalWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((member['character'] ?? '').toString().isNotEmpty)
                  Text(
                    member['character'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppTheme.roseQuartz.withOpacity(0.7),
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_isLoadingReviews) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(color: AppTheme.deepRose, strokeWidth: 2),
          ),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          'No reviews yet. Be the first to share your thoughts!',
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withOpacity(0.5),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _reviews.map((review) {
          final author = review['author'] ?? 'Anonymous';
          final content = (review['content'] ?? '').toString();
          final rating = review['rating'];
          // Trim very long reviews for display
          final preview = content.length > 280 ? '${content.substring(0, 280)}…' : content;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.velvet.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.roseQuartz.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getAvatarColor(author),
                      ),
                      alignment: Alignment.center,
                      child: (review['avatar'] ?? '').toString().isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                review['avatar'],
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  _getReviewerInitial(author),
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.petalWhite,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              _getReviewerInitial(author),
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.petalWhite,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: AppTheme.petalWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (rating != null)
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: AppTheme.warmAmber, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  rating.toString(),
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.blushGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  preview,
                  style: GoogleFonts.outfit(
                    color: AppTheme.petalWhite.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSimilarSection() {
    if (_isLoadingSimilar) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(color: AppTheme.deepRose, strokeWidth: 2),
          ),
        ),
      );
    }
    if (_similar.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          'No similar titles found.',
          style: GoogleFonts.outfit(color: AppTheme.petalWhite.withOpacity(0.5), fontSize: 13),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _similar.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _similar[index];
          return GestureDetector(
            onTap: () => _showSimilarItem(item),
            child: SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.posterPath.isNotEmpty
                            ? Image.network(item.posterPath, fit: BoxFit.cover)
                            : Container(
                                color: AppTheme.velvet,
                                child: const Center(
                                  child: Icon(Icons.movie_creation_outlined, color: AppTheme.roseQuartz),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item.year.isNotEmpty ? item.year : (item.mediaType == 'movie' ? 'Movie' : 'Series'),
                    style: GoogleFonts.outfit(
                      color: AppTheme.blushGold.withOpacity(0.7),
                      fontSize: 10,
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

  Widget _buildStatusChip(String label, String status) {
    final isSelected = _currentStatus == status;
    return GestureDetector(
      onTap: () => _updateStatus(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.deepRose : AppTheme.velvet,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.deepRose : AppTheme.roseQuartz.withOpacity(0.25),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.deepRose.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? AppTheme.petalWhite : AppTheme.roseQuartz.withOpacity(0.8),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
