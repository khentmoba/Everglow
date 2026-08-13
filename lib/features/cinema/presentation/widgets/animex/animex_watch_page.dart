import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/anilist_detail.dart';
import '../../../data/models/animex_models.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/ani_zip_service.dart';
import '../../../data/services/anilist_service.dart';
import '../../../data/services/animex_stores.dart';

import 'animex_badges.dart';
import 'animex_buttons.dart';
import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_player.dart';
import 'animex_poster_row.dart';
import 'animex_section_header.dart';
import 'animex_tokens.dart';
part 'animex_watch_page_widgets.dart';

class _ServerOption {
  final String name;
  final String Function(int episode, String audio) urlBuilder;
  final bool available;

  const _ServerOption({
    required this.name,
    required this.urlBuilder,
    this.available = true,
  });
}

/// Anime detail / watch page: hero with info, video player with server
/// tabs + sub/dub toggle, episode grid, share, playlists and
/// recommendations.
class AnimeXWatchPage extends StatefulWidget {
  final AnimeXController controller;

  const AnimeXWatchPage({super.key, required this.controller});

  @override
  State<AnimeXWatchPage> createState() => _AnimeXWatchPageState();
}

class _AnimeXWatchPageState extends State<AnimeXWatchPage> {
  final AniListService _aniList = AniListService();
  final AniZipService _aniZip = AniZipService();
  final ScrollController _scrollCtrl = ScrollController();

  AniListDetail? _detail;
  List<AniListEpisode> _episodes = [];
  late int _selectedEpisode;
  int _episodePage = 1;
  String _audio = 'sub';
  int _serverIndex = 0;
  List<_ServerOption> _servers = [];
  final Set<int> _failedServerIndices = {};
  bool _showErrorCard = false;
  bool _probingServer = false;

  static const _episodesPerPage = 24;

  MediaItem get _item => widget.controller.watchItem!;
  int get _malId => _item.tmdbId;
  int? get _anilistId => _item.anilistId;

  @override
  void initState() {
    super.initState();
    final resume = context
        .read<AnimexStores>()
        .findHistory('animex-${_anilistId ?? _malId}');
    _selectedEpisode = resume?.episode ?? _item.currentEpisode ?? 1;
    _load();
  }

  Future<void> _load() async {
    final detail = await _aniList.fetchDetailsWithFallback(
      anilistId: _anilistId,
      malId: _malId,
    );
    var tmdbId = _item.tmdbId;
    try {
      final mappings = await _aniZip.fetchMappings(_malId);
      final mapped = mappings?['mappings'] as Map<String, dynamic>?;
      final tvdb = mapped?['themoviedb_id'];
      if (tvdb is num && tvdb > 0) tmdbId = tvdb.toInt();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _episodes = _buildEpisodeList(detail);
      if (_episodes.isNotEmpty) {
        _selectedEpisode =
            _selectedEpisode.clamp(1, _episodes.length).toInt();
      }
      _servers = _buildServers(tmdbId);
    });
    _recordHistory(_selectedEpisode);
    _probeCurrentServer();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<AniListEpisode> _buildEpisodeList(AniListDetail? detail) {
    final fromDetail = detail?.episodes ?? const <AniListEpisode>[];
    if (fromDetail.isNotEmpty) return fromDetail;
    final count = detail?.episodeCount ?? _item.episodeCount ?? 12;
    if (count <= 0) return const [];
    return List.generate(count, (i) => AniListEpisode(number: i + 1));
  }

  List<_ServerOption> _buildServers(int tmdbId) {
    final anilistId = _anilistId;
    return [
      _ServerOption(
        name: 'Server 1',
        urlBuilder: (ep, audio) =>
            'https://player.videasy.net/tv/$tmdbId?season=1&episode=$ep',
        available: tmdbId > 0,
      ),
      _ServerOption(
        name: 'Server 2',
        urlBuilder: (ep, audio) =>
            'https://megaplay.buzz/stream/ani/$anilistId/$ep/$audio',
        available: anilistId != null,
      ),
      _ServerOption(
        name: 'Server 3',
        urlBuilder: (ep, audio) =>
            'https://vidnest.fun/anime/$anilistId/$ep/$audio',
        available: anilistId != null,
      ),
      _ServerOption(
        name: 'Server 4',
        urlBuilder: (ep, audio) =>
            'https://tryembed.us.cc/embed/anime/$anilistId/$ep/'
            '${audio == 'sub' ? '1' : '2'}',
        available: anilistId != null,
      ),
    ];
  }

