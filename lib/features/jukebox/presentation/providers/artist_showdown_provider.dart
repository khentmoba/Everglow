import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/artist_suggestion.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../../data/services/music_sync_service.dart';

/// One song in an artist showdown: how many times each person played it.
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

  /// 'khent' | 'clair' | null when tied.
  String? get leader {
    if (khentPlays > clairPlays) return 'khent';
    if (clairPlays > khentPlays) return 'clair';
    return null;
  }
}

/// Khent vs Clair for any artist: head-to-head total plus the song-by-song
/// table. Results are cached per artist for the session so switching back
/// and forth never refetches.
///
/// Every play shown belongs to a named song: rows union the artist's
/// catalog (`fetchArtistCatalogTracksAll` + recent scrobbles, counted per
/// song via `track.getInfo`) with each user's own top-tracks chart filtered
/// to the artist, keeping the higher count when both name a song. The
/// catalog finds deep cuts below the chart; the chart finds user-specific
/// tracks (name variants, delisted songs) the global catalog misses.
/// Headline totals are the row sums, so the column always adds up.
///
/// The older `user.getartisttracks` endpoint is deprecated since 2019 and
/// returns individual scrobbles without playcounts from a stale backend,
/// so it always collapsed to "No plays yet" live.
class ArtistShowdownProvider extends ChangeNotifier {
  ArtistShowdownProvider({
    MusicSyncService? syncService,
    String initialArtist = ArtistShowdownProvider.defaultArtist,
    Duration chartTimeout = const Duration(seconds: 5),
    Duration discoveryTimeout = const Duration(seconds: 15),
  }) : _sync = syncService ?? MusicSyncService(),
       _chartTimeout = chartTimeout,
       _discoveryTimeout = discoveryTimeout {
    _khentUser = EnvConfig.lastfmUserKhent;
    _clairUser = EnvConfig.lastfmUserClair;
    selectArtist(initialArtist);
  }

  static const String defaultArtist = 'Ethel Cain';

  /// Page size for `user.gettoptracks` fallback.
  static const int _topTracksPageSize = 200;

  /// How many 200-row pages to walk for the fallback path.
  static const int _topTracksMaxPages = 5;

  /// Most songs of one artist to ask Last.fm about for the history timeline.
  static const int _historyMaxTracks = 50;

  final MusicSyncService _sync;
  final Duration _chartTimeout;
  final Duration _discoveryTimeout;
  late final String _khentUser;
  late final String _clairUser;

  String _artist = '';
  bool _isLoading = true;
  bool _disposed = false;
  int _requestId = 0;

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

  /// 'khent' | 'clair' | null when tied or empty.
  String? get leader {
    if (!hasData) return null;
    if (_khentTotal > _clairTotal) return 'khent';
    if (_clairTotal > _khentTotal) return 'clair';
    return null;
  }

  /// Khent's share of the combined total (0..1) for the versus bar.
  double get khentShare {
    final total = _khentTotal + _clairTotal;
    if (total <= 0) return 0.5;
    return _khentTotal / total;
  }

