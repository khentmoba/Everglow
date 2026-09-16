part of 'animex_watch_page.dart';

/// Mobile episode card matching Reference Image #2 (horizontal swipeable card).
class _MobileEpisodeCard extends StatelessWidget {
  final AniListEpisode episode;
  final String fallbackPoster;
  final String animeTitle;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _MobileEpisodeCard({
    required this.episode,
    required this.fallbackPoster,
    required this.animeTitle,
    required this.isPlaying,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final ep = episode;
    final title = (ep.title != null && ep.title!.isNotEmpty)
        ? ep.title!
        : 'Episode ${ep.number}';
    final synopsis = ep.synopsis?.trim() ?? '';
    final hasSynopsis = synopsis.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: AnimeXTokens.surface,
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
          border: Border.all(
            color: isPlaying ? AnimeXTokens.accent : AnimeXTokens.border,
            width: isPlaying ? 1.5 : 1.0,
          ),
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: AnimeXTokens.accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EpisodeThumbnail(
              episode: ep,
              fallbackPoster: fallbackPoster,
              isPlaying: isPlaying,
              width: 260,
              height: 145,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: dmSansStyle(
                        size: 13,
                        color: isPlaying
                            ? AnimeXTokens.accentWarm
                            : AnimeXTokens.textPrimary,
                        weight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      animeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dmSansStyle(
                        size: 11,
                        color: AnimeXTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (hasSynopsis) ...[
                      GestureDetector(
                        onTap: onInfoTap,
                        child: Text(
                          synopsis,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: dmSansStyle(
                            size: 11.5,
                            color: AnimeXTokens.textSecondary.withValues(
                              alpha: 0.85,
                            ),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onInfoTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_stories_outlined,
                              size: 12,
                              color: AnimeXTokens.accentWarm,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'What happened \u2192',
                              style: dmSansStyle(
                                size: 10.5,
                                color: AnimeXTokens.accentWarm,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (ep.airedAt != null)
                      Text(
                        'Aired: ${ep.airedAt!.year}-${ep.airedAt!.month.toString().padLeft(2, '0')}-${ep.airedAt!.day.toString().padLeft(2, '0')}',
                        style: dmSansStyle(
                          size: 11,
                          color: AnimeXTokens.textMuted,
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

/// Mobile episode selector matching Reference Image #2 (placed directly below player).
class _MobileEpisodesSection extends StatefulWidget {
  final List<AniListEpisode> episodes;
  final int selectedEpisode;
  final String animeTitle;
  final String fallbackPoster;
  final ValueChanged<int> onSelectEpisode;
  final void Function(AniListEpisode) onShowInfo;

  const _MobileEpisodesSection({
    required this.episodes,
    required this.selectedEpisode,
    required this.animeTitle,
    required this.fallbackPoster,
    required this.onSelectEpisode,
    required this.onShowInfo,
  });

  @override
  State<_MobileEpisodesSection> createState() => _MobileEpisodesSectionState();
}

class _MobileEpisodesSectionState extends State<_MobileEpisodesSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _showSearch = false;
  bool _sortAscending = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _query) setState(() => _query = q);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(covariant _MobileEpisodesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedEpisode != widget.selectedEpisode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToActive() {
    if (!_scrollCtrl.hasClients || widget.episodes.isEmpty) return;
    final activeIndex = widget.episodes.indexWhere(
      (e) => e.number == widget.selectedEpisode,
    );
    if (activeIndex <= 0) return;
    // Each card is width 260 + 12 gap = 272
    final target = (activeIndex * 272.0) - 20.0;
    _scrollCtrl.animateTo(
      target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  List<AniListEpisode> _filteredEpisodes() {
    var list = widget.episodes;
    if (_query.isNotEmpty) {
      list = list.where((e) {
        final numStr = e.number.toString();
        final padded = numStr.padLeft(2, '0');
        final t = (e.title ?? '').toLowerCase();
        final s = (e.synopsis ?? '').toLowerCase();
        return numStr == _query ||
            padded == _query ||
            'episode $numStr'.contains(_query) ||
            'ep $numStr'.contains(_query) ||
            t.contains(_query) ||
            s.contains(_query);
      }).toList();
    }
    if (!_sortAscending) {
      list = list.reversed.toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredEpisodes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // EPISODES header row matching Reference Image #2
        Row(
          children: [
            Text(
              'EPISODES',
              style: dmSansStyle(
                size: 14,
                color: AnimeXTokens.textPrimary,
                weight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${widget.episodes.length})',
              style: dmSansStyle(
                size: 12,
                color: AnimeXTokens.textMuted,
                weight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Search pill button
            GestureDetector(
              onTap: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) _searchCtrl.clear();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _showSearch
                      ? AnimeXTokens.accent.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _showSearch
                        ? AnimeXTokens.accent
                        : AnimeXTokens.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: AnimeXTokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Search',
                      style: dmSansStyle(
                        size: 11.5,
                        color: AnimeXTokens.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Sort button
            GestureDetector(
              onTap: () => setState(() => _sortAscending = !_sortAscending),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AnimeXTokens.border),
                ),
                child: const Icon(
                  Icons.swap_vert_rounded,
                  size: 16,
                  color: AnimeXTokens.textSecondary,
                ),
              ),
            ),
          ],
        ),

        if (_showSearch) ...[
          const SizedBox(height: 10),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: AnimeXTokens.surface,
              borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
              border: Border.all(color: AnimeXTokens.borderStrong),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: AnimeXTokens.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: dmSansStyle(
                      size: 12.5,
                      color: AnimeXTokens.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by title, number, or keyword...',
                      hintStyle: dmSansStyle(
                        size: 12,
                        color: AnimeXTokens.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchCtrl.clear(),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AnimeXTokens.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Horizontal scrolling episode cards
        if (displayList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: Text(
              'No episodes found matching "$_query"',
              style: dmSansStyle(size: 12.5, color: AnimeXTokens.textMuted),
            ),
          )
        else
          SizedBox(
            height: 300,
            child: ListView.separated(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: displayList.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final ep = displayList[index];
                final active = ep.number == widget.selectedEpisode;
                return _MobileEpisodeCard(
                  episode: ep,
                  fallbackPoster: widget.fallbackPoster,
                  animeTitle: widget.animeTitle,
                  isPlaying: active,
                  onTap: () => widget.onSelectEpisode(ep.number),
                  onInfoTap: () => widget.onShowInfo(ep),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Episode Information / "What Happened" modal bottom sheet.
void _showEpisodeInfoSheet(
  BuildContext context, {
  required AniListEpisode episode,
  required String animeTitle,
  required String fallbackPoster,
  required bool isPlaying,
  required VoidCallback onPlay,
}) {
  final ep = episode;
  final title = (ep.title != null && ep.title!.isNotEmpty)
      ? ep.title!
      : 'Episode ${ep.number}';
  final synopsis = ep.synopsis?.trim() ?? '';

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AnimeXTokens.surfaceRaised,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AnimeXTokens.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Episode Header with Thumbnail
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EpisodeThumbnail(
                              episode: ep,
                              fallbackPoster: fallbackPoster,
                              isPlaying: isPlaying,
                              width: 120,
                              height: 68,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: dmSansStyle(
                                      size: 15,
                                      color: AnimeXTokens.textPrimary,
                                      weight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    animeTitle,
                                    style: dmSansStyle(
                                      size: 12,
                                      color: AnimeXTokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      if (ep.duration != null &&
                                          ep.duration! > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '${ep.duration} min',
                                            style: dmSansStyle(
                                              size: 10.5,
                                              color: AnimeXTokens.textSecondary,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (ep.airedAt != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'Aired ${ep.airedAt!.year}-${ep.airedAt!.month.toString().padLeft(2, '0')}-${ep.airedAt!.day.toString().padLeft(2, '0')}',
                                            style: dmSansStyle(
                                              size: 10.5,
                                              color: AnimeXTokens.textSecondary,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(height: 1, color: AnimeXTokens.border),
                        const SizedBox(height: 14),

                        // "What Happened" Info Section
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_stories_outlined,
                              size: 18,
                              color: AnimeXTokens.accentWarm,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'What happened in this episode',
                              style: dmSansStyle(
                                size: 13.5,
                                color: AnimeXTokens.accentWarm,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          synopsis.isNotEmpty
                              ? synopsis
                              : 'No detailed synopsis is available for this episode yet.',
                          style: interBodyStyle(
                            size: 13,
                            color: AnimeXTokens.textSecondary,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action button
                        if (!isPlaying)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                onPlay();
                              },
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Play Episode ${ep.number}',
                                style: dmSansStyle(
                                  size: 13.5,
                                  color: Colors.white,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AnimeXTokens.accent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AnimeXTokens.radiusMd,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
