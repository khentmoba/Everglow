import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/music_status.dart';
import '../../data/services/music_sync_service.dart';
import '../../data/services/music_persistence_service.dart';

class JukeboxProvider extends ChangeNotifier {
  JukeboxProvider({
    MusicSyncService? apiService,
    MusicPersistenceService? persistenceService,
    AuthService? authService,
    Future<bool> Function(String uid)? awardListenXp,
    Duration pollInterval = const Duration(seconds: 60),
    Duration livePollInterval = const Duration(seconds: 25),
    Duration resubscribeDelay = const Duration(seconds: 5),
  }) : _apiService = apiService ?? MusicSyncService(),
       _persistenceService =
           persistenceService ?? MusicPersistenceService(),
       _authService = authService,
       _awardListenXp = awardListenXp,
       _pollInterval = pollInterval,
       _livePollInterval = livePollInterval,
       _resubscribeDelay = resubscribeDelay {
    // Replay the latest known state to every (re)subscriber: broadcast
    // streams don't retain events, so without this a fresh StreamBuilder
    // (e.g. after navigating back to the dashboard) shows empty cards
    // until the next Firestore write lands, minutes later.
    _statusController =
        StreamController<Map<String, MusicStatus>>.broadcast(
          onListen: _replayLatest,
        );
    _initProvider();
  }

  final MusicSyncService _apiService;
  final MusicPersistenceService _persistenceService;
  final AuthService? _authService;
  final Future<bool> Function(String uid)? _awardListenXp;
  final Duration _pollInterval;
  final Duration _livePollInterval;
  final Duration _resubscribeDelay;

  /// Last awarded track per Last.fm username, so the poll doesn't
  /// re-award the same scrobble every tick.
  final Map<String, String> _lastAwardedTrackKey = {};

  /// Last synced track per Last.fm username. The poll skips its Firestore
  /// write when nothing changed, so idle hours cost zero writes instead
  /// of two every minute. Play/stop transitions always change the key
  /// (live vs timestamped), so they still sync immediately.
  final Map<String, String> _lastSyncedTrackKey = {};

  late final StreamController<Map<String, MusicStatus>> _statusController;
  StreamSubscription? _firestoreSubscription;
  Timer? _pollingTimer;
  Timer? _resubscribeTimer;
  int _resubscribeAttempts = 0;
  bool _disposed = false;

  final Map<String, MusicStatus> _currentStatus = {};

  Stream<Map<String, MusicStatus>> get statusStream => _statusController.stream;

  void _initProvider() {
    final khentUser = EnvConfig.lastfmUserKhent;
    final clairUser = EnvConfig.lastfmUserClair;

    // 1. Initial local state
    _currentStatus[khentUser] = MusicStatus.empty(khentUser);
    _currentStatus[clairUser] = MusicStatus.empty(clairUser);

    // 2. Listen to Firestore for real-time updates (Global Consistency)
    _subscribeToFirestore([khentUser, clairUser]);

    // 3. Start Polling Last.fm to keep Firestore updated
    // Adaptive cadence (see _pollLoop): ~25s while anyone is live so song
    // changes surface fast, 60s while idle to stay kind to Last.fm.
    _pollLoop(khentUser, clairUser);
  }

  /// Polls Last.fm, then waits [_livePollInterval] while anyone is live
  /// and [_pollInterval] while idle. Fast polling only runs during actual
  /// listening, and Firestore writes still happen only on track changes,
  /// so realtime costs nothing extra there — just a few more free
  /// Last.fm reads while music plays.
  Future<void> _pollLoop(String khent, String clair) async {
    final live = await _fetchAndSync(khent, clair);
    if (_disposed) return;
    // Echoed Firestore state covers failed polls: a failed fetch returns
    // false, but the last known live state keeps the fast cadence.
    final anyoneLive =
        live || _currentStatus.values.any((s) => s.isPlaying);
    _pollingTimer = Timer(anyoneLive ? _livePollInterval : _pollInterval, () {
      if (_disposed) return;
      _pollLoop(khent, clair);
    });
  }

  void _replayLatest() {
    if (!_statusController.isClosed) {
      _statusController.add(Map.from(_currentStatus));
    }
  }

