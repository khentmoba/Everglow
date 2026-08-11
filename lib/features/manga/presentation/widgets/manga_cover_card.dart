import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/mangadex_service.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// Grid card for a manga / manhwa / manhua cover.
/// Features: hover/press scale, shimmer loading, consistent tokens.
class MangaCoverCard extends StatefulWidget {
  final MangaItem item;
  final VoidCallback onTap;

  const MangaCoverCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<MangaCoverCard> createState() => _MangaCoverCardState();
}

class _MangaCoverCardState extends State<MangaCoverCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _imageLoaded = false;

  // Singleton — never create per build
  static final MangaDexService _mangaDex = MangaDexService();

  Color get _typeColor {
    switch (widget.item.originalLanguage) {
      case 'ko':
        return AppColors.animeMagenta;
      case 'zh':
        return AppColors.animeCyan;
      default:
        return AppColors.deepRose;
    }
  }

  String get _coverUrl {
    final url = widget.item.coverUrl;
    if (url.isEmpty) return url;
    if (url.startsWith('http') &&
        (url.contains('mangadex.org') || url.contains('mangadex.network')) &&
        !url.contains('proxyMangaImage')) {
      return _mangaDex.proxiedImageUrl(url);
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.95 : (_isHovered ? 1.03 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: AppRadius.radiusMd,
                border: Border.all(
                  color: _isHovered
                      ? AppColors.deepRose.withValues(alpha: 0.4)
                      : AppColors.border,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? AppColors.glowRose
                        : Colors.black.withValues(alpha: 0.25),
                    blurRadius: _isHovered ? 20 : 10,
                    offset: Offset(0, _isHovered ? 8 : 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: AppRadius.radiusMd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Shimmer placeholder while image loads
                    if (!_imageLoaded) _buildShimmer(),

                    if (_coverUrl.isNotEmpty)
                      Image.network(
                        _coverUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
                          if (frame != null && !_imageLoaded) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _imageLoaded = true);
                            });
                          }
                          return child;
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(),
                      )
                    else
                      _buildPlaceholder(),

                    // Library status badge
                    if (widget.item.isInLibrary)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.deepRose.withValues(alpha: 0.88),
                            borderRadius: AppRadius.radiusXs,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark,
                                  color: AppColors.petalWhite, size: 10),
                              const SizedBox(width: 4),
                              Text(
                                widget.item.libraryDisplay,
                                style: AppTypography.outfitWhite.copyWith(fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Bottom gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.92),
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.item.title,
                              style: AppTypography.outfitWhite.copyWith(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _typeColor.withValues(alpha: 0.2),
                                    borderRadius: AppRadius.radiusXs,
                                    border: Border.all(
                                      color: _typeColor.withValues(alpha: 0.4),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    widget.item.contentType.toUpperCase(),
                                    style: AppTypography.outfitWhite.copyWith(color: AppColors.roseQuartz, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ),
                                if (widget.item.year.isNotEmpty)
                                  Text(
                                    widget.item.year,
                                    style: AppTypography.outfitWhite.copyWith(color: AppColors.blushGold
                                          .withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Hover highlight overlay
                    if (_isHovered)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.deepRose.withValues(alpha: 0.06),
                            borderRadius: AppRadius.radiusMd,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      color: AppColors.shimmerBase,
      child: Center(
        child: Icon(
          Icons.menu_book_outlined,
          color: AppColors.roseQuartz.withValues(alpha: 0.15),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.velvet,
      child: const Center(
        child: Icon(
          Icons.menu_book_outlined,
          color: AppColors.roseQuartz,
          size: 32,
        ),
      ),
    );
  }
}
