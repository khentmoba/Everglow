import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/artist_suggestion.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../../data/services/music_sync_service.dart';

class ShowdownTrack {
  final String trackName;
  final int khentPlays;
  final int clairPlays;
  final String? imageUrl;
  final String spotifyUrl;
  final String? mbid;

  const ShowdownTrack({
    required this.trackName,
    required this.khentPlays,
    required this.clairPlays,
    this.imageUrl,
    required this.spotifyUrl,
    this.mbid,
  });

  int get combinedPlays => khentPlays + clairPlays;

  String? get leader {
    if (khentPlays > clairPlays) return 'khent';
    if (clairPlays > khentPlays) return 'clair';
    return null;
  }
}

class ArtistShowdownProvider extends ChangeNotifier {
  ArtistShowdownProvider({
    MusicSyncService? syncService,
    String initialArtist = ArtistShowdownProvider.defaultArtist,
    Duration chartTimeout = const Duration(seconds: 12),
    Duration catalogTimeout = const Duration(seconds: 10),
    Duration discoveryTimeout = const Duration(seconds: 25),
    Duration retryDelay = const Duration(milliseconds: 1200),
  }) : _sync = syncService ?? MusicSyncService(),
       _chartTimeout = chartTimeout,
       _catalogTimeout = catalogTimeout,
       _discoveryTimeout = discoveryTimeout,
       _retryDelay = retryDelay {
    _khentUser = EnvConfig.lastfmUserKhent;
    _clairUser = EnvConfig.lastfmUserClair;
    selectArtist(initialArtist);
  }

  static const String defaultArtist = 'Ethel Cain';

  static const int _topTracksPageSize = 200;

  static const int _topTracksMaxPages = 5;

  static const int _historyMaxTracks = 50;

  final MusicSyncService _sync;
  final Duration _chartTimeout;
  final Duration _catalogTimeout;
  final Duration _discoveryTimeout;
  final Duration _retryDelay;
  late final String _khentUser;
  late final String _clairUser;

  String _artist = '';
  bool _isLoading = true;
  bool _disposed = false;
  int _requestId = 0;
  Timer? _retryTimer;
  Completer<void>? _retryCompleter;

  int _khentTotal = 0;
  int _clairTotal = 0;
  List<ShowdownTrack> _tracks = const [];

  final Map<String, _CachedShowdown> _cache = {};

  List<ArtistSuggestion> _suggestions = const [];
  bool _isSearching = false;
  int _searchRequestId = 0;
  final Map<String, List<ArtistSuggestion>> _suggestionCache = {};
  final Map<String, String?> _artistImageCache = {};

  bool _isLoadingHistory = false;
  List<MusicStatus> _khentHistory = const [];
  List<MusicStatus> _clairHistory = const [];
  int _historyRequestId = 0;
  final Map<String, _CachedArtistHistory> _historyCache = {};

  String get artist => _artist;
  bool get isLoading => _isLoading;
  int get khentTotal => _khentTotal;
  int get clairTotal => _clairTotal;
  List<ShowdownTrack> get tracks => _tracks;
  bool get hasData => _khentTotal > 0 || _clairTotal > 0;
  List<ArtistSuggestion> get suggestions => _suggestions;
  bool get isSearching => _isSearching;

  bool get isLoadingHistory => _isLoadingHistory;
  List<MusicStatus> get khentHistory => _khentHistory;
  List<MusicStatus> get clairHistory => _clairHistory;
  bool get hasHistory => _khentHistory.isNotEmpty || _clairHistory.isNotEmpty;

  String? get leader {
    if (!hasData) return null;
    if (_khentTotal > _clairTotal) return 'khent';
    if (_clairTotal > _khentTotal) return 'clair';
    return null;
  }

  double get khentShare {
    final total = _khentTotal + _clairTotal;
    if (total <= 0) return 0.5;
    return _khentTotal / total;
  }

