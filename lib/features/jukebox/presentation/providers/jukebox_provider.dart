import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../data/models/music_status.dart';
import '../../data/services/music_sync_service.dart';
import '../../data/services/music_persistence_service.dart';

class JukeboxProvider extends ChangeNotifier {
  final MusicSyncService _apiService = MusicSyncService();
  final MusicPersistenceService _persistenceService = MusicPersistenceService();
  
  final _statusController = StreamController<Map<String, MusicStatus>>.broadcast();
  StreamSubscription? _firestoreSubscription;
  Timer? _pollingTimer;

  final Map<String, MusicStatus> _currentStatus = {};

  Stream<Map<String, MusicStatus>> get statusStream => _statusController.stream;

  JukeboxProvider() {
    _initProvider();
  }

  void _initProvider() {
    String khentUser = 'khentsgdz';
    String clairUser = 'clair';

    if (dotenv.isInitialized) {
      khentUser = dotenv.env['LASTFM_USER_KHENT'] ?? khentUser;
      clairUser = dotenv.env['LASTFM_USER_CLAIR'] ?? clairUser;
    }

    // 1. Initial local state (Khent only — Clair's card is hidden by design)
    _currentStatus[khentUser] = MusicStatus.empty(khentUser);
    _statusController.add(Map.from(_currentStatus));

    // 2. Listen to Firestore for real-time updates (Global Consistency)
    _firestoreSubscription = _persistenceService.musicStatusStream([khentUser]).listen((data) {
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
    _fetchAndSync(khentUser);
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchAndSync(khentUser);
    });
  }

  Future<void> _fetchAndSync(String khent) async {
    final khentStatus = await _apiService.fetchRecentTrack(khent);
    if (khentStatus != null) {
      await _persistenceService.saveMusicStatus(khentStatus);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _firestoreSubscription?.cancel();
    _statusController.close();
    super.dispose();
  }
}
