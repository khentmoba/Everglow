import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/optimistic_action.dart';
import 'package:provider/provider.dart';
import '../../domain/models/memory_photo.dart';
import '../../data/services/gallery_service.dart';
import '../../../../core/theme/app_typography.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<MemoryPhoto> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<MemoryPhoto> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List<MemoryPhoto>.of(widget.photos);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNeighbors());
  }

  /// Warm the browser/HTTP cache for the adjacent full-res photos so
  /// swiping left/right paints instantly instead of streaming on demand.
  void _precacheNeighbors() {
    if (!mounted) return;
    for (final i in [_currentIndex - 1, _currentIndex + 1]) {
      if (i < 0 || i >= _photos.length) continue;
      precacheImage(
        NetworkImage(GalleryService.displayUrl(_photos[i].imageUrl)),
        context,
      ).ignore();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(MemoryPhoto photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.velvet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.25)),
        ),
        title: const Text('Delete Photo?', style: AppTypography.cormorantBold),
        content: Text(
          'This action cannot be undone.',
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.roseQuartz.withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              HapticFeedback.lightImpact();

              final removedIndex = _currentIndex;
              final removedPhoto = photo;
              final isLastPhoto = _photos.length <= 1;

              if (isLastPhoto) {
                Navigator.pop(context);
                GalleryService().deletePhoto(removedPhoto).catchError((
                  Object e,
                ) {
                  Logger.e('Photo delete failed', error: e);
                });
                return;
              }

              OptimisticAction.run(
                apply: () {
                  setState(() {
                    _photos.removeAt(removedIndex);
                    if (_currentIndex >= _photos.length) {
                      _currentIndex = _photos.length - 1;
                    }
                  });
                },
                action: () => GalleryService().deletePhoto(removedPhoto),
                rollback: () {
                  if (mounted) {
                    setState(() {
                      _photos.insert(
                        removedIndex.clamp(0, _photos.length),
                        removedPhoto,
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete photo. Restored.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
            child: Text(
              'Delete',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.deepRose,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AuthService>().uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.petalWhite,
            size: 20,
          ),
        ),
        title: Text(
          '${_currentIndex + 1} / ${_photos.length}',
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.petalWhite,
            fontSize: 14,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_photos.isNotEmpty && _photos[_currentIndex].uploadedBy == myUid)
            IconButton(
              onPressed: () => _showDeleteDialog(_photos[_currentIndex]),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.deepRose,
                size: 22,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Photo viewer
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _photos.length,
              onPageChanged: (i) {
                setState(() => _currentIndex = i);
                _precacheNeighbors();
              },
              itemBuilder: (context, index) {
                final photo = _photos[index];
                final decodeWidth =
                    (MediaQuery.sizeOf(context).width *
                            MediaQuery.devicePixelRatioOf(context))
                        .round()
                        .clamp(800, 2400);
                final thumbUrl = photo.thumbUrl;
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Instant paint: the grid thumbnail is already in the
                        // image cache, so it shows immediately while the
                        // full-res photo streams in on top of it.
                        if (thumbUrl?.isNotEmpty == true)
                          Image.network(
                            GalleryService.displayUrl(thumbUrl!),
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            excludeFromSemantics: true,
                            errorBuilder: (context, _, _) =>
                                const SizedBox.shrink(),
                          ),
                        Image.network(
                          GalleryService.displayUrl(photo.imageUrl),
                          fit: BoxFit.contain,
                          cacheWidth: kIsWeb ? null : decodeWidth,
                          gaplessPlayback: true,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            // Thumbnail underneath stays visible while the
                            // full photo loads; legacy photos without one
                            // keep the spinner so the wait is visible.
                            if (thumbUrl?.isNotEmpty == true) {
                              return const SizedBox.shrink();
                            }
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                    : null,
                                color: AppColors.blushGold,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) {
                            // Full-res failed: keep the thumbnail when we
                            // have one, otherwise show the broken icon.
                            if (thumbUrl?.isNotEmpty == true) {
                              return const SizedBox.shrink();
                            }
                            return const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: AppColors.roseQuartz,
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Caption bar
          if (_photos.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.black],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_photos[_currentIndex].caption.isNotEmpty)
                    Text(
                      _photos[_currentIndex].caption,
                      style: AppTypography.cormorantRegular.copyWith(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        ' ${_photos[_currentIndex].uploadedBy}',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 12,
                          color: AppColors.blushGold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_photos[_currentIndex].uploadedAt.month}/${_photos[_currentIndex].uploadedAt.day}/${_photos[_currentIndex].uploadedAt.year}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          color: AppColors.petalWhite.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                  if (_photos[_currentIndex].tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: _photos[_currentIndex].tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.softLavender.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "#$tag",
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 10,
                                  color: AppColors.softLavender,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
