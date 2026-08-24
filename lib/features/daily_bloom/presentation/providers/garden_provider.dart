import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/garden_stats.dart';
import '../../data/services/garden_service.dart';

class GardenProvider extends ChangeNotifier {
  final GardenService _service = GardenService();
  GardenStats? _stats;
  GardenStats? _partnerStats;
  String? _userId;
  String? _partnerUid;
  StreamSubscription<GardenStats>? _subscription;
  StreamSubscription<GardenStats>? _partnerSubscription;

  GardenStats? get stats => _stats;
  GardenStats? get partnerStats => _partnerStats;

  void updateUserId(String? userId) {
    if (_userId == userId) return;

    _subscription?.cancel();
    _userId = userId;

    if (_userId != null && _userId!.isNotEmpty) {
      _subscription = _service.watchStats(_userId!).listen((newStats) {
        _stats = newStats;
        notifyListeners();
      });
    } else {
      _stats = null;
      notifyListeners();
    }
  }

  /// Start watching partner's garden stats for the shared view.
  void watchPartner(String? partnerUid) {
    if (_partnerUid == partnerUid) return;

    _partnerSubscription?.cancel();
    _partnerUid = partnerUid;

    if (_partnerUid != null && _partnerUid!.isNotEmpty) {
      _partnerSubscription = _service.watchPartnerStats(_partnerUid!).listen((
        newStats,
      ) {
        _partnerStats = newStats;
        notifyListeners();
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

  Future<void> recordInteraction() async {
    if (_userId == null || _userId!.isEmpty) return;
    await _service.recordInteraction(_userId!);
  }

  /// Change the user's plant type.
  Future<void> setPlantType(String plantType) async {
    if (_userId == null || _userId!.isEmpty) return;
    await _service.setPlantType(_userId!, plantType);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _partnerSubscription?.cancel();
    super.dispose();
  }
}
