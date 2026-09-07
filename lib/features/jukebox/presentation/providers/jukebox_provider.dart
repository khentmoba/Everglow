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
    Duration pollInterval = const Duration(seconds: 30),
    Duration resubscribeDelay = const Duration(seconds: 5),
  }) : _apiService = apiService ?? MusicSyncService(),
       _persistenceService =
           persistenceService ?? MusicPersistenceService(),
       _authService = authService,
       _awardListenXp = awardListenXp,
       _pollInterval = pollInterval,
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
  final Duration _resubscribeDelay;

  /// Last awarded track per Last.fm username, so the 30s poll doesn't
  /// re-award the same scrobble every tick.
  final Map<String, String> _lastAwardedTrackKey = {};

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
    // Poll every 30 seconds as per original spec requirements
    _fetchAndSync(khentUser, clairUser);
    _pollingTimer = Timer.periodic(_pollInterval, (timer) {
      _fetchAndSync(khentUser, clairUser);
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

  Future<void> _fetchAndSync(String khent, String clair) async {
    final futures = <Future<void>>[];
    if (khent.isNotEmpty) {
      futures.add(_fetchListen(khent));
    }
    if (clair.isNotEmpty) {
      futures.add(_fetchListen(clair));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  Future<void> _fetchListen(String lastfmUser) async {
    MusicStatus? status;
    try {
      status = await _apiService.fetchRecentTrack(lastfmUser);
    } catch (_) {
      return;
    }
    if (status == null) return;
    try {
      await _persistenceService.saveMusicStatus(status);
    } catch (_) {}
    await _awardListenFor(status);
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
    } catch (_) {}
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
