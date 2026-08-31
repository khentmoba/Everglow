import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/animex_models.dart';
import '../../../data/services/animex_stores.dart';

import 'animex_buttons.dart';
import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_tokens.dart';

const _emojiOptions = [
  'star',
  'heart',
  'fire',
  'book',
  'tv',
  'sparkles',
  'rocket',
  'music',
  'movie',
  'crown',
];

const _emojiGlyphs = {
  'star': '★',
  'heart': '♥',
  'fire': '🔥',
  'book': '📖',
  'tv': '📺',
  'sparkles': '✨',
  'rocket': '🚀',
  'music': '🎵',
  'movie': '🎬',
  'crown': '👑',
};

/// Custom playlists page with create/rename/delete management.
class AnimeXPlaylistsPage extends StatelessWidget {
  final AnimeXController controller;

  const AnimeXPlaylistsPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<AnimexStores>().playlists;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Playlists',
                    style: bebasStyle(
                      size: 32,
                      color: AnimeXTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your custom collections',
                    style: dmSansStyle(
                      size: 13,
                      color: AnimeXTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimeXPrimaryButton(
              label: 'Create',
              icon: Icons.add_rounded,
              onTap: () => _showCreateDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bookmark_add_outlined,
                    color: AnimeXTokens.textMuted,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No playlists yet - create your first one',
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 150,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, i) {
              final p = playlists[i];
              return _PlaylistCard(
                playlist: p,
                onTap: () => controller.openPlaylist(p.id),
                onManage: () => _showManageSheet(context, p.id),
              );
            },
          ),
        const SizedBox(height: 24),
        AnimeXFooter(controller: controller),
      ],
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final stores = context.read<AnimexStores>();
    final nameCtrl = TextEditingController();
    var emoji = 'star';
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC000000),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AnimeXTokens.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AnimeXTokens.radius2xl),
            side: const BorderSide(color: AnimeXTokens.border),
          ),
          title: Text(
            'Create Playlist',
            style: dmSansStyle(
              size: 17,
              color: AnimeXTokens.textPrimary,
              weight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: dmSansStyle(size: 14, color: AnimeXTokens.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Playlist name',
                  hintStyle: dmSansStyle(
                    size: 14,
                    color: AnimeXTokens.textMuted,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
                    borderSide: const BorderSide(color: AnimeXTokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
                    borderSide: const BorderSide(color: AnimeXTokens.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _emojiOptions)
                    GestureDetector(
                      onTap: () => setState(() => emoji = e),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: emoji == e
                              ? AnimeXTokens.accent.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            AnimeXTokens.radiusLg,
                          ),
                          border: Border.all(
                            color: emoji == e
                                ? AnimeXTokens.accent
                                : AnimeXTokens.border,
                          ),
                        ),
                        child: Text(
                          _emojiGlyphs[e]!,
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
              ),
            ),
            AnimeXPrimaryButton(
              label: 'Create',
              onTap: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await stores.createPlaylist(name: name, emoji: emoji);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  void _showManageSheet(BuildContext context, String id) {
    final stores = context.read<AnimexStores>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AnimeXTokens.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AnimeXTokens.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.drive_file_rename_outline_rounded,
                color: AnimeXTokens.textPrimary,
              ),
              title: Text(
                'Rename',
                style: dmSansStyle(
                  size: 14,
                  color: AnimeXTokens.textPrimary,
                  weight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRenameDialog(context, id);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AnimeXTokens.accent,
              ),
              title: Text(
                'Delete playlist',
                style: dmSansStyle(
                  size: 14,
                  color: AnimeXTokens.accent,
                  weight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await stores.deletePlaylist(id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, String id) async {
    final stores = context.read<AnimexStores>();
    final playlist = stores.playlistById(id);
    if (playlist == null) return;
    final nameCtrl = TextEditingController(text: playlist.name);
    var emoji = playlist.emoji;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AnimeXTokens.surfaceRaised,
          title: Text(
            'Rename playlist',
            style: dmSansStyle(
              size: 17,
              color: AnimeXTokens.textPrimary,
              weight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: dmSansStyle(size: 14, color: AnimeXTokens.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
                    borderSide: const BorderSide(color: AnimeXTokens.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in _emojiOptions)
                    GestureDetector(
                      onTap: () => setState(() => emoji = e),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: emoji == e
                              ? AnimeXTokens.accent.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            AnimeXTokens.radiusMd,
                          ),
                          border: Border.all(
                            color: emoji == e
                                ? AnimeXTokens.accent
                                : AnimeXTokens.border,
                          ),
                        ),
                        child: Text(
                          _emojiGlyphs[e]!,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
              ),
            ),
            AnimeXPrimaryButton(
              label: 'Save',
              onTap: () async {
                await stores.updatePlaylist(
                  id,
                  name: nameCtrl.text.trim().isEmpty
                      ? playlist.name
                      : nameCtrl.text.trim(),
                  emoji: emoji,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }
}

class _PlaylistCard extends StatelessWidget {
  final AnimexPlaylist playlist;
  final VoidCallback onTap;
  final VoidCallback onManage;

  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final name = playlist.name;
    final emoji = playlist.emoji;
    final count = playlist.items.length;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AnimeXTokens.radius2xl),
            border: Border.all(color: AnimeXTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _emojiGlyphs[emoji] ?? '★',
                    style: const TextStyle(fontSize: 26),
                  ),
                  GestureDetector(
                    onTap: onManage,
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      color: AnimeXTokens.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dmSansStyle(
                  size: 15,
                  color: AnimeXTokens.textPrimary,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count anime',
                style: dmSansStyle(size: 12, color: AnimeXTokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
