import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_segmented_control.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../domain/models/memory_photo.dart';
import '../../data/services/gallery_service.dart';
import '../widgets/add_photo_dialog.dart';
import '../widgets/gallery_map_view.dart';
import '../widgets/this_week_view.dart';
import 'photo_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final GalleryService _galleryService = GalleryService();
  String _searchQuery = '';
  Timer? _searchDebounce;
  int _tabIndex = 0; // 0 grid, 1 map, 2 week

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _openAddPhoto() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const AddPhotoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.deepRose,
                  alignment: Alignment(-0.7, -0.9),
                  size: 0.9,
                  opacity: 0.16,
                ),
                RadialGlow(
                  color: AppColors.auroraLilac,
                  alignment: Alignment(0.9, 0.7),
                  size: 0.7,
                  opacity: 0.10,
                ),
              ],
              showPetals: true,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const EverglowFeatureHeader(
                  title: 'Memory Gallery',
                  subtitle: 'our shared album',
                  icon: Icons.photo_library_rounded,
                  hue: AppColors.roseQuartz,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EverglowSegmentedControl(
                    selectedIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                    activeColor: AppColors.roseQuartz,
                    items: const [
                      SegmentItem('Grid', Icons.grid_view_rounded),
                      SegmentItem('Map', Icons.map_rounded),
                      SegmentItem('Week', Icons.history_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_tabIndex == 0) _buildSearchBar(),
                if (_tabIndex == 0) const SizedBox(height: 4),
                Expanded(
                  child: _tabIndex == 1
                      ? StreamBuilder<List<MemoryPhoto>>(
                          stream: _galleryService.getPhotosWithLocationStream(),
                          builder: (context, snap) {
                            final photos = snap.data ?? [];
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.deepRose,
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            return GalleryMapView(photos: photos);
                          },
                        )
                      : _tabIndex == 2
                      ? const ThisWeekView()
                      : StreamBuilder<List<MemoryPhoto>>(
                          stream: _searchQuery.isNotEmpty
                              ? _galleryService.searchPhotos(_searchQuery)
                              : _galleryService.getPhotosStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const EverglowSkeletonGrid(
                                count: 6,
                                maxCrossAxisExtent: 220,
                                itemHeight: 200,
                                spacing: 10,
                                childAspectRatio: 0.75,
                              );
                            }

                            final photos = snapshot.data ?? [];
                            if (photos.isEmpty) {
                              return EverglowEmptyState(
                                icon: Icons.photo_library_outlined,
                                title: 'No memories yet',
                                subtitle: 'Tap + to add your first photo',
                                ctaLabel: 'Add Photo',
                                onCta: _openAddPhoto,
                              );
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 220,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 0.82,
                                  ),
                              itemCount: photos.length,
                              itemBuilder: (context, index) {
                                final photo = photos[index];
                                return _PhotoCard(
                                  photo: photo,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PhotoViewerScreen(
                                          photos: photos,
                                          initialIndex: index,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _FloatingAddButton(onPressed: _openAddPhoto),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: AnimatedContainer(
        duration: AppMotion.orZero(AppMotion.fast),
        decoration: BoxDecoration(
          color: AppColors.velvet.withValues(alpha: 0.38),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.10),
          ),
        ),
        child: TextField(
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.petalWhite,
            fontSize: 13,
          ),
          onChanged: (v) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _searchQuery = v.trim());
            });
          },
          decoration: InputDecoration(
            hintText: 'Search memories...',
            hintStyle: AppTypography.outfitWhite.copyWith(
              color: AppColors.petalWhite.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.petalWhite.withValues(alpha: 0.42),
              size: 19,
            ),
            isDense: true,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingAddButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _FloatingAddButton({required this.onPressed});

  @override
  State<_FloatingAddButton> createState() => _FloatingAddButtonState();
}

class _FloatingAddButtonState extends State<_FloatingAddButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add a photo',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.fast),
            curve: AppMotion.easeOutStrong,
            transform: Matrix4.identity()
              ..scaleByDouble(
                _hovered ? 1.08 : 1.0,
                _hovered ? 1.08 : 1.0,
                _hovered ? 1.08 : 1.0,
                1.0,
              ),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.roseGoldGradient,
              border: Border.all(
                color: AppColors.petalWhite.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(
              Icons.add_photo_alternate_rounded,
              color: AppColors.petalWhite,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoCard extends StatefulWidget {
  final MemoryPhoto photo;
  final VoidCallback onTap;

  const _PhotoCard({required this.photo, required this.onTap});

  @override
  State<_PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<_PhotoCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    return Semantics(
      button: true,
      label: photo.caption.isEmpty ? 'Memory photo' : photo.caption,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.medium),
            curve: AppMotion.easeOutStrong,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hovered ? -4.0 : 0.0, 0.0, 1.0)
              ..scaleByDouble(
                _pressed ? 0.95 : (_hovered ? 1.03 : 1.0),
                _pressed ? 0.95 : (_hovered ? 1.03 : 1.0),
                _pressed ? 0.95 : (_hovered ? 1.03 : 1.0),
                1.0,
              ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: _hovered
                    ? AppColors.blushGold.withValues(alpha: 0.6)
                    : AppColors.blushGold.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.inkDeep.withValues(alpha: 0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
                if (_hovered)
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.25),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  GalleryService.displayUrl(photo.imageUrl),
                  fit: BoxFit.cover,
                  cacheWidth: 440,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppColors.twilight,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.petalWhite.withValues(alpha: 0.42),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    return Container(
                      color: AppColors.twilight,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.roseQuartz,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
                // Bottom gradient + caption
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 34, 10, 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (photo.caption.isNotEmpty)
                          Text(
                            photo.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 11,
                              color: AppColors.petalWhite,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              size: 9,
                              color: AppColors.auroraRose,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                photo.uploadedBy,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitBold.copyWith(
                                  fontSize: 9,
                                  color: AppColors.petalWhite.withValues(alpha: 0.42),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
