import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/config/env_config.dart';
import '../../data/models/music_status.dart';
import '../../data/services/music_sync_service.dart';
import '../../data/services/music_persistence_service.dart';

class JukeboxProvider extends ChangeNotifier {
  final MusicSyncService _apiService = MusicSyncService();
  final MusicPersistenceService _persistenceService = MusicPersistenceService();

  final _statusController =
      StreamController<Map<String, MusicStatus>>.broadcast();
  StreamSubscription? _firestoreSubscription;
  Timer? _pollingTimer;

  final Map<String, MusicStatus> _currentStatus = {};

  Stream<Map<String, MusicStatus>> get statusStream => _statusController.stream;

  JukeboxProvider() {
    _initProvider();
  }

  void _initProvider() {
    final khentUser = EnvConfig.lastfmUserKhent;
    final clairUser = EnvConfig.lastfmUserClair;

    // 1. Initial local state
    _currentStatus[khentUser] = MusicStatus.empty(khentUser);
    _currentStatus[clairUser] = MusicStatus.empty(clairUser);
    _statusController.add(Map.from(_currentStatus));

    // 2. Listen to Firestore for real-time updates (Global Consistency)
    _firestoreSubscription = _persistenceService
        .musicStatusStream([khentUser, clairUser])
        .listen((data) {
          if (data.isNotEmpty) {
            _currentStatus.addAll(data);
            if (!_statusController.isClosed) {
              _statusController.add(Map.from(_currentStatus));
            }
            notifyListeners();
          }
        });

    // 3. Start Polling Last.fm to keep Firestore updated
    // Poll every 30 seconds as per original spec requirements
    _fetchAndSync(khentUser, clairUser);
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchAndSync(khentUser, clairUser);
    });
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
    _pollingTimer?.cancel();
    _firestoreSubscription?.cancel();
    _statusController.close();
    super.dispose();
  }
}