  Future<void> searchArtists(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (_suggestions.isNotEmpty || _isSearching) {
        _suggestions = const [];
        _isSearching = false;
        _safeNotify();
      }
      return;
    }
    final key = trimmed.toLowerCase();
    final cached = _suggestionCache[key];
    if (cached != null) {
      _suggestions = cached;
      _isSearching = false;
      _safeNotify();
      if (cached.any((s) => s.imageUrl == null)) {
        unawaited(_enrichSuggestionArtwork(_searchRequestId, key));
      }
      return;
    }
    final request = ++_searchRequestId;
    _isSearching = true;
    _safeNotify();
    final results = await _sync.fetchArtistSuggestions(trimmed);
    if (_disposed || request != _searchRequestId) return;
    _suggestionCache[key] = results;
    _suggestions = results;
    _isSearching = false;
    _safeNotify();
    unawaited(_enrichSuggestionArtwork(request, key));
  }

  Future<void> _enrichSuggestionArtwork(int request, String queryKey) async {
    for (var i = 0; i < _suggestions.length; i++) {
      if (_disposed || request != _searchRequestId) return;
      final current = _suggestions[i];
      if (current.imageUrl != null) continue;
      final artistKey = current.name.trim().toLowerCase();
      String? art;
      if (_artistImageCache.containsKey(artistKey)) {
        art = _artistImageCache[artistKey];
      } else {
        art = await _sync.fetchArtistImage(current.name);
        if (_disposed || request != _searchRequestId) return;
        _artistImageCache[artistKey] = art;
      }
      if (art == null || art.isEmpty) continue;
      final next = List<ArtistSuggestion>.from(_suggestions);
      next[i] = current.copyWith(imageUrl: art);
      _suggestions = next;
      _suggestionCache[queryKey] = next;
      _safeNotify();
    }
  }

  void clearSuggestions() {
    _searchRequestId++;
    if (_suggestions.isEmpty && !_isSearching) return;
    _suggestions = const [];
    _isSearching = false;
    _safeNotify();
  }

  Future<void> selectArtist(String name, {bool force = false}) async {
    final artist = name.trim();
    clearSuggestions();
    if (artist.isEmpty) return;
    final isSameArtist = artist.toLowerCase() == _artist.toLowerCase();
    if (!force && isSameArtist) return;
    final request = ++_requestId;
    _cancelRetryTimer();
    final key = artist.toLowerCase();

    if (force) {
      _cache.remove(key);
      _historyCache.remove(key);
    }

    final cachedHist = _historyCache[key];
    if (cachedHist != null) {
      _khentHistory = cachedHist.khentHistory;
      _clairHistory = cachedHist.clairHistory;
      _isLoadingHistory = false;
    } else {
      _khentHistory = const [];
      _clairHistory = const [];
      _isLoadingHistory = false;
    }

    final cached = _cache[key];
    if (cached != null) {
      _artist = artist;
      _khentTotal = cached.khentTotal;
      _clairTotal = cached.clairTotal;
      _tracks = cached.tracks;
      _isLoading = false;
      _safeNotify();
      return;
    }
    _artist = artist;
    _isLoading = true;
    if (!isSameArtist) {
      _khentTotal = 0;
      _clairTotal = 0;
      _tracks = const [];
    }
    _safeNotify();
    (int, int, List<ShowdownTrack>)? localRows;
    var finalTimedOut = false;
    var finalHadFailure = false;
    var finalRows = (0, 0, const <ShowdownTrack>[]);

    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        var timedOut = false;
        final result = await _fetchArtistShowdownRows(
          artist,
          onChartRows: (rows) {
            if (_disposed || request != _requestId || rows.$3.isEmpty) return;
            localRows = rows;
            _khentTotal = rows.$1;
            _clairTotal = rows.$2;
            _tracks = rows.$3;
            _safeNotify();
          },
        ).timeout(
          _discoveryTimeout,
          onTimeout: () {
            timedOut = true;
            Logger.w('ArtistShowdown: discovery timed out for "$artist"');
            final fallback =
                localRows ??
                (isSameArtist
                    ? (_khentTotal, _clairTotal, _tracks)
                    : (0, 0, const <ShowdownTrack>[]));
            return (fallback.$1, fallback.$2, fallback.$3, true);
          },
        );
        if (_disposed || request != _requestId) return;

        finalTimedOut = timedOut;
        finalHadFailure = result.$4;
        finalRows = (result.$1, result.$2, result.$3);
        final isEmpty =
            finalRows.$1 == 0 && finalRows.$2 == 0 && finalRows.$3.isEmpty;

        if (isEmpty && (finalTimedOut || finalHadFailure) && attempt == 0) {
          Logger.w(
            'ArtistShowdown: retrying "$artist" after empty transient failure',
          );
          final completer = Completer<void>();
          _retryCompleter = completer;
          _retryTimer = Timer(_retryDelay, () {
            if (!completer.isCompleted) completer.complete();
          });
          await completer.future;
          if (_disposed || request != _requestId) return;
          continue;
        }
        break;
      }

      _khentTotal = finalRows.$1;
      _clairTotal = finalRows.$2;
      _tracks = finalRows.$3;
      final isEmpty = _khentTotal == 0 && _clairTotal == 0 && _tracks.isEmpty;
      if (!finalTimedOut && !(isEmpty && finalHadFailure)) {
        _cache[key] = _CachedShowdown(
          khentTotal: _khentTotal,
          clairTotal: _clairTotal,
          tracks: _tracks,
        );
      }
    } catch (e, st) {
      Logger.e('ArtistShowdown: failed to load "$artist"', error: e, stackTrace: st);
    } finally {
      if (!_disposed && request == _requestId) {
        _isLoading = false;
        _safeNotify();
      }
    }
    unawaited(_enrichArtwork(request, key, artist));
  }

  Future<void> refresh() async {
    final target = _artist.trim().isNotEmpty
        ? _artist.trim()
        : defaultArtist;
    await selectArtist(target, force: true);
  }

  Future<void> _enrichArtwork(
    int request,
    String cacheKey,
    String artist,
  ) async {
    final indices = <int>[];
    for (var i = 0; i < _tracks.length; i++) {
      if (_tracks[i].imageUrl == null || _tracks[i].imageUrl!.isEmpty) {
        indices.add(i);
      }
    }
    if (indices.isEmpty) return;

    const concurrency = 4;
    for (var c = 0; c < indices.length; c += concurrency) {
      if (_disposed || request != _requestId) return;
      final chunk = indices.skip(c).take(concurrency).toList();
      final results = await Future.wait(
        chunk.map((idx) async {
          final t = _tracks[idx];
          final art = await _sync.fetchTrackArtwork(
            artist: artist,
            track: t.trackName,
            mbid: t.mbid,
          );
          return (idx: idx, art: art);
        }),
      );
      if (_disposed || request != _requestId) return;
      var changed = false;
      final next = List<ShowdownTrack>.from(_tracks);
      for (final r in results) {
        if (r.art != null && r.art!.isNotEmpty) {
          final cur = next[r.idx];
          next[r.idx] = ShowdownTrack(
            trackName: cur.trackName,
            khentPlays: cur.khentPlays,
            clairPlays: cur.clairPlays,
            imageUrl: r.art,
            spotifyUrl: cur.spotifyUrl,
            mbid: cur.mbid,
          );
          changed = true;
        }
      }
      if (changed) {
        _tracks = next;
        final cached = _cache[cacheKey];
        if (cached != null) {
          _cache[cacheKey] = _CachedShowdown(
            khentTotal: cached.khentTotal,
            clairTotal: cached.clairTotal,
            tracks: next,
          );
        }
        _safeNotify();
      }
    }
  }

  Future<(int, int, List<ShowdownTrack>, bool)> _fetchArtistShowdownRows(
    String artist, {
    required void Function((int, int, List<ShowdownTrack>)) onChartRows,
  }) async {
    final wanted = artist.trim().toLowerCase();
    final failuresBefore = _sync.transientFailureCount;
    var hadTransientFailure = false;

    final chartFuture =
        Future.wait([
          _tracksForArtistLegacy(_khentUser, artist),
          _tracksForArtistLegacy(_clairUser, artist),
        ]).timeout(
          _chartTimeout,
          onTimeout: () {
            hadTransientFailure = true;
            Logger.w('ArtistShowdown: chart fetch timed out for "$artist"');
            return <List<TopMusicTrack>>[const [], const []];
          },
        ).then((charts) {
          if (charts[0].isNotEmpty || charts[1].isNotEmpty) {
            onChartRows(_merge(charts[0], charts[1]));
          }
          return charts;
        }).catchError((Object e, StackTrace st) {
          hadTransientFailure = true;
          Logger.w('ArtistShowdown: chart fetch failed for "$artist"', error: e);
          return <List<TopMusicTrack>>[const [], const []];
        });

    final catalogFuture = _sync
        .fetchArtistCatalogTracksAll(artist, pageSize: 50, maxPages: 2)
        .timeout(
          _catalogTimeout,
          onTimeout: () {
            hadTransientFailure = true;
            return const [];
          },
        )
        .catchError((Object e, StackTrace st) {
          hadTransientFailure = true;
          Logger.w('ArtistShowdown: catalog fetch failed for "$artist"', error: e);
          return const <TopMusicTrack>[];
        });
    final recentKhentFuture = _sync
        .fetchRecentTracks(_khentUser, limit: 50)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            hadTransientFailure = true;
            return const [];
          },
        )
        .catchError((Object e, StackTrace st) {
          hadTransientFailure = true;
          Logger.w('ArtistShowdown: recent tracks fetch failed for "$artist"', error: e);
          return const <MusicStatus>[];
        });
    final recentClairFuture = _sync
        .fetchRecentTracks(_clairUser, limit: 50)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            hadTransientFailure = true;
            return const [];
          },
        )
        .catchError((Object e, StackTrace st) {
          hadTransientFailure = true;
          Logger.w('ArtistShowdown: recent tracks fetch failed for "$artist"', error: e);
          return const <MusicStatus>[];
        });

    final charts = await chartFuture;

    final catalog = await catalogFuture;
    final candidateMap = <String, TopMusicTrack>{};
    for (final t in catalog) {
      candidateMap[t.trackName.trim().toLowerCase()] = t;
    }

    final recentKhent = await recentKhentFuture;
    final recentClair = await recentClairFuture;
    for (final s in [...recentKhent, ...recentClair]) {
      if (s.artistName.trim().toLowerCase() == wanted &&
          s.trackName.isNotEmpty) {
        final key = s.trackName.trim().toLowerCase();
        candidateMap.putIfAbsent(
          key,
          () => TopMusicTrack(
            rank: candidateMap.length + 1,
            trackName: s.trackName.trim(),
            artistName: artist,
            playCount: 0,
            imageUrl: s.imageUrl,
            spotifyUrl:
                'https://open.spotify.com/search/${Uri.encodeComponent('$artist ${s.trackName}')}',
          ),
        );
      }
    }

    final candidates = candidateMap.values.take(30).toList();

    if (candidates.isNotEmpty) {
      final khentTracksFuture = _sync
          .fetchUserArtistTracks(
            _khentUser,
            artist,
            candidateTracks: candidates,
            batchSize: 16,
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              hadTransientFailure = true;
              return const [];
            },
          )
          .catchError((Object e, StackTrace st) {
            hadTransientFailure = true;
            Logger.w(
              'ArtistShowdown: user artist tracks fetch failed for "$artist"',
              error: e,
            );
            return const <TopMusicTrack>[];
          });
      final clairTracksFuture = _sync
          .fetchUserArtistTracks(
            _clairUser,
            artist,
            candidateTracks: candidates,
            batchSize: 16,
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              hadTransientFailure = true;
              return const [];
            },
          )
          .catchError((Object e, StackTrace st) {
            hadTransientFailure = true;
            Logger.w(
              'ArtistShowdown: user artist tracks fetch failed for "$artist"',
              error: e,
            );
            return const <TopMusicTrack>[];
          });
      final results = await Future.wait([khentTracksFuture, clairTracksFuture]);
      final charts = await chartFuture;
      final khent = _unionUserTracks(results[0], charts[0]);
      final clair = _unionUserTracks(results[1], charts[1]);

      final failed =
          hadTransientFailure || _sync.transientFailureCount > failuresBefore;
      if (khent.isNotEmpty || clair.isNotEmpty) {
        final merged = _merge(khent, clair);
        return (merged.$1, merged.$2, merged.$3, failed);
      }
    }

    final failed =
        hadTransientFailure || _sync.transientFailureCount > failuresBefore;
    final merged = _merge(charts[0], charts[1]);
    return (merged.$1, merged.$2, merged.$3, failed);
  }

  Future<List<TopMusicTrack>> _tracksForArtistLegacy(
    String username,
    String artist,
  ) async {
    final wanted = artist.trim().toLowerCase();
    final top = await _sync.fetchTopTracksPaged(
      username,
      pageSize: _topTracksPageSize,
      maxPages: _topTracksMaxPages,
    );
    return top
        .where((t) => t.artistName.trim().toLowerCase() == wanted)
        .toList();
  }

  static List<TopMusicTrack> _unionUserTracks(
    List<TopMusicTrack> first,
    List<TopMusicTrack> second,
  ) {
    final byTrack = <String, TopMusicTrack>{};
    for (final t in [...first, ...second]) {
      final key = _key(t.trackName);
      final existing = byTrack[key];
      if (existing == null) {
        byTrack[key] = t;
      } else {
        final winner = t.playCount > existing.playCount ? t : existing;
        byTrack[key] = TopMusicTrack(
          rank: winner.rank,
          trackName: winner.trackName,
          artistName: winner.artistName,
          playCount: winner.playCount,
          imageUrl: winner.imageUrl ?? existing.imageUrl ?? t.imageUrl,
          spotifyUrl: winner.spotifyUrl,
          mbid: winner.mbid ?? existing.mbid ?? t.mbid,
        );
      }
    }
    return byTrack.values.toList();
  }

  static (int, int, List<ShowdownTrack>) _merge(
    List<TopMusicTrack> khent,
    List<TopMusicTrack> clair,
  ) {
    var khentTotal = 0;
    var clairTotal = 0;
    final byTrack = <String, _Draft>{};
    for (final t in khent) {
      khentTotal += t.playCount;
      final draft = byTrack.putIfAbsent(
        _key(t.trackName),
        () => _Draft(name: t.trackName, spotifyUrl: t.spotifyUrl),
      );
      draft.khent += t.playCount;
      draft.imageUrl ??= t.imageUrl;
      draft.mbid ??= t.mbid;
    }
    for (final t in clair) {
      clairTotal += t.playCount;
      final draft = byTrack.putIfAbsent(
        _key(t.trackName),
        () => _Draft(name: t.trackName, spotifyUrl: t.spotifyUrl),
      );
      draft.clair += t.playCount;
      draft.imageUrl ??= t.imageUrl;
      draft.mbid ??= t.mbid;
    }
    final tracks = byTrack.values
        .map(
          (d) => ShowdownTrack(
            trackName: d.name,
            khentPlays: d.khent,
            clairPlays: d.clair,
            imageUrl: d.imageUrl,
            spotifyUrl: d.spotifyUrl,
            mbid: d.mbid,
          ),
        )
        .toList();
    tracks.sort((a, b) => b.combinedPlays.compareTo(a.combinedPlays));
    return (khentTotal, clairTotal, tracks);
  }

  static String _key(String name) => name.trim().toLowerCase();

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadArtistHistory({bool forceRefresh = false}) async {
    final artist = _artist.trim();
    if (artist.isEmpty) return;
    final key = artist.toLowerCase();

    if (!forceRefresh && _historyCache.containsKey(key)) {
      final cached = _historyCache[key]!;
      _khentHistory = cached.khentHistory;
      _clairHistory = cached.clairHistory;
      _isLoadingHistory = false;
      _safeNotify();
      return;
    }

    final request = ++_historyRequestId;
    _isLoadingHistory = true;
    _safeNotify();

    final khentTracks = _tracks
        .where((t) => t.khentPlays > 0)
        .map((t) => t.trackName)
        .toList();
    final clairTracks = _tracks
        .where((t) => t.clairPlays > 0)
        .map((t) => t.trackName)
        .toList();

    try {
      final results = await Future.wait([
        _sync.fetchArtistHistory(
          _khentUser,
          artist: artist,
          knownTracks: khentTracks,
          maxTracks: _historyMaxTracks,
        ),
        _sync.fetchArtistHistory(
          _clairUser,
          artist: artist,
          knownTracks: clairTracks,
          maxTracks: _historyMaxTracks,
        ),
      ]);

      if (_disposed || request != _historyRequestId) return;

      final trackArtworks = <String, String>{};
      for (final t in _tracks) {
        if (t.imageUrl != null && t.imageUrl!.isNotEmpty) {
          trackArtworks[t.trackName.trim().toLowerCase()] = t.imageUrl!;
        }
      }

      List<MusicStatus> attachCovers(List<MusicStatus> list) {
        return list.map((s) {
          if (s.imageUrl != null && s.imageUrl!.isNotEmpty) return s;
          final matchingArt = trackArtworks[s.trackName.trim().toLowerCase()];
          if (matchingArt != null) {
            return s.copyWith(imageUrl: matchingArt);
          }
          return s;
        }).toList();
      }

      _khentHistory = attachCovers(results[0]);
      _clairHistory = attachCovers(results[1]);

      _historyCache[key] = _CachedArtistHistory(
        khentHistory: _khentHistory,
        clairHistory: _clairHistory,
      );
    } catch (e, st) {
      Logger.e('ArtistShowdown: failed to load history for "$artist"', error: e, stackTrace: st);
    } finally {
      if (!_disposed && request == _historyRequestId) {
        _isLoadingHistory = false;
        _safeNotify();
      }
    }
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final completer = _retryCompleter;
    _retryCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRetryTimer();
    super.dispose();
  }
}

class _Draft {
  _Draft({required this.name, required this.spotifyUrl});
  final String name;
  final String spotifyUrl;
  int khent = 0;
  int clair = 0;
  String? imageUrl;
  String? mbid;
}

class _CachedShowdown {
  const _CachedShowdown({
    required this.khentTotal,
    required this.clairTotal,
    required this.tracks,
  });
  final int khentTotal;
  final int clairTotal;
  final List<ShowdownTrack> tracks;
}

class _CachedArtistHistory {
  const _CachedArtistHistory({
    required this.khentHistory,
    required this.clairHistory,
  });
  final List<MusicStatus> khentHistory;
  final List<MusicStatus> clairHistory;
}
