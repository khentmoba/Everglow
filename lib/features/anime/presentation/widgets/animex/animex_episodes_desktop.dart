part of 'animex_watch_page.dart';

/// PC sidebar episode row item matching Reference Image #1.
class _DesktopEpisodeTile extends StatefulWidget {
  final AniListEpisode episode;
  final String fallbackPoster;
  final String animeTitle;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _DesktopEpisodeTile({
    required this.episode,
    required this.fallbackPoster,
    required this.animeTitle,
    required this.isPlaying,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  State<_DesktopEpisodeTile> createState() => _DesktopEpisodeTileState();
}

class _DesktopEpisodeTileState extends State<_DesktopEpisodeTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final title = (ep.title != null && ep.title!.isNotEmpty)
        ? ep.title!
        : 'Episode ${ep.number}';
    final hasSynopsis = ep.synopsis != null && ep.synopsis!.trim().isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isPlaying
                ? AnimeXTokens.accent.withValues(alpha: 0.14)
                : (_hovered
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
            border: Border.all(
              color: widget.isPlaying
                  ? AnimeXTokens.accent.withValues(alpha: 0.5)
                  : (_hovered
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.transparent),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EpisodeThumbnail(
                episode: ep,
                fallbackPoster: widget.fallbackPoster,
                isPlaying: widget.isPlaying,
                width: 116,
                height: 66,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: dmSansStyle(
                        size: 12.5,
                        color: widget.isPlaying
                            ? AnimeXTokens.accentWarm
                            : AnimeXTokens.textPrimary,
                        weight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.animeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dmSansStyle(
                        size: 11,
                        color: AnimeXTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (widget.isPlaying) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AnimeXTokens.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'Watching',
                              style: dmSansStyle(
                                size: 10,
                                color: AnimeXTokens.accentWarm,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (hasSynopsis)
                          GestureDetector(
                            onTap: widget.onInfoTap,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 12,
                                    color: AnimeXTokens.accentWarm.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'What happened',
                                    style: dmSansStyle(
                                      size: 10,
                                      color: AnimeXTokens.accentWarm.withValues(
                                        alpha: 0.9,
                                      ),
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (ep.airedAt != null)
                          Text(
                            '${ep.airedAt!.year}-${ep.airedAt!.month.toString().padLeft(2, '0')}-${ep.airedAt!.day.toString().padLeft(2, '0')}',
                            style: dmSansStyle(
                              size: 10,
                              color: AnimeXTokens.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PC right-hand sidebar matching Reference Image #1.
class _DesktopEpisodesSidebar extends StatefulWidget {
  final List<AniListEpisode> episodes;
  final int selectedEpisode;
  final String animeTitle;
  final String fallbackPoster;
  final ValueChanged<int> onSelectEpisode;
  final void Function(AniListEpisode) onShowInfo;

  const _DesktopEpisodesSidebar({
    required this.episodes,
    required this.selectedEpisode,
    required this.animeTitle,
    required this.fallbackPoster,
    required this.onSelectEpisode,
    required this.onShowInfo,
  });

  @override
  State<_DesktopEpisodesSidebar> createState() =>
      _DesktopEpisodesSidebarState();
}

class _DesktopEpisodesSidebarState extends State<_DesktopEpisodesSidebar> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _listScrollCtrl = ScrollController();
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
  void didUpdateWidget(covariant _DesktopEpisodesSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedEpisode != widget.selectedEpisode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listScrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToActive() {
    if (!_listScrollCtrl.hasClients || widget.episodes.isEmpty) return;
    final activeIndex = widget.episodes.indexWhere(
      (e) => e.number == widget.selectedEpisode,
    );
    if (activeIndex <= 0) return;
    final target = (activeIndex * 84.0) - 100.0;
    _listScrollCtrl.animateTo(
      target.clamp(0.0, _listScrollCtrl.position.maxScrollExtent),
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

  AniListEpisode? _findEpisode(int num) {
    for (final e in widget.episodes) {
      if (e.number == num) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentEp = _findEpisode(widget.selectedEpisode);
    final currentTitle =
        currentEp?.title ?? 'Episode ${widget.selectedEpisode}';
    final nextEp = _findEpisode(widget.selectedEpisode + 1);
    final nextTitle =
        nextEp?.title ??
        (widget.selectedEpisode < widget.episodes.length
            ? 'Episode ${widget.selectedEpisode + 1}'
            : null);

    final displayList = _filteredEpisodes();

    return Container(
      decoration: BoxDecoration(
        color: AnimeXTokens.surface,
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
        border: Border.all(color: AnimeXTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Episodes',
                      style: dmSansStyle(
                        size: 16,
                        color: AnimeXTokens.textPrimary,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.episodes.length}',
                        style: dmSansStyle(
                          size: 11,
                          color: AnimeXTokens.textSecondary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Playing Episode ${widget.selectedEpisode} - $currentTitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dmSansStyle(
                    size: 11.5,
                    color: AnimeXTokens.textSecondary,
                  ),
                ),
                if (nextTitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Up next: $nextTitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dmSansStyle(
                      size: 11,
                      color: AnimeXTokens.accentWarm,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Search bar and sort toggle
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            AnimeXTokens.radiusMd,
                          ),
                          border: Border.all(color: AnimeXTokens.border),
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
                                style: dmSansStyle(
                                  size: 12,
                                  color: AnimeXTokens.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Find episode',
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
                                  size: 15,
                                  color: AnimeXTokens.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _sortAscending = !_sortAscending),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            AnimeXTokens.radiusMd,
                          ),
                          border: Border.all(color: AnimeXTokens.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.swap_vert_rounded,
                              size: 15,
                              color: AnimeXTokens.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sortAscending ? 'Oldest' : 'Newest',
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
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AnimeXTokens.border),
          // Scrollable episode list
          Expanded(
            child: displayList.isEmpty
                ? Center(
                    child: Text(
                      'No episodes found',
                      style: dmSansStyle(
                        size: 12.5,
                        color: AnimeXTokens.textMuted,
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _listScrollCtrl,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _listScrollCtrl,
                      padding: const EdgeInsets.all(8),
                      physics: const ClampingScrollPhysics(),
                      itemCount: displayList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final ep = displayList[index];
                        final active = ep.number == widget.selectedEpisode;
                        return _DesktopEpisodeTile(
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
          ),
        ],
      ),
    );
  }
}
