import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../../data/services/music_sync_service.dart';

class MusicStatsProvider extends ChangeNotifier with WidgetsBindingObserver {
  MusicStatsProvider({
    MusicSyncService? syncService,
    Future<Uri> Function(Uri url)? signLastfmUrl,
    Duration artworkRetryCooldown = _defaultArtworkRetryCooldown,
    SharedPreferences? prefs,
    bool surfaceActive = true,
  }) : _syncService = syncService ?? MusicSyncService(signUrl: signLastfmUrl),
       _artworkRetryCooldown = artworkRetryCooldown,
       _prefs = prefs,
       _surfaceActive = surfaceActive {
    _khentUser = EnvConfig.lastfmUserKhent;
    _clairUser = EnvConfig.lastfmUserClair;
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (_surfaceActive) {
      _started = true;
      _init();
    }
  }

  final MusicSyncService _syncService;
  SharedPreferences? _prefs;
  late final String _khentUser;
  late final String _clairUser;

  static const int _topTracksLimit = 10;
  static const int _recentTracksLimit = 5;

  final List<TopMusicTrack> _topTracks = [];
  final List<MusicStatus> _recentTracks = [];
  final List<TopMusicTrack> _clairTopTracks = [];
  final List<MusicStatus> _clairRecentTracks = [];
  final Map<String, String?> _artworkCache = {};
  final Set<String> _reactiveHealAttempted = {};
  bool _isLoading = true;
  bool _disposed = false;
  bool _appActive = true;
  bool _surfaceActive;
  bool _started = false;
  bool _refreshing = false;
  bool _topRefreshPending = false;
  bool get _active => _appActive && _surfaceActive;

  void setSurfaceActive(bool active) {
    if (_disposed || active == _surfaceActive) return;
    _surfaceActive = active;
    _syncActivity();
  }

  void _syncActivity() {
    _recentTracksTimer?.cancel();
    _topTracksTimer?.cancel();
    if (!_active) return;
    if (!_started) {
      _started = true;
      unawaited(_init());
    } else if (!_isLoading) {
      unawaited(_periodicRecentRefresh());
      _startTimers();
    }
  }

  int _khentTotalPlays = 0;
  int _clairTotalPlays = 0;

  Timer? _recentTracksTimer;
  Timer? _topTracksTimer;

  List<TopMusicTrack> get topTracks => List.unmodifiable(_topTracks);
  List<MusicStatus> get recentTracks => List.unmodifiable(_recentTracks);
  List<TopMusicTrack> get clairTopTracks => List.unmodifiable(_clairTopTracks);
  List<MusicStatus> get clairRecentTracks =>
      List.unmodifiable(_clairRecentTracks);
  String get username => _khentUser;
  String get clairUsername => _clairUser;
  bool get isLoading => _isLoading;
  bool get hasData =>
      _topTracks.isNotEmpty ||
      _recentTracks.isNotEmpty ||
      _clairTopTracks.isNotEmpty ||
      _clairRecentTracks.isNotEmpty;

  int get khentTotalPlays => _khentTotalPlays;
  int get clairTotalPlays => _clairTotalPlays;

  int get khentRawTotalPlays => _khentTotalPlays;
  int get clairRawTotalPlays => _clairTotalPlays;

  bool get isKhentLeader =>
      hasData && khentTotalPlays > 0 && khentTotalPlays > clairTotalPlays;

  bool get isClairLeader =>
      hasData && clairTotalPlays > 0 && clairTotalPlays > khentTotalPlays;

  bool get isTie =>
      hasData &&
      khentTotalPlays > 0 &&
      clairTotalPlays > 0 &&
      khentTotalPlays == clairTotalPlays;