  void _selectEpisode(int episode) {
    if (_selectedEpisode == episode) return;
    setState(() => _selectedEpisode = episode);
    _resetForNewEpisode();
    _recordHistory(episode);
  }

  void _stepEpisode(int delta) {
    final next = (_selectedEpisode + delta).clamp(1, _episodes.length);
    if (next != _selectedEpisode) _selectEpisode(next);
  }

  void _recordHistory(int episode) {
    final stores = context.read<AnimexStores>();
    stores.recordWatch(
      key: 'animex-${_anilistId ?? _malId}',
      anilistId: _anilistId,
      malId: _malId,
      title: _item.title,
      coverUrl: _item.posterUrl,
      episode: episode,
      episodeMinutes: _detail?.duration ?? 24,
    );
  }

  String get _playerUrl {
    final servers = _servers.where((s) => s.available).toList();
    if (servers.isEmpty) return '';
    final index = _serverIndex.clamp(0, servers.length - 1);
    return servers[index].urlBuilder(_selectedEpisode, _audio);
  }

  void _handleContentError() {
    if (!mounted) return;
    final available = <int>[];
    for (var i = 0; i < _servers.length; i++) {
      if (_servers[i].available) available.add(i);
    }
    if (available.isEmpty) return;
    _failedServerIndices.add(_serverIndex);
    final next = available
        .where((i) => !_failedServerIndices.contains(i))
        .toList();
    if (next.isEmpty) {
      setState(() => _showErrorCard = true);
      return;
    }
    setState(() {
      _serverIndex = next.first;
      _showErrorCard = false;
    });
    _probeCurrentServer();
  }

  void _selectServer(int index) {
    setState(() {
      _serverIndex = index;
      _failedServerIndices.remove(index);
      _showErrorCard = false;
    });
    _probeCurrentServer();
  }

