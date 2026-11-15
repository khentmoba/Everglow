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
import '../../../../../core/services/offline_media/offline_media_item.dart';
import '../../../../../core/services/offline_media/offline_media_service.dart';
import '../../../../../core/services/offline_media/offline_media_storage.dart';
import '../../../../watch_party/presentation/widgets/start_watch_party_button.dart';
import '../../../data/services/anilist_service.dart';
import '../../../data/services/tmdb_anime_details.dart';
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

@visibleForTesting
Widget buildDesktopEpisodesSidebarForTesting({
  required List<AniListEpisode> episodes,
  required int selectedEpisode,
  required String animeTitle,
  required String fallbackPoster,
  required ValueChanged<int> onSelectEpisode,
  required void Function(AniListEpisode) onShowInfo,
  List<AniListSeason> seasons = const [],
  ValueChanged<AniListSeason>? onSelectSeason,
  AniListSeason? nextSeason,
  int animeId = 0,
}) {
  return _DesktopEpisodesSidebar(
    episodes: episodes,
    selectedEpisode: selectedEpisode,
    animeTitle: animeTitle,
    fallbackPoster: fallbackPoster,
    onSelectEpisode: onSelectEpisode,
    onShowInfo: onShowInfo,
    seasons: seasons,
    onSelectSeason: onSelectSeason,
    nextSeason: nextSeason,
    animeId: animeId,
  );
}

@visibleForTesting
Widget buildMobileEpisodesSectionForTesting({
  required List<AniListEpisode> episodes,
  required int selectedEpisode,
  required String animeTitle,
  required String fallbackPoster,
  required ValueChanged<int> onSelectEpisode,
  required void Function(AniListEpisode) onShowInfo,
  List<AniListSeason> seasons = const [],
  ValueChanged<AniListSeason>? onSelectSeason,
  AniListSeason? nextSeason,
  int animeId = 0,
}) {
  return _MobileEpisodesSection(
    episodes: episodes,
    selectedEpisode: selectedEpisode,
    animeTitle: animeTitle,
    fallbackPoster: fallbackPoster,
    onSelectEpisode: onSelectEpisode,
    onShowInfo: onShowInfo,
    seasons: seasons,
    onSelectSeason: onSelectSeason,
    nextSeason: nextSeason,
    animeId: animeId,
  );
}