  Future<void> _init() async {
    unawaited(_loadCachedTotals());
    await Future.wait([
      _refreshTopTracks(_khentUser, _topTracks),
      _refreshRecentTracks(_khentUser, _recentTracks),
      _refreshTopTracks(_clairUser, _clairTopTracks),
      _refreshRecentTracks(_clairUser, _clairRecentTracks),
      _refreshUserTotals(),
    ]);
    if (_disposed) return;
    if (_isLoading) {
      _isLoading = false;
      _safeNotify();
    }

    unawaited(_enrichTopTrackArtwork(_topTracks));
    unawaited(_enrichRecentTrackArtwork(_recentTracks));
    unawaited(_enrichTopTrackArtwork(_clairTopTracks));
    unawaited(_enrichRecentTrackArtwork(_clairRecentTracks));

    _startTimers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_disposed || active == _appActive) return;
    _appActive = active;
    _syncActivity();
  }

  void _startTimers() {
    if (_disposed || !_active) return;
    _recentTracksTimer?.cancel();
    _topTracksTimer?.cancel();

    _recentTracksTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _periodicRecentRefresh(),
    );
    _topTracksTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _periodicTopRefresh(),
    );
  }

  Future<void> _periodicRecentRefresh() => _refreshStatistics(top: false);
  Future<void> _periodicTopRefresh() => _refreshStatistics(top: true);

  Future<void> _refreshStatistics({required bool top}) async {
    if (_disposed || !_active || _isLoading) return;
    if (_refreshing) {
      _topRefreshPending |= top;
      return;
    }
    _refreshing = true;
    try {
      do {
        final refreshTop = top || _topRefreshPending;
        _topRefreshPending = false;
        if (refreshTop) {
          await _refreshTop();
        } else {
          await _refreshRecent();
        }
        top = false;
      } while (_topRefreshPending && _active && !_disposed);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshRecent() async {
    if (_disposed || !_active) return;
    final needTop =
        _topTracks.isEmpty ||
        _clairTopTracks.isEmpty ||
        _khentTotalPlays == 0 ||
        _clairTotalPlays == 0;
    await Future.wait([
      _refreshRecentTracks(_khentUser, _recentTracks),
      _refreshRecentTracks(_clairUser, _clairRecentTracks),
      if (needTop) _refreshTopTracks(_khentUser, _topTracks),
      if (needTop) _refreshTopTracks(_clairUser, _clairTopTracks),
      if (needTop) _refreshUserTotals(),
    ]);
    await Future.wait([
      _enrichRecentTrackArtwork(_recentTracks),
      _enrichRecentTrackArtwork(_clairRecentTracks),
      if (needTop) _enrichTopTrackArtwork(_topTracks),
      if (needTop) _enrichTopTrackArtwork(_clairTopTracks),
    ]);
  }

  Future<void> _refreshTop() async {
    if (_disposed || !_active) return;
    await Future.wait([
      _refreshTopTracks(_khentUser, _topTracks),
      _refreshTopTracks(_clairUser, _clairTopTracks),
      _refreshUserTotals(),
    ]);
    await Future.wait([
      _enrichTopTrackArtwork(_topTracks),
      _enrichTopTrackArtwork(_clairTopTracks),
    ]);
  }

  Future<void> _loadCachedTotals() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final khent = prefs.getInt('jukebox_total_plays_$_khentUser') ?? 0;
      final clair = prefs.getInt('jukebox_total_plays_$_clairUser') ?? 0;
      if (_disposed) return;
      var changed = false;
      if (khent > 0 && _khentTotalPlays == 0) {
        _khentTotalPlays = khent;
        changed = true;
      }
      if (clair > 0 && _clairTotalPlays == 0) {
        _clairTotalPlays = clair;
        changed = true;
      }
      if (changed) _safeNotify();
    } catch (e, st) {
      Logger.e(
        'MusicStatsProvider: Failed to load cached totals',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _saveCachedTotals() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      if (_khentTotalPlays > 0) {
        await prefs.setInt('jukebox_total_plays_$_khentUser', _khentTotalPlays);
      }
      if (_clairTotalPlays > 0) {
        await prefs.setInt('jukebox_total_plays_$_clairUser', _clairTotalPlays);
      }
    } catch (e, st) {
      Logger.e(
        'MusicStatsProvider: Failed to save cached totals',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _refreshUserTotals() async {
    final results = await Future.wait([
      _syncService.fetchUserTotalPlays(_khentUser),
      _syncService.fetchUserTotalPlays(_clairUser),
    ]);
    if (_disposed) return;
    final khent = results[0];
    final clair = results[1];
    var changed = false;
    if (khent > 0 && khent != _khentTotalPlays) {
      _khentTotalPlays = khent;
      changed = true;
    }
    if (clair > 0 && clair != _clairTotalPlays) {
      _clairTotalPlays = clair;
      changed = true;
    }
    if (changed) {
      _safeNotify();
      unawaited(_saveCachedTotals());
    }
  }

  Future<void> _refreshTopTracks(
    String username,
    List<TopMusicTrack> destination,
  ) async {
    final tracks = await _syncService.fetchTopTracks(
      username,
      limit: _topTracksLimit,
    );
    if (_disposed) return;
    if (tracks.isEmpty && destination.isNotEmpty) return;
    final sorted = List<TopMusicTrack>.from(tracks)
      ..sort((a, b) {
        final cmp = b.playCount.compareTo(a.playCount);
        if (cmp != 0) return cmp;
        final rankA = a.rank > 0 ? a.rank : 999;
        final rankB = b.rank > 0 ? b.rank : 999;
        return rankA.compareTo(rankB);
      });
    for (var i = 0; i < sorted.length; i++) {
      sorted[i] = sorted[i].copyWith(rank: i + 1);
    }
    destination
      ..clear()
      ..addAll(sorted);
    if (_isLoading && hasData) {
      _isLoading = false;
    }
    _safeNotify();
  }

  Future<void> _refreshRecentTracks(
    String username,
    List<MusicStatus> destination,
  ) async {
    final tracks = await _syncService.fetchRecentTracks(
      username,
      limit: _recentTracksLimit,
    );
    if (_disposed) return;
    final total = _syncService.getLastObservedTotalPlays(username);
    if (total > 0) {
      if (username == _khentUser && total != _khentTotalPlays) {
        _khentTotalPlays = total;
        unawaited(_saveCachedTotals());
      } else if (username == _clairUser && total != _clairTotalPlays) {
        _clairTotalPlays = total;
        unawaited(_saveCachedTotals());
      }
    }
    if (tracks.isEmpty && destination.isNotEmpty) return;
    destination
      ..clear()
      ..addAll(tracks);
    if (_isLoading && hasData) {
      _isLoading = false;
    }
    _safeNotify();
  }

  Future<void> _enrichTopTrackArtwork(List<TopMusicTrack> tracks) async {
    final indices = <int>[];
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      if (t.imageUrl == null || t.albumName == null || t.albumName!.isEmpty) {
        indices.add(i);
      }
    }
    if (indices.isEmpty) return;
    const concurrency = 4;
    var changed = false;
    for (var c = 0; c < indices.length; c += concurrency) {
      final chunk = indices.skip(c).take(concurrency).toList();
      final results = await Future.wait(
        chunk.map((idx) async {
          final track = tracks[idx];
          final meta = await _metadataFor(
            track.artistName,
            track.trackName,
            mbid: track.mbid,
          );
          return (idx: idx, track: track, meta: meta);
        }),
      );
      for (final r in results) {
        if (_disposed || r.meta == null) continue;
        if (!identical(tracks[r.idx], r.track)) continue;
        final current = tracks[r.idx];
        final newArt = r.meta!.artworkUrl ?? current.imageUrl;
        final newAlbum =
            (r.meta!.albumName != null && r.meta!.albumName!.isNotEmpty)
            ? r.meta!.albumName
            : current.albumName;
        if (current.imageUrl == newArt && current.albumName == newAlbum) {
          continue;
        }
        tracks[r.idx] = current.copyWith(imageUrl: newArt, albumName: newAlbum);
        changed = true;
      }
      if (changed) {
        _safeNotify();
        changed = false;
      }
    }
  }

  Future<void> _enrichRecentTrackArtwork(List<MusicStatus> tracks) async {
    final indices = <int>[];
    for (var i = 0; i < tracks.length; i++) {
      if (tracks[i].imageUrl == null) indices.add(i);
    }
    if (indices.isEmpty) return;
    const concurrency = 4;
    var changed = false;
    for (var c = 0; c < indices.length; c += concurrency) {
      final chunk = indices.skip(c).take(concurrency).toList();
      final results = await Future.wait(
        chunk.map((idx) async {
          final status = tracks[idx];
          final artwork = await _artworkFor(
            status.artistName,
            status.trackName,
          );
          return (idx: idx, status: status, artwork: artwork);
        }),
      );
      for (final r in results) {
        if (_disposed || r.artwork == null) continue;
        if (!identical(tracks[r.idx], r.status)) continue;
        if (tracks[r.idx].imageUrl == r.artwork) continue;
        tracks[r.idx] = MusicStatus(
          username: r.status.username,
          trackName: r.status.trackName,
          artistName: r.status.artistName,
          albumName: r.status.albumName,
          imageUrl: r.artwork,
          isPlaying: r.status.isPlaying,
          spotifyUrl: r.status.spotifyUrl,
          timestamp: r.status.timestamp,
        );
        changed = true;
      }
      if (changed) {
        _safeNotify();
        changed = false;
      }
    }
  }

  final Map<String, DateTime> _artworkMissAt = {};

  static const _defaultArtworkRetryCooldown = Duration(minutes: 10);

  final Duration _artworkRetryCooldown;

  Future<void> healTopTrackCover({
    required String artist,
    required String track,
    String? mbid,
  }) async {
    final key = '$artist\u0000$track';
    if (!_reactiveHealAttempted.add(key)) return;
    final meta = await _metadataFor(
      artist,
      track,
      mbid: mbid,
      bypassCooldown: true,
    );
    final artwork = meta?.artworkUrl;
    if (_disposed || artwork == null) return;
    var changed = false;
    for (final list in [_topTracks, _clairTopTracks]) {
      for (var i = 0; i < list.length; i++) {
        final t = list[i];
        if (t.artistName == artist &&
            t.trackName == track &&
            (t.imageUrl != artwork ||
                (meta?.albumName != null && t.albumName != meta!.albumName))) {
          list[i] = t.copyWith(
            imageUrl: artwork,
            albumName: meta?.albumName ?? t.albumName,
          );
          changed = true;
        }
      }
    }
    if (changed) _safeNotify();
  }

  Future<void> healRecentTrackCover({
    required String artist,
    required String track,
  }) async {
    final key = '$artist\u0000$track';
    if (!_reactiveHealAttempted.add(key)) return;
    final artwork = await _artworkFor(artist, track, bypassCooldown: true);
    if (_disposed || artwork == null) return;
    var changed = false;
    for (final list in [_recentTracks, _clairRecentTracks]) {
      for (var i = 0; i < list.length; i++) {
        final s = list[i];
        if (s.artistName == artist &&
            s.trackName == track &&
            s.imageUrl != artwork) {
          list[i] = s.copyWith(imageUrl: artwork);
          changed = true;
        }
      }
    }
    if (changed) _safeNotify();
  }

  final Map<String, TrackMetadata?> _metadataCache = {};

  Future<TrackMetadata?> _metadataFor(
    String artist,
    String track, {
    String? mbid,
    bool bypassCooldown = false,
  }) async {
    final key = '$artist\u0000$track';
    if (_metadataCache.containsKey(key)) return _metadataCache[key];
    final missAt = _artworkMissAt[key];
    if (!bypassCooldown &&
        missAt != null &&
        DateTime.now().difference(missAt) < _artworkRetryCooldown) {
      return null;
    }
    final meta = await _syncService.fetchTrackMetadata(
      artist: artist,
      track: track,
      mbid: mbid,
    );
    if (meta == null ||
        (meta.artworkUrl == null &&
            (meta.albumName == null || meta.albumName!.isEmpty))) {
      _artworkMissAt[key] = DateTime.now();
      return null;
    }
    _metadataCache[key] = meta;
    if (meta.artworkUrl != null) _artworkCache[key] = meta.artworkUrl!;
    _artworkMissAt.remove(key);
    return meta;
  }

  Future<String?> _artworkFor(
    String artist,
    String track, {
    String? mbid,
    bool bypassCooldown = false,
  }) async {
    final meta = await _metadataFor(
      artist,
      track,
      mbid: mbid,
      bypassCooldown: bypassCooldown,
    );
    return meta?.artworkUrl;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _recentTracksTimer?.cancel();
    _topTracksTimer?.cancel();
    super.dispose();
  }
}
