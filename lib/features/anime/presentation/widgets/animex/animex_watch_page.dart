import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
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
import 'animex_poster_row.dart';
import 'animex_section_header.dart';
import 'animex_tokens.dart';
part 'animex_watch_page_widgets.dart';
part 'animex_watch_page_sheets.dart';
part 'animex_watch_page_episodes.dart';

class AnimeServerOption {
  final String name;
  final String Function(int episode, String audio) urlBuilder;
  final bool available;

  const AnimeServerOption({
    required this.name,
    required this.urlBuilder,
    this.available = true,
  });
}

typedef _ServerOption = AnimeServerOption;

/// Anime detail / watch page: hero with info, video player with server
/// tabs + sub/dub toggle, episode grid, share, playlists and
/// recommendations.
class AnimeXWatchPage extends StatefulWidget {
  final AnimeXController controller;

  const AnimeXWatchPage({super.key, required this.controller});

  /// Normalizes legacy server names ('Server 1', etc.) to provider names.
  /// True when a fetched embed page is the provider's "can't play this"
  /// error instead of a player. Static so the regression tests can pin
  /// every known marker.
  static bool isProviderErrorPage(String body) {
    final lower = body.toLowerCase();
    return lower.contains("we're sorry") ||
        lower.contains('error code: <span>410</span>') ||
        lower.contains('error - megaplay') ||
        lower.contains('all stream servers failed') ||
        lower.contains('no playable stream sources') ||
        // MegaPlay / AniXo refuse sandboxed iframes outright — our
        // player frame stays sandboxed (no popups for Clair), so
        // their block cards must fail over to the next server.
        lower.contains('sandbox is not allowed') ||
        lower.contains('sandboxed our player is not allowed') ||
        lower.contains('remove sandbox') ||
        // VidLink 404s dead embeds with a Next.js "not found" shell (its
        // anime player died sitewide in Sep 2026) and prints its own
        // "Couldn't Find This Episode" card once the bundle runs.
        lower.contains('this page could not be found') ||
        lower.contains("coudn't find this episode") ||
        lower.contains("couldn't find this episode") ||
        (lower.contains('410') && lower.contains('copyright violation'));
  }

  static String normalizeServerName(String? name) {
    if (name == null) return '';
    switch (name) {
      case 'Server 1':
        return 'Everglow';
      // Legacy: the VidLink anime server was removed (dead upstream
      // since Sep 2026). Old saved choices still normalize here and
      // fall back to the first available server in [_load].
      case 'Server 2':
        return 'VidLink';
      case 'Server 3':
        return 'Megavid';
      // Prior branch names ('Mega Play', 'Anixo') map to the current
      // spellings so remembered choices survive the rename.
      case 'Mega Play':
        return 'MegaPlay';
      case 'Anixo':
        return 'AniXo';
      default:
        return name;
    }
  }

  /// Picks the MAL id used for ani.zip mappings lookups. The route often
  /// carries only an AniList id (the id slot reads 0), so prefer the MAL
  /// id from the freshly fetched AniList detail and fall back to the
  /// route's id slot.
  @visibleForTesting
  static int resolveMappingsMalId({
    int? detailMalId,
    required int routeMalId,
  }) {
    if (detailMalId != null && detailMalId > 0) return detailMalId;
    return routeMalId;
  }

