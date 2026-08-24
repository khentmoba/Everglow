import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/anilist_detail.dart';
import '../../data/models/media_item.dart';
import '../../data/services/ani_zip_service.dart';
import '../../data/services/anilist_service.dart';
import '../../data/services/jikan_service.dart';
import '../../data/services/tmdb_service.dart';
import '../../../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'episode_drawer_sections/drawer_helpers.dart';
import 'episode_drawer_sections/episode_list_section.dart';
import 'episode_drawer_sections/cast_section.dart';
import 'episode_drawer_sections/reviews_section.dart';
import 'episode_drawer_sections/similar_section.dart';
import 'episode_drawer_sections/trailer_section.dart';
import '../../../../core/theme/app_typography.dart';
import 'episode_drawer_sections/cinema/cinema_hero.dart';
import 'episode_drawer_sections/cinema/cinema_cast_section.dart';
import 'episode_drawer_sections/cinema/cinema_reviews_section.dart';
import 'episode_drawer_sections/cinema/cinema_section_header.dart';
import 'episode_drawer_sections/cinema/cinema_similar_section.dart';
part 'episode_drawer_widgets.dart';
part 'episode_drawer_state_base.dart';
part 'episode_drawer_state_core2.dart';

class EpisodeDrawer extends StatefulWidget {
  final MediaItem item;

  /// When true, the drawer renders the cinematic Everglow Cinema variant
  /// (hero poster, glass meta panel, large cast cards). Dashboard previews
  /// keep the classic layout by leaving this false.
  final bool cinemaVariant;

  const EpisodeDrawer({
    super.key,
    required this.item,
    this.cinemaVariant = false,
  });

  @override
  State<EpisodeDrawer> createState() => _EpisodeDrawerState();
}

class _EpisodeDrawerState extends _EpisodeDrawerStateCore2 {
  @override
  Widget build(BuildContext context) {
    final ratingNum = _details?['vote_average'] as num?;
    final rating = ratingNum != null
        ? ratingNum.toDouble().toStringAsFixed(1)
        : 'N/A';
    // For anime we don't have TMDB's `release_date` / `first_air_date`,
    // so we fall back to AniList's `seasonYear` and finally to whatever
    // the MediaItem already remembers from Jikan's discover payload.
    String releaseDate;
    if (_isAnimeSourced) {
      releaseDate = widget.item.year;
    } else if (widget.item.mediaType == 'movie') {
      releaseDate = (_details?['release_date'] ?? '') as String;
    } else {
      releaseDate = (_details?['first_air_date'] ?? '') as String;
    }
    final year = releaseDate.isNotEmpty
        ? releaseDate.split('-')[0]
        : widget.item.year;
    final episodeRunTimes = _details?['episode_run_time'] as List?;
    // Anime-sourced runtime comes from AniList's `duration` field
    // (in minutes per episode). We surface it in the same slot so the
    // hero header shows a single "Xm" badge next to the rating.
    final runtime = _isAnimeSourced
        ? (_details?['_duration'])
        : (_details?['runtime'] ??
              (episodeRunTimes != null && episodeRunTimes.isNotEmpty
                  ? episodeRunTimes.first
                  : null));
    final backdropPath = _details?['backdrop_path'];
    // For anime, backdrop is a fully-qualified AniList CDN URL stored on
    // `_details[_backdropUrl]`; for TMDB it's a path that we need to
    // prefix with the image CDN. The MediaItem itself also carries a
    // pre-built URL from discover/search which we use as a final
    // fallback so the hero never renders as a flat gray rectangle.
    String backdropUrl;
    if (_isAnimeSourced) {
      final aniBackdrop = _details?['_backdropUrl'] as String?;
      backdropUrl = (aniBackdrop != null && aniBackdrop.isNotEmpty)
          ? aniBackdrop
          : widget.item.backdropPath.isNotEmpty
          ? widget.item.backdropPath
          : widget.item.posterPath;
    } else {
      backdropUrl = backdropPath != null
          ? 'https://image.tmdb.org/t/p/w780$backdropPath'
          : widget.item.backdropPath.isNotEmpty
          ? widget.item.backdropPath
          : widget.item.posterPath;
    }
    final ratingVal = double.tryParse(rating) ?? 0;
    final ratingFraction = (ratingVal / 10).clamp(0.0, 1.0);

    // The Everglow Cinema variant gets its own cinematic layout; the
    // dashboard previews keep the classic drawer below.
    if (widget.cinemaVariant) {
      return _buildCinemaEnhanced(
        year: year,
        rating: rating,
        ratingFraction: ratingFraction,
        runtime: runtime,
        backdropUrl: backdropUrl,
      );
    }

    return Material(
      color: AppColors.deepBlack,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HERO BACKDROP ──
              SliverToBoxAdapter(
                child: TrailerSection(
                  backdropUrl: backdropUrl,
                  trailerKey: _trailerKey,
                  isLoadingTrailer: _isLoadingTrailer,
                  isPlayingTrailer: _isPlayingTrailer,
                  isMobile: _isMobile,
                  year: year,
                  rating: rating,
                  ratingFraction: ratingFraction,
                  runtime: runtime,
                  title: widget.item.title,
                  isDetailsLoading: _details == null,
                  onToggleTrailer: () => setState(() {
                    _trailerUserInitiated = true;
                    _isPlayingTrailer = true;
                  }),
                  onCloseTrailer: () =>
                      setState(() => _isPlayingTrailer = false),
                  onClose: () => Navigator.pop(context),
                ),
              ),

              // ── META + ACTIONS ──
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildMetaSection(
                    year,
                    rating,
                    ratingFraction,
                    runtime,
                  ),
                ),
              ),

