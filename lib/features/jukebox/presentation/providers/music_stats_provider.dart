import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../../data/services/music_sync_service.dart';

/// Khent-only music statistics for the dashboard.
///
/// Exposes Khent's all-time top 10 tracks and 5 most recent scrobbles.
/// Clair is intentionally not tracked here yet, per product decision.
class MusicStatsProvider extends ChangeNotifier {
  MusicStatsProvider({MusicSyncService? syncService})
      : _syncService = syncService ?? MusicSyncService() {
    _khentUser =
        (dotenv.isInitialized ? dotenv.env['LASTFM_USER_KHENT'] : null) ??
        'khentsgdz';
    _init();
  }

  final MusicSyncService _syncService;
  late final String _khentUser;

  static const int _topTracksLimit = 10;
  static const int _recentTracksLimit = 5;

  final List<TopMusicTrack> _topTracks = [];
  final List<MusicStatus> _recentTracks = [];
  final Map<String, String?> _artworkCache = {};
  bool _isLoading = true;
  bool _disposed = false;

  Timer? _recentTracksTimer;
  Timer? _topTracksTimer;

  List<TopMusicTrack> get topTracks => List.unmodifiable(_topTracks);
  List<MusicStatus> get recentTracks => List.unmodifiable(_recentTracks);
  String get username => _khentUser;
  bool get isLoading => _isLoading;
  bool get hasData => _topTracks.isNotEmpty || _recentTracks.isNotEmpty;

  Future<void> _init() async {
    await Future.wait([_refreshTopTracks(), _refreshRecentTracks()]);
    _isLoading = false;
    _safeNotify();

    // Last.fm returns its default placeholder image for tracks without
    // artwork, so fill in real album covers in the background.
    unawaited(_enrichTopTrackArtwork());
    unawaited(_enrichRecentTrackArtwork());

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
    await _refreshRecentTracks();
    await _enrichRecentTrackArtwork();
  }

  Future<void> _periodicTopRefresh() async {
    await _refreshTopTracks();
    await _enrichTopTrackArtwork();
  }

  Future<void> _refreshTopTracks() async {
    final tracks = await _syncService.fetchTopTracks(
      _khentUser,
      limit: _topTracksLimit,
    );
    if (_disposed) return;
    _topTracks
      ..clear()
      ..addAll(tracks);
    _safeNotify();
  }

  Future<void> _refreshRecentTracks() async {
    final tracks = await _syncService.fetchRecentTracks(
      _khentUser,
      limit: _recentTracksLimit,
    );
    if (_disposed) return;
    _recentTracks
      ..clear()
      ..addAll(tracks);
    _safeNotify();
  }

  /// Replaces missing (or placeholder) top-track artwork with the track's
  /// real album art from `track.getinfo`. Runs in the background so the
  /// leaderboard renders immediately.
  Future<void> _enrichTopTrackArtwork() async {
    var changed = false;
    for (var i = 0; i < _topTracks.length; i++) {
      final track = _topTracks[i];
      if (track.imageUrl != null) continue;
      final artwork = await _artworkFor(
        track.artistName,
        track.trackName,
        mbid: track.mbid,
      );
      if (_disposed || artwork == null) continue;
      if (!identical(_topTracks[i], track)) continue;
      if (_topTracks[i].imageUrl == artwork) continue;
      _topTracks[i] = TopMusicTrack(
        rank: track.rank,
        trackName: track.trackName,
        artistName: track.artistName,
        playCount: track.playCount,
        imageUrl: artwork,
        spotifyUrl: track.spotifyUrl,
        mbid: track.mbid,
      );
      changed = true;
    }
    if (changed) _safeNotify();
  }

  /// Same enrichment as [_enrichTopTrackArtwork] but for recent scrobbles.
  Future<void> _enrichRecentTrackArtwork() async {
    var changed = false;
    for (var i = 0; i < _recentTracks.length; i++) {
      final status = _recentTracks[i];
      if (status.imageUrl != null) continue;
      final artwork = await _artworkFor(status.artistName, status.trackName);
      if (_disposed || artwork == null) continue;
      if (!identical(_recentTracks[i], status)) continue;
      if (_recentTracks[i].imageUrl == artwork) continue;
      _recentTracks[i] = MusicStatus(
        username: status.username,
        trackName: status.trackName,
        artistName: status.artistName,
        albumName: status.albumName,
        imageUrl: artwork,
        isPlaying: status.isPlaying,
        spotifyUrl: status.spotifyUrl,
        timestamp: status.timestamp,
      );
      changed = true;
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