  /// Builds the anime embed servers, cleanest first. Every server plays
  /// caged inside the sandboxed player frame:
  ///
  /// - Everglow: our own embed.html shell around CineSrc. Default for
  ///   fresh titles. TMDB-keyed, so it only becomes available once
  ///   ani.zip supplies a `themoviedb_id`. 100% ad-free.
  /// - MegaPlay: third-party embed keyed on the AniList id (falls back
  ///   to MAL). Sits before AniXo so titles without a TMDB mapping open
  ///   on it, matching the MegaPlay / AniXo / Megavid order.
  /// - AniXo: third-party embed keyed on the AniList id (falls back to
  ///   MAL). Both third-party embeds stay sandboxed (no popups); when
  ///   either answers with its sandbox-block or 410 card the probe
  ///   advances to the next server.
  /// - Megavid: direct HLS streams from Megavid's `/source` API served
  ///   through `proxyAnime`. Bypasses the third-party website embed
  ///   and all its popunders completely — 100% AD-FREE.
  ///
  /// VidLink used to sit between these two, but its anime embeds 404
  /// sitewide since Sep 2026 ("Couldn't Find This Episode" on every
  /// title), so it is no longer offered. A remembered VidLink choice
  /// simply falls back to the first available server below.
  ///
  /// Picks the TMDB id for titles ani.zip can't map, via a strict
  /// catalog search: the kind must match (`movie` for films, `tv`
  /// otherwise), the normalized title must equal, and the year must
  /// equal when both sides know it. Anything looser risks opening the
  /// wrong film for Clair, so near-misses return null (server stays
  /// hidden) instead of guessing.
  @visibleForTesting
  static int? pickTmdbFallbackId({
    required List<MediaItem> results,
    required String title,
    required String year,
    required bool isMovie,
  }) {
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final want = norm(title);
    if (want.isEmpty) return null;
    final wantKind = isMovie ? 'movie' : 'tv';
    final wantYear = year.trim();
    for (final r in results) {
      if (r.tmdbId <= 0) continue;
      if (r.mediaType.trim().toLowerCase() != wantKind) continue;
      if (norm(r.title) != want) continue;
      final gotYear = r.year.trim();
      if (wantYear.isNotEmpty &&
          gotYear.isNotEmpty &&
          gotYear != wantYear) {
        continue;
      }
      return r.tmdbId;
    }
    return null;
  }

  /// [episodeSlots] maps a MAL episode number to the season/episode
  /// pair TMDB expects — shows whose MAL entry starts mid-series (e.g.
  /// Attack on Titan season 2) would otherwise open the wrong episode.
  /// [isMovie] switches the TMDB-keyed server to the movie endpoint:
  /// films (e.g. Drifting Home) have a movie TMDB id, and the TV
  /// endpoint with that id opens nothing.
  /// [idToken] is Clair's Firebase login token for the `proxyAnime`
  /// servers (player iframes cannot send headers, so it travels as
  /// `?token=`).
  static List<AnimeServerOption> buildServers({
    int? anilistId,
    int? malId,
    int? tmdbId,
    Map<int, ({int season, int episode})> episodeSlots = const {},
    String idToken = '',
    String title = '',
    bool isMovie = false,
  }) {
    final hasAni = anilistId != null && anilistId > 0;
    final effectiveMal = malId ?? 0;
    final effectiveTmdb = tmdbId ?? 0;
    final aniId = hasAni ? anilistId : 0;

    final hasSource = hasAni || effectiveMal > 0;

    String proxyAnimeUrl(String source, int ep, String audio) {
      final params = <String>[
        'source=$source',
        'anilistId=$aniId',
        'malId=$effectiveMal',
        'ep=$ep',
        'audio=$audio',
        if (title.isNotEmpty) 'title=${Uri.encodeComponent(title)}',
        if (idToken.isNotEmpty) 'token=${Uri.encodeComponent(idToken)}',
      ];
      return 'https://us-central1-everglow-1c6db.cloudfunctions.net/'
          'proxyAnime?${params.join('&')}';
    }

    return [
      AnimeServerOption(
        name: 'Everglow',
        urlBuilder: (ep, audio) {
          if (isMovie) {
            return 'https://everglow-1c6db.web.app/embed.html'
                '?tmdbId=$effectiveTmdb&type=movie';
          }
          final slot = episodeSlots[ep];
          final season = slot?.season ?? 1;
          final episode = slot?.episode ?? ep;
          return 'https://everglow-1c6db.web.app/embed.html'
              '?tmdbId=$effectiveTmdb&type=tv&s=$season&e=$episode';
        },
        available: effectiveTmdb > 0,
      ),
      AnimeServerOption(
        name: 'MegaPlay',
        urlBuilder: (ep, audio) {
          if (hasAni) {
            return 'https://megaplay.buzz/stream/ani/$aniId/$ep/$audio';
          }
          return 'https://megaplay.buzz/stream/mal/$effectiveMal/$ep/$audio';
        },
        available: hasSource,
      ),
      AnimeServerOption(
        name: 'AniXo',
        urlBuilder: (ep, audio) {
          if (hasAni) {
            return 'https://anixo.buzz/embed/ani/$aniId/$ep?track=$audio';
          }
          return 'https://anixo.buzz/embed/mal/$effectiveMal/$ep?track=$audio';
        },
        available: hasSource,
      ),
      AnimeServerOption(
        name: 'Megavid',
        urlBuilder: (ep, audio) => proxyAnimeUrl('megavid', ep, audio),
        available: hasSource,
      ),
    ];
  }

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