              if (widget.item.mediaType == 'movie')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(children: [_buildPlayButton()]),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: EpisodeListSection(
                    episodes: _episodes,
                    seasons: _seasons,
                    selectedSeasonNumber: _selectedSeasonNumber,
                    isLoadingEpisodes: _isLoadingEpisodes,
                    tmdbMatchedSeason: _tmdbMatchedSeason,
                    onPlayEpisode: _playEpisode,
                    onSeasonChanged: (sn) {
                      setState(() => _selectedSeasonNumber = sn);
                      _fetchSeasonEpisodes(sn);
                    },
                  ),
                ),

              // ── CAST ──
              SliverToBoxAdapter(
                child: buildDrawerSectionHeader(
                  _isAnimeSourced ? 'Voice Cast' : 'Cast',
                ),
              ),
              SliverToBoxAdapter(
                child: CastSection(
                  cast: _cast,
                  isLoading: _isLoadingCast,
                  isAnimeSourced: _isAnimeSourced,
                ),
              ),

              // ── REVIEWS ──
              SliverToBoxAdapter(child: buildDrawerSectionHeader('Reviews')),
              SliverToBoxAdapter(
                child: ReviewsSection(
                  reviews: _reviews,
                  isLoading: _isLoadingReviews,
                ),
              ),

              // ── MORE LIKE THIS ──
              SliverToBoxAdapter(
                child: buildDrawerSectionHeader("Mochi says… 🐱"),
              ),
              SliverToBoxAdapter(
                child: SimilarSection(
                  similar: _similar,
                  isLoading: _isLoadingSimilar,
                  onItemTap: _showSimilarItem,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // META SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMetaSection(
    String year,
    String rating,
    double ratingFraction,
    dynamic runtime,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Genre chips
          if (_genreNames.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _genreNames.map((g) => _buildGenreChip(g)).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Anime-specific meta row: studio + format + airing status + next episode countdown.
          // This is hidden for non-anime items because those fields
          // don't have meaningful TMDB equivalents.
          if (_isAnimeSourced &&
              (_studio.isNotEmpty ||
                  _format.isNotEmpty ||
                  _airingStatus.isNotEmpty)) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_studio.isNotEmpty)
                  _buildAnimeFactChip(_studio, Icons.movie_creation_outlined),
                if (_format.isNotEmpty)
                  _buildAnimeFactChip(_format, Icons.tv_rounded),
                if (_airingStatus.isNotEmpty)
                  _buildAnimeFactChip(
                    _airingStatus,
                    Icons.fiber_manual_record_rounded,
                  ),
                if (_aniListDetail?.nextAiringAt != null)
                  _buildAiringCountdownChip(
                    _aniListDetail!.nextAiringAt!,
                    _aniListDetail!.nextAiringEpisode,
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          // Watchlist status heading
          Text(
            'Status',
            style: AppTypography.outfitHeading.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 10),
          // Cinema-only profiles (Breyan, Octagram) only get generic
          // "Want to Watch" / "Watched" — never the partner-specific chips,
          // which would leak Khent/Clair semantics.
          Builder(
            builder: (context) {
              final isCinemaOnly = context
                  .watch<AuthService>()
                  .isCinemaOnlyUser;
              final chips = isCinemaOnly
                  ? Row(
                      children: [
                        _buildStatusChip(
                          'Want to Watch',
                          'to-watch',
                          icon: Icons.bookmark_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Currently Watching',
                          'watching-self',
                          icon: Icons.play_circle_filled_rounded,
                          activeColor: const Color(0xFFFF6D00),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Watched',
                          'watched-self',
                          icon: Icons.check_circle_rounded,
                          activeColor: const Color(0xFF2E7D32),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _buildStatusChip(
                          'Want to Watch',
                          'to-watch',
                          icon: Icons.bookmark_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Khent Watching',
                          'watching-khent',
                          icon: Icons.play_circle_filled_rounded,
                          activeColor: const Color(0xFFFF6D00),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Clair Watching',
                          'watching-clair',
                          icon: Icons.play_circle_filled_rounded,
                          activeColor: const Color(0xFFE91E8C),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Both Watching',
                          'watching-both',
                          icon: Icons.people_rounded,
                          activeColor: const Color(0xFFFF9800),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Khent Watched',
                          'watched-khent',
                          icon: Icons.person_rounded,
                          activeColor: const Color(0xFF1976D2),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Clair Watched',
                          'watched-clair',
                          icon: Icons.favorite_rounded,
                          activeColor: const Color(0xFFE91E8C),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Both Watched',
                          'watched-both',
                          icon: Icons.people_rounded,
                          activeColor: const Color(0xFF2E7D32),
                        ),
                      ],
                    );
              return Scrollbar(
                thumbVisibility: true,
                controller: _statusScrollCtrl,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  controller: _statusScrollCtrl,
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent &&
                          event.scrollDelta.dy != 0) {
                        final ctrl = _statusScrollCtrl;
                        final clamped = (ctrl.offset + event.scrollDelta.dy)
                            .clamp(
                              ctrl.position.minScrollExtent,
                              ctrl.position.maxScrollExtent,
                            );
                        ctrl.jumpTo(clamped);
                      }
                    },
                    child: chips,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Overview
          if (_details?['overview'] != null &&
              (_details!['overview'] as String).isNotEmpty) ...[
            Text(
              _details!['overview'],
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.75),
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PLAY BUTTON
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _playMovie,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
            const SizedBox(width: 8),
            Text(
              'Play',
              style: AppTypography.outfitHeading.copyWith(
                color: Colors.black,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ANIME SEASON NAV
  // ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  // ──────────────────────────────────────────────────────────────
  // CINEMA ENHANCED VARIANT
  // ──────────────────────────────────────────────────────────────

  Widget _buildCinemaEnhanced({
    required String year,
    required String rating,
    required double ratingFraction,
    required dynamic runtime,
    required String backdropUrl,
  }) {
    String posterUrl;
    if (_isAnimeSourced) {
      posterUrl = _details?['_posterUrl'] as String? ?? widget.item.posterPath;
    } else {
      final pp = _details?['poster_path'] as String?;
      posterUrl = pp != null && pp.isNotEmpty
          ? 'https://image.tmdb.org/t/p/w342$pp'
          : widget.item.posterPath;
    }
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Material(
      color: AppColors.inkDeep,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: CinemaHero(
                backdropUrl: backdropUrl,
                posterUrl: posterUrl,
                trailerKey: _trailerKey,
                isLoadingTrailer: _isLoadingTrailer,
                isPlayingTrailer: _isPlayingTrailer,
                isMobile: _isMobile,
                isWide: isWide,
                year: year,
                rating: rating,
                ratingFraction: ratingFraction,
                runtime: runtime,
                title: widget.item.title,
                isDetailsLoading: _details == null,
                trailerUserInitiated: _trailerUserInitiated,
                onToggleTrailer: () => setState(() {
                  _trailerUserInitiated = true;
                  _isPlayingTrailer = true;
                }),
                onCloseTrailer: () => setState(() => _isPlayingTrailer = false),
                onClose: () => Navigator.pop(context),
              ),
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildCinemaMetaPanel(),
              ),
            ),
            if (widget.item.mediaType == 'movie')
              SliverToBoxAdapter(child: _buildCinemaActions())
            else
              SliverToBoxAdapter(
                child: EpisodeListSection(
                  episodes: _episodes,
                  seasons: _seasons,
                  selectedSeasonNumber: _selectedSeasonNumber,
                  isLoadingEpisodes: _isLoadingEpisodes,
                  tmdbMatchedSeason: _tmdbMatchedSeason,
                  onPlayEpisode: _playEpisode,
                  onSeasonChanged: (sn) {
                    setState(() => _selectedSeasonNumber = sn);
                    _fetchSeasonEpisodes(sn);
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: CinemaSectionHeader(
                eyebrow: _isAnimeSourced ? 'CHARACTERS & VOICES' : 'STAR CAST',
                title: _isAnimeSourced ? 'Voice Cast' : 'Cast',
                trailing: _cast.isNotEmpty ? '${_cast.length}' : null,
              ),
            ),
            SliverToBoxAdapter(
              child: CinemaCastSection(
                cast: _cast,
                isLoading: _isLoadingCast,
                isAnimeSourced: _isAnimeSourced,
              ),
            ),
            const SliverToBoxAdapter(
              child: CinemaSectionHeader(
                eyebrow: 'WORD OF MOUTH',
                title: 'Reviews',
              ),
            ),
            SliverToBoxAdapter(
              child: CinemaReviewsSection(
                reviews: _reviews,
                isLoading: _isLoadingReviews,
              ),
            ),
            const SliverToBoxAdapter(
              child: CinemaSectionHeader(
                eyebrow: 'DISCOVER MORE',
                title: 'Mochi says\u2026 \u{1F431}',
              ),
            ),
            SliverToBoxAdapter(
              child: CinemaSimilarSection(
                similar: _similar,
                isLoading: _isLoadingSimilar,
                onItemTap: _showSimilarItem,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 72)),
          ],
        ),
      ),
    );
  }

  Widget _buildCinemaMetaPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.roseQuartz.withValues(alpha: 0.28),
              AppColors.roseQuartz.withValues(alpha: 0.05),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(1.2),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panelGlass,
            borderRadius: BorderRadius.circular(21),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_genreNames.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _genreNames
                      .map((g) => _buildEnhancedGenreChip(g))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (_isAnimeSourced &&
                  (_studio.isNotEmpty ||
                      _format.isNotEmpty ||
                      _airingStatus.isNotEmpty)) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_studio.isNotEmpty)
                      _buildEnhancedAnimeFactChip(
                        _studio,
                        Icons.movie_creation_outlined,
                      ),
                    if (_format.isNotEmpty)
                      _buildEnhancedAnimeFactChip(_format, Icons.tv_rounded),
                    if (_airingStatus.isNotEmpty)
                      _buildEnhancedAnimeFactChip(
                        _airingStatus,
                        Icons.fiber_manual_record_rounded,
                      ),
                    if (_aniListDetail?.nextAiringAt != null)
                      _buildAiringCountdownChip(
                        _aniListDetail!.nextAiringAt!,
                        _aniListDetail!.nextAiringEpisode,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Status',
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: AppColors.roseQuartz.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 10),
              _buildCinemaStatusArea(),
              const SizedBox(height: 18),
              if (_details?['overview'] != null &&
                  (_details!['overview'] as String).isNotEmpty) ...[
                Text(
                  'STORY',
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 10,
                    letterSpacing: 2.4,
                    color: AppColors.blushGold.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _details!['overview'],
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCinemaStatusArea() {
    return Builder(
      builder: (context) {
        final isCinemaOnly = context.watch<AuthService>().isCinemaOnlyUser;
        final chips = isCinemaOnly
            ? Row(
                children: [
                  _buildEnhancedStatusChip(
                    'Want to Watch',
                    'to-watch',
                    icon: Icons.bookmark_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildEnhancedStatusChip(
                    'Currently Watching',
                    'watching-self',
                    icon: Icons.play_circle_filled_rounded,
                    activeColor: AppColors.cinemaOrange,
                  ),
                  const SizedBox(width: 8),
                  _buildEnhancedStatusChip(
                    'Watched',
                    'watched-self',
                    icon: Icons.check_circle_rounded,
                    activeColor: AppColors.cinemaGreen,
                  ),
                ],
              )
            : Row(
                children: [
                  _buildEnhancedStatusChip(
                    'Want to Watch',
                    'to-watch',
                    icon: Icons.bookmark_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildEnhancedStatusChip(
                    'Khent Watching',
                    'watching-khent',
                    icon: Icons.play_circle_filled_rounded,
                    activeColor: AppColors.cinemaOrange,
                  ),
                  const SizedBox(width: 8),
                  _buildEnhancedStatusChip(
                    'Clair Watching',
                    'watching-clair',
                    icon: Icons.play_circle_filled_rounded,
                    activeColor: AppColors.cinemaPink,
                  ),
                  const SizedBox(width: 8),
                  _buildEnhancedStatusChip(
                    'Both Watching',
                    'watching-both',
                    icon: Icons.people_rounded,
                    activeColor: AppColors.cinemaAmber,
                  ),
                  const SizedBox(width: 8),
                  _buildEnhancedStatusChip(
                    'Khent Watched',
                    'watched-khent',
                    icon: Icons.person_rounded,
                    activeColor: AppColors.cinemaBlue,
                  ),
                  const SizedBox(width: 8),
                  _buildEnhancedStatusChip(
                    'Clair Watched',
                    'watched-clair',
                    icon: Icons.favorite_rounded,
                    activeColor: AppColors.cinemaPink,
                  ),
                  const SizedBox(width: 8),
                  _buildEnhancedStatusChip(
                    'Both Watched',
                    'watched-both',
                    icon: Icons.people_rounded,
                    activeColor: AppColors.cinemaGreen,
                  ),
                ],
              );
        return Scrollbar(
          thumbVisibility: true,
          controller: _statusScrollCtrl,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            controller: _statusScrollCtrl,
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
                  final ctrl = _statusScrollCtrl;
                  final clamped = (ctrl.offset + event.scrollDelta.dy).clamp(
                    ctrl.position.minScrollExtent,
                    ctrl.position.maxScrollExtent,
                  );
                  ctrl.jumpTo(clamped);
                }
              },
              child: chips,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedStatusChip(
    String label,
    String status, {
    IconData icon = Icons.check_circle_rounded,
    Color activeColor = AppColors.deepRose,
  }) {
    final isSelected = _currentStatus == status;
    return GestureDetector(
      onTap: () => _updateStatus(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeColor.withValues(alpha: 0.3),
                    activeColor.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isSelected ? null : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.9)
                : AppColors.moonlight.withValues(alpha: 0.16),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : AppColors.mutedPurple,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTypography.outfitHeading.copyWith(
                color: isSelected ? Colors.white : AppColors.mutedPurple,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCinemaActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Column(children: [_buildCinemaPlayButton()]),
    );
  }

  Widget _buildCinemaPlayButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _playMovie,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.auroraRose, AppColors.deepRose],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.5),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(width: 8),
              Text(
                'Play Now',
                style: AppTypography.outfitHeading.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Smaller chip used for anime-specific facts (studio, format, airing
  /// status). Renders a leading icon and a tighter padding than the
  /// genre chip so the three facts fit on one row at mobile width.

  /// Live countdown chip showing time until the next episode airs. Uses a
  /// one-minute timer to keep the countdown accurate without excessive
  /// rebuilds. The chip is pulsing-animated to draw attention and only
  /// rendered when AniList provides a `nextAiringAt` timestamp.

  Widget _buildStatusChip(
    String label,
    String status, {
    IconData icon = Icons.check_circle_rounded,
    Color activeColor = AppColors.deepRose,
  }) {
    final isSelected = _currentStatus == status;
    return GestureDetector(
      onTap: () => _updateStatus(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : AppColors.moonlight.withValues(alpha: 0.14),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black : AppColors.mutedPurple,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitHeading.copyWith(
                color: isSelected ? Colors.black : AppColors.mutedPurple,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live countdown chip that ticks every minute showing time until the next
/// episode airs. Self-contained StatefulWidget so it can manage its own
/// timer lifecycle without cluttering the drawer state.
