import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/music_status.dart';
import '../../data/services/music_sync_service.dart';
import '../../data/services/music_persistence_service.dart';

class JukeboxProvider extends ChangeNotifier {
  JukeboxProvider({
    MusicSyncService? apiService,
    MusicPersistenceService? persistenceService,
    Duration pollInterval = const Duration(seconds: 30),
    Duration resubscribeDelay = const Duration(seconds: 5),
  }) : _apiService = apiService ?? MusicSyncService(),
       _persistenceService =
           persistenceService ?? MusicPersistenceService(),
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
  final Duration _pollInterval;
  final Duration _resubscribeDelay;

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
      futures.add(_apiService.fetchRecentTrack(khent).then((s) {
        if (s != null) return _persistenceService.saveMusicStatus(s);
      }));
    }
    if (clair.isNotEmpty) {
      futures.add(_apiService.fetchRecentTrack(clair).then((s) {
        if (s != null) return _persistenceService.saveMusicStatus(s);
      }));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
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
