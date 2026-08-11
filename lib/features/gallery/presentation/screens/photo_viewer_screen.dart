import 'package:flutter/material.dart';import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../domain/models/memory_photo.dart';
import '../../data/services/gallery_service.dart';
import 'package:everglow/core/theme/app_typography.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
        backgroundColor: AppTheme.velvet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.blushGold.withValues(alpha: 0.25),
          ),
        ),
        title: Text(
          'Delete Photo?',
          style: AppTypography.cormorantBold,
        ),
        content: Text(
          'This action cannot be undone.',
          style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await GalleryService().deletePhoto(photo);
              if (context.mounted) {
                if (widget.photos.length <= 1) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    widget.photos.removeAt(_currentIndex);
                    if (_currentIndex >= widget.photos.length) {
                      _currentIndex = widget.photos.length - 1;
                    }
                  });
                }
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.outfitWhite.copyWith(color: AppTheme.deepRose, fontWeight: FontWeight.bold),
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
            color: AppTheme.petalWhite,
            size: 20,
          ),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 14),
        ),
        centerTitle: true,
        actions: [
          if (widget.photos.isNotEmpty &&
              widget.photos[_currentIndex].uploadedBy == myUid)
            IconButton(
              onPressed: () =>
                  _showDeleteDialog(widget.photos[_currentIndex]),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.deepRose,
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
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      GalleryService.displayUrl(photo.imageUrl),
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: AppTheme.blushGold,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stack) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: AppTheme.roseQuartz,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Caption bar
          if (widget.photos.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.photos[_currentIndex].caption.isNotEmpty)
                    Text(
                      widget.photos[_currentIndex].caption,
                      style: AppTypography.cormorantRegular.copyWith(fontSize: 18, fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '📸 ${widget.photos[_currentIndex].uploadedBy}',
                        style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.blushGold),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${widget.photos[_currentIndex].uploadedAt.month}/${widget.photos[_currentIndex].uploadedAt.day}/${widget.photos[_currentIndex].uploadedAt.year}',
                        style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppTheme.petalWhite.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                  if (widget.photos[_currentIndex].tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: widget.photos[_currentIndex]
                          .tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.softLavender
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "#$tag",
                                style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.softLavender),
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
