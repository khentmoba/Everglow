import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/shared/widgets/everglow/everglow_empty_state.dart';
import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';
import '../../domain/models/memory_photo.dart';
import '../../data/services/gallery_service.dart';
import '../widgets/add_photo_dialog.dart';
import 'photo_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final GalleryService _galleryService = GalleryService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GamifiedBackground(
        child: SafeArea(
          child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.roseQuartz,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Memory Gallery',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.roseQuartz,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: TextField(
                style: GoogleFonts.outfit(
                  color: AppTheme.petalWhite,
                  fontSize: 13,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: "Search memories…",
                  hintStyle: GoogleFonts.outfit(
                    color: AppTheme.petalWhite.withValues(alpha: 0.55),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.blushGold,
                    size: 18,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppTheme.blushGold.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.blushGold),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // ── Photo Grid ──
            Expanded(
              child: StreamBuilder<List<MemoryPhoto>>(
                stream: _searchQuery.isNotEmpty
                    ? _galleryService.searchPhotos(_searchQuery)
                    : _galleryService.getPhotosStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const EverglowSkeletonGrid(
                      count: 6,
                      crossAxisCount: 3,
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
                      onCta: () async {
                        await showDialog(
                          context: context,
                          barrierColor: Colors.transparent,
                          builder: (context) => const AddPhotoDialog(),
                        );
                      },
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.85,
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => const AddPhotoDialog(),
          );
        },
        backgroundColor: AppTheme.deepRose,
        foregroundColor: AppTheme.petalWhite,
        child: const Icon(Icons.add_photo_alternate_rounded),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final MemoryPhoto photo;
  final VoidCallback onTap;

  const _PhotoCard({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.blushGold.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepRose.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            Image.network(
              GalleryService.displayUrl(photo.imageUrl),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppTheme.twilight,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.blushGold,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stack) {
                return Container(
                  color: AppTheme.twilight,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: AppTheme.roseQuartz,
                      size: 32,
                    ),
                  ),
                );
              },
            ),

            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 30, 10, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
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
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppTheme.petalWhite,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      photo.uploadedBy,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: AppTheme.blushGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
