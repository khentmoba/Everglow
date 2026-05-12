import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/garden_stats.dart';
import '../../data/services/garden_service.dart';

class GardenProvider extends ChangeNotifier {
  final GardenService _service = GardenService();
  GardenStats? _stats;
  String? _userId;
  StreamSubscription<GardenStats>? _subscription;

  GardenStats? get stats => _stats;

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

  Future<void> recordInteraction() async {
    if (_userId == null || _userId!.isEmpty) return;
    await _service.recordInteraction(_userId!);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
