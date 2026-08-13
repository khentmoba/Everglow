import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/animex_models.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/animex_stores.dart';

import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_grid.dart';
import 'animex_tokens.dart';

/// Detail page for a single custom playlist.
class AnimeXPlaylistDetailPage extends StatelessWidget {
  final AnimeXController controller;

  const AnimeXPlaylistDetailPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final id = controller.playlistId ?? '';
    if (id.isEmpty) {
      return const SizedBox.shrink();
    }
    final playlist = context.watch<AnimexStores>().playlistById(id);
    if (playlist == null) {
      return const SizedBox.shrink();
    }

    final items = playlist.items;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 64),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: controller.closeDetail,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                  border: Border.all(color: AnimeXTokens.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 13,
                      color: AnimeXTokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Playlists',
                      style: dmSansStyle(
                        size: 12.5,
                        color: AnimeXTokens.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              playlist.emoji.isEmpty ? '★' : playlist.emoji,
              style: const TextStyle(fontSize: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: bebasStyle(
                      size: 34,
                      color: AnimeXTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${items.length} anime',
                    style: dmSansStyle(
                      size: 13,
                      color: AnimeXTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    color: AnimeXTokens.textMuted,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This playlist is empty',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 14,
                      color: AnimeXTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          AnimeXGrid(
            items: items.map(mediaItemFromPlaylistItem).toList(),
            onTap: (item) => controller.openWatch(item),
            hoverActionBuilder: (item) => GestureDetector(
              onTap: () {
                if (item.anilistId != null) {
                  context
                      .read<AnimexStores>()
                      .removeFromPlaylist(id, item.anilistId!);
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xCC0A0A0F),
                    shape: BoxShape.circle,
                    border: Border.all(color: AnimeXTokens.borderStrong),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: AnimeXTokens.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        AnimeXFooter(controller: controller),
      ],
    );
  }
}

MediaItem mediaItemFromPlaylistItem(AnimexPlaylistItem p) {
  return MediaItem(
    id: '',
    tmdbId: p.malId,
    title: p.title,
    mediaType: 'tv',
    posterPath: p.coverUrl,
    year: p.year,
    status: '',
    isAnime: true,
    addedAt: DateTime.now(),
    source: 'jikan',
    anilistId: p.anilistId,
    format: p.format,
  );
}
