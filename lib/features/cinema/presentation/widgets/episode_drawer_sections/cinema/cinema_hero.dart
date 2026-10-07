import 'package:flutter/material.dart';
import '../../../../../../shared/utils/responsive_image.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_typography.dart';
import '../../../../../../shared/widgets/app_network_image.dart';
import '../../trailer_player.dart';
import '../drawer_helpers.dart';
import '../../netflix/netflix_colors.dart';

void _noop() {}

/// Netflix-inspired cinematic hero for the Everglow Cinema detail drawer.
/// Full-bleed backdrop (or autoplaying trailer with real-time audio toggle),
/// smooth layered scrims, floating circular close button in top right,
/// volume/mute button in bottom right, and stylized title with high-contrast
/// white Play button and quick circular action buttons.
class CinemaHero extends StatelessWidget {
  final String backdropUrl;
  final String posterUrl;
  final String? trailerKey;
  final bool isLoadingTrailer;
  final bool isPlayingTrailer;
  final bool isTrailerMuted;
  final bool isMobile;
  final bool isWide;
  final String title;
  final VoidCallback onPlay;
  final String playLabel;
  final bool isAddedToWatchlist;
  final VoidCallback onToggleWatchlist;
  final bool isLiked;
  final VoidCallback onRate;
  final bool isUnreleased;
  final VoidCallback? onRemindMe;
  final VoidCallback? onShareDiscord;
  final VoidCallback onToggleMute;
  final VoidCallback onClose;
  final VoidCallback? onToggleTrailer;
  final VoidCallback? onCloseTrailer;
  final bool isDetailsLoading;
  final bool trailerUserInitiated;
  final String year;
  final String rating;
  final double ratingFraction;
  final dynamic runtime;

  const CinemaHero({
    super.key,
    required this.backdropUrl,
    required this.posterUrl,
    this.trailerKey,
    required this.isLoadingTrailer,
    required this.isPlayingTrailer,
    this.isTrailerMuted = true,
    required this.isMobile,
    required this.isWide,
    required this.title,
    this.onPlay = _noop,
    this.playLabel = 'Play',
    this.isAddedToWatchlist = false,
    this.onToggleWatchlist = _noop,
    this.isLiked = false,
    this.onRate = _noop,
    this.isUnreleased = false,
    this.onRemindMe,
    this.onShareDiscord,
    this.onToggleMute = _noop,
    required this.onClose,
    this.onToggleTrailer,
    this.onCloseTrailer,
    this.isDetailsLoading = false,
    this.trailerUserInitiated = false,
    this.year = '',
    this.rating = '',
    this.ratingFraction = 0.0,
    this.runtime,
  });

  @override
  Widget build(BuildContext context) {
    final height = isMobile ? 280.0 : 440.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isPlayingTrailer && trailerKey != null)
            _buildTrailer(context)
          else
            _buildBackdrop(context),
          _buildScrims(),
          _buildTopBar(context),
          if (trailerKey != null) _buildVolumeButton(),
          _buildTitleAndActions(context),
        ],
      ),
    );
  }

  Widget _buildTrailer(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TrailerPlayer(
          videoKey: trailerKey!,
          muted: isTrailerMuted,
          autoplay: true,
          loop: true,
        ),
      ],
    );
  }

  Widget _buildBackdrop(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdropUrl.isNotEmpty)
          AppNetworkImage(
            imageUrl: backdropUrl,
            fit: BoxFit.cover,
            cacheWidth: heroCacheWidth(context),
            placeholder: _buildPlaceholder(isLoading: true),
            errorWidget: _buildPlaceholder(isLoading: false),
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
          colors: [AppColors.shimmerBase, NetflixColors.surface],
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
          // Top scrim for close button legibility
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                ],
                stops: const [0, 0.35],
              ),
            ),
          ),
          // Bottom scrim melting seamlessly into the dialog card background
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  NetflixColors.surface.withValues(alpha: 0.35),
                  NetflixColors.surface.withValues(alpha: 0.85),
                  NetflixColors.surface,
                ],
                stops: const [0, 0.45, 0.78, 1.0],
              ),
            ),
          ),
          // Left scrim for title and button legibility
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
                stops: const [0, 0.5],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // Both hero variants must add the live top inset to their fixed
    // offsets so the close X sits below the status bar on mobile.
    final topInset = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 10 + topInset,
      right: 16,
      child: _buildCloseButton(),
    );
  }

  Widget _buildCloseButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xCC181818),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
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
    );
  }

  Widget _buildVolumeButton() {
    return Positioned(
      bottom: 24,
      right: 20,
      child: Tooltip(
        message: isTrailerMuted ? 'Unmute' : 'Mute',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onToggleMute,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0x99181818),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                isTrailerMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleAndActions(BuildContext context) {
    return Positioned(
      left: 24,
      right: 76,
      bottom: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cleanTitle(title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.outfitBold.copyWith(
              fontSize: isMobile ? 26 : 38,
              color: Colors.white,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // White Netflix Play Button
              _buildPlayButton(),
              if (isUnreleased) ...[
                _CircleActionButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Remind Me',
                  onTap: onRemindMe ?? () {},
                ),
              ],
              _CircleActionButton(
                icon: isAddedToWatchlist
                    ? Icons.check_rounded
                    : Icons.add_rounded,
                tooltip: isAddedToWatchlist
                    ? 'In Watchlist'
                    : 'Add to Watchlist',
                onTap: onToggleWatchlist,
                activeColor: isAddedToWatchlist ? AppColors.deepRose : null,
              ),
              _CircleActionButton(
                icon: isLiked
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_off_alt_rounded,
                tooltip: isLiked ? 'Rated' : 'Rate',
                onTap: onRate,
                activeColor: isLiked ? AppColors.deepRose : null,
              ),
              if (onShareDiscord != null) ...[
                _CircleActionButton(
                  icon: Icons.share_rounded,
                  tooltip: 'Share to #watch-party',
                  onTap: onShareDiscord!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPlay,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 18 : 24,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                playLabel,
                style: AppTypography.outfitBold.copyWith(
                  color: Colors.black,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? activeColor;

  const _CircleActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.activeColor,
  });

  @override
  State<_CircleActionButton> createState() => _CircleActionButtonState();
}

class _CircleActionButtonState extends State<_CircleActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.5),
              border: Border.all(
                color: widget.activeColor ??
                    (_hovered
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4)),
                width: 1.5,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: widget.activeColor ?? Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
