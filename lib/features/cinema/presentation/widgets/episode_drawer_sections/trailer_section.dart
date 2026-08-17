import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../trailer_player.dart';
import 'drawer_helpers.dart';
import '../../../../../core/theme/app_typography.dart';

/// Renders the hero backdrop area: a full-width backdrop image with an
/// optional embedded YouTube trailer player, cinematic gradient overlays,
/// a close button, and a bottom overlay showing the title, year, rating
/// stars, and runtime badge.
class TrailerSection extends StatelessWidget {
  final String backdropUrl;
  final String? trailerKey;
  final bool isLoadingTrailer;
  final bool isPlayingTrailer;
  final bool isMobile;
  final String year;
  final String rating;
  final double ratingFraction;
  final dynamic runtime;
  final String title;
  final bool isDetailsLoading;
  final VoidCallback onToggleTrailer;
  final VoidCallback onCloseTrailer;
  final VoidCallback onClose;

  const TrailerSection({
    super.key,
    required this.backdropUrl,
    this.trailerKey,
    required this.isLoadingTrailer,
    required this.isPlayingTrailer,
    required this.isMobile,
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
    return Stack(
      children: [
        // Backdrop image or Trailer Player
        SizedBox(
          height: isMobile ? 300 : 460,
          width: double.infinity,
          child: isPlayingTrailer && trailerKey != null
              ? _buildTrailerPlayer()
              : _buildBackdropImage(),
        ),

        // Cinematic gradients (wrapped in IgnorePointer so the Watch Trailer
        // and Close Trailer buttons underneath stay tappable on mobile).
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.deepBlack.withValues(alpha: 0.6),
                    AppColors.deepBlack,
                  ],
                  stops: const [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.deepBlack.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Top: drag handle
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Close button
        Positioned(
          top: 14,
          right: 16,
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),

        // Bottom overlay: title
        Positioned(
          bottom: 16,
          left: 20,
          right: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cleanTitle(title),
                style: AppTypography.cormorantBlack.copyWith(fontSize: isMobile ? 30 : 42, height: 1.1, shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 16,
                    ),
                  ], color: Colors.white),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (double.tryParse(rating) != null) ...[
                    Text(
                      '${(double.parse(rating) * 10).round()}% Match',
                      style: AppTypography.outfitHeading.copyWith(color: const Color(0xFF7ED69A), fontSize: 13),
                    ),
                    dot(),
                  ],
                  if (year.isNotEmpty) ...[
                    Text(
                      year,
                      style: AppTypography.outfitWhite.copyWith(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                    dot(),
                  ],
                  if (runtime != null) ...[
                    Text(
                      '${runtime}m',
                      style: AppTypography.outfitWhite.copyWith(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                    ),
                    dot(),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'HD',
                      style: AppTypography.outfitHeading.copyWith(color: Colors.white.withValues(alpha: 0.9), fontSize: 9, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrailerPlayer() {
    return Stack(
      children: [
        TrailerPlayer(
          videoKey: trailerKey!,
          // Mute on mobile so browser autoplay policies don't
          // silently block playback.
          muted: isMobile,
          autoplay: true,
          loop: true,
        ),
        Positioned(
          top: 14,
          left: 16,
          child: GestureDetector(
            onTap: onCloseTrailer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Close Trailer',
                    style: AppTypography.outfitWhite.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackdropImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        backdropUrl.isNotEmpty
            ? Image.network(
                backdropUrl,
                fit: BoxFit.cover,
                cacheWidth: 900,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _buildBackdropPlaceholder(isLoading: true);
                },
                errorBuilder: (_, _, _) =>
                    _buildBackdropPlaceholder(isLoading: false),
              )
            : _buildBackdropPlaceholder(isLoading: isDetailsLoading),
        if (trailerKey != null && !isLoadingTrailer)
          Center(
            child: GestureDetector(
              onTap: onToggleTrailer,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.deepRose.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepRose.withValues(alpha: 0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Watch Trailer',
                      style: AppTypography.outfitWhite.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBackdropPlaceholder({required bool isLoading}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.shimmerBase, AppColors.deepBlack],
        ),
      ),
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: AppColors.deepRose,
                strokeWidth: 2,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.movie_creation_outlined,
                  color: AppColors.mutedPurple.withValues(alpha: 0.6),
                  size: 42,
                ),
                const SizedBox(height: 8),
                Text(
                  'No preview available',
                  style: AppTypography.outfitBold.copyWith(color: AppColors.mutedPurple, fontSize: 11, letterSpacing: 1.2),
                ),
              ],
            ),
    );
  }
}
