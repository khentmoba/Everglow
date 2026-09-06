import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/garden_stats.dart';
import '../../data/services/garden_service.dart';
import '../../../../core/utils/logger.dart';

class GardenProvider extends ChangeNotifier {
  final GardenStatsSource _service;
  GardenStats? _stats;
  GardenStats? _partnerStats;
  String? _userId;
  String? _partnerUid;
  StreamSubscription<GardenStats>? _subscription;
  StreamSubscription<GardenStats>? _partnerSubscription;

  /// Bounded re-subscribe loop for the own-garden stream. Without it, a
  /// single transient failure (permission-denied racing the /users doc sync,
  /// offline blip, or the withFirestoreTimeout silent close under WebChannel
  /// contention) left [_stats] null forever — the dashboard then rendered a
  /// giant empty DailyBloom with only a stage-0 pot and no chips.
  static const int _maxRetries = 5;
  Timer? _retryTimer;
  int _retryCount = 0;
  Object? _lastError;
  bool _disposed = false;

  GardenProvider({GardenStatsSource? service})
    : _service = service ?? GardenService();

  GardenStats? get stats => _stats;
  GardenStats? get partnerStats => _partnerStats;

  /// True when the own-garden stream failed and no stats have arrived yet.
  /// The UI uses this to offer a manual retry instead of a blank section.
  bool get hasError => _lastError != null && _stats == null;

  void updateUserId(String? userId) {
    if (_userId == userId) return;

    _cancelSubscription();
    _retryTimer?.cancel();
    _retryCount = 0;
    _lastError = null;
    _userId = userId;

    if (_userId != null && _userId!.isNotEmpty) {
      _subscribe();
    } else {
      _stats = null;
      notifyListeners();
    }
  }

  void _subscribe() {
    final uid = _userId;
    if (uid == null || uid.isEmpty || _disposed) return;
    _cancelSubscription();
    _subscription = _service.watchStats(uid).listen(
      (newStats) {
        _stats = newStats;
        _lastError = null;
        _retryCount = 0;
        _retryTimer?.cancel();
        if (!_disposed) notifyListeners();
      },
      onError: (Object error) {
        Logger.e('Garden stats stream failed', error: error);
        _scheduleRetry(error);
      },
      onDone: () {
        // withFirestoreTimeout closes silently when the first snapshot never
        // arrives; treat a data-less close as a failure worth retrying.
        if (_stats == null) {
          Logger.e('Garden stats stream closed before first snapshot');
          _scheduleRetry(StateError('garden-stats closed without data'));
        }
      },
    );
  }

  void _scheduleRetry(Object error) {
    _cancelSubscription();
    _lastError = error;
    if (_retryCount >= _maxRetries) {
      Logger.e('Garden stats retries exhausted ($_maxRetries)');
      if (!_disposed) notifyListeners();
      return;
    }
    _retryCount++;
    if (!_disposed) notifyListeners();
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
      if (_disposed || _userId == null || _userId!.isEmpty) return;
      _subscribe();
    });
  }

  /// Manual retry from the error UI. Resets the backoff budget.
  void retry() {
    if (_userId == null || _userId!.isEmpty || _disposed) return;
    _retryTimer?.cancel();
    _retryCount = 0;
    _subscribe();
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Start watching partner's garden stats for the shared view.
  void watchPartner(String? partnerUid) {
    if (_partnerUid == partnerUid) return;

    _partnerSubscription?.cancel();
    _partnerSubscription = null;
    _partnerUid = partnerUid;

    if (_partnerUid != null && _partnerUid!.isNotEmpty) {
      _partnerSubscription = _service.watchPartnerStats(_partnerUid!).listen((
        newStats,
      ) {
        _partnerStats = newStats;
        if (!_disposed) notifyListeners();
      }, onError: (Object error) {
        // Keep the last known partner stats; a transient partner failure
        // must not surface as an unhandled async error.
        Logger.e('Partner garden stats stream failed', error: error);
      });
    } else {
      _partnerStats = null;
      notifyListeners();
    }
  }

  /// Stop watching partner stats (when leaving shared view).
  void stopWatchingPartner() {
    _partnerSubscription?.cancel();
    _partnerSubscription = null;
    _partnerUid = null;
    _partnerStats = null;
    notifyListeners();
  }

  /// Never throws: callers fire-and-forget this from UI callbacks, so a
  /// Firestore failure must log, not crash the zone.
  Future<void> recordInteraction() async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      await _service.recordInteraction(_userId!);
    } catch (e) {
      Logger.e('Garden recordInteraction failed', error: e);
    }
  }

  /// Change the user's plant type.
  Future<void> setPlantType(String plantType) async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      await _service.setPlantType(_userId!, plantType);
    } catch (e) {
      Logger.e('Garden setPlantType failed', error: e);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _partnerSubscription?.cancel();
    super.dispose();
  }
}
