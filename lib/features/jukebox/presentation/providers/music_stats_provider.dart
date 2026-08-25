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
  }) : _syncService = syncService ?? MusicSyncService(signUrl: signLastfmUrl) {
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
    await Future.wait([
      _refreshRecentTracks(_khentUser, _recentTracks),
      _refreshRecentTracks(_clairUser, _clairRecentTracks),
    ]);
    await Future.wait([
      _enrichRecentTrackArtwork(_recentTracks),
      _enrichRecentTrackArtwork(_clairRecentTracks),
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
    if (khent != _khentTotalPlays) {
      _khentTotalPlays = khent;
      changed = true;
    }
    if (clair != _clairTotalPlays) {
      _clairTotalPlays = clair;
      changed = true;
    }
    if (changed) _safeNotify();
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

  Future<String?> _artworkFor(
    String artist,
    String track, {
    String? mbid,
  }) async {
    final key = '$artist\u0000$track';
    if (_artworkCache.containsKey(key)) return _artworkCache[key];
    final artwork = await _syncService.fetchTrackArtwork(
      artist: artist,
      track: track,
      mbid: mbid,
    );
    _artworkCache[key] = artwork;
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
