import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/config/env_config.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../../data/services/music_sync_service.dart';

/// Last.fm music statistics for both people in the couple.
///
/// Exposes each user's all-time top 10 tracks and 5 most recent scrobbles.
class MusicStatsProvider extends ChangeNotifier {
  MusicStatsProvider({
    MusicSyncService? syncService,
    Future<Uri> Function(Uri url)? signLastfmUrl,
    Duration artworkRetryCooldown = _defaultArtworkRetryCooldown,
  })  : _syncService = syncService ?? MusicSyncService(signUrl: signLastfmUrl),
        _artworkRetryCooldown = artworkRetryCooldown {
    _khentUser = EnvConfig.lastfmUserKhent;
    _clairUser = EnvConfig.lastfmUserClair;
    _init();
  }

  final MusicSyncService _syncService;
  late final String _khentUser;
  late final String _clairUser;

  static const int _topTracksLimit = 10;
  static const int _recentTracksLimit = 5;

  final List<TopMusicTrack> _topTracks = [];
  final List<MusicStatus> _recentTracks = [];
  final List<TopMusicTrack> _clairTopTracks = [];
  final List<MusicStatus> _clairRecentTracks = [];
  final Map<String, String?> _artworkCache = {};
  // One reactive heal per track per session: AppNetworkImage.onError fires
  // on every rebuild while failed, so without this a permanently artless
  // track would hammer the APIs. Periodic enrichment still retries after
  // the cooldown, so a transient failure recovers on the next tick.
  final Set<String> _reactiveHealAttempted = {};
  bool _isLoading = true;
  bool _disposed = false;

  /// All-time scrobble totals from Last.fm `user.getInfo` (0 while loading
  /// or when the API is unreachable — the UI falls back to the top-10 sum).
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

  /// Effective totals — prefers the authoritative Last.fm playcount, falls
  /// back to the sum of the loaded top-10 when that count is still 0.
  int get khentTotalPlays =>
      _khentTotalPlays > 0 ? _khentTotalPlays : _topTracksSum(_topTracks);
  int get clairTotalPlays =>
      _clairTotalPlays > 0 ? _clairTotalPlays : _topTracksSum(_clairTopTracks);

  /// Raw API totals (0 means not yet loaded / unavailable).
  int get khentRawTotalPlays => _khentTotalPlays;
  int get clairRawTotalPlays => _clairTotalPlays;

  static int _topTracksSum(List<TopMusicTrack> tracks) =>
      tracks.fold<int>(0, (s, t) => s + t.playCount);

  /// Whether Khent is the current listening champion (strictly more plays).
  bool get isKhentLeader =>
      hasData && khentTotalPlays > 0 && khentTotalPlays > clairTotalPlays;

  /// Whether Clair is the current listening champion.
  bool get isClairLeader =>
      hasData && clairTotalPlays > 0 && clairTotalPlays > khentTotalPlays;

  bool get isTie =>
      hasData &&
      khentTotalPlays > 0 &&
      clairTotalPlays > 0 &&
      khentTotalPlays == clairTotalPlays;

