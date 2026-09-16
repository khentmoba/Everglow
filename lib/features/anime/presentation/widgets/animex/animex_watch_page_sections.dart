part of 'animex_watch_page.dart';

/// Player + info section builders for [_AnimeXWatchPageState].
extension _AnimeXWatchPageSections on _AnimeXWatchPageState {
  Widget _buildPlayerSection(BuildContext context) {
    final episodes = _episodes;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1200;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxPlayerHeight = (viewportHeight - 280)
        .clamp(240.0, AnimeXTokens.playerMaxHeight)
        .toDouble();

    // The sidebar top-aligns with the player, so its height matches the
    // player's effective 16:9 height exactly (the player column and the
    // sidebar share the same row constraints).
    final contentWidth = (width - 48).clamp(
      0.0,
      AnimeXTokens.watchPageMaxWidth,
    );
    final playerColumnWidth = contentWidth - 20 - 380;
    final sidebarHeight = (playerColumnWidth * 9 / 16)
        .clamp(0.0, maxPlayerHeight)
        .toDouble();

    final playerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlayer(context),
        const SizedBox(height: 12),
        _buildCurrentEpisodeHeader(context),
        _buildServerNotice(context),
        if (!_showErrorCard && _playerUrl.isNotEmpty && _skipRowVisible) ...[
          const SizedBox(height: 4),
          _buildSkipRow(context),
        ],
        const SizedBox(height: 10),
        _buildServerAndAudioRow(context),
        const SizedBox(height: 12),
        _buildStepButtons(context),
      ],
    );

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AnimeXTokens.watchPageMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: playerColumn),
                const SizedBox(width: 20),
                SizedBox(
                  width: 380,
                  height: sidebarHeight,
                  child: _DesktopEpisodesSidebar(
                    episodes: episodes,
                    selectedEpisode: _selectedEpisode,
                    animeTitle: _displayTitle,
                    fallbackPoster: _item.posterUrl,
                    onSelectEpisode: _selectEpisode,
                    onShowInfo: _openEpisodeInfo,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AnimeXTokens.watchPageMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              playerColumn,
              const SizedBox(height: 24),
              _MobileEpisodesSection(
                episodes: episodes,
                selectedEpisode: _selectedEpisode,
                animeTitle: _displayTitle,
                fallbackPoster: _item.posterUrl,
                onSelectEpisode: _selectEpisode,
                onShowInfo: _openEpisodeInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    // Cap height so the player never crowds out the server selector and episode
    // list on shorter screens (such as laptops or landscape tablets).
    final maxPlayerHeight = (viewportHeight - 280)
        .clamp(240.0, AnimeXTokens.playerMaxHeight)
        .toDouble();

    final player = _showErrorCard
        ? _buildErrorCard(context)
        : AnimeXPlayerFrame(
            key: ValueKey('player-$_playerUrl'),
            url: _playerUrl,
            onContentError: _handleContentError,
            onProgress: _onPlayerProgress,
            onPlayerEpisodeChanged: _onPlayerEpisodeChanged,
            scrollController: _scrollCtrl,
          );

    return Center(
      child: ConstrainedBox(
        key: const Key('animex-player-box'),
        constraints: BoxConstraints(maxHeight: maxPlayerHeight),
        child: player,
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AnimeXTokens.surface,
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
          border: Border.all(color: AnimeXTokens.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AnimeXTokens.accent,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              "We're Sorry!",
              style: dmSansStyle(
                size: 20,
                color: AnimeXTokens.textPrimary,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This episode is not available on the current server. '
                'Try another server below.',
                textAlign: TextAlign.center,
                style: dmSansStyle(
                  size: 13.5,
                  color: AnimeXTokens.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final detail = _detail!;
    final japanese = context.select<AnimexStores, bool>(
      (stores) => stores.titleJapanese,
    );
    final title = japanese
        ? (detail.titleNative.isNotEmpty ? detail.titleNative : _item.title)
        : (detail.titleEnglish.isNotEmpty ? detail.titleEnglish : _item.title);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AnimeXTokens.watchPageMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: bebasStyle(size: 30, color: AnimeXTokens.textPrimary),
              ),
              const SizedBox(height: 8),
              if (detail.synopsis.isNotEmpty)
                Text(
                  detail.synopsis,
                  style: interBodyStyle(size: 13.5, height: 1.65),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _InfoItem(
                    label: 'Studios',
                    value: detail.studios.isNotEmpty
                        ? detail.studios.take(2).join(', ')
                        : '—',
                  ),
                  _InfoItem(
                    label: 'Airing',
                    value: detail.airingStatus.isNotEmpty
                        ? detail.airingStatus
                        : '—',
                  ),
                  _InfoItem(
                    label: 'Duration',
                    value: detail.duration != null
                        ? '${detail.duration} min'
                        : '—',
                  ),
                  _InfoItem(
                    label: 'Genres',
                    value: detail.genres.isNotEmpty
                        ? detail.genres.take(3).join(', ')
                        : '—',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelations(BuildContext context) {
    final relations = _detail!.relations
        .map(
          (r) => MediaItem(
            id: '',
            tmdbId: r.malId ?? 0,
            title: r.title,
            mediaType: r.format.trim().toLowerCase() == 'movie'
                ? 'movie'
                : 'tv',
            posterPath: r.coverImageUrl,
            year: '',
            status: '',
            isAnime: true,
            addedAt: DateTime.now(),
            source: 'jikan',
            anilistId: r.id,
            format: r.format,
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: AnimeXSectionHeader(
            icon: Icons.link_rounded,
            title: 'Related',
          ),
        ),
        AnimeXPosterRow(
          items: relations,
          onTap: (item) => widget.controller.openWatch(item),
        ),
      ],
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    final recs = _detail!.recommendations
        .map(
          (r) => MediaItem(
            id: '',
            tmdbId: r.malId ?? 0,
            title: r.title,
            mediaType: 'tv',
            posterPath: r.coverImageUrl,
            year: '',
            status: '',
            isAnime: true,
            addedAt: DateTime.now(),
            source: 'jikan',
            anilistId: r.id,
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: AnimeXSectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'Recommended Anime',
          ),
        ),
        AnimeXPosterRow(
          items: recs,
          onTap: (item) => widget.controller.openWatch(item),
        ),
      ],
    );
  }

  void _showShareSheet(BuildContext context) {
    final japanese = context.read<AnimexStores>().titleJapanese;
    final title = _titleFor(japanese);
    final url = _detail?.siteUrl ?? 'https://everglow-1c6db.web.app/anime';
    final text = 'Watching $title on Everglow';
    final encodedUrl = Uri.encodeComponent(url);
    final encodedText = Uri.encodeComponent(text);
    final targets = <(String, IconData, String)>[
      (
        'Telegram',
        Icons.send_rounded,
        'https://t.me/share/url?url=$encodedUrl&text=$encodedText',
      ),
      (
        'WhatsApp',
        Icons.chat_bubble_outline_rounded,
        'https://wa.me/?text=$encodedText%20$encodedUrl',
      ),
      (
        'X / Twitter',
        Icons.alternate_email_rounded,
        'https://twitter.com/intent/tweet?url=$encodedUrl&text=$encodedText',
      ),
      (
        'Reddit',
        Icons.forum_outlined,
        'https://reddit.com/submit?url=$encodedUrl&title=$encodedText',
      ),
    ];
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Share',
                  style: dmSansStyle(
                    size: 16,
                    color: AnimeXTokens.textPrimary,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            for (final (label, icon, link) in targets)
              ListTile(
                leading: Icon(icon, color: AnimeXTokens.textPrimary, size: 20),
                title: Text(
                  label,
                  style: dmSansStyle(
                    size: 14,
                    color: AnimeXTokens.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  launchUrl(
                    Uri.parse(link),
                    mode: LaunchMode.externalApplication,
                  );
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
