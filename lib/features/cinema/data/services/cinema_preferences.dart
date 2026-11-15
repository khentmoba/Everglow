import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/logger.dart';

class CinemaPreferences extends ChangeNotifier {
  static final instance = CinemaPreferences();

  String _user = '';
  int _generation = 0;
  int _writeRevision = 0;
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();
  bool _hideSpoilers = true;
  bool _autoplayNext = false;

  String get currentUser => _user;
  bool get hideSpoilers => _hideSpoilers;
  bool get autoplayNext => _autoplayNext;

  Future<void> setUser(String? name) {
    final user = name ?? '';
    if (user == _user) return _loading ?? Future<void>.value();
    final generation = ++_generation;
    _user = user;
    _hideSpoilers = true;
    _autoplayNext = false;
    _loading = user.isEmpty ? null : _load(user, generation);
    notifyListeners();
    return _loading ?? Future<void>.value();
  }

  Future<void> _load(String user, int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation) return;
      final raw = prefs.getString('cinema_preferences_v1/$user');
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          _hideSpoilers = data['hideSpoilers'] != false;
          _autoplayNext = data['autoplayNext'] == true;
        }
      }
      notifyListeners();
    } catch (e, st) {
      Logger.e('Cinema preferences: load failed', error: e, stackTrace: st);
    }
  }

  Future<void> setHideSpoilers(bool value) => _set(hideSpoilers: value);
  Future<void> setAutoplayNext(bool value) => _set(autoplayNext: value);

  Future<void> _set({bool? hideSpoilers, bool? autoplayNext}) async {
    final user = _user;
    final generation = _generation;
    await _loading;
    if (generation != _generation || user.isEmpty) return;
    _hideSpoilers = hideSpoilers ?? _hideSpoilers;
    _autoplayNext = autoplayNext ?? _autoplayNext;
    final revision = ++_writeRevision;
    final value = jsonEncode({
      'hideSpoilers': _hideSpoilers,
      'autoplayNext': _autoplayNext,
    });
    notifyListeners();
    _writes = _writes.then((_) async {
      if (generation != _generation || revision != _writeRevision) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (generation != _generation || revision != _writeRevision) return;
        await prefs.setString('cinema_preferences_v1/$user', value);
      } catch (e, st) {
        Logger.e('Cinema preferences: save failed', error: e, stackTrace: st);
      }
    });
    await _writes;
  }
}