class _AnimeXWatchPageState extends State<AnimeXWatchPage>
    with WidgetsBindingObserver {
  final AniListService _aniList = AniListService();
  final AniZipService _aniZip = AniZipService();
  final AniSkipService _aniSkip = AniSkipService();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _episodesKey = GlobalKey();

  AniSkipTimes? _skipTimes;

  int? _startSeconds;
  double? _lastKnownPosition;
  MediaItem? _accountProgress;
  double? _playbackDuration;
  double? _lastWindowedMaxPlayerHeight;
  bool _ready = false;
  bool _episodeChosen = false;
  AuthService? _auth;
  String _owner = '';

  double? _playbackPosition;

  late final MediaItem _watchItem;
  AniListDetail? _detail;
  List<AniListEpisode> _episodes = [];
  late int _selectedEpisode;

  late int _playerEpisode;
  String _audio = 'sub';
  int _serverIndex = 0;
  final PlayerMemoryService _memoryService = PlayerMemoryService();
  late final TMDBService _tmdbService = TMDBService();
  Timer? _progressThrottler;
  bool _hasUnsavedProgress = false;
  Future<void> _progressSave = Future.value();

  String? _rememberedServer;
  int? _mappedAnilistId;
  int? _mappedTmdbId;

  Map<int, ({int season, int episode})> _episodeSlots = const {};

  bool _isFilm = false;

  String get _memoryKey => _item.source == 'tmdb'
      ? PlayerMemoryService.cinemaKey(
          id: _item.tmdbId,
          mediaType: _item.mediaType,
          isAnime: false,
        )
      : PlayerMemoryService.animexKey(anilistId: _anilistId, malId: _malId);
  List<_ServerOption> _servers = [];

  final Set<int> _failedServerIndices = {};
  bool _showErrorCard = false;
  bool _probingServer = false;

  AniListEpisode? get _activeEpisode {
    for (final e in _episodes) {
      if (e.number == _selectedEpisode) return e;
    }
    return null;
  }

  String get _activeEpisodeTitle {
    final ep = _activeEpisode;
    final t = ep?.title;
    if (context.select<AnimexStores, bool>((stores) => stores.hideSpoilers)) {
      return 'Episode $_selectedEpisode';
    }
    if (t != null && t.isNotEmpty) return t;
    return 'Episode $_selectedEpisode';
  }

  void _openEpisodeInfo(AniListEpisode ep) {
    if (!_ready) return;
    _showEpisodeInfoSheet(
      context,
      episode: ep,
      animeTitle: _displayTitle,
      fallbackPoster: _item.posterUrl,
      isPlaying: ep.number == _selectedEpisode,
      hideSpoilers:
          context.read<AnimexStores>().hideSpoilers &&
          ep.number >= _selectedEpisode,
      onPlay: () => _selectEpisode(ep.number),
    );
  }

  MediaItem get _item => _watchItem;
  String get _historyKey => _item.source == 'tmdb'
      ? 'animex-tmdb-${_item.mediaType}-${_item.tmdbId}'
      : 'animex-${_anilistId ?? _malId}';
  int get _malId =>
      _detail?.malId ?? (_item.source == 'tmdb' ? 0 : _item.tmdbId);
  int? get _anilistId => _item.anilistId;

  List<AniListSeason> get _seasons => _detail?.seasons ?? const [];

  AniListSeason? get _nextSeason {
    final list = _seasons;
    if (list.length <= 1) return null;
    final index = list.indexWhere((s) => s.isCurrent);
    if (index >= 0 && index < list.length - 1) {
      return list[index + 1];
    }
    return null;
  }

  void _openSeason(AniListSeason season) {
    if (season.isCurrent) return;
    final item = MediaItem(
      id: '',
      tmdbId: season.malId ?? 0,
      title: season.title,
      mediaType: season.format.trim().toLowerCase() == 'movie' ? 'movie' : 'tv',
      posterPath: season.coverImageUrl,
      year: season.year != null && season.year! > 0 ? '${season.year}' : '',
      status: '',
      isAnime: true,
      addedAt: DateTime.now(),
      source: 'jikan',
      anilistId: season.id,
      format: season.format,
      episodeCount: season.episodeCount,
    );
    widget.controller.openWatch(item);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchItem = widget.controller.watchItem!;
    final resume = context.read<AnimexStores>().findHistory(_historyKey);
    try {
      _auth = context.read<AuthService>();
      _owner = _auth?.currentUser ?? '';
    } catch (_) {
      // Isolated demo/tests intentionally have no signed-in profile.
    }
    _selectedEpisode = AnimeXWatchPage.resolveResume(
      item: _item,
      saved: widget.controller.savedAnime(_item),
      local: resume,
      requestedEpisode: widget.controller.watchEpisode,
    ).episode;
    _playerEpisode = _selectedEpisode;
    _isFilm = _item.isMovie;
    _servers = _buildServers();
    _serverIndex = AnimeXWatchPage.defaultServerIndex(_servers);
    _episodes = _buildEpisodeList(null);
    _initialize();
  }

  String? _offlineBlobUrl;

  Future<void> _checkOfflinePlayback() async {
    final animeId = _watchItem.anilistId ?? _watchItem.tmdbId;
    var offlineItem = OfflineMediaService.instance.getItem(
      OfflineMediaService.animeEpisodeId(animeId, _playerEpisode),
    );
    if (offlineItem == null && _watchItem.tmdbId > 0) {
      offlineItem = OfflineMediaService.instance.getItem(
        OfflineMediaService.animeEpisodeId(_watchItem.tmdbId, _playerEpisode),
      );
    }
    if (offlineItem != null && offlineItem.isCompleted) {
      final url = await OfflineMediaService.instance.getPlayableUrl(
        offlineItem,
      );
      if (mounted && url != null && url.isNotEmpty) {
        if (_offlineBlobUrl != null && _offlineBlobUrl != url) {
          unawaited(
            OfflineMediaStorage.instance.revokeBlobUrl(_offlineBlobUrl!),
          );
        }
        setState(() => _offlineBlobUrl = url);
        return;
      }
    }
    if (_offlineBlobUrl != null) {
      unawaited(OfflineMediaStorage.instance.revokeBlobUrl(_offlineBlobUrl!));
      if (mounted) {
        setState(() => _offlineBlobUrl = null);
      }
    }
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([_load(), _restoreMemory()]);
    } catch (e, st) {
      Logger.e('AnimeX: watch initialization failed', error: e, stackTrace: st);
    }
    if (!mounted) return;
    await _checkOfflinePlayback();
    if (_episodes.isNotEmpty) {
      final knownCount = _detail?.episodeCount ?? _item.episodeCount;
      final episode = knownCount != null && knownCount > 0
          ? _selectedEpisode.clamp(1, knownCount).toInt()
          : _selectedEpisode;
      if (episode > _episodes.length) {
        _episodes = [
          ..._episodes,
          for (var n = _episodes.length + 1; n <= episode; n++)
            AniListEpisode(number: n),
        ];
      }
      if (episode != _selectedEpisode) {
        _startSeconds = null;
        _playbackPosition = null;
      }
      _selectedEpisode = episode;
      _playerEpisode = episode;
    }
    setState(() => _ready = true);
    _fetchSkipTimes();
    _recordHistory(_selectedEpisode);
    _probeCurrentServer();
  }

  Future<void> _restoreMemory() async {
    final memory = await _memoryService.load(_memoryKey);
    if (!mounted) return;
    MediaItem? saved;
    if (widget.loadSavedProgress != null) {
      saved = await widget.loadSavedProgress!(_item);
    } else if (_currentUserName().isNotEmpty) {
      saved = await _tmdbService.getSavedProgress(
        _item.tmdbId,
        _owner,
        source: _item.source,
        mediaType: _item.mediaType,
        anilistId: _anilistId,
      );
      saved ??= widget.controller.savedAnime(_item);
    }
    if (!mounted || (_auth != null && _currentUserName().isEmpty)) return;
    _accountProgress = saved;
    if (!_episodeChosen) {
      final local = context.read<AnimexStores>().findHistory(_historyKey);
      final resume = AnimeXWatchPage.resolveResume(
        item: _item,
        saved: saved,
        local: local,
        requestedEpisode: widget.controller.watchEpisode,
      );
      _selectedEpisode = resume.episode;
      _playerEpisode = resume.episode;
      _startSeconds = resume.seconds;
      _hasUnsavedProgress = false;
      _lastKnownPosition = resume.seconds?.toDouble();
      _playbackPosition = null;
      _playbackDuration = (saved ?? _item).durationSeconds?.toDouble();
    }
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

  Future<void> _fetchSkipTimes() async {
    final malId = _malId;
    final episode = _selectedEpisode;
    if (malId <= 0) return;
    final times = await _aniSkip.fetchSkipTimes(malId, episode);
    if (!mounted || _selectedEpisode != episode) return;
    setState(() => _skipTimes = times);
  }

  void _onPlayerProgress(VideasyProgress progress) {
    if (!mounted || !_ready) return;
    final episode = progress.episode;
    if (episode != null && episode != _selectedEpisode) return;
    _playbackPosition = progress.positionSeconds;
    _lastKnownPosition = progress.positionSeconds;
    _playbackDuration = progress.durationSeconds;
    _hasUnsavedProgress = true;
    _scheduleProgressSave();
  }

  String? get _nextToken => _nextUp?.token;

  bool get _nextIsSeason => _nextUp?.isSeason ?? false;

  ({String token, bool isSeason})? get _nextUp => AnimeXWatchPage.nextUp(
    isFilm: _isFilm,
    selectedEpisode: _selectedEpisode,
    episodeCount: _episodes.length,
    hasNextSeason: _nextSeason != null,
  );

  void _setAudio(String a) {
    if (!_ready || (a != 'sub' && a != 'dub') || a == _audio) return;
    setState(() {
      _audio = a;
      _startSeconds =
          _playbackPosition?.round() ??
          (_playerEpisode == _selectedEpisode ? _startSeconds : null);
      _playbackPosition = null;
      _playerEpisode = _selectedEpisode;
    });
    _memoryService.save(_memoryKey, audio: a);
    _failedServerIndices.clear();
    _showErrorCard = false;
    _probeCurrentServer();
  }

  Future<void> _load() async {
    if (_item.source == 'tmdb') {
      final data = await _tmdbService.fetchMediaDetails(
        _item.tmdbId,
        _item.mediaType,
      );
      if (!mounted) return;
      final mapped = mapTmdbAnimeDetails(_item, data ?? const {});
      _mappedTmdbId = _item.tmdbId;
      _episodeSlots = mapped.slots;
      _isFilm = _item.isMovie;
      setState(() {
        _detail = mapped.detail;
        _episodes = _buildEpisodeList(mapped.detail);
        _servers = _buildServers();
        _serverIndex = AnimeXWatchPage.defaultServerIndex(
          _servers,
          rememberedServer: _rememberedServer,
        );
      });
      return;
    }
    final malId = _malId;
    final anilistId = _anilistId;
    if (malId <= 0 && anilistId == null) return;
    final detail = await _aniList.fetchDetailsWithFallback(
      anilistId: anilistId,
      malId: malId,
    );
    int? mappedAnilistId;
    int? mappedTmdbId;
    final mappingsMalId = AnimeXWatchPage.resolveMappingsMalId(
      detailMalId: detail?.malId,
      routeMalId: _malId,
    );
    Map<int, ({int season, int episode})> episodeSlots = const {};
    Map<int, Map<String, dynamic>> aniZipEpisodes = const {};
    try {
      var mappings = mappingsMalId > 0
          ? await _aniZip.fetchMappings(mappingsMalId)
          : null;
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
      _servers = nextServers;
      _serverIndex = AnimeXWatchPage.defaultServerIndex(
        nextServers,
        rememberedServer: _rememberedServer,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _progressThrottler?.cancel();
      if (_ready) _saveWatchProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressThrottler?.cancel();
    if (_offlineBlobUrl != null) {
      unawaited(OfflineMediaStorage.instance.revokeBlobUrl(_offlineBlobUrl!));
    }
    if (_ready) _saveWatchProgress();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<AniListEpisode> _buildEpisodeList(
    AniListDetail? detail, {
    Map<int, Map<String, dynamic>> aniZipEpisodes = const {},
  }) {
    return AnimeXWatchPage.buildEpisodeList(
      detail: detail,
      fallbackEpisodeCount: _item.episodeCount,
      aniZipEpisodes: aniZipEpisodes,
    );
  }

  bool _filmFor(AniListDetail? detail) {
    if (_item.isMovie) return true;
    if (detail == null) return false;
    if (detail.format == 'MOVIE') return true;
    final episodes = detail.episodeCount ?? _item.episodeCount ?? 0;
    final minutes = detail.duration ?? 0;
    return episodes == 1 && minutes >= 60;
  }

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
    _episodeChosen = true;
    if (_selectedEpisode == episode) return;
    setState(() {
      _selectedEpisode = episode;
      _playerEpisode = episode;
    });
    _resetForNewEpisode();
    _recordHistory(episode);
    if (_ready) _saveWatchProgress(episode: episode, positionSeconds: 0);
    _fetchSkipTimes();
  }

  void _onPlayerEpisodeChanged(int tmdbSeason, int tmdbEpisode) {
    if (!mounted || _episodes.isEmpty) return;
    final current = (_serverIndex >= 0 && _serverIndex < _servers.length)
        ? _servers[_serverIndex]
        : null;
    if (current == null || current.name != 'CineSrc') return;
    final mapped = AnimeXWatchPage.mapPlayerEpisodeToMal(
      tmdbSeason: tmdbSeason,
      tmdbEpisode: tmdbEpisode,
      episodeSlots: _episodeSlots,
      episodeCount: _episodes.length,
    );
    if (mapped == null || mapped == _selectedEpisode) return;
    setState(() => _selectedEpisode = mapped);
    final loadedStart = _startSeconds;
    _resetForNewEpisode();
    _startSeconds = loadedStart;
    _recordHistory(mapped);
    _saveWatchProgress(episode: mapped, positionSeconds: 0);
    _fetchSkipTimes();
  }

  void _stepEpisode(int delta) {
    final next = (_selectedEpisode + delta).clamp(1, _episodes.length);
    if (next != _selectedEpisode) _selectEpisode(next);
  }

  void _recordHistory(int episode) {
    if (_item.source == 'tmdb') return;
    final stores = context.read<AnimexStores>();
    stores.recordWatch(
      key: _historyKey,
      anilistId: _anilistId,
      malId: _malId,
      title: _item.title,
      coverUrl: _item.posterUrl,
      episode: episode,
      totalEpisodes: _detail?.episodeCount ?? _item.episodeCount ?? 0,
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

  String _watchedStatusFor(String userName) {
    switch (userName) {
      case 'khentsgdz':
        return 'watched-khent';
      case 'clairjassen':
        return 'watched-clair';
      default:
        return 'watched-self';
    }
  }

  String _currentUserName() => _auth?.currentUser == _owner ? _owner : '';

  void _saveWatchProgress({int? episode, double? positionSeconds}) {
    final userName = _currentUserName();
    if (userName.isEmpty || (!_hasUnsavedProgress && episode == null)) return;
    _hasUnsavedProgress = false;

    final ep = episode ?? _selectedEpisode;
    final pos = positionSeconds ?? _lastKnownPosition;
    final duration = _playbackDuration?.round();

    final effectiveTmdbId = (_accountProgress?.tmdbId ?? 0) > 0
        ? _accountProgress!.tmdbId
        : _item.tmdbId > 0
        ? _item.tmdbId
        : (_anilistId ?? 0);
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
      status: _watchingStatusFor(userName),
      isAnime: true,
      userName: userName,
      addedAt: DateTime.now(),
      source: _item.source.isNotEmpty ? _item.source : 'jikan',
      anilistId: _anilistId ?? _accountProgress?.anilistId,
      synopsis: _item.synopsis,
      episodeCount: _item.episodeCount ?? _detail?.episodeCount,
      airingStatus: _item.airingStatus,
      format: _item.format,
      studio: _item.studio,
      genres: _item.genres,
    );

    final isMovie = mediaItem.isMovie;
    final hitsFinale = MediaItem.isCompletedProgress(
      episode: isMovie ? null : ep,
      totalEpisodes: mediaItem.episodeCount,
      isMovie: isMovie,
    );
    final status = hitsFinale
        ? _watchedStatusFor(userName)
        : _watchingStatusFor(userName);
    final progressSeason = AnimeXWatchPage.resolveProgressSeason(
      isMovie: isMovie,
      title: mediaItem.title,
      episode: ep,
      episodeSlots: _episodeSlots,
    );
    _progressSave = _progressSave.then(
      (_) => _tmdbService.updateProgress(
        mediaItem,
        userName,
        season: progressSeason,
        episode: isMovie ? null : ep,
        timestamp: pos?.round(),
        durationSeconds: duration,
        status: status,
      ),
    );
  }

  void _scheduleProgressSave() {
    if (_progressThrottler?.isActive ?? false) return;
    _progressThrottler = Timer(const Duration(seconds: 15), () {
      if (mounted && _ready) _saveWatchProgress();
    });
  }

  AnimeServerOption? get _currentServer {
    if (_serverIndex < 0 || _serverIndex >= _servers.length) return null;
    return _servers[_serverIndex];
  }

  String get _playerUrl {
    if (_offlineBlobUrl != null && _offlineBlobUrl!.isNotEmpty) {
      return _offlineBlobUrl!;
    }

    if (!_ready || _servers.isEmpty) return '';
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
    return current.urlFor(_playerEpisode, _audio, startSeconds: _startSeconds);
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
    final nextStart =
        _playbackPosition?.round() ??
        (_currentServer?.supportsResume == true &&
                _playerEpisode == _selectedEpisode
            ? _startSeconds
            : null);
    setState(() {
      _serverIndex = next.first;
      _startSeconds = nextStart;
      _playbackPosition = null;
      _playerEpisode = _selectedEpisode;
      _showErrorCard = false;
    });
    _persistServer(next.first);
    _probeCurrentServer();
  }

  void _selectServer(int index) {
    if (!_ready) return;
    final nextStart =
        _playbackPosition?.round() ??
        (_currentServer?.supportsResume == true &&
                _playerEpisode == _selectedEpisode
            ? _startSeconds
            : null);
    setState(() {
      _serverIndex = index;
      _startSeconds = nextStart;
      _playbackPosition = null;
      _playerEpisode = _selectedEpisode;
      _failedServerIndices.clear();
      _showErrorCard = false;
    });
    _persistServer(index);
    _probeCurrentServer(autoAdvance: false);
  }

  void _persistServer(int index) {
    if (index < 0 || index >= _servers.length) return;
    _memoryService.save(_memoryKey, server: _servers[index].name);
  }

  static const String _probeProxyUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml';

  Future<String?> _fetchProbeBody(Uri url) async {
    try {
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) return 'no playable stream sources';
      return utf8.decode(response.bodyBytes);
    } catch (_) {
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

  Future<void> _probeCurrentServer({bool autoAdvance = true}) async {
    final url = _playerUrl;
    if (url.isEmpty || _probingServer) return;
    setState(() => _probingServer = true);
    try {
      final body = await _fetchProbeBody(Uri.parse(url));
      if (mounted &&
          url == _playerUrl &&
          body != null &&
          AnimeXWatchPage.isProviderErrorPage(body)) {
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
    _startSeconds = null;
    _playbackPosition = null;
    _lastKnownPosition = null;
    _playbackDuration = null;
    _progressThrottler?.cancel();
    unawaited(_checkOfflinePlayback());
  }

  bool get _canWatchTogether {
    try {
      return context.read<AuthService>().isCoupleUser;
    } on ProviderNotFoundException {
      return false;
    }
  }

  String get _displayTitle {
    final japanese = context.select<AnimexStores, bool>(
      (stores) => stores.titleJapanese,
    );
    return _titleFor(japanese);
  }

  Future<void> _startAnimeWatchParty() async {
    final malId = _malId;
    if (malId <= 0) return;
    final media = MediaRef(
      tmdbId: malId,
      malId: malId,
      mediaType: _isFilm ? 'movie' : 'tv',
      isAnime: true,
      season: 1,
      episode: _isFilm ? 1 : _selectedEpisode,
      episodeCount: _episodes.isEmpty ? null : _episodes.length,
      title: _displayTitle,
      posterPath: _item.posterPath,
    );
    await startWatchParty(context, media);
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
        if (_detail != null && _seasons.length > 1) ...[
          const SizedBox(height: 32),
          _buildSeasons(context),
        ],
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
                    'Episode $_selectedEpisode${_activeEpisodeTitle != 'Episode $_selectedEpisode' ? ' \u2022 $_activeEpisodeTitle' : ''}',
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
            if (_canWatchTogether && _malId > 0) ...[
              GestureDetector(
                onTap: _startAnimeWatchParty,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepRose.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(
                        AnimeXTokens.radiusSm,
                      ),
                      border: Border.all(
                        color: AppColors.deepRose.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 14,
                          color: AppColors.roseQuartz,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Watch Together',
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
            ],
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

  Widget _buildCurrentEpisodeHeader(BuildContext context) {
    final ep = _activeEpisode;
    final epTitle = _activeEpisodeTitle;
    final airedAt = ep?.airedAt;

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
          ],
        ),
      ],
    );
  }

  Widget _buildServerAndAudioRow(BuildContext context) {
    final failedNote = _failedServersNote();
    final row = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < _servers.length; i++)
          if (_servers[i].available)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _servers[i].name,
                        style: dmSansStyle(
                          size: 12,
                          color: _failedServerIndices.contains(i)
                              ? AnimeXTokens.textSecondary.withValues(
                                  alpha: 0.5,
                                )
                              : _serverIndex == i
                              ? AnimeXTokens.accentWarm
                              : AnimeXTokens.textSecondary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (_servers[i].tag.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _servers[i].tag,
                            style: dmSansStyle(
                              size: 9,
                              color: AnimeXTokens.textSecondary,
                              weight: FontWeight.w600,
                              letterSpacing: 0.03,
                            ),
                          ),
                        ),
                      ],
                      if (_failedServerIndices.contains(i)) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: "Didn't load for this episode",
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: AnimeXTokens.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(width: 6),
        if (_currentServer?.supportsAudioSelection != true)
          Text(
            'Choose audio inside the player',
            style: dmSansStyle(size: 12, color: AnimeXTokens.textSecondary),
          )
        else
          _AudioToggle(audio: _audio, onChanged: _setAudio),
      ],
    );
    if (failedNote.isEmpty) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        const SizedBox(height: 10),
        Text(
          failedNote,
          style: dmSansStyle(size: 12, color: AnimeXTokens.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPlaybackPrefsRow(BuildContext context) {
    final stores = context.watch<AnimexStores?>();
    if (stores == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PrefToggle(
          label: 'Auto next',
          value: stores.autoNext,
          onChanged: stores.setAutoNext,
        ),
        _PrefToggle(
          label: 'Skip intro',
          value: stores.skipIntro,
          onChanged: stores.setSkipIntro,
        ),
      ],
    );
  }

  String _failedServersNote() {
    if (_showErrorCard || _failedServerIndices.isEmpty) return '';
    final failed = [
      for (final i in _failedServerIndices)
        if (i >= 0 && i < _servers.length) _servers[i].name,
    ];
    if (failed.isEmpty) return '';
    final names = failed.join(', ');
    final current = _currentServer?.name;
    return current == null
        ? "$names didn't load for this episode."
        : "$names didn't load for this episode, so we switched to $current.";
  }

  Widget _buildStepButtons(BuildContext context) {
    final isLastEpisode = _selectedEpisode >= _episodes.length;
    final nextSeason = _nextSeason;
    final hasNextSeason = isLastEpisode && nextSeason != null;

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
          label: hasNextSeason ? 'Next Season' : 'Next Episode',
          icon: hasNextSeason ? Icons.skip_next_rounded : null,
          enabled: !isLastEpisode || hasNextSeason,
          onTap: hasNextSeason
              ? () => _openSeason(nextSeason)
              : () => _stepEpisode(1),
        ),
      ],
    );
  }
}