  /// Fetches the embed URL from our origin (the providers send permissive
  /// CORS headers) and scans the HTML for their "content unavailable"
  /// error page. When found, advances to the next available server so the
  /// user never stares at a dead "We're Sorry / 410" iframe.
  Future<void> _probeCurrentServer() async {
    final url = _playerUrl;
    if (url.isEmpty || _probingServer) return;
    setState(() => _probingServer = true);
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      final body = utf8.decode(response.bodyBytes);
      if (_isProviderErrorPage(body) && mounted) {
        _handleContentError();
      }
    } catch (_) {
      // Network errors are ambiguous; leave the iframe up so the user can
      // still try the current server manually.
    } finally {
      if (mounted) setState(() => _probingServer = false);
    }
  }

  bool _isProviderErrorPage(String body) {
    final lower = body.toLowerCase();
    return lower.contains("we're sorry") ||
        lower.contains('error code: <span>410</span>') ||
        lower.contains('error - megaplay') ||
        (lower.contains('410') && lower.contains('copyright violation'));
  }

  void _resetForNewEpisode() {
    _failedServerIndices.clear();
    _showErrorCard = false;
  }

  String get _displayTitle {
    final japanese = context.select<AnimexStores, bool>(
      (stores) => stores.titleJapanese,
    );
    return _titleFor(japanese);
  }

  String _titleFor(bool japanese) {
    final detail = _detail;
    if (japanese) {
      final native = detail?.titleNative ?? '';
      if (native.isNotEmpty) return native;
    }
    final english = detail?.titleEnglish ?? '';
    if (english.isNotEmpty) return english;
    return _item.title;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 64),
      children: [
        _buildHero(context),
        const SizedBox(height: 24),
        _buildPlayerSection(context),
        const SizedBox(height: 32),
        if (_detail != null) _buildInfoSection(context),
        if (_detail != null && _detail!.relations.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildRelations(context),
        ],
        if (_detail != null && _detail!.recommendations.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildRecommendations(context),
        ],
        const SizedBox(height: 32),
        AnimeXFooter(controller: widget.controller),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    final detail = _detail;
    final banner = detail?.bannerImageUrl.isNotEmpty == true
        ? detail!.bannerImageUrl
        : _item.backdropUrl;
    return Container(
      height: 420,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: AnimeXTokens.bg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (banner.isNotEmpty)
            Image.network(
              banner,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(color: AnimeXTokens.surfaceRaised),
            )
          else
            Container(color: AnimeXTokens.surfaceRaised),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC0A0A0F),
                  Color(0x59000000),
                  Color(0xF20A0A0F),
                ],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: widget.controller.closeDetail,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0x990A0A0F),
                        borderRadius: BorderRadius.circular(
                          AnimeXTokens.radiusLg,
                        ),
                        border: Border.all(color: AnimeXTokens.borderStrong),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
                  child: SizedBox(
                    width: 110,
                    height: 160,
                    child: _item.posterUrl.isEmpty
                        ? Container(color: AnimeXTokens.surfaceRaised)
                        : Image.network(
                            _item.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AnimeXTokens.surfaceRaised,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: bebasStyle(
                          size: 42,
                          color: AnimeXTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (detail != null)
                            statusBadge(detail.airingStatus),
                          if (detail != null && detail.format.isNotEmpty)
                            AnimeXBadge(
                              label: detail.format,
                              kind: AnimeXBadgeKind.episodes,
                            ),
                          if (detail?.episodeCount != null)
                            AnimeXBadge(
                              label: '${detail!.episodeCount} EP',
                              kind: AnimeXBadgeKind.episodes,
                            ),
                          if (detail?.averageScore != null &&
                              detail!.averageScore! > 0)
                            AnimeXBadge(
                              label:
                                  '★ ${detail.averageScore!.toStringAsFixed(1)}',
                              kind: AnimeXBadgeKind.rating,
                            ),
                          if (detail?.duration != null)
                            AnimeXBadge(
                              label: '${detail!.duration} min',
                              kind: AnimeXBadgeKind.episodes,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          AnimeXWatchNowButton(
                            label: 'Watch Now',
                            onTap: () => _scrollToPlayer(),
                          ),
                          AnimeXSecondaryButton(
                            label: 'Trailer',
                            icon: Icons.play_circle_outline_rounded,
                            onTap: () => showAnimexTrailer(
                              context,
                              youtubeId: detail?.trailerYoutubeId,
                              anilistId: _anilistId,
                              malId: _malId,
                              title: _displayTitle,
                            ),
                          ),
                          AnimeXSecondaryButton(
                            label: 'Save to Playlist',
                            icon: Icons.bookmark_add_outlined,
                            onTap: () => _showPlaylistSheet(context),
                          ),
                          AnimeXGhostButton(
                            label: 'Share',
                            icon: Icons.ios_share_rounded,
                            onTap: () => _showShareSheet(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSection(BuildContext context) {
    final episodes = _episodes;
    final resume = context
        .watch<AnimexStores>()
        .findHistory('animex-${_anilistId ?? _malId}');
    final resumeEpisode = resume?.episode;
    final pageCount =
        (episodes.length / _episodesPerPage).ceil().clamp(1, 1 << 31);
    final pageEpisodes = episodes
        .skip((_episodePage - 1) * _episodesPerPage)
        .take(_episodesPerPage)
        .toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnimeXTokens.pageMaxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showErrorCard)
              _buildErrorCard(context)
            else
              AnimeXPlayerFrame(
                key: ValueKey('player-$_playerUrl'),
                url: _playerUrl,
                onContentError: _handleContentError,
                scrollController: _scrollCtrl,
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < _servers.length; i++)
                  if (_servers[i].available)
                    GestureDetector(
                      onTap: () => _selectServer(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _serverIndex == i
                              ? AnimeXTokens.accent.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            AnimeXTokens.radiusSm,
                          ),
                          border: Border.all(
                            color: _serverIndex == i
                                ? AnimeXTokens.accent.withValues(alpha: 0.45)
                                : AnimeXTokens.border,
                          ),
                        ),
                        child: Text(
                          _servers[i].name,
                          style: dmSansStyle(
                            size: 12,
                            color: _serverIndex == i
                                ? AnimeXTokens.accentWarm
                                : AnimeXTokens.textSecondary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                const SizedBox(width: 6),
                _AudioToggle(
                  audio: _audio,
                  onChanged: (a) {
                    setState(() => _audio = a);
                    _failedServerIndices.clear();
                    _showErrorCard = false;
                    _probeCurrentServer();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'All Episodes',
                  style: dmSansStyle(
                    size: 16,
                    color: AnimeXTokens.textPrimary,
                    weight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (resumeEpisode != null &&
                    resumeEpisode != _selectedEpisode)
                  GestureDetector(
                    onTap: () => _selectEpisode(resumeEpisode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AnimeXTokens.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AnimeXTokens.accent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Resume EP $resumeEpisode',
                        style: dmSansStyle(
                          size: 11.5,
                          color: AnimeXTokens.accent,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (pageCount > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      '$_episodePage / $pageCount',
                      style: dmSansStyle(
                        size: 12,
                        color: AnimeXTokens.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (pageEpisodes.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                alignment: Alignment.center,
                child: Text(
                  'Episode List Unavailable',
                  style: dmSansStyle(
                    size: 13,
                    color: AnimeXTokens.textSecondary,
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridColumns(context),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  mainAxisExtent: 38,
                ),
                itemCount: pageEpisodes.length,
                itemBuilder: (context, i) {
                  final ep = pageEpisodes[i].number;
                  final active = ep == _selectedEpisode;
                  return GestureDetector(
                    onTap: () => _selectEpisode(ep),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? AnimeXTokens.accent
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(
                          AnimeXTokens.radiusSm,
                        ),
                        border: Border.all(
                          color: active
                              ? AnimeXTokens.accent
                              : AnimeXTokens.border,
                        ),
                      ),
                      child: Text(
                        ep.toString().padLeft(2, '0'),
                        style: dmSansStyle(
                          size: 12,
                          color: active
                              ? Colors.white
                              : AnimeXTokens.textSecondary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (pageCount > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimeXGhostButton(
                    label: 'Prev',
                    onTap: _episodePage > 1
                        ? () => setState(() => _episodePage--)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  AnimeXGhostButton(
                    label: 'Next',
                    onTap: _episodePage < pageCount
                        ? () => setState(() => _episodePage++)
                        : null,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _EpisodeStepButton(
                  label: 'Prev Episode',
                  enabled: _selectedEpisode > 1,
                  onTap: () => _stepEpisode(-1),
                ),
                const SizedBox(width: 10),
                _EpisodeStepButton(
                  label: 'Next Episode',
                  enabled: _selectedEpisode < episodes.length,
                  onTap: () => _stepEpisode(1),
                ),
              ],
            ),
          ],
        ),
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnimeXTokens.pageMaxWidth),
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
                  value: detail.duration != null ? '${detail.duration} min' : '—',
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
    );
  }

  Widget _buildRelations(BuildContext context) {
    final relations = _detail!.relations
        .map((r) => MediaItem(
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
              format: r.format,
            ))
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
        .map((r) => MediaItem(
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
            ))
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

  void _scrollToPlayer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        460,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
      );
    });
  }

  int _gridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1280) return 6;
    if (width >= 640) return 4;
    return 2;
  }

  void _showPlaylistSheet(BuildContext context) {
    final stores = context.read<AnimexStores>();
    final item = _item;
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
                              p.items.any(
                                      (i) => i.anilistId == item.anilistId)
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: p.items.any(
                                      (i) => i.anilistId == item.anilistId)
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
                                  (i) => i.anilistId == item.anilistId)) {
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
                  launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
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

