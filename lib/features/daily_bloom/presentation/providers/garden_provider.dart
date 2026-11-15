import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/garden_stats.dart';
import '../../data/services/garden_service.dart';
import '../../../xp/data/services/xp_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/optimistic_action.dart';

class GardenProvider extends ChangeNotifier {
  final GardenStatsSource _service;
  GardenStats? _stats;
  GardenStats? _partnerStats;
  String? _userId;
  String? _partnerUid;
  StreamSubscription<GardenStats>? _subscription;
  StreamSubscription<GardenStats>? _partnerSubscription;

  static const int _maxRetries = 5;
  Timer? _retryTimer;
  int _retryCount = 0;
  Timer? _partnerRetryTimer;
  int _partnerRetryCount = 0;
  Object? _lastError;
  Object? _lastPartnerError;
  bool _disposed = false;

  bool _exhausted = false;

  GardenProvider({GardenStatsSource? service})
    : _service = service ?? GardenService();

  GardenStats? get stats => _stats;
  GardenStats? get partnerStats => _partnerStats;
  String? get partnerUid => _partnerUid;

  bool get hasError => _lastError != null && _stats == null;

  bool get hasSettledError => _exhausted && _stats == null;

  bool get hasPartnerError =>
      _lastPartnerError != null && _partnerStats == null;

  void updateUserId(String? userId) {
    if (_userId == userId) return;

    _cancelSubscription();
    _retryTimer?.cancel();
    _retryCount = 0;
    _lastError = null;
    _exhausted = false;
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
    _subscription = _service
        .watchStats(uid)
        .listen(
          (newStats) {
            _stats = newStats;
            _lastError = null;
            _exhausted = false;
            _retryCount = 0;
            _retryTimer?.cancel();
            if (!_disposed) notifyListeners();
          },
          onError: (Object error) {
            Logger.e('Garden stats stream failed', error: error);
            _scheduleRetry(error);
          },
          onDone: () {
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
      _exhausted = true;
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

  void retry() {
    if (_userId == null || _userId!.isEmpty || _disposed) return;
    _retryTimer?.cancel();
    _retryCount = 0;
    _exhausted = false;
    _subscribe();
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  void watchPartner(String? partnerUid) {
    if (_partnerUid == partnerUid && _partnerSubscription != null) return;

    _partnerRetryTimer?.cancel();
    _partnerRetryCount = 0;
    _lastPartnerError = null;
    _partnerSubscription?.cancel();
    _partnerSubscription = null;
    _partnerUid = partnerUid;

    if (_partnerUid != null && _partnerUid!.isNotEmpty) {
      _subscribePartner();
    } else {
      _partnerStats = null;
      notifyListeners();
    }
  }

  void _subscribePartner() {
    final uid = _partnerUid;
    if (uid == null || uid.isEmpty || _disposed) return;
    _partnerSubscription?.cancel();
    _partnerSubscription = _service
        .watchPartnerStats(uid)
        .listen(
          (newStats) {
            _partnerStats = newStats;
            _lastPartnerError = null;
            _partnerRetryCount = 0;
            _partnerRetryTimer?.cancel();
            if (!_disposed) notifyListeners();
          },
          onError: (Object error) {
            Logger.e('Partner garden stats stream failed', error: error);
            _schedulePartnerRetry(error);
          },
          onDone: () {
            if (_partnerStats == null) {
              Logger.e(
                'Partner garden stats stream closed before first snapshot',
              );
              _schedulePartnerRetry(
                StateError('garden-partner-stats closed without data'),
              );
            }
          },
        );
  }

  void _schedulePartnerRetry(Object error) {
    _partnerSubscription?.cancel();
    _lastPartnerError = error;
    if (_partnerRetryCount >= _maxRetries) {
      Logger.e('Partner garden stats retries exhausted ($_maxRetries)');
      if (!_disposed) notifyListeners();
      return;
    }
    _partnerRetryCount++;
    if (!_disposed) notifyListeners();
    _partnerRetryTimer?.cancel();
    _partnerRetryTimer = Timer(Duration(seconds: 1 + _partnerRetryCount), () {
      if (_disposed || _partnerUid == null || _partnerUid!.isEmpty) return;
      _subscribePartner();
    });
  }

  void retryPartner() {
    if (_partnerUid == null || _partnerUid!.isEmpty || _disposed) return;
    _partnerRetryTimer?.cancel();
    _partnerRetryCount = 0;
    _lastPartnerError = null;
    _subscribePartner();
  }

  void stopWatchingPartner() {
    _partnerRetryTimer?.cancel();
    _partnerRetryCount = 0;
    _lastPartnerError = null;
    _partnerSubscription?.cancel();
    _partnerSubscription = null;
    _partnerUid = null;
    _partnerStats = null;
    notifyListeners();
  }

  Future<void> recordInteraction() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;

    final previousStats = _stats;
    await OptimisticAction.run(
      apply: () {
        if (_stats != null) {
          final newInteractions = _stats!.totalInteractions + 1;
          _stats = _stats!.copyWith(
            totalInteractions: newInteractions,
            currentStage: GardenStats.calculateStage(newInteractions),
            lastVisit: DateTime.now(),
          );
          if (!_disposed) notifyListeners();
        }
      },
      action: () async {
        await _service.recordInteraction(uid);
        try {
          await XPService().awardGarden(uid);
        } catch (e) {
          Logger.e('Garden: XP award failed', error: e);
        }
      },
      rollback: () {
        _stats = previousStats;
        if (!_disposed) notifyListeners();
      },
    );
  }

  Future<void> setPlantType(String plantType) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;

    final previousStats = _stats;
    await OptimisticAction.run(
      apply: () {
        if (_stats != null) {
          _stats = _stats!.copyWith(plantType: plantType);
          if (!_disposed) notifyListeners();
        }
      },
      action: () => _service.setPlantType(uid, plantType),
      rollback: () {
        _stats = previousStats;
        if (!_disposed) notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _partnerRetryTimer?.cancel();
    _subscription?.cancel();
    _partnerSubscription?.cancel();
    super.dispose();
  }
}
