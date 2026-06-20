import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';
import 'everglow_skeleton.dart';

/// Media poster card with shimmer loading, error fallback, semantics.
///
/// Replaces both `ShelfCard` and `ShelfPosterCard`.
/// Used for cinema, anime, books, manga content rows.
class EverglowPosterCard extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final String? badge;
  final int? rank;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double radius;

  const EverglowPosterCard({
    super.key,
    this.imageUrl,
    required this.title,
    this.subtitle,
    this.badge,
    this.rank,
    this.onTap,
    this.width = 110,
    this.height = 165,
    this.radius = AppRadius.md,
  });

  @override
  State<EverglowPosterCard> createState() => _EverglowPosterCardState();
}

class _EverglowPosterCardState extends State<EverglowPosterCard> {
  bool _hovered = false;
  bool _pressed = false;
  bool _imageLoaded = false;
  bool _imageError = false;

  @override
  Widget build(BuildContext context) {
    final effectiveScale = _pressed
        ? AppMotion.pressScale
        : (_hovered ? AppMotion.hoverScale : 1.0);
    final effectiveTranslateY =
        _hovered && !_pressed ? AppMotion.hoverLift : 0.0;

    Widget card = AnimatedContainer(
      duration: AppMotion.orZero(AppMotion.fast),
      curve: AppMotion.easeOutStrong,
      width: widget.width,
      height: widget.height,
      transform: Matrix4.identity()
        ..translate(0.0, effectiveTranslateY, 0.0)
        ..scale(effectiveScale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: _hovered
              ? AppColors.deepRose.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: _hovered ? AppElevation.card : AppElevation.e1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image or placeholder
          _buildImage(),
          // Title gradient overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xCC000000),
                    Color(0xF2000000),
                  ],
                ),
              ),
              child: Text(
                widget.title,
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.petalWhite,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Badge (top-right)
          if (widget.badge != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.deepRose,
                  borderRadius: AppRadius.radiusXs,
                ),
                child: Text(
                  widget.badge!,
                  style: AppTypography.labelSmall().copyWith(
                    color: AppColors.petalWhite,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          // Rank (top-left)
          if (widget.rank != null)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.twilight.withValues(alpha: 0.8),
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${widget.rank}',
                    style: AppTypography.labelSmall().copyWith(
                      color: AppColors.blushGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Interactive wrapper
    if (widget.onTap != null) {
      card = Semantics(
        button: true,
        label: '${widget.badge != null ? "${widget.badge}, " : ""}${widget.title}${widget.subtitle != null ? ", ${widget.subtitle}" : ""}',
        child: FocusableActionDetector(
          onShowHoverHighlight: (h) => setState(() => _hovered = h),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: card,
            ),
          ),
        ),
      );
    }

    return card;
  }

  Widget _buildImage() {
    if (widget.imageUrl == null || _imageError) {
      return _Placeholder(radius: widget.radius);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Shimmer while loading
        if (!_imageLoaded)
          EverglowSkeleton(
            width: widget.width,
            height: widget.height,
            radius: widget.radius,
          ),
        Image.network(
          widget.imageUrl!,
          fit: BoxFit.cover,
          frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
            if (frame != null || wasSynchronouslyLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_imageLoaded) {
                  setState(() => _imageLoaded = true);
                }
              });
            }
            return _imageLoaded
                ? child
                : const SizedBox.shrink();
          },
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_imageError) {
                setState(() => _imageError = true);
              }
            });
            return _Placeholder(radius: widget.radius);
          },
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double radius;
  const _Placeholder({required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.velvet, AppColors.twilight],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 32,
          color: AppColors.textDisabled,
        ),
      ),
    );
  }
}
