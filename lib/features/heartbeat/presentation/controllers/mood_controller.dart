import 'package:flutter/foundation.dart';
import '../../data/services/mood_service.dart';

class MoodController extends ChangeNotifier {
  final MoodSource _service;
  final Future<bool> Function(String uid)? _awardMoodXp;

  bool _isCheckingIn = false;
  int? _selectedScore;
  bool _hasSubmittedToday = false;

  MoodController(this._service, {Future<bool> Function(String uid)? awardMoodXp})
      : _awardMoodXp = awardMoodXp;

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
    String? uid,
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

    final award = _awardMoodXp;
    if (uid != null && uid.isNotEmpty && award != null) {
      try {
        await award(uid);
      } catch (_) {}
    }
  }
}
