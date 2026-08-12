import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_typography.dart';
import '../../trailer_player.dart';
import '../drawer_helpers.dart';

/// Cinematic hero for the Everglow Cinema detail drawer. Full-bleed
/// backdrop (or autoplaying trailer), layered scrims, a glass close
/// button, a floating poster card on wide screens, and a title block
/// with match score, star rating, year, runtime, and HD badge.
class CinemaHero extends StatelessWidget {
  final String backdropUrl;
  final String posterUrl;
  final String? trailerKey;
  final bool isLoadingTrailer;
  final bool isPlayingTrailer;
  final bool isMobile;
  final bool isWide;
  final String year;
  final String rating;
  final double ratingFraction;
  final dynamic runtime;
  final String title;
  final bool isDetailsLoading;
  final VoidCallback onToggleTrailer;
  final VoidCallback onCloseTrailer;
  final VoidCallback onClose;

  const CinemaHero({
    super.key,
    required this.backdropUrl,
    required this.posterUrl,
    this.trailerKey,
    required this.isLoadingTrailer,
    required this.isPlayingTrailer,
    required this.isMobile,
    required this.isWide,
    required this.year,
    required this.rating,
    required this.ratingFraction,
    required this.runtime,
    required this.title,
    required this.isDetailsLoading,
    required this.onToggleTrailer,
    required this.onCloseTrailer,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final height = isMobile ? 350.0 : 470.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isPlayingTrailer && trailerKey != null)
            _buildTrailer()
          else
            _buildBackdrop(),
          _buildScrims(),
          _buildTopBar(),
          if (trailerKey != null && !isLoadingTrailer && !isPlayingTrailer)
            _buildTrailerCta(),
          if (isWide) _buildPosterCard(),
          _buildTitleBlock(),
        ],
      ),
    );
  }

  Widget _buildTrailer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        TrailerPlayer(
          videoKey: trailerKey!,
          muted: isMobile,
          autoplay: true,
          loop: true,
        ),
        Positioned(
          top: 60,
          left: 16,
          child: GestureDetector(
            onTap: onCloseTrailer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Close Trailer',
                    style: AppTypography.outfitBold.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackdrop() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdropUrl.isNotEmpty)
          Image.network(
            backdropUrl,
            fit: BoxFit.cover,
            cacheWidth: 1100,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _buildPlaceholder(isLoading: true);
            },
            errorBuilder: (_, _, _) => _buildPlaceholder(isLoading: false),
          )
        else
          _buildPlaceholder(isLoading: isDetailsLoading),
      ],
    );
  }

  Widget _buildPlaceholder({required bool isLoading}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.shimmerBase, AppColors.inkDeep],
        ),
      ),
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: AppColors.deepRose,
                strokeWidth: 2,
              ),
            )
          : const Icon(
              Icons.movie_creation_outlined,
              color: AppColors.mutedPurple,
              size: 46,
            ),
    );
  }

  Widget _buildScrims() {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Top scrim so the handle and close button stay legible.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.inkDeep.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
                stops: const [0, 0.35],
              ),
            ),
          ),
          // Bottom scrim melting into the page background.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.inkDeep.withValues(alpha: 0.35),
                  AppColors.inkDeep.withValues(alpha: 0.92),
                  AppColors.inkDeep,
                ],
                stops: const [0, 0.52, 0.82, 1],
              ),
            ),
          ),
          // Left scrim for title legibility on busy backdrops.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.inkDeep.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
                stops: const [0, 0.5],
              ),
            ),
          ),
          // Soft rose glow near the bottom-left, kept very subtle.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.35, 1.1),
                radius: 1.1,
                colors: [
                  AppColors.deepRose.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
                stops: const [0, 0.6],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
        Positioned(top: 10, right: 16, child: _buildCloseButton()),
      ],
    );
  }

  Widget _buildCloseButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: GestureDetector(
          onTap: onClose,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailerCta() {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: onToggleTrailer,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.inkDeep.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.roseQuartz.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.auroraRose, AppColors.deepRose],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepRose.withValues(alpha: 0.6),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Watch Trailer',
                  style: AppTypography.outfitHeading.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterCard() {
    return Positioned(
      right: 28,
      bottom: 24,
      width: 132,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.25),
                blurRadius: 28,
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: posterUrl.isNotEmpty
                ? Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const ColoredBox(color: AppColors.shimmerBase);
                    },
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.shimmerBase),
                  )
                : const ColoredBox(color: AppColors.shimmerBase),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBlock() {
    final ratingNum = double.tryParse(rating);
    final filledStars = (ratingFraction * 5).round();
    return Positioned(
      left: 24,
      right: isWide ? 200 : 56,
      bottom: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cleanTitle(title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cormorantBlackWhite.copyWith(
              fontSize: isMobile ? 31 : 44,
              height: 1.05,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (ratingNum != null)
                Text(
                  '${(ratingNum * 10).round()}% Match',
                  style: AppTypography.outfitHeading.copyWith(
                    color: AppColors.cinemaMatch,
                    fontSize: 13.5,
                  ),
                ),
              if (ratingNum != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    return Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: i < filledStars
                          ? AppColors.warmAmber
                          : Colors.white.withValues(alpha: 0.28),
                    );
                  }),
                ),
                Text(
                  rating,
                  style: AppTypography.outfitWhite.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (year.isNotEmpty)
                Text(
                  year,
                  style: AppTypography.outfitWhite.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (runtime != null)
                Text(
                  '${runtime}m',
                  style: AppTypography.outfitWhite.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'HD',
                  style: AppTypography.outfitHeading.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