  /// Live autocomplete: type "lana del" and pick "Lana Del Rey".
  /// Results are cached per query for the session; stale responses are
  /// dropped via [_searchRequestId] so fast typing never shows old rows.
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
      // A retype can hit the cache while an earlier enrichment pass is
      // still fetching photos — top up any rows still missing theirs.
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
    // Last.fm ships no artist photos (placeholder-only since 2019), so
    // rows would all show the initial tile. Enrich from Spotify in the
    // background and pop photos in as they land.
    unawaited(_enrichSuggestionArtwork(request, key));
  }

  /// Fills in missing suggestion photos from Spotify without blocking the
  /// dropdown. Each hit updates the live list and the per-query cache so
  /// retyping finds photos instantly. Photos are also cached per artist so
  /// overlapping queries ("lana" vs "lana del") never refetch.
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

  /// Hides the dropdown (after picking, submitting, or clearing the box).
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
    var timedOut = false;
    (int, int, List<ShowdownTrack>)? localRows;
    try {
      final rows = await _fetchArtistShowdownRows(
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
          return localRows ??
              (isSameArtist
                  ? (_khentTotal, _clairTotal, _tracks)
                  : (0, 0, const <ShowdownTrack>[]));
        },
      );
      // A newer selectArtist won while these reads were in flight — drop them.
      if (_disposed || request != _requestId) return;
      _khentTotal = rows.$1;
      _clairTotal = rows.$2;
      _tracks = rows.$3;
      if (!timedOut) {
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
    // `user.gettoptracks` rarely ships real covers, so rows would all fall
    // back to the music-note tile. Enrich missing artwork in the background
    // (Last.fm track.getinfo, then iTunes) and pop covers in as they land.
    unawaited(_enrichArtwork(request, key, artist));
  }

  /// Forces a reload of the current artist's showdown, evicting any cached
  /// result so new scrobbles or network retries are fetched fresh.
  Future<void> refresh() async {
    final target = _artist.trim().isNotEmpty
        ? _artist.trim()
        : defaultArtist;
    await selectArtist(target, force: true);
  }

  /// Fills in missing covers for the current showdown without blocking the
  /// table. Each hit updates the live list and the per-artist cache so
  /// switching away and back keeps the artwork.
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

  /// Fetches track rows for [artist] from two sources, unioned per user.
  ///
  /// Discovers all tracks belonging to [artist] via Last.fm catalog
  /// (`artist.gettoptracks`), plus any recently scrobbled tracks for [artist]
  /// to capture unreleased or newly played tracks, then queries each user's
  /// exact playcount for those songs — and unions that with each user's own
  /// top-tracks chart filtered to [artist].
  ///
  /// If catalog discovery finds no plays (e.g. offline, mock test service,
  /// or zero scrobbles found), falls back to filtering the top tracks chart.
  Future<(int, int, List<ShowdownTrack>)> _fetchArtistShowdownRows(
    String artist, {
    required void Function((int, int, List<ShowdownTrack>)) onChartRows,
  }) async {
    final wanted = artist.trim().toLowerCase();

    final chartFuture =
        Future.wait([
          _tracksForArtistLegacy(_khentUser, artist),
          _tracksForArtistLegacy(_clairUser, artist),
        ]).timeout(
          _chartTimeout,
          onTimeout: () {
            Logger.w('ArtistShowdown: chart fetch timed out for "$artist"');
            return <List<TopMusicTrack>>[const [], const []];
          },
        ).then((charts) {
          if (charts[0].isNotEmpty || charts[1].isNotEmpty) {
            onChartRows(_merge(charts[0], charts[1]));
          }
          return charts;
        }).catchError((Object e, StackTrace st) {
          Logger.w('ArtistShowdown: chart fetch failed for "$artist"', error: e);
          return <List<TopMusicTrack>>[const [], const []];
        });

    // 1. Discover candidate tracks strictly for this artist in parallel.
    final catalogFuture = _sync
        .fetchArtistCatalogTracksAll(artist, pageSize: 50, maxPages: 2)
        .timeout(const Duration(seconds: 4), onTimeout: () => const [])
        .catchError((Object e, StackTrace st) {
          Logger.w('ArtistShowdown: catalog fetch failed for "$artist"', error: e);
          return const <TopMusicTrack>[];
        });
    final recentKhentFuture = _sync
        .fetchRecentTracks(_khentUser, limit: 50)
        .timeout(const Duration(seconds: 4), onTimeout: () => const [])
        .catchError((Object e, StackTrace st) {
          Logger.w('ArtistShowdown: recent tracks fetch failed for "$artist"', error: e);
          return const <MusicStatus>[];
        });
    final recentClairFuture = _sync
        .fetchRecentTracks(_clairUser, limit: 50)
        .timeout(const Duration(seconds: 4), onTimeout: () => const [])
        .catchError((Object e, StackTrace st) {
          Logger.w('ArtistShowdown: recent tracks fetch failed for "$artist"', error: e);
          return const <MusicStatus>[];
        });

    final charts = await chartFuture;

    final catalog = await catalogFuture;
    final candidateMap = <String, TopMusicTrack>{};
    for (final t in catalog) {
      candidateMap[t.trackName.trim().toLowerCase()] = t;
    }

    // Complement with any recent scrobbles matching this artist
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

    // 2. If candidate tracks were found for this artist, query per-track
    // playcounts and union with each user's own chart: the catalog misses
    // user-specific tracks (name variants, delisted songs), and the chart
    // misses deep cuts below its pages. Unioned, every played song is a
    // named row instead of unnamed filler.
    if (candidates.isNotEmpty) {
      final khentTracksFuture = _sync
          .fetchUserArtistTracks(
            _khentUser,
            artist,
            candidateTracks: candidates,
            batchSize: 16,
          )
          .timeout(const Duration(seconds: 6), onTimeout: () => const [])
          .catchError((Object e, StackTrace st) {
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
          .timeout(const Duration(seconds: 6), onTimeout: () => const [])
          .catchError((Object e, StackTrace st) {
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

      if (khent.isNotEmpty || clair.isNotEmpty) {
        return _merge(khent, clair);
      }
    }

    // 3. Fallback: if candidate search found nothing new, return top tracks chart.
    return _merge(charts[0], charts[1]);
  }

  /// Legacy fallback: pulls each user's top tracks chart and filters by artist.
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

  /// Unions two same-user track lists into one row per song, keeping the
  /// higher playcount when both sources name it. Both lists claim to report
  /// the same all-time count, so the higher one wins and no confirmed play
  /// is ever hidden; artwork falls back to whichever side has it.
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

  /// Merges both users' track lists into one song-by-song table, sorted by
  /// combined plays. Matching is case-insensitive so "Strangers" and
  /// "strangers" count as the same song.
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

  /// Fetches listening history (scrobbles with dates and times) for the current
  /// artist for both Khent and Clair. Caches per artist so re-opening is instant.
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

      // Attach enriched artwork from _tracks if available and missing on scrobble
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

  @override
  void dispose() {
    _disposed = true;
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
