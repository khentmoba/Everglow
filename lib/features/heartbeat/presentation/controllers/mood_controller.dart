import 'package:flutter/material.dart';
import '../../data/services/mood_service.dart';

class MoodController extends ChangeNotifier {
  final MoodService _service;

  bool _isCheckingIn = false;
  int? _selectedScore;
  bool _hasSubmittedToday = false;

  MoodController(this._service);

  bool get isCheckingIn => _isCheckingIn;
  int? get selectedScore => _selectedScore;
  bool get hasSubmittedToday => _hasSubmittedToday;

  void startCheckIn() {
    _isCheckingIn = true;
    _selectedScore = null;
    notifyListeners();
  }

  void cancelCheckIn() {
    _isCheckingIn = false;
    notifyListeners();
  }

  Future<void> checkTodayStatus(String username) async {
    _hasSubmittedToday = await _service.hasSubmittedToday(username);
    notifyListeners();
  }

  Future<void> submitMood({
    required String username,
    required int score,
    required String emoji,
  }) async {
    _selectedScore = score;
    notifyListeners();

    try {
      await _service.submitMood(username: username, score: score, emoji: emoji);
    } catch (e) {
      // If it fails, revert the selection so user can try again
      _selectedScore = null;
      notifyListeners();
      return;
    }

    _hasSubmittedToday = true;
    _isCheckingIn = false;
    notifyListeners();
  }
}
