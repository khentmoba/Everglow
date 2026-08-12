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

    // Recent scrobbles refresh frequently so a fresh listen shows up
    // quickly; the all-time leaderboard barely changes, so it is polled
    // far less often.
    _recentTracksTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshRecentTracks(),
    );
    _topTracksTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _refreshTopTracks(),
    );
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
