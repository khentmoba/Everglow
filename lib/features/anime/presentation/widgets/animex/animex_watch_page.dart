import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../../shared/utils/responsive_image.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/anilist_detail.dart';
import '../../../data/models/animex_models.dart';
import '../../../../cinema/data/models/media_item.dart';
import '../../../../cinema/data/services/ani_zip_service.dart';
import '../../../../cinema/data/services/player_memory_service.dart';
import '../../../../cinema/data/services/tmdb_service.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../data/services/anilist_service.dart';
import '../../../data/services/animex_stores.dart';
import '../../../data/services/aniskip_service.dart';
import 'animex_videasy_progress.dart';

import 'animex_badges.dart';
import 'animex_buttons.dart';
import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_player.dart';
import 'animex_poster_row.dart';
import 'animex_section_header.dart';
import 'animex_tokens.dart';
import '../../../../../core/theme/app_colors.dart';
part 'animex_watch_page_widgets.dart';
part 'animex_watch_page_sheets.dart';

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
  final AniSkipService _aniSkip = AniSkipService();
  final ScrollController _scrollCtrl = ScrollController();

  /// Community OP/ED timestamps for the current episode, if anyone marked it.
  AniSkipTimes? _skipTimes;

  /// One-shot jump target (seconds) appended as Videasy `progress=`.
  /// Cleared on episode/server change so it never leaks across videos.
  int? _skipJumpSeconds;

  /// Last Videasy-reported playback position (seconds). Null on other
  /// servers or before the first progress event — the skip buttons stay
  /// manually visible until position is known.
  double? _playbackPosition;

  AniListDetail? _detail;
  List<AniListEpisode> _episodes = [];
  late int _selectedEpisode;
  int _episodePage = 1;
  String _audio = 'sub';
  int _serverIndex = 0;
  final PlayerMemoryService _memoryService = PlayerMemoryService();
  late final TMDBService _tmdbService = TMDBService();
  Timer? _progressThrottler;
  Timer? _heartbeatTimer;

  /// Server name remembered from the last visit; applied once the
  /// server list resolves in [_load].
  String? _rememberedServer;

  String get _memoryKey =>
      PlayerMemoryService.animexKey(anilistId: _anilistId, malId: _malId);
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
    final resume = context.read<AnimexStores>().findHistory(
      'animex-${_anilistId ?? _malId}',
    );
    _selectedEpisode = resume?.episode ?? _item.currentEpisode ?? 1;
    _load();
    _fetchSkipTimes();
    _restoreMemory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _saveWatchProgress(episode: _selectedEpisode);
    });
  }

  /// Restores this anime's last-used server and sub/dub choice.
  /// The episode itself already resumes via [AnimexStores] history.
  Future<void> _restoreMemory() async {
    final memory = await _memoryService.load(_memoryKey);
    if (!mounted) return;
    final audio = memory.audio ?? '';
    final server = memory.server;
    if ((audio == 'sub' || audio == 'dub') && audio != _audio) {
      setState(() => _audio = audio);
    }
    if (server != null && server.isNotEmpty) {
      _rememberedServer = server;
      final index = _servers.indexWhere(
        (s) => s.available && s.name == server,
      );
      if (index != -1 && index != _serverIndex && mounted) {
        setState(() => _serverIndex = index);
      }
    }
  }

  /// Loads AniSkip OP/ED times for the selected episode. Stale responses
  /// (user zapped to another episode mid-flight) are dropped.
  Future<void> _fetchSkipTimes() async {
    final malId = _malId;
    final episode = _selectedEpisode;
    if (malId <= 0) return;
    final times = await _aniSkip.fetchSkipTimes(malId, episode);
    if (!mounted || _selectedEpisode != episode) return;
    setState(() => _skipTimes = times);
  }

  /// Jumps past the opening/ending. Videasy honors `progress=` so the
  /// player reloads at the destination; other servers have no known seek
  /// param, so Clair gets the exact time to drag to instead.
  /// Videasy progress events drive the auto-appearing skip buttons. Only
  /// visibility flips rebuild — the page doesn't repaint on every tick.
  /// Stale events (previous episode still talking) are dropped.
  void _onPlayerProgress(VideasyProgress progress) {
    if (!mounted) return;
    final episode = progress.episode;
    if (episode != null && episode != _selectedEpisode) return;
    final before = _skipRowVisible;
    _playbackPosition = progress.positionSeconds;
    if (before != _skipRowVisible) setState(() {});
    _scheduleProgressHeartbeat(
      progress.positionSeconds,
      progress.durationSeconds,
    );
  }

  /// Whether the skip row shows anything right now: without a known
  /// position (other servers, events warming up) every marked button
  /// shows; once Videasy reports position, each button only appears
  /// inside its own timestamps.
  bool get _skipRowVisible {
    final times = _skipTimes;
    if (times == null || times.isEmpty) return false;
    final pos = _playbackPosition;
    if (pos == null) return true;
    return _skipButtonVisible(times.opening) ||
        _skipButtonVisible(times.ending);
  }

  bool _skipButtonVisible(AniSkipTime? time) {
    if (time == null) return false;
    final pos = _playbackPosition;
    if (pos == null) return true;
    return skipVisibleAt(time, pos);
  }

  void _skipTo(AniSkipTime time, String label) {
    if (_playerUrl.contains('videasy')) {
      // Position resets so the buttons stay visible while the player
      // reloads at the destination, then auto-hide on the next event.
      setState(() {
        _skipJumpSeconds = time.end.round();
        _playbackPosition = null;
      });
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "This server can't auto-jump — drag the bar to ${time.endLabel} to skip the $label.",
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _load() async {
    final malId = _malId;
    final anilistId = _anilistId;
    if (malId <= 0 && anilistId == null) return;
    final detail = await _aniList.fetchDetailsWithFallback(
      anilistId: anilistId,
      malId: malId,
    );
    int? tmdbId;
    try {
      final mappings = await _aniZip.fetchMappings(_malId);
      final mapped = mappings?['mappings'] as Map<String, dynamic>?;
      final raw = mapped?['themoviedb_id'];
      if (raw is num && raw > 0) {
        tmdbId = raw.toInt();
      } else if (raw is String && raw.isNotEmpty) {
        final parsed = int.tryParse(raw);
        if (parsed != null && parsed > 0) tmdbId = parsed;
      }
    } catch (_) {}
    final resolvedTmdbId = tmdbId ?? 0;
    if (!mounted) return;
    final nextServers = _buildServers(resolvedTmdbId);
    final firstAvailable = nextServers.indexWhere((s) => s.available);
    setState(() {
      _detail = detail;
      _episodes = _buildEpisodeList(detail);
      if (_episodes.isNotEmpty) {
        _selectedEpisode = _selectedEpisode.clamp(1, _episodes.length).toInt();
      }
      _servers = nextServers;
      final rememberedIndex = _rememberedServer == null
          ? -1
          : nextServers.indexWhere(
              (s) => s.available && s.name == _rememberedServer,
            );
      if (rememberedIndex != -1) {
        _serverIndex = rememberedIndex;
      } else if (firstAvailable != -1 &&
          (_serverIndex >= _servers.length ||
              !_servers[_serverIndex].available)) {
        _serverIndex = firstAvailable;
      }
    });
    _recordHistory(_selectedEpisode);
    _saveWatchProgress(episode: _selectedEpisode);
    _startPeriodicHeartbeat();
    _probeCurrentServer();
  }

  @override
  void dispose() {
    _progressThrottler?.cancel();
    _heartbeatTimer?.cancel();
    _saveWatchProgress();
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
        name: 'Server 3',
        urlBuilder: (ep, audio) =>
            'https://vidnest.fun/anime/$anilistId/$ep/$audio',
        available: anilistId != null,
      ),
      _ServerOption(
        name: 'Server 1',
        urlBuilder: (ep, audio) =>
            'https://player.videasy.net/tv/$tmdbId?season=1&episode=$ep',
        available: tmdbId > 0,
      ),
      _ServerOption(
        name: 'Server 4',
        urlBuilder: (ep, audio) =>
            'https://tryembed.us.cc/embed/anime/$anilistId/$ep/'
            '${audio == 'sub' ? '1' : '2'}',
        available: anilistId != null,
      ),
      _ServerOption(
        name: 'Server 2',
        urlBuilder: (ep, audio) =>
            'https://megaplay.buzz/stream/ani/$anilistId/$ep/$audio',
        available: false,
      ),
    ];
  }

  void _selectEpisode(int episode) {
    if (_selectedEpisode == episode) return;
    setState(() => _selectedEpisode = episode);
    _resetForNewEpisode();
    _recordHistory(episode);
    _saveWatchProgress(episode: episode, positionSeconds: 0);
    _fetchSkipTimes();
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

  String _watchingStatusFor(String userName) {
    switch (userName) {
      case 'khentsgdz':
        return 'watching-khent';
      case 'clairjassen':
        return 'watching-clair';
      default:
        return 'watching-self';
    }
  }

  String _currentUserName() {
    try {
      return Provider.of<AuthService>(context, listen: false).currentUser ?? '';
    } catch (_) {
      return '';
    }
  }

  void _saveWatchProgress({int? episode, double? positionSeconds}) {
    final userName = _currentUserName();
    if (userName.isEmpty) return;

    final ep = episode ?? _selectedEpisode;
    final pos = positionSeconds ?? _playbackPosition;
    final duration = (_detail?.duration != null && _detail!.duration! > 0)
        ? _detail!.duration! * 60
        : null;

    final status = _watchingStatusFor(userName);
    final effectiveTmdbId =
        _item.tmdbId > 0 ? _item.tmdbId : (_anilistId ?? 0);
    if (effectiveTmdbId <= 0) return;

    final mediaItem = MediaItem(
      id: '',
      tmdbId: effectiveTmdbId,
      title: _item.title,
      mediaType: _item.mediaType.isNotEmpty ? _item.mediaType : 'tv',
      posterPath:
          _item.posterPath.isNotEmpty ? _item.posterPath : _item.posterUrl,
      backdropPath: _item.backdropPath,
      year: _item.year,
      status: status,
      isAnime: true,
      userName: userName,
      addedAt: DateTime.now(),
      source: _item.source.isNotEmpty ? _item.source : 'jikan',
      anilistId: _anilistId,
      synopsis: _item.synopsis,
      episodeCount: _item.episodeCount ?? _detail?.episodeCount,
      airingStatus: _item.airingStatus,
      format: _item.format,
      studio: _item.studio,
      genres: _item.genres,
    );

    _tmdbService.updateProgress(
      mediaItem,
      userName,
      season: 1,
      episode: ep,
      timestamp: pos?.round(),
      durationSeconds: duration,
      status: status,
    );
  }

  void _scheduleProgressHeartbeat(double position, double duration) {
    if (_progressThrottler?.isActive ?? false) return;
    _progressThrottler = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      final userName = _currentUserName();
      if (userName.isEmpty) return;
      final effectiveTmdbId =
          _item.tmdbId > 0 ? _item.tmdbId : (_anilistId ?? 0);
      if (effectiveTmdbId <= 0) return;
      _tmdbService.heartbeatProgress(
        effectiveTmdbId,
        userName,
        season: 1,
        episode: _selectedEpisode,
        timestamp: position.round(),
        durationSeconds: duration.round(),
      );
    });
  }

  void _startPeriodicHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final userName = _currentUserName();
      if (userName.isEmpty) return;
      final effectiveTmdbId =
          _item.tmdbId > 0 ? _item.tmdbId : (_anilistId ?? 0);
      if (effectiveTmdbId <= 0) return;
      _tmdbService.heartbeatProgress(
        effectiveTmdbId,
        userName,
        season: 1,
        episode: _selectedEpisode,
        timestamp: _playbackPosition?.round(),
        durationSeconds:
            (_detail?.duration != null && _detail!.duration! > 0)
                ? _detail!.duration! * 60
                : null,
      );
    });
  }

  String get _playerUrl {
    final servers = _servers.where((s) => s.available).toList();
    if (servers.isEmpty) return '';
    final index = _serverIndex.clamp(0, servers.length - 1);
    final url = servers[index].urlBuilder(_selectedEpisode, _audio);
    // Skip-button jump: Videasy honors ?progress=<seconds>; other anime
    // servers have no known seek param, so the override only applies here.
    final jump = _skipJumpSeconds;
    if (jump != null && jump > 0 && url.contains('videasy')) {
      return url.contains('?') ? '$url&progress=$jump' : '$url?progress=$jump';
    }
    return url;
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
    _persistServer(next.first);
    _probeCurrentServer();
  }

  void _selectServer(int index) {
    setState(() {
      _serverIndex = index;
      _failedServerIndices.remove(index);
      _showErrorCard = false;
      _skipJumpSeconds = null;
      _playbackPosition = null;
    });
    _persistServer(index);
    _probeCurrentServer();
  }

  /// Remembers the working server for this anime so the next visit
  /// opens straight on it. Fire-and-forget.
  void _persistServer(int index) {
    if (index < 0 || index >= _servers.length) return;
    _memoryService.save(_memoryKey, server: _servers[index].name);
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
    _skipTimes = null;
    _skipJumpSeconds = null;
    _playbackPosition = null;
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
            AppNetworkImage(
              imageUrl: banner,
              fit: BoxFit.cover,
              cacheWidth: heroCacheWidth(context),
              errorWidget: Container(color: AnimeXTokens.surfaceRaised),
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
                  AppColors.scrimMedium,
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
                        : AppNetworkImage(
                            imageUrl: _item.posterUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 250,
                            errorWidget: Container(
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
                          if (detail != null) statusBadge(detail.airingStatus),
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
    final resume = context.watch<AnimexStores>().findHistory(
      'animex-${_anilistId ?? _malId}',
    );
    final resumeEpisode = resume?.episode;
    final pageCount = (episodes.length / _episodesPerPage).ceil().clamp(
      1,
      1 << 31,
    );
    final pageEpisodes = episodes
        .skip((_episodePage - 1) * _episodesPerPage)
        .take(_episodesPerPage)
        .toList();

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
              _buildPlayer(context),
              const SizedBox(height: 16),
            if (!_showErrorCard &&
                _playerUrl.isNotEmpty &&
                _skipRowVisible) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_skipButtonVisible(_skipTimes!.opening))
                    AnimeXGhostButton(
                      label:
                          'Skip Opening \u2192 ${_skipTimes!.opening!.endLabel}',
                      icon: Icons.skip_next_rounded,
                      color: AnimeXTokens.accentWarm,
                      onTap: () => _skipTo(_skipTimes!.opening!, 'opening'),
                    ),
                  if (_skipButtonVisible(_skipTimes!.ending))
                    AnimeXGhostButton(
                      label:
                          'Skip Ending \u2192 ${_skipTimes!.ending!.endLabel}',
                      icon: Icons.skip_next_rounded,
                      color: AnimeXTokens.accentWarm,
                      onTap: () => _skipTo(_skipTimes!.ending!, 'ending'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
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
                    _memoryService.save(_memoryKey, audio: a);
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
                if (resumeEpisode != null && resumeEpisode != _selectedEpisode)
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _EpisodeStepButton(
                  label: 'Prev Episode',
                  enabled: _selectedEpisode > 1,
                  onTap: () => _stepEpisode(-1),
                ),
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
            mediaType: 'tv',
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
    if (width >= 840) return 6;
    if (width >= 540) return 4;
    return 2;
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
