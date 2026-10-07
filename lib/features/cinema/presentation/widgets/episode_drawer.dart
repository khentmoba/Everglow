import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/logger.dart';
import '../../../anime/data/models/anilist_detail.dart';
import '../../data/models/media_item.dart';
import '../../data/services/ani_zip_service.dart';
import '../../../anime/data/services/anilist_service.dart';
import '../../../anime/data/services/jikan_service.dart';
import '../../data/services/tmdb_service.dart';
import '../../data/services/cinema_preferences.dart';
import '../../data/services/discord_share_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/widgets/everglow/everglow_button.dart';
import '../../../../shared/utils/tmdb_images.dart';
import 'package:go_router/go_router.dart';
import 'episode_drawer_sections/drawer_helpers.dart';
import 'episode_drawer_sections/episode_list_section.dart';
import 'episode_drawer_sections/cast_section.dart';
import 'episode_drawer_sections/reviews_section.dart';
import 'episode_drawer_sections/similar_section.dart';
import 'episode_drawer_sections/extra_tabs.dart';
import 'episode_drawer_sections/trailer_section.dart';
import '../../../../core/theme/app_typography.dart';
import 'episode_drawer_sections/cinema/cinema_hero.dart';
import 'episode_drawer_sections/cinema/cinema_cast_section.dart';
import 'episode_drawer_sections/cinema/cinema_reviews_section.dart';
import 'episode_drawer_sections/cinema/cinema_similar_section.dart';
import 'netflix/netflix_colors.dart';
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
  bool _isSharingDiscord = false;

  Widget _buildEpisodeList({bool netflixStyle = false}) => ListenableBuilder(
    listenable: CinemaPreferences.instance,
    builder: (context, _) => EpisodeListSection(
      episodes: _episodes,
      seasons: _seasons,
      selectedSeasonNumber: _selectedSeasonNumber,
      isLoadingEpisodes: _isLoadingEpisodes,
      tmdbMatchedSeason: _tmdbMatchedSeason,
      hideSpoilers:
          widget.item.isCinemaItem && CinemaPreferences.instance.hideSpoilers,
      currentSeason: widget.item.isAnime ? null : widget.item.currentSeason,
      currentEpisode: widget.item.isAnime ? null : widget.item.currentEpisode,
      currentPositionSeconds: widget.item.isAnime
          ? 0
          : widget.item.currentTimestamp ?? 0,
      currentDurationSeconds: widget.item.isAnime
          ? 0
          : widget.item.durationSeconds ?? 0,
      allEpisodesWatched: !widget.item.isAnime && widget.item.isWatched,
      netflixStyle: netflixStyle,
      onPlayEpisode: _playEpisode,
      onSeasonChanged: (sn) {
        setState(() => _selectedSeasonNumber = sn);
        _fetchSeasonEpisodes(sn);
      },
    ),
  );

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
    } else if (_isFilm) {
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
          ? TmdbImages.backdropFor(backdropPath)
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
        releaseDate: releaseDate,
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

              if (_isFilm)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPlayButton(),
                        const SizedBox(height: AppSpacing.sm),
                        _buildDiscordShareButton(),
                      ],
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Films never reach here (_isFilm true shows Play
                      // above). ONA-listed films like Drifting Home used to
                      // fall through and render fake Episode rows.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: _buildDiscordShareButton(
                          season: _selectedSeasonNumber,
                        ),
                      ),
                      // Films never reach here (_isFilm true shows Play
                      // above). ONA-listed films like Drifting Home used to
                      // fall through and render fake Episode rows.
                      _buildEpisodeList(),
                    ],
                  ),
                ),

              // ── CAST / REVIEWS / MORE (lazy tabs — only the open tab builds) ──
              SliverToBoxAdapter(
                child: DrawerExtraTabs(
                  selected: _extraTab,
                  onSelect: _selectExtraTab,
                  isAnimeSourced: _isAnimeSourced,
                ),
              ),
              SliverToBoxAdapter(child: _buildExtraTabBody()),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }

  /// Only the selected tab's section is built. Data stays cached in
  /// [_cast]/[_reviews]/[_similar], so switching tabs never refetches.
  Widget _buildExtraTabBody() {
    switch (_extraTab) {
      case 1:
        return ReviewsSection(reviews: _reviews, isLoading: _isLoadingReviews);
      case 2:
        return SimilarSection(
          similar: _similar,
          isLoading: _isLoadingSimilar,
          onItemTap: _showSimilarItem,
        );
      case 0:
      default:
        return CastSection(
          cast: _cast,
          isLoading: _isLoadingCast,
          isAnimeSourced: _isAnimeSourced,
        );
    }
  }

  Widget _buildCinemaExtraTabBody() {
    switch (_extraTab) {
      case 1:
        return CinemaReviewsSection(
          reviews: _reviews,
          isLoading: _isLoadingReviews,
        );
      case 2:
        return CinemaSimilarSection(
          similar: _similar,
          isLoading: _isLoadingSimilar,
          onItemTap: _showSimilarItem,
        );
      case 0:
      default:
        return CinemaCastSection(
          cast: _cast,
          isLoading: _isLoadingCast,
          isAnimeSourced: _isAnimeSourced,
        );
    }
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
          // Only couple users (Khent/Clair) get the partner-specific chips;
          // everyone else (Breyan, Octagram, guests) gets the generic
          // \"Want to Watch\" / \"Currently Watching\" / \"Watched\" set so
          // Khent/Clair semantics never leak.
          Builder(
            builder: (context) {
              final isCouple = context.select<AuthService, bool>(
                (a) => a.isCoupleUser,
              );
              final chips = isCouple
                  ? Row(
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
                          activeColor: AppColors.cinemaOrange,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Clair Watching',
                          'watching-clair',
                          icon: Icons.play_circle_filled_rounded,
                          activeColor: AppColors.cinemaPink,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Both Watching',
                          'watching-both',
                          icon: Icons.people_rounded,
                          activeColor: AppColors.cinemaAmber,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Khent Watched',
                          'watched-khent',
                          icon: Icons.person_rounded,
                          activeColor: AppColors.cinemaBlue,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Clair Watched',
                          'watched-clair',
                          icon: Icons.favorite_rounded,
                          activeColor: AppColors.cinemaPink,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Both Watched',
                          'watched-both',
                          icon: Icons.people_rounded,
                          activeColor: AppColors.cinemaGreen,
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
                          'Currently Watching',
                          'watching-self',
                          icon: Icons.play_circle_filled_rounded,
                          activeColor: AppColors.cinemaOrange,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Watched',
                          'watched-self',
                          icon: Icons.check_circle_rounded,
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
    required String releaseDate,
    required String rating,
    required double ratingFraction,
    required dynamic runtime,
    required String backdropUrl,
  }) {
    final isUnreleased = _isUnreleased(releaseDate);
    final hasProgress =
        (widget.item.currentTimestamp != null &&
            widget.item.currentTimestamp! > 0) ||
        (widget.item.currentSeason != null &&
            widget.item.currentEpisode != null &&
            (widget.item.currentSeason! > 1 ||
                widget.item.currentEpisode! > 1));
    final playLabel = hasProgress ? 'Resume' : 'Play';

    String posterUrl;
    if (_isAnimeSourced) {
      posterUrl = _details?['_posterUrl'] as String? ?? widget.item.posterPath;
    } else {
      final pp = _details?['poster_path'] as String?;
      posterUrl = pp != null && pp.isNotEmpty
          ? TmdbImages.posterFor(pp)
          : widget.item.posterPath;
    }
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final isCouple = context.select<AuthService, bool>((a) => a.isCoupleUser);

    final cardContent = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: CinemaHero(
            backdropUrl: backdropUrl,
            posterUrl: posterUrl,
            trailerKey: _trailerKey,
            isLoadingTrailer: _isLoadingTrailer,
            isPlayingTrailer: _isPlayingTrailer,
            isTrailerMuted: _trailerMuted,
            isMobile: _isMobile,
            isWide: isWide,
            title: widget.item.title,
            playLabel: playLabel,
            onPlay: _isFilm
                ? _playMovie
                : () => _playEpisode(
                    widget.item.currentSeason ?? 1,
                    widget.item.currentEpisode ?? 1,
                    widget.item.title,
                  ),
            isAddedToWatchlist: _isInWatchlist,
            onToggleWatchlist: _toggleWatchlist,
            isLiked: _isLiked,
            onRate: _toggleLike,
            isUnreleased: isUnreleased,
            onRemindMe: () => _updateStatus('to-watch'),
            onShareDiscord: isCouple
                ? () => _shareToDiscord(season: _selectedSeasonNumber)
                : null,
            onToggleMute: _toggleTrailerMute,
            onClose: () => Navigator.pop(context),
            onToggleTrailer: () => setState(() {
              _isPlayingTrailer = true;
            }),
            onCloseTrailer: () => setState(() => _isPlayingTrailer = false),
          ),
        ),
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: _buildNetflixDetailsSection(
              year: year,
              rating: rating,
              ratingFraction: ratingFraction,
              runtime: runtime,
              isUnreleased: isUnreleased,
            ),
          ),
        ),
        if (!_isFilm) ...[
          SliverToBoxAdapter(child: _buildEpisodeList(netflixStyle: true)),
        ],
        // "More Like This" recommendation cards grid
        SliverToBoxAdapter(
          child: CinemaSimilarSection(
            similar: _similar,
            isLoading: _isLoadingSimilar,
            onItemTap: _showSimilarItem,
            isGrid: true,
          ),
        ),
        // Extra Tabs: Cast & Reviews
        SliverToBoxAdapter(
          child: DrawerExtraTabs(
            selected: _extraTab,
            onSelect: _selectExtraTab,
            isAnimeSourced: _isAnimeSourced,
            cinemaStyle: true,
          ),
        ),
        SliverToBoxAdapter(child: _buildCinemaExtraTabBody()),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );

    if (_isMobile) {
      return Material(
        color: NetflixColors.surface,
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height,
          child: cardContent,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dismiss barrier clicking outside the dialog card
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {}, // absorbs tap so clicking inside does not dismiss
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 880,
                  maxHeight: MediaQuery.sizeOf(context).height - 56,
                ),
                margin: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: NetflixColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.85),
                      blurRadius: 48,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Material(
                    color: NetflixColors.surface,
                    child: cardContent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetflixDetailsSection({
    required String year,
    required String rating,
    required double ratingFraction,
    required dynamic runtime,
    required bool isUnreleased,
  }) {
    final ratingNum = double.tryParse(rating);
    final isWide = MediaQuery.sizeOf(context).width >= 680;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 62,
                  child: _buildNetflixLeftColumn(
                    year: year,
                    ratingNum: ratingNum,
                    runtime: runtime,
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(flex: 38, child: _buildNetflixRightColumn()),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNetflixLeftColumn(
                  year: year,
                  ratingNum: ratingNum,
                  runtime: runtime,
                ),
                const SizedBox(height: 20),
                _buildNetflixRightColumn(),
              ],
            ),
          const SizedBox(height: 20),
          _buildCinemaStatusSection(),
        ],
      ),
    );
  }

  Widget _buildNetflixLeftColumn({
    required String year,
    required double? ratingNum,
    required dynamic runtime,
  }) {
    final overview = (_details?['overview'] as String?) ?? widget.item.synopsis;

    final episodesCountStr = _isFilm
        ? ''
        : (_details?['number_of_episodes'] != null
              ? '${_details!['number_of_episodes']} Episodes'
              : (_seasons.length > 1
                    ? '${_seasons.length} Seasons'
                    : (_episodes.isNotEmpty
                          ? '${_episodes.length} Episodes'
                          : (widget.item.episodeCount != null
                                ? '${widget.item.episodeCount} Episodes'
                                : ''))));

    final runtimeStr = _isFilm && runtime != null ? '${runtime}m' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badges row: Match %, Year, Episodes / Duration, HD, CC
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (ratingNum != null && ratingNum > 0)
              Text(
                '${(ratingNum * 10).round()}% Match',
                style: AppTypography.outfitHeading.copyWith(
                  color: NetflixColors.match,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (year.isNotEmpty)
              Text(
                year,
                style: AppTypography.outfitWhite.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (episodesCountStr.isNotEmpty)
              Text(
                episodesCountStr,
                style: AppTypography.outfitWhite.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (runtimeStr.isNotEmpty)
              Text(
                runtimeStr,
                style: AppTypography.outfitWhite.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            // HD badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'HD',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 10,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // CC badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'CC',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 10,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Rating & Advisory Row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_certification != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _certification!,
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            Text(
              _contentAdvisory,
              style: AppTypography.outfitWhite.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        if (_topTenRank != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: NetflixColors.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'TOP\n10',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '#$_topTenRank in ${_isFilm ? 'Movies' : 'TV Shows'} Today',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
        if (overview.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            overview,
            style: AppTypography.outfitWhite.copyWith(
              color: NetflixColors.textPrimary.withValues(alpha: 0.9),
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
        ],
        if (_isAnimeSourced &&
            (_studio.isNotEmpty ||
                _format.isNotEmpty ||
                _airingStatus.isNotEmpty)) ...[
          const SizedBox(height: 14),
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
        ],
      ],
    );
  }

  Widget _buildNetflixRightColumn() {
    final castNames = _cast
        .take(4)
        .map((c) => (c['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (castNames.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Cast: ',
                    style: AppTypography.outfitWhite.copyWith(
                      color: NetflixColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: castNames.join(', '),
                    style: AppTypography.outfitWhite.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: ', more',
                    style: AppTypography.outfitWhite.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_genreNames.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Genres: ',
                    style: AppTypography.outfitWhite.copyWith(
                      color: NetflixColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: _genreNames.join(', '),
                    style: AppTypography.outfitWhite.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'This ${_isFilm ? 'Movie' : 'Show'} Is: ',
                  style: AppTypography.outfitWhite.copyWith(
                    color: NetflixColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: _showMoodTags,
                  style: AppTypography.outfitWhite.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCinemaStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: AppTypography.outfitHeading.copyWith(
            fontSize: 11,
            letterSpacing: 1.2,
            color: NetflixColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _buildCinemaStatusArea(),
      ],
    );
  }

  Widget _buildCinemaStatusArea() {
    return Builder(
      builder: (context) {
        final isCouple = context.select<AuthService, bool>(
          (a) => a.isCoupleUser,
        );
        final chips = isCouple
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildEnhancedStatusChip(
                    'Want to Watch',
                    'to-watch',
                    icon: Icons.bookmark_rounded,
                  ),
                  _buildEnhancedStatusChip(
                    'Khent Watching',
                    'watching-khent',
                    icon: Icons.play_circle_filled_rounded,
                    activeColor: AppColors.cinemaOrange,
                  ),
                  _buildEnhancedStatusChip(
                    'Clair Watching',
                    'watching-clair',
                    icon: Icons.play_circle_filled_rounded,
                    activeColor: NetflixColors.accent,
                  ),
                  _buildEnhancedStatusChip(
                    'Both Watching',
                    'watching-both',
                    icon: Icons.people_rounded,
                    activeColor: AppColors.cinemaAmber,
                  ),
                  _buildEnhancedStatusChip(
                    'Khent Watched',
                    'watched-khent',
                    icon: Icons.person_rounded,
                    activeColor: AppColors.cinemaBlue,
                  ),
                  _buildEnhancedStatusChip(
                    'Clair Watched',
                    'watched-clair',
                    icon: Icons.favorite_rounded,
                    activeColor: NetflixColors.accent,
                  ),
                  _buildEnhancedStatusChip(
                    'Both Watched',
                    'watched-both',
                    icon: Icons.people_rounded,
                    activeColor: AppColors.cinemaGreen,
                  ),
                ],
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildEnhancedStatusChip(
                    'Want to Watch',
                    'to-watch',
                    icon: Icons.bookmark_rounded,
                  ),
                  _buildEnhancedStatusChip(
                    'Currently Watching',
                    'watching-self',
                    icon: Icons.play_circle_filled_rounded,
                    activeColor: AppColors.cinemaOrange,
                  ),
                  _buildEnhancedStatusChip(
                    'Watched',
                    'watched-self',
                    icon: Icons.check_circle_rounded,
                    activeColor: AppColors.cinemaGreen,
                  ),
                ],
              );
        return chips;
      },
    );
  }

  Widget _buildEnhancedStatusChip(
    String label,
    String status, {
    IconData icon = Icons.check_circle_rounded,
    Color activeColor = NetflixColors.accent,
  }) {
    // Listens to the status directly so a tap repaints only the chips.
    // The drawer body (hero/trailer/episodes) never rebuilds for this.
    return ValueListenableBuilder<String>(
      valueListenable: _statusNotifier,
      builder: (context, current, _) {
        final isSelected = current == status;
        return GestureDetector(
          onTap: () => _updateStatus(status),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.16)
                  : NetflixColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.75)
                    : NetflixColors.hairline,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? activeColor : NetflixColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppTypography.outfitHeading.copyWith(
                    color: isSelected
                        ? Colors.white
                        : NetflixColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// True when the title's release/first-air date is in the future.
  /// Unparseable or missing dates read as released — the bell only
  /// appears when we positively know the title isn't out yet.
  bool _isUnreleased(String releaseDate) {
    if (releaseDate.isEmpty) return false;
    final parsed = DateTime.tryParse(releaseDate);
    if (parsed == null) return false;
    final now = DateTime.now();
    return parsed.isAfter(DateTime(now.year, now.month, now.day));
  }

  Widget _buildDiscordShareButton({int? season, int? episode}) {
    return Builder(
      builder: (context) {
        final isCouple = context.select<AuthService, bool>(
          (a) => a.isCoupleUser,
        );
        if (!isCouple) return const SizedBox.shrink();
        return EverglowButton.glass(
          label: _isSharingDiscord ? 'Sharing…' : 'Share to Discord',
          icon: Icons.share_rounded,
          enabled: !_isSharingDiscord,
          onPressed: _isSharingDiscord
              ? null
              : () => _shareToDiscord(season: season, episode: episode),
          tooltip: 'Post this pick to #watch-party',
        );
      },
    );
  }

  Future<void> _shareToDiscord({int? season, int? episode}) async {
    if (_isSharingDiscord) return;
    setState(() => _isSharingDiscord = true);
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        Logger.e('[EpisodeDrawer] Discord share failed: no ID token');
        if (mounted) _showSnack('Discord share failed — cinema still works');
        return;
      }
      var posterPath = widget.item.posterPath;
      if (posterPath.isEmpty) {
        final rawPoster = _details?['poster_path'] as String?;
        if (rawPoster != null && rawPoster.isNotEmpty) {
          posterPath = TmdbImages.posterFor(rawPoster);
        } else {
          posterPath = (_details?['_posterUrl'] as String?) ?? '';
        }
      }
      const endpoint =
          'https://us-central1-everglow-1c6db.cloudfunctions.net/notifyDiscordWatch';
      final ok = await DiscordShareService(endpoint: endpoint).share(
        idToken: idToken,
        title: widget.item.title,
        posterPath: posterPath,
        mediaType: widget.item.mediaType,
        season: season,
        episode: episode,
      );
      if (!mounted) return;
      if (ok) {
        _showSnack('Shared to #watch-party');
      } else {
        Logger.e(
          '[EpisodeDrawer] Discord share failed for "${widget.item.title}"',
        );
        _showSnack('Discord share failed — cinema still works');
      }
    } catch (e) {
      Logger.e('[EpisodeDrawer] Discord share failed', error: e);
      if (mounted) _showSnack('Discord share failed — cinema still works');
    } finally {
      if (mounted) setState(() => _isSharingDiscord = false);
    }
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
    // Same isolation as the enhanced chip: only chips repaint on tap.
    return ValueListenableBuilder<String>(
      valueListenable: _statusNotifier,
      builder: (context, current, _) {
        final isSelected = current == status;
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
      },
    );
  }
}

/// Live countdown chip that ticks every minute showing time until the next
/// episode airs. Self-contained StatefulWidget so it can manage its own
/// timer lifecycle without cluttering the drawer state.

/// "Remind me" bell for unreleased titles (cinema variant).
///
/// Self-contained: reads its initial state with one Firestore get and
/// toggles the flag on the caller's own watchlist doc. No OS
/// notification yet — the bell marks the title and surfaces it in the
/// Library's Reminders filter.
class _RemindMeButton extends StatefulWidget {
  final MediaItem item;
  const _RemindMeButton({required this.item});

  @override
  State<_RemindMeButton> createState() => _RemindMeButtonState();
}

class _RemindMeButtonState extends State<_RemindMeButton> {
  bool? _set;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) {
      if (mounted) setState(() => _set = false);
      return;
    }
    final value = await TMDBService().isReminderSet(
      widget.item.tmdbId,
      userName,
    );
    if (mounted) setState(() => _set = value);
  }

  Future<void> _toggle() async {
    final current = _set;
    final userName = context.read<AuthService>().currentUser ?? '';
    if (current == null || userName.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _set = !current);
    try {
      await TMDBService().setRemindMe(widget.item, userName, value: !current);
    } catch (e) {
      Logger.e('[EpisodeDrawer] Remind-me toggle failed', error: e);
      if (mounted) setState(() => _set = current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = _set ?? false;
    return GestureDetector(
      onTap: _set == null ? null : _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: set
              ? NetflixColors.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: set
                ? NetflixColors.accent
                : AppColors.moonlight.withValues(alpha: 0.3),
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_set == null)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: NetflixColors.accent,
                  strokeWidth: 2,
                ),
              )
            else ...[
              Icon(
                set
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: set ? NetflixColors.accent : AppColors.textMedium,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                set ? 'Reminder Set' : 'Remind Me',
                style: AppTypography.outfitHeading.copyWith(
                  color: set ? NetflixColors.accent : AppColors.textMedium,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
