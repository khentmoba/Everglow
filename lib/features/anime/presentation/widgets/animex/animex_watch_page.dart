import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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

import 'animex_buttons.dart';
import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_player.dart';
import '../../../../../core/utils/logger.dart';
import 'animex_poster_row.dart';
import 'animex_section_header.dart';
import 'animex_tokens.dart';
import '../../../../../core/theme/app_colors.dart';
part 'animex_watch_page_widgets.dart';
part 'animex_watch_page_sheets.dart';
part 'animex_watch_page_episodes.dart';
part 'animex_episodes_desktop.dart';
part 'animex_episodes_mobile.dart';
part 'animex_watch_page_config.dart';
part 'animex_watch_page_sections.dart';

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

  /// Episode the player frame was loaded with. Manual navigation keeps it
  /// equal to [_selectedEpisode], but when the embed advances on its own
  /// (CineSrc auto-play or its built-in episode picker) only
  /// [_selectedEpisode] moves — the frame keeps playing the new episode
  /// without a reload while the list, header, and history follow it.
  late int _playerEpisode;
  String _audio = 'sub';
  int _serverIndex = 0;
  final PlayerMemoryService _memoryService = PlayerMemoryService();
  late final TMDBService _tmdbService = TMDBService();
  Timer? _progressThrottler;
  Timer? _heartbeatTimer;

  /// Server name remembered from the last visit; applied once the
  /// server list resolves in [_load].
  String? _rememberedServer;
  int? _mappedAnilistId;
  int? _mappedTmdbId;

  /// MAL episode number -> the season/episode pair TMDB expects, used
  /// by the TMDB-keyed players so shows whose MAL entry starts
  /// mid-series (e.g. Attack on Titan season 2) don't open the wrong
  /// episode.
  Map<int, ({int season, int episode})> _episodeSlots = const {};

  /// Whether the TMDB-keyed server uses the movie endpoint. Starts from
  /// the route item; [_load] refines it once the AniList detail lands.
  bool _isFilm = false;

  String get _memoryKey =>
      PlayerMemoryService.animexKey(anilistId: _anilistId, malId: _malId);
  List<_ServerOption> _servers = [];

  final Set<int> _failedServerIndices = {};
  bool _showErrorCard = false;
  bool _probingServer = false;
  bool _hideServerNotice = false;

  AniListEpisode? get _activeEpisode {
    for (final e in _episodes) {
      if (e.number == _selectedEpisode) return e;
    }
    return null;
  }

  String get _activeEpisodeTitle {
    final ep = _activeEpisode;
    final t = ep?.title;
    if (t != null && t.isNotEmpty) return t;
    return 'Episode $_selectedEpisode';
  }

  void _openEpisodeInfo(AniListEpisode ep) {
    _showEpisodeInfoSheet(
      context,
      episode: ep,
      animeTitle: _displayTitle,
      fallbackPoster: _item.posterUrl,
      isPlaying: ep.number == _selectedEpisode,
      onPlay: () => _selectEpisode(ep.number),
    );
  }

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
    _playerEpisode = _selectedEpisode;
    _isFilm = _item.isMovie;
    _servers = _buildServers();
    _serverIndex = AnimeXWatchPage.defaultServerIndex(_servers);
    _episodes = _buildEpisodeList(null);
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
      final normalized = AnimeXWatchPage.normalizeServerName(server);
      _rememberedServer = normalized;
      final index = _servers.indexWhere(
        (s) => s.available && s.name == normalized,
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
    int? mappedAnilistId;
    int? mappedTmdbId;
    // ani.zip mappings are MAL-keyed — querying mal_id=0 returns nothing,
    // which used to hide every TMDB-keyed server and leave Clair with a
    // Megavid-only list.
    final mappingsMalId = AnimeXWatchPage.resolveMappingsMalId(
      detailMalId: detail?.malId,
      routeMalId: _malId,
    );
    Map<int, ({int season, int episode})> episodeSlots = const {};
    // The ani.zip mappings payload also carries per-episode metadata
    // (title variants, overview/summary, still image, runtime, air
    // date) — AniList streaming episodes have clean titles + licensed
    // stills but no synopses, so merge both sources in
    // [_buildEpisodeList]. The mappings call is cached, so reusing the
    // same payload here costs no extra round-trip.
    Map<int, Map<String, dynamic>> aniZipEpisodes = const {};
    try {
      var mappings = mappingsMalId > 0
          ? await _aniZip.fetchMappings(mappingsMalId)
          : null;
      // MAL-less titles still resolve through the AniList id — without
      // this the TMDB-keyed servers never appear for them.
      mappings ??= await _aniZip.fetchMappingsByAnilist(
        anilistId ?? detail?.id ?? 0,
      );
      final mapped = mappings?['mappings'] as Map<String, dynamic>?;
      final rawAni = mapped?['anilist_id'];
      if (rawAni is num && rawAni > 0) {
        mappedAnilistId = rawAni.toInt();
      } else if (rawAni is String && rawAni.isNotEmpty) {
        final parsed = int.tryParse(rawAni);
        if (parsed != null && parsed > 0) mappedAnilistId = parsed;
      }
      final rawTmdb = mapped?['themoviedb_id'];
      if (rawTmdb is num && rawTmdb > 0) {
        mappedTmdbId = rawTmdb.toInt();
      } else if (rawTmdb is String && rawTmdb.isNotEmpty) {
        final parsed = int.tryParse(rawTmdb);
        if (parsed != null && parsed > 0) mappedTmdbId = parsed;
      }
      final rawEpisodes = mappings?['episodes'] as Map<String, dynamic>?;
      if (rawEpisodes != null && rawEpisodes.isNotEmpty) {
        final parsedMap = <int, Map<String, dynamic>>{};
        final parsedSlots = <int, ({int season, int episode})>{};
        rawEpisodes.forEach((key, value) {
          if (value is! Map<String, dynamic>) return;
          final n = int.tryParse(key.toString());
          if (n == null) return;
          parsedMap[n] = value;
          final season = (value['seasonNumber'] as num?)?.toInt();
          final episodeNo = (value['episodeNumber'] as num?)?.toInt();
          if (season != null &&
              season > 0 &&
              episodeNo != null &&
              episodeNo > 0) {
            parsedSlots[n] = (season: season, episode: episodeNo);
          }
        });
        aniZipEpisodes = parsedMap;
        episodeSlots = parsedSlots;
      }
    } catch (e, st) {
      Logger.e(
        'AnimeX: aniZip mappings fetch failed for ${detail?.titleEnglish}',
        error: e,
        stackTrace: st,
      );
    }
    // ani.zip doesn't know every title (e.g. Drifting Home has no
    // themoviedb_id) — without a TMDB id every TMDB-keyed server hides
    // and Clair is left with a Megavid-only list. Fall back to a strict
    // catalog search (exact title + kind + year, never a guess) so films
    // like that still open on Everglow.
    mappedTmdbId ??= await _searchTmdbFallback(detail);
    _mappedAnilistId = mappedAnilistId;
    _mappedTmdbId = mappedTmdbId;
    _episodeSlots = episodeSlots;
    _isFilm = _filmFor(detail);
    if (!mounted) return;
    final nextServers = _buildServers(
      mappedAnilistId: mappedAnilistId,
      mappedMalId: mappingsMalId,
    );
    setState(() {
      _detail = detail;
      _episodes = _buildEpisodeList(detail, aniZipEpisodes: aniZipEpisodes);
      if (_episodes.isNotEmpty) {
        _selectedEpisode = _selectedEpisode.clamp(1, _episodes.length).toInt();
        _playerEpisode = _playerEpisode.clamp(1, _episodes.length).toInt();
      }
      _servers = nextServers;
      // Fresh visits open on Everglow whenever it is available (it is
      // ours: no ads, no popups); an explicit remembered choice wins.
      _serverIndex = AnimeXWatchPage.defaultServerIndex(
        nextServers,
        rememberedServer: _rememberedServer,
      );
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

  /// Merges AniList streaming-episode data (clean titles, licensed
  /// stills) with ani.zip per-episode metadata (English/x-jat titles,
  /// overview/summary synopsis, TVDB stills, runtime, air date).
  /// AniList wins on title/thumbnail when present; ani.zip fills every
  /// gap so each episode card has a name, a thumbnail, and a
  /// "what happened" synopsis.
  List<AniListEpisode> _buildEpisodeList(
    AniListDetail? detail, {
    Map<int, Map<String, dynamic>> aniZipEpisodes = const {},
  }) {
    final fromDetail = detail?.episodes ?? const <AniListEpisode>[];
    final detailMap = <int, AniListEpisode>{
      for (final e in fromDetail) e.number: e,
    };

    final countFromDetail = detail?.episodeCount ?? _item.episodeCount ?? 0;
    final maxNum = [
      countFromDetail,
      if (detailMap.isNotEmpty) detailMap.keys.reduce((a, b) => a > b ? a : b),
      if (aniZipEpisodes.isNotEmpty)
        aniZipEpisodes.keys.reduce((a, b) => a > b ? a : b),
    ].fold<int>(0, (a, b) => a > b ? a : b);

    final effectiveCount = maxNum > 0 ? maxNum : 12;

    final out = <AniListEpisode>[];
    for (var i = 1; i <= effectiveCount; i++) {
      final base = detailMap[i];
      final az = aniZipEpisodes[i];
      final azTitles = az?['title'] as Map<String, dynamic>?;

      final azEnTitle = azTitles?['en'] as String?;
      final azJatTitle = azTitles?['x-jat'] as String?;
      final azJaTitle = azTitles?['ja'] as String?;

      final baseTitle = base?.title;
      final title =
          (baseTitle != null &&
              baseTitle.isNotEmpty &&
              !baseTitle.toLowerCase().startsWith('episode $i'))
          ? baseTitle
          : (azEnTitle ?? azJatTitle ?? baseTitle ?? 'Episode $i');

      final titleRomaji = base?.titleRomaji ?? azJatTitle ?? azJaTitle;

      final baseSynopsis = base?.synopsis;
      final synopsis = (baseSynopsis != null && baseSynopsis.isNotEmpty)
          ? baseSynopsis
          : ((az?['overview'] as String?)?.isNotEmpty == true
                ? (az?['overview'] as String?)
                : (az?['summary'] as String?));

      final baseThumb = base?.thumbnail;
      final thumbnail = (baseThumb != null && baseThumb.isNotEmpty)
          ? baseThumb
          : (az?['image'] as String?);

      final rawDuration = az?['runtime'] ?? az?['length'];
      final duration =
          base?.duration ??
          (rawDuration is num ? rawDuration.toInt() : null) ??
          detail?.duration;

      DateTime? airedAt = base?.airedAt;
      if (airedAt == null) {
        final rawAir = az?['airDate'] ?? az?['airdate'];
        if (rawAir is String && rawAir.isNotEmpty) {
          airedAt = DateTime.tryParse(rawAir);
        }
      }

      out.add(
        AniListEpisode(
          number: i,
          title: title,
          titleRomaji: titleRomaji,
          synopsis: synopsis,
          airedAt: airedAt,
          duration: duration,
          thumbnail: thumbnail,
        ),
      );
    }
    return out;
  }

  /// True when this title is a film rather than a series. The route
  /// item usually knows (`isMovie`), but ONA-listed films (e.g. Drifting
  /// Home: tv + a single 120-minute episode) don't — so an AniList
  /// MOVIE format or one long episode counts too. Films need the TMDB
  /// *movie* endpoint and a movie catalog search; series need TV.
  bool _filmFor(AniListDetail? detail) {
    if (_item.isMovie) return true;
    if (detail == null) return false;
    if (detail.format == 'MOVIE') return true;
    final episodes = detail.episodeCount ?? _item.episodeCount ?? 0;
    final minutes = detail.duration ?? 0;
    return episodes == 1 && minutes >= 60;
  }

  /// Strict TMDB fallback for titles ani.zip can't map. Tries the
  /// English, romaji, then route title; the first strict match wins.
  /// Never throws — a miss just leaves the TMDB servers hidden.
  Future<int?> _searchTmdbFallback(AniListDetail? detail) async {
    final candidates = <String>[
      if (detail != null) ...[
        detail.titleEnglish,
        detail.titleRomaji,
        detail.titleNative,
      ],
      _item.title,
    ];
    final isFilm = _filmFor(detail);
    final seen = <String>{};
    for (final candidate in candidates) {
      final query = candidate.trim();
      // English and route titles are often identical — one search each.
      if (query.isEmpty || !seen.add(query)) continue;
      List<MediaItem> results;
      try {
        results = await _tmdbService.searchMedia(query);
      } catch (_) {
        return null;
      }
      if (results.isEmpty) continue;
      final hit = AnimeXWatchPage.pickTmdbFallbackId(
        results: results,
        title: query,
        year: _item.year,
        isMovie: isFilm,
      );
      if (hit != null) return hit;
    }
    return null;
  }

  List<AnimeServerOption> _buildServers({
    int? mappedAnilistId,
    int? mappedMalId,
  }) {
    return AnimeXWatchPage.buildServers(
      anilistId: _anilistId ?? mappedAnilistId ?? _mappedAnilistId,
      malId: mappedMalId ?? _malId,
      tmdbId: _mappedTmdbId,
      episodeSlots: _episodeSlots,
      isMovie: _isFilm,
    );
  }

  void _selectEpisode(int episode) {
    if (_selectedEpisode == episode) return;
    // Manual navigation drives BOTH the UI and the player frame: the new
    // URL key reloads the embed on the picked episode.
    setState(() {
      _selectedEpisode = episode;
      _playerEpisode = episode;
    });
    _resetForNewEpisode();
    _recordHistory(episode);
    _saveWatchProgress(episode: episode, positionSeconds: 0);
    _fetchSkipTimes();
  }

  /// Follows the player when the embed changes episodes on its own.
  ///
  /// CineSrc auto-play (and its built-in episode picker) moves to the
  /// next episode inside the frame without telling us — the list used to
  /// keep highlighting the old episode. The embed announces each move
  /// (`cinesrc:nextepisode`, forwarded by our embed.html wrapper), so we
  /// move the selection, header, history, and progress to match while
  /// leaving the loaded frame untouched — no reload, no lost position.
  void _onPlayerEpisodeChanged(int tmdbSeason, int tmdbEpisode) {
    if (!mounted || _episodes.isEmpty) return;
    // Only the Everglow server reports internal episode changes. Anything
    // else arriving here is stale — a server switch already moved on.
    final current = (_serverIndex >= 0 && _serverIndex < _servers.length)
        ? _servers[_serverIndex]
        : null;
    if (current == null || current.name != 'Everglow') return;
    final mapped = AnimeXWatchPage.mapPlayerEpisodeToMal(
      tmdbSeason: tmdbSeason,
      tmdbEpisode: tmdbEpisode,
      episodeSlots: _episodeSlots,
      episodeCount: _episodes.length,
    );
    if (mapped == null || mapped == _selectedEpisode) return;
    setState(() => _selectedEpisode = mapped);
    _resetForNewEpisode();
    _recordHistory(mapped);
    _saveWatchProgress(episode: mapped, positionSeconds: 0);
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
    final effectiveTmdbId = _item.tmdbId > 0 ? _item.tmdbId : (_anilistId ?? 0);
    if (effectiveTmdbId <= 0) return;

    final mediaItem = MediaItem(
      id: '',
      tmdbId: effectiveTmdbId,
      title: _item.title,
      mediaType: _item.mediaType.isNotEmpty ? _item.mediaType : 'tv',
      posterPath: _item.posterPath.isNotEmpty
          ? _item.posterPath
          : _item.posterUrl,
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

    // Movies have no episode progress — write null so Firestore never
    // gains stale S1E1 fields that shelves would then display.
    // Series resolve the real season (ani.zip mapping, else the season in
    // the title) so "Black Clover Season 2" never saves as S1E1.
    final isMovie = mediaItem.isMovie;
    final progressSeason = AnimeXWatchPage.resolveProgressSeason(
      isMovie: isMovie,
      title: mediaItem.title,
      episode: ep,
      episodeSlots: _episodeSlots,
    );
    _tmdbService.updateProgress(
      mediaItem,
      userName,
      season: progressSeason,
      episode: isMovie ? null : ep,
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
      final effectiveTmdbId = _item.tmdbId > 0
          ? _item.tmdbId
          : (_anilistId ?? 0);
      if (effectiveTmdbId <= 0) return;
      _tmdbService.heartbeatProgress(
        effectiveTmdbId,
        userName,
        season: AnimeXWatchPage.resolveProgressSeason(
          isMovie: _item.isMovie,
          title: _item.title,
          episode: _selectedEpisode,
          episodeSlots: _episodeSlots,
        ),
        episode: _item.isMovie ? null : _selectedEpisode,
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
      final effectiveTmdbId = _item.tmdbId > 0
          ? _item.tmdbId
          : (_anilistId ?? 0);
      if (effectiveTmdbId <= 0) return;
      _tmdbService.heartbeatProgress(
        effectiveTmdbId,
        userName,
        season: AnimeXWatchPage.resolveProgressSeason(
          isMovie: _item.isMovie,
          title: _item.title,
          episode: _selectedEpisode,
          episodeSlots: _episodeSlots,
        ),
        episode: _item.isMovie ? null : _selectedEpisode,
        timestamp: _playbackPosition?.round(),
        durationSeconds: (_detail?.duration != null && _detail!.duration! > 0)
            ? _detail!.duration! * 60
            : null,
      );
    });
  }

  String get _playerUrl {
    if (_servers.isEmpty) return '';
    AnimeServerOption? current;
    if (_serverIndex >= 0 &&
        _serverIndex < _servers.length &&
        _servers[_serverIndex].available) {
      current = _servers[_serverIndex];
    } else {
      for (final s in _servers) {
        if (s.available) {
          current = s;
          break;
        }
      }
    }
    if (current == null) return '';
    // Built from the LOADED episode, not the selection: after a
    // player-driven advance the selection moves on while the frame keeps
    // playing, and the URL must stay byte-identical so Flutter reuses it.
    final url = current.urlBuilder(_playerEpisode, _audio);
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
      // A new server must load the episode actually being watched, which
      // may have drifted ahead of the loaded frame via player auto-play.
      _playerEpisode = _selectedEpisode;
      _showErrorCard = false;
    });
    _persistServer(next.first);
    _probeCurrentServer();
  }

  void _selectServer(int index) {
    setState(() {
      _serverIndex = index;
      // A new server must load the episode actually being watched, which
      // may have drifted ahead of the loaded frame via player auto-play.
      _playerEpisode = _selectedEpisode;
      _failedServerIndices.clear();
      _showErrorCard = false;
      _skipJumpSeconds = null;
      _playbackPosition = null;
    });
    _persistServer(index);
    _probeCurrentServer(autoAdvance: false);
  }

  /// Remembers the working server for this anime so the next visit
  /// opens straight on it. Fire-and-forget.
  void _persistServer(int index) {
    if (index < 0 || index >= _servers.length) return;
    _memoryService.save(_memoryKey, server: _servers[index].name);
  }

  /// Cloud helper that re-fetches any allowlisted page with permissive
  /// CORS, so the probe can read third-party embeds that send no CORS
  /// headers — a direct fetch from Flutter Web dies before a response
  /// exists.
  static const String _probeProxyUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml';

  /// Fetches the embed page for the dead-server probe: first directly
  /// (works for our own endpoints and any provider sending CORS), then
  /// through `proxyFetchHtml` when the browser blocks the request. Null
  /// when both paths fail — the caller leaves the iframe up.
  ///
  /// A non-200 answer counts as dead even when its body holds no known
  /// marker: Megavid's healthy player page contains the same "Embed
  /// Only" text as its 403 block page (a hidden div), so the status
  /// code is the only thing telling them apart. The sentinel reuses the
  /// marker the failure pages already carry.
  Future<String?> _fetchProbeBody(Uri url) async {
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return 'no playable stream sources';
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      // Missing CORS headers or a network hiccup. One retry through our
      // HTML proxy keeps the probe working from Flutter Web.
      try {
        final proxied = Uri.parse(
          '$_probeProxyUrl?url=${Uri.encodeComponent(url.toString())}',
        );
        final response = await http
            .get(proxied)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) return 'no playable stream sources';
        return utf8.decode(response.bodyBytes);
      } catch (e, st) {
        Logger.e(
          'AnimeX: server probe proxy fallback failed for $url',
          error: e,
          stackTrace: st,
        );
      }
      return null;
    }
  }

  /// Fetches the embed URL and scans the HTML for the provider's
  /// "content unavailable" error page. When found, advances to the next
  /// available server so the user never stares at a dead "We're Sorry /
  /// 410 / Couldn't Find This Episode" iframe.
  Future<void> _probeCurrentServer({bool autoAdvance = true}) async {
    final url = _playerUrl;
    if (url.isEmpty || _probingServer) return;
    setState(() => _probingServer = true);
    try {
      final body = await _fetchProbeBody(Uri.parse(url));
      if (body != null &&
          AnimeXWatchPage.isProviderErrorPage(body) &&
          mounted) {
        if (autoAdvance) {
          _handleContentError();
        } else {
          setState(() => _showErrorCard = true);
        }
      }
    } catch (_) {
      // Network errors are ambiguous; leave the iframe up so the user can
      // still try the current server manually.
    } finally {
      if (mounted) setState(() => _probingServer = false);
    }
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
        _buildTopBar(context),
        const SizedBox(height: 12),
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

  Widget _buildTopBar(BuildContext context) {
    final detail = _detail;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.controller.closeDetail,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0x990A0A0F),
                    borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dmSansStyle(
                      size: 15,
                      color: AnimeXTokens.textPrimary,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Episode $_selectedEpisode${_activeEpisodeTitle.isNotEmpty ? ' \u2022 $_activeEpisodeTitle' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dmSansStyle(
                      size: 11.5,
                      color: AnimeXTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (detail?.trailerYoutubeId != null)
              GestureDetector(
                onTap: () => showAnimexTrailer(
                  context,
                  youtubeId: detail?.trailerYoutubeId,
                  anilistId: _anilistId,
                  malId: _malId,
                  title: _displayTitle,
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(
                        AnimeXTokens.radiusSm,
                      ),
                      border: Border.all(color: AnimeXTokens.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 15,
                          color: AnimeXTokens.textPrimary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Trailer',
                          style: dmSansStyle(
                            size: 11.5,
                            color: AnimeXTokens.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showPlaylistSheet(context),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
                    border: Border.all(color: AnimeXTokens.border),
                  ),
                  child: const Icon(
                    Icons.bookmark_add_outlined,
                    size: 17,
                    color: AnimeXTokens.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showShareSheet(context),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
                    border: Border.all(color: AnimeXTokens.border),
                  ),
                  child: const Icon(
                    Icons.ios_share_rounded,
                    size: 17,
                    color: AnimeXTokens.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerNotice(BuildContext context) {
    if (_hideServerNotice) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x33FF2E63),
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
        border: Border.all(color: const Color(0x55FF2E63)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0x44FF2E63),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: AnimeXTokens.accentWarm,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "If the current server doesn't work, feel free to try the other available servers.",
              style: dmSansStyle(
                size: 11.5,
                color: Colors.white,
                weight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _hideServerNotice = true),
            child: const Icon(
              Icons.close_rounded,
              size: 15,
              color: AnimeXTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentEpisodeHeader(BuildContext context) {
    final ep = _activeEpisode;
    final epTitle = _activeEpisodeTitle;
    final airedAt = ep?.airedAt;
    final hasSynopsis = ep?.synopsis != null && ep!.synopsis!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          epTitle,
          style: dmSansStyle(
            size: 18,
            color: AnimeXTokens.textPrimary,
            weight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Episode $_selectedEpisode',
              style: dmSansStyle(
                size: 12,
                color: AnimeXTokens.accentWarm,
                weight: FontWeight.w700,
              ),
            ),
            if (ep?.duration != null && ep!.duration! > 0) ...[
              Text(
                '  \u2022  ',
                style: dmSansStyle(size: 11, color: AnimeXTokens.textMuted),
              ),
              Text(
                '${ep.duration} min',
                style: dmSansStyle(size: 12, color: AnimeXTokens.textSecondary),
              ),
            ],
            if (airedAt != null) ...[
              Text(
                '  \u2022  ',
                style: dmSansStyle(size: 11, color: AnimeXTokens.textMuted),
              ),
              Text(
                '${airedAt.year}-${airedAt.month.toString().padLeft(2, '0')}-${airedAt.day.toString().padLeft(2, '0')}',
                style: dmSansStyle(size: 12, color: AnimeXTokens.textSecondary),
              ),
            ],
            if (hasSynopsis) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => _openEpisodeInfo(ep),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_stories_outlined,
                        size: 14,
                        color: AnimeXTokens.accentWarm,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'What happened',
                        style: dmSansStyle(
                          size: 11.5,
                          color: AnimeXTokens.accentWarm,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSkipRow(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (_skipButtonVisible(_skipTimes!.opening))
          AnimeXGhostButton(
            label: 'Skip Opening \u2192 ${_skipTimes!.opening!.endLabel}',
            icon: Icons.skip_next_rounded,
            color: AnimeXTokens.accentWarm,
            onTap: () => _skipTo(_skipTimes!.opening!, 'opening'),
          ),
        if (_skipButtonVisible(_skipTimes!.ending))
          AnimeXGhostButton(
            label: 'Skip Ending \u2192 ${_skipTimes!.ending!.endLabel}',
            icon: Icons.skip_next_rounded,
            color: AnimeXTokens.accentWarm,
            onTap: () => _skipTo(_skipTimes!.ending!, 'ending'),
          ),
      ],
    );
  }

  Widget _buildServerAndAudioRow(BuildContext context) {
    return Wrap(
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
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
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
            setState(() {
              _audio = a;
              // The reloaded URL must carry the episode actually being
              // watched, which may have drifted ahead via auto-play.
              _playerEpisode = _selectedEpisode;
            });
            _memoryService.save(_memoryKey, audio: a);
            _failedServerIndices.clear();
            _showErrorCard = false;
            _probeCurrentServer();
          },
        ),
      ],
    );
  }

  Widget _buildStepButtons(BuildContext context) {
    return Wrap(
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
          enabled: _selectedEpisode < _episodes.length,
          onTap: () => _stepEpisode(1),
        ),
      ],
    );
  }
}
