import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_segmented_control.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../domain/models/memory_photo.dart';
import '../../data/services/gallery_service.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/utils/firestore_pagination.dart';
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
  final _gallerySearchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  Future<FirestorePage<MemoryPhoto>>? _searchFuture;
  final List<MemoryPhoto> _olderPhotos = [];
  DocumentSnapshot? _olderPhotoCursor;
  bool _loadingOlderPhotos = false;
  Object? _olderPhotosError;

  final List<MemoryPhoto> _olderSearchPhotos = [];
  DocumentSnapshot? _olderSearchCursor;
  bool _loadingOlderSearch = false;
  Object? _olderSearchError;
  int _tabIndex = 0; // 0 grid, 1 map, 2 week

  @override
  void dispose() {
    _gallerySearchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  static int _galleryColumns(BuildContext context) {
    if (AppBreakpoint.isDesktop(context)) return 6;
    if (AppBreakpoint.isTablet(context)) return 5;
    return 3;
  }

  Future<void> _openAddPhoto() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const AddPhotoDialog(),
    );
  }

  void _appendUnique(List<MemoryPhoto> target, Iterable<MemoryPhoto> values) {
    final ids = target.map((photo) => photo.id).toSet();
    for (final photo in values) {
      if (ids.add(photo.id)) target.add(photo);
    }
  }

  Future<void> _loadOlderPhotos(FirestorePage<MemoryPhoto> latest) async {
    final cursor = _olderPhotoCursor ?? latest.nextCursor;
    if (cursor == null || _loadingOlderPhotos) return;
    setState(() {
      _loadingOlderPhotos = true;
      _olderPhotosError = null;
    });
    try {
      final page = await _galleryService.getPhotosPage(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _appendUnique(_olderPhotos, page.items);
        _olderPhotoCursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) setState(() => _olderPhotosError = error);
    } finally {
      if (mounted) setState(() => _loadingOlderPhotos = false);
    }
  }

  void _startSearch(String query) {
    final trimmed = query.trim();
    setState(() {
      _searchQuery = trimmed;
      _olderSearchPhotos.clear();
      _olderSearchCursor = null;
      _olderSearchError = null;
      _searchFuture = trimmed.isEmpty
          ? null
          : _galleryService.searchPhotosPage(trimmed);
    });
  }

  Future<void> _loadOlderSearch(FirestorePage<MemoryPhoto> latest) async {
    final cursor = _olderSearchCursor ?? latest.nextCursor;
    if (cursor == null || _loadingOlderSearch) return;
    final query = _searchQuery;
    setState(() {
      _loadingOlderSearch = true;
      _olderSearchError = null;
    });
    try {
      final page = await _galleryService.searchPhotosPage(
        query,
        cursor: cursor,
      );
      if (!mounted || query != _searchQuery) return;
      setState(() {
        _appendUnique(_olderSearchPhotos, page.items);
        _olderSearchCursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted && query == _searchQuery) {
        setState(() => _olderSearchError = error);
      }
    } finally {
      if (mounted && query == _searchQuery) {
        setState(() => _loadingOlderSearch = false);
      }
    }
  }

  Widget _buildPhotoGrid(List<MemoryPhoto> photos) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _galleryColumns(context),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final photo = photos[index];
          return _PhotoCard(
            photo: photo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PhotoViewerScreen(photos: photos, initialIndex: index),
                ),
              );
            },
          );
        }, childCount: photos.length),
      ),
    );
  }

  Widget _buildPagingFooter({
    required bool hasMore,
    required bool loading,
    required Object? error,
    required VoidCallback onLoad,
  }) {
    if (!hasMore && error == null) return const SliverToBoxAdapter();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        child: Center(
          child: error != null
              ? TextButton.icon(
                  onPressed: onLoad,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry older photos'),
                )
              : TextButton(
                  onPressed: loading ? null : onLoad,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load older photos'),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      glows: [
        const RadialGlow(
          color: AppColors.deepRose,
          alignment: Alignment(-0.7, -0.9),
          size: 0.9,
          opacity: 0.16,
        ),
        const RadialGlow(
          color: AppColors.auroraLilac,
          alignment: Alignment(0.9, 0.7),
          size: 0.7,
          opacity: 0.10,
        ),
      ],
      body: Column(
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
                ? FutureBuilder<List<MemoryPhoto>>(
                    future: _galleryService.getPhotosWithLocationStream(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: EverglowSkeleton(
                            width: double.infinity,
                            height: 200,
                            radius: 16,
                          ),
                        );
                      }
                      if (snap.hasError) {
                        return EverglowEmptyState(
                          icon: Icons.map_rounded,
                          title: 'Could not load map photos',
                          subtitle: 'Try again',
                          ctaLabel: 'Retry',
                          onCta: () => setState(() {}),
                        );
                      }
                      return GalleryMapView(
                        photos: snap.data ?? const <MemoryPhoto>[],
                      );
                    },
                  )
                : _tabIndex == 2
                ? const ThisWeekView()
                : _searchQuery.isNotEmpty
                ? _buildSearchResults()
                : EverglowStreamView<FirestorePage<MemoryPhoto>>(
                    stream: _galleryService.getPhotosStream(),
                    streamLabel: 'gallery-grid',
                    errorMessage: 'Could not load photos',
                    errorIcon: Icons.photo_library_outlined,
                    onRetry: () => setState(() {}),
                    loadingView: EverglowSkeletonGrid(
                      count: 6,
                      crossAxisCount: _galleryColumns(context),
                      spacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    isEmpty: (page) =>
                        page.items.isEmpty && _olderPhotos.isEmpty,
                    emptyView: EverglowEmptyState(
                      icon: Icons.photo_library_outlined,
                      title: 'No memories yet',
                      subtitle: 'Tap + to add your first photo',
                      ctaLabel: 'Add Photo',
                      onCta: _openAddPhoto,
                    ),
                    builder: (context, latest) {
                      final photos = [...latest.items];
                      _appendUnique(photos, _olderPhotos);
                      final hasMore = _olderPhotos.isNotEmpty
                          ? _olderPhotoCursor != null
                          : latest.nextCursor != null;
                      return CustomScrollView(
                        slivers: [
                          _buildPhotoGrid(photos),
                          _buildPagingFooter(
                            hasMore: hasMore,
                            loading: _loadingOlderPhotos,
                            error: _olderPhotosError,
                            onLoad: () => _loadOlderPhotos(latest),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _FloatingAddButton(onPressed: _openAddPhoto),
    );
  }

  Widget _buildSearchResults() {
    final future = _searchFuture;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<FirestorePage<MemoryPhoto>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return EverglowSkeletonGrid(
            count: 6,
            crossAxisCount: _galleryColumns(context),
            spacing: 10,
            childAspectRatio: 0.82,
          );
        }
        if (snap.hasError) {
          return EverglowEmptyState(
            icon: Icons.photo_library_outlined,
            title: 'Search failed',
            subtitle: 'Try again',
            ctaLabel: 'Retry',
            onCta: () => _startSearch(_searchQuery),
          );
        }

        final latest = snap.data!;
        final photos = [...latest.items];
        _appendUnique(photos, _olderSearchPhotos);
        final hasMore = _olderSearchPhotos.isNotEmpty
            ? _olderSearchCursor != null
            : latest.nextCursor != null;
        if (photos.isEmpty && !hasMore) {
          return const EverglowEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matches',
            subtitle: 'Try a different keyword',
          );
        }
        return CustomScrollView(
          slivers: [
            if (photos.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No matches in this part of the archive.'),
                ),
              ),
            _buildPhotoGrid(photos),
            _buildPagingFooter(
              hasMore: hasMore,
              loading: _loadingOlderSearch,
              error: _olderSearchError,
              onLoad: () => _loadOlderSearch(latest),
            ),
          ],
        );
      },
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
              if (mounted) _startSearch(v);
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
                AppNetworkImage(
                  imageUrl: GalleryService.displayUrl(
                    photo.thumbUrl?.isNotEmpty == true
                        ? photo.thumbUrl!
                        : photo.imageUrl,
                    thumb: photo.thumbUrl?.isNotEmpty != true,
                  ),
                  fit: BoxFit.cover,
                  cacheWidth: 440,
                  errorWidget: Container(
                    color: AppColors.twilight,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: AppColors.roseQuartz,
                        size: 32,
                      ),
                    ),
                  ),
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
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.42,
                                  ),
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