  /// Firebase login token for the `proxyAnime` (Megavid) server —
  /// player iframes cannot send headers, so it travels as `?token=`.
  /// Empty until sign-in resolves; the server stays listed and simply
  /// fails over until then.
  String _idToken = '';

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
    _isFilm = _item.isMovie;
    _servers = _buildServers();
    _serverIndex = _firstAvailableServer(_servers);
    _episodes = _buildEpisodeList(null);
    _refreshIdToken();
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
    } catch (_) {}
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
    final firstAvailable = nextServers.indexWhere((s) => s.available);
    setState(() {
      _detail = detail;
      _episodes = _buildEpisodeList(detail, aniZipEpisodes: aniZipEpisodes);
      if (_episodes.isNotEmpty) {
        _selectedEpisode = _selectedEpisode.clamp(1, _episodes.length).toInt();
      }
      _servers = nextServers;
      final normalizedRemembered =
          AnimeXWatchPage.normalizeServerName(_rememberedServer);
      final rememberedIndex = normalizedRemembered.isEmpty
          ? -1
          : nextServers.indexWhere(
              (s) => s.available && s.name == normalizedRemembered,
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
      final title = (baseTitle != null &&
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
      final duration = base?.duration ??
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
      idToken: _idToken,
      title: _item.title,
      isMovie: _isFilm,
    );
  }

  /// Fetches the login token once so the `proxyAnime` server can
  /// authenticate. Rebuilds the server list in place so the current
  /// selection survives — only the Megavid URL changes.
  Future<void> _refreshIdToken() async {
    try {
      final token =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      if (!mounted || token.isEmpty || token == _idToken) return;
      final currentName = _servers.isNotEmpty &&
              _serverIndex >= 0 &&
              _serverIndex < _servers.length
          ? _servers[_serverIndex].name
          : null;
      setState(() {
        _idToken = token;
        _servers = _buildServers();
        if (currentName != null) {
          final again = _servers.indexWhere(
            (s) => s.available && s.name == currentName,
          );
          if (again != -1) _serverIndex = again;
        }
      });
    } catch (_) {}
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

    // Movies have no episode progress — write null so Firestore never
    // gains stale S1E1 fields that shelves would then display.
    final isMovie = mediaItem.isMovie;
    _tmdbService.updateProgress(
      mediaItem,
      userName,
      season: isMovie ? null : 1,
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
      final effectiveTmdbId =
          _item.tmdbId > 0 ? _item.tmdbId : (_anilistId ?? 0);
      if (effectiveTmdbId <= 0) return;
      _tmdbService.heartbeatProgress(
        effectiveTmdbId,
        userName,
        season: _item.isMovie ? null : 1,
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
      final effectiveTmdbId =
          _item.tmdbId > 0 ? _item.tmdbId : (_anilistId ?? 0);
      if (effectiveTmdbId <= 0) return;
      _tmdbService.heartbeatProgress(
        effectiveTmdbId,
        userName,
        season: _item.isMovie ? null : 1,
        episode: _item.isMovie ? null : _selectedEpisode,
        timestamp: _playbackPosition?.round(),
        durationSeconds:
            (_detail?.duration != null && _detail!.duration! > 0)
                ? _detail!.duration! * 60
                : null,
      );
    });
  }

  /// Index of the first available server, or 0 when none is available
  /// yet (the player then shows an empty URL until [_load] resolves).
  static int _firstAvailableServer(List<AnimeServerOption> servers) {
    final index = servers.indexWhere((s) => s.available);
    return index == -1 ? 0 : index;
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
    final url = current.urlBuilder(_selectedEpisode, _audio);
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
  Future<String?> _fetchProbeBody(Uri url) async {
    try {
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10));
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
        return utf8.decode(response.bodyBytes);
      } catch (_) {}
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
      if (body != null && AnimeXWatchPage.isProviderErrorPage(body) && mounted) {
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
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
    final contentWidth = (width - 48).clamp(0.0, AnimeXTokens.watchPageMaxWidth);
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