  Future<void> _init() async {
    await Future.wait([
      _refreshTopTracks(_khentUser, _topTracks),
      _refreshRecentTracks(_khentUser, _recentTracks),
      _refreshTopTracks(_clairUser, _clairTopTracks),
      _refreshRecentTracks(_clairUser, _clairRecentTracks),
      _refreshUserTotals(),
    ]);
    _isLoading = false;
    _safeNotify();

    // Last.fm returns its default placeholder image for tracks without
    // artwork, so fill in real album covers in the background.
    unawaited(_enrichTopTrackArtwork(_topTracks));
    unawaited(_enrichRecentTrackArtwork(_recentTracks));
    unawaited(_enrichTopTrackArtwork(_clairTopTracks));
    unawaited(_enrichRecentTrackArtwork(_clairRecentTracks));

    // Recent scrobbles refresh frequently so a fresh listen shows up
    // quickly; the all-time leaderboard barely changes, so it is polled
    // far less often.
    _recentTracksTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _periodicRecentRefresh(),
    );
    _topTracksTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _periodicTopRefresh(),
    );
  }

  Future<void> _periodicRecentRefresh() async {
    // If the leaderboard is still empty (e.g. the boot fetch hit a
    // transient Last.fm error payload), retry it here every minute
    // instead of waiting up to 10 minutes for the top-tracks timer —
    // otherwise one bad response sticks "No music stats yet" on screen.
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

  Future<void> _periodicTopRefresh() async {
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

  Future<void> _refreshUserTotals() async {
    final results = await Future.wait([
      _syncService.fetchUserTotalPlays(_khentUser),
      _syncService.fetchUserTotalPlays(_clairUser),
    ]);
    if (_disposed) return;
    final khent = results[0];
    final clair = results[1];
    var changed = false;
    // user.getInfo returns 0 on failure — never let a failed poll zero out
    // a good total, or the leaderboard header loses its listens pill.
    if (khent > 0 && khent != _khentTotalPlays) {
      _khentTotalPlays = khent;
      changed = true;
    }
    if (clair > 0 && clair != _clairTotalPlays) {
      _clairTotalPlays = clair;
      changed = true;
    }
    if (changed) _safeNotify();
  }

  Future<void> _refreshTopTracks(
    String username,
    List<TopMusicTrack> destination,
  ) async {
    // A failed fetch returns [] (Last.fm error payloads, timeouts, auth).
    // Keep the last good leaderboard instead of wiping it — an empty
    // response must never stick "No music stats yet" over good data.
    // Only the very first load (destination still empty) may stay empty.
    final tracks = await _syncService.fetchTopTracks(
      username,
      limit: _topTracksLimit,
    );
    if (_disposed) return;
    if (tracks.isEmpty && destination.isNotEmpty) return;
    destination
      ..clear()
      ..addAll(tracks);
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
    if (tracks.isEmpty && destination.isNotEmpty) return;
    destination
      ..clear()
      ..addAll(tracks);
    _safeNotify();
  }

  /// Replaces missing (or placeholder) top-track artwork with the track's
  /// real album art from `track.getinfo`. Runs in the background so the
  /// leaderboard renders immediately. Batched with concurrency=4 so 10 tracks
  /// don't take 10×RTT serially.
  Future<void> _enrichTopTrackArtwork(List<TopMusicTrack> tracks) async {
    final indices = <int>[];
    for (var i = 0; i < tracks.length; i++) {
      if (tracks[i].imageUrl == null) indices.add(i);
    }
    if (indices.isEmpty) return;
    const concurrency = 4;
    var changed = false;
    for (var c = 0; c < indices.length; c += concurrency) {
      final chunk = indices.skip(c).take(concurrency).toList();
      final results = await Future.wait(chunk.map((idx) async {
        final track = tracks[idx];
        final artwork = await _artworkFor(
          track.artistName,
          track.trackName,
          mbid: track.mbid,
        );
        return (idx: idx, track: track, artwork: artwork);
      }));
      for (final r in results) {
        if (_disposed || r.artwork == null) continue;
        if (!identical(tracks[r.idx], r.track)) continue;
        if (tracks[r.idx].imageUrl == r.artwork) continue;
        tracks[r.idx] = TopMusicTrack(
          rank: r.track.rank,
          trackName: r.track.trackName,
          artistName: r.track.artistName,
          playCount: r.track.playCount,
          imageUrl: r.artwork,
          spotifyUrl: r.track.spotifyUrl,
          mbid: r.track.mbid,
        );
        changed = true;
      }
    }
    if (changed) _safeNotify();
  }

  /// Same enrichment as [_enrichTopTrackArtwork] but for recent scrobbles.
  /// Batched for the same reason.
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
      final results = await Future.wait(chunk.map((idx) async {
        final status = tracks[idx];
        final artwork = await _artworkFor(status.artistName, status.trackName);
        return (idx: idx, status: status, artwork: artwork);
      }));
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
    }
    if (changed) _safeNotify();
  }

  /// When a lookup last came up empty, so transient failures (Last.fm rate
  /// limits, timeouts) are retried instead of blanking the track forever.
  final Map<String, DateTime> _artworkMissAt = {};

  /// Default cooldown before a failed artwork lookup is retried. Keeps the
  /// 1-minute recent-tracks tick from hammering the APIs for permanently
  /// artless tracks while still recovering a few minutes after a transient
  /// failure. Injectable via [artworkRetryCooldown] for tests, where the
  /// fake-async clock never advances `DateTime.now()`.
  static const _defaultArtworkRetryCooldown = Duration(minutes: 10);

  final Duration _artworkRetryCooldown;

  /// Reactive heal for a cover that looks valid but fails to load (stale
  /// Last.fm CDN URL, expired proxy cache, ...). Called from the row's
  /// image error builder — bypasses the miss cooldown so the broken tile
  /// heals immediately instead of waiting up to 10 minutes, and updates
  /// every matching row in both users' leaderboards. One attempt per
  /// track per session (AppNetworkImage.onError fires on every rebuild
  /// while failed); periodic enrichment still retries after the cooldown.
  Future<void> healTopTrackCover({
    required String artist,
    required String track,
    String? mbid,
  }) async {
    final key = '$artist\u0000$track';
    if (!_reactiveHealAttempted.add(key)) return;
    final artwork = await _artworkFor(
      artist,
      track,
      mbid: mbid,
      bypassCooldown: true,
    );
    if (_disposed || artwork == null) return;
    var changed = false;
    for (final list in [_topTracks, _clairTopTracks]) {
      for (var i = 0; i < list.length; i++) {
        final t = list[i];
        if (t.artistName == artist &&
            t.trackName == track &&
            t.imageUrl != artwork) {
          list[i] = TopMusicTrack(
            rank: t.rank,
            trackName: t.trackName,
            artistName: t.artistName,
            playCount: t.playCount,
            imageUrl: artwork,
            spotifyUrl: t.spotifyUrl,
            mbid: t.mbid,
          );
          changed = true;
        }
      }
    }
    if (changed) _safeNotify();
  }

  /// Same reactive heal as [healTopTrackCover] but for recent scrobbles.
  Future<void> healRecentTrackCover({
    required String artist,
    required String track,
  }) async {
    final key = '$artist\u0000$track';
    if (!_reactiveHealAttempted.add(key)) return;
    final artwork = await _artworkFor(
      artist,
      track,
      bypassCooldown: true,
    );
    if (_disposed || artwork == null) return;
    var changed = false;
    for (final list in [_recentTracks, _clairRecentTracks]) {
      for (var i = 0; i < list.length; i++) {
        final s = list[i];
        if (s.artistName == artist &&
            s.trackName == track &&
            s.imageUrl != artwork) {
          list[i] = MusicStatus(
            username: s.username,
            trackName: s.trackName,
            artistName: s.artistName,
            albumName: s.albumName,
            imageUrl: artwork,
            isPlaying: s.isPlaying,
            spotifyUrl: s.spotifyUrl,
            timestamp: s.timestamp,
          );
          changed = true;
        }
      }
    }
    if (changed) _safeNotify();
  }

  Future<String?> _artworkFor(
    String artist,
    String track, {
    String? mbid,
    bool bypassCooldown = false,
  }) async {
    final key = '$artist\u0000$track';
    if (_artworkCache.containsKey(key)) return _artworkCache[key];
    final missAt = _artworkMissAt[key];
    if (!bypassCooldown &&
        missAt != null &&
        DateTime.now().difference(missAt) < _artworkRetryCooldown) {
      return null;
    }
    final artwork = await _syncService.fetchTrackArtwork(
      artist: artist,
      track: track,
      mbid: mbid,
    );
    if (artwork != null) {
      // Only hits are cached: a miss stays retryable so one bad boot (e.g.
      // a rate-limited enrichment wave) never blanks covers for the session.
      _artworkCache[key] = artwork;
      _artworkMissAt.remove(key);
    } else {
      _artworkMissAt[key] = DateTime.now();
    }
    return artwork;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _recentTracksTimer?.cancel();
    _topTracksTimer?.cancel();
    super.dispose();
  }
}