  void _subscribeToFirestore(List<String> usernames) {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = _persistenceService
        .musicStatusStream(usernames)
        .listen(
          _handleFirestoreData,
          onError: (Object error, StackTrace stackTrace) {
            // The dashboard is reachable before Firebase Auth restores
            // (offline prefs session), so the first listen can fail with
            // permission-denied; without a handler the subscription dies
            // silently and live updates never recover. Resubscribe instead.
            Logger.w('Jukebox: music-status stream error ($error); retrying');
            _scheduleResubscribe(usernames);
          },
          onDone: () {
            // The stream wrapper closes slow first snapshots and the
            // source can close on reconnects — resubscribe either way.
            Logger.w('Jukebox: music-status stream closed; resubscribing');
            _scheduleResubscribe(usernames);
          },
        );
  }

  void _scheduleResubscribe(List<String> usernames) {
    if (_disposed) return;
    _resubscribeTimer?.cancel();
    // Back off so a persistently-denied session doesn't hot-loop listens.
    var delay = _resubscribeDelay;
    for (var i = 0; i < _resubscribeAttempts; i++) {
      delay = delay * 2;
      if (delay > const Duration(minutes: 1)) {
        delay = const Duration(minutes: 1);
        break;
      }
    }
    _resubscribeAttempts++;
    _resubscribeTimer = Timer(delay, () {
      if (_disposed || _statusController.isClosed) return;
      _subscribeToFirestore(usernames);
    });
  }

  void _handleFirestoreData(Map<String, MusicStatus> data) {
    if (_disposed) return;
    if (data.isNotEmpty) {
      _resubscribeAttempts = 0;
      _currentStatus.addAll(data);
      if (!_statusController.isClosed) {
        _statusController.add(Map.from(_currentStatus));
      }
      notifyListeners();
    }
  }

  /// Returns true when either user is currently playing (drives [_pollLoop]).
  Future<bool> _fetchAndSync(String khent, String clair) async {
    final futures = <Future<bool>>[];
    if (khent.isNotEmpty) {
      futures.add(_fetchListen(khent));
    }
    if (clair.isNotEmpty) {
      futures.add(_fetchListen(clair));
    }
    if (futures.isEmpty) return false;
    final results = await Future.wait(futures);
    return results.any((live) => live);
  }

  Future<bool> _fetchListen(String lastfmUser) async {
    MusicStatus? status;
    try {
      status = await _apiService.fetchRecentTrack(lastfmUser);
    } catch (_) {
      return false;
    }
    if (status == null) return false;
    final key = _trackKey(status);
    if (key.isNotEmpty && _lastSyncedTrackKey[lastfmUser] == key) {
      return status.isPlaying;
    }
    _lastSyncedTrackKey[lastfmUser] = key;
    try {
      await _persistenceService.saveMusicStatus(status);
    } catch (e) {
      Logger.e('Jukebox: saveMusicStatus failed', error: e);
    }
    await _awardListenFor(status);
    return status.isPlaying;
  }

  Future<void> _awardListenFor(MusicStatus status) async {
    final award = _awardListenXp;
    if (award == null) return;
    final key = _trackKey(status);
    if (key.isEmpty || _lastAwardedTrackKey[status.username] == key) return;
    _lastAwardedTrackKey[status.username] = key;
    final uid = _uidForLastfmUser(status.username);
    if (uid == null || uid.isEmpty) return;
    try {
      await award(uid);
    } catch (e) {
      Logger.e('Jukebox: listen XP award failed', error: e);
    }
  }

  static String _trackKey(MusicStatus status) {
    final stamp = status.timestamp?.millisecondsSinceEpoch.toString() ??
        (status.isPlaying ? 'live' : '');
    return '${status.trackName}␟${status.artistName}␟$stamp';
  }

  /// Maps a Last.fm username back to the signed-in Firebase uid when the
  /// scrobble belongs to the current user. Partner scrobbles are skipped —
  /// XP is earned, never gifted across accounts from one device.
  String? _uidForLastfmUser(String lastfmUser) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    if (!_isOwnScrobble(lastfmUser)) return null;
    return uid;
  }

  bool _isOwnScrobble(String lastfmUser) {
    final auth = _authService;
    final me = auth?.currentUser?.toLowerCase();
    if (me == null || me.isEmpty) {
      // Fallback when AuthService isn't wired (tests): only award when the
      // device's own username matches the scrobble owner.
      return false;
    }
    final mine = me == 'khentsgdz' ? EnvConfig.lastfmUserKhent : me == 'clairjassen' ? EnvConfig.lastfmUserClair : '';
    if (mine.isEmpty) return false;
    return lastfmUser.toLowerCase() == mine.toLowerCase();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollingTimer?.cancel();
    _resubscribeTimer?.cancel();
    _firestoreSubscription?.cancel();
    _statusController.close();
    super.dispose();
  }
}
