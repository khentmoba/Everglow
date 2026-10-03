part of 'animex_watch_page.dart';

// Keep spoiler metadata out of both text and thumbnail widgets (not blurred).
AniListEpisode _episodeWithoutSpoilers(AniListEpisode episode) =>
    AniListEpisode(
      number: episode.number,
      duration: episode.duration,
      airedAt: episode.airedAt,
    );

class _HideSpoilersSwitch extends StatelessWidget {
  const _HideSpoilersSwitch();

  @override
  Widget build(BuildContext context) {
    final hideSpoilers = context.select<AnimexStores?, bool>(
      (stores) => stores?.hideSpoilers ?? true,
    );
    return Material(
      color: Colors.transparent,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Hide spoilers',
          style: dmSansStyle(size: 12, color: AnimeXTokens.textPrimary),
        ),
        activeTrackColor: AnimeXTokens.accent,
        value: hideSpoilers,
        onChanged: context.read<AnimexStores?>()?.setHideSpoilers,
      ),
    );
  }
}

@visibleForTesting
void showEpisodeInfoSheetForTesting(
  BuildContext context, {
  required AniListEpisode episode,
  required String animeTitle,
  required String fallbackPoster,
  required bool isPlaying,
  required VoidCallback onPlay,
  bool hideSpoilers = true,
}) => _showEpisodeInfoSheet(
  context,
  episode: episode,
  animeTitle: animeTitle,
  fallbackPoster: fallbackPoster,
  isPlaying: isPlaying,
  onPlay: onPlay,
  hideSpoilers: hideSpoilers,
);

void _showPlaylistSheet(BuildContext context) {
  final stores = context.read<AnimexStores>();
  final state = context.findAncestorStateOfType<_AnimeXWatchPageState>();
  final item = state?._item;
  if (item == null) return;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AnimeXTokens.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final playlists = stores.playlists;
          return Column(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Save to Playlist',
                        style: dmSansStyle(
                          size: 16,
                          color: AnimeXTokens.textPrimary,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AnimeXPrimaryButton(
                      label: 'New',
                      icon: Icons.add_rounded,
                      onTap: () async {
                        final playlist = await stores.createPlaylist(
                          name: 'Playlist ${playlists.length + 1}',
                          emoji: 'star',
                        );
                        await stores.addToPlaylist(
                          playlist.id,
                          AnimexPlaylistItem(
                            anilistId: item.anilistId,
                            malId: item.tmdbId,
                            title: item.title,
                            coverUrl: item.posterUrl,
                            year: item.year,
                            format: item.format,
                          ),
                        );
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No playlists yet',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 13,
                      color: AnimeXTokens.textSecondary,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in playlists)
                        ListTile(
                          leading: Text(
                            p.emoji.isEmpty ? '★' : p.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          title: Text(
                            p.name,
                            style: dmSansStyle(
                              size: 14,
                              color: AnimeXTokens.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                          trailing: Icon(
                            p.items.any((i) => i.anilistId == item.anilistId)
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color:
                                p.items.any(
                                  (i) => i.anilistId == item.anilistId,
                                )
                                ? AnimeXTokens.success
                                : AnimeXTokens.textMuted,
                          ),
                          onTap: () async {
                            final entry = AnimexPlaylistItem(
                              anilistId: item.anilistId,
                              malId: item.tmdbId,
                              title: item.title,
                              coverUrl: item.posterUrl,
                              year: item.year,
                              format: item.format,
                            );
                            if (p.items.any(
                              (i) => i.anilistId == item.anilistId,
                            )) {
                              if (item.anilistId != null) {
                                await stores.removeFromPlaylist(
                                  p.id,
                                  item.anilistId!,
                                );
                              }
                            } else {
                              await stores.addToPlaylist(p.id, entry);
                            }
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    ),
  );
}
