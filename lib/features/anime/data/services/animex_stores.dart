import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/animex_models.dart';

class AnimexStores extends ChangeNotifier {
  AnimexStores._internal();

  static final AnimexStores instance = AnimexStores._internal();

  static const _historyKeyBase = 'animex_watch_history_v1';
  static const _playlistsKeyBase = 'animex_playlists_v1';
  static const _prefsKeyBase = 'animex_prefs_v1';

  List<AnimexHistoryEntry> _history = [];
  List<AnimexPlaylist> _playlists = [];
  bool _titleJapanese = false;
  bool _hideSpoilers = true;
  bool _autoNext = true;
  bool _skipIntro = true;
  final Map<String, bool> _scheduleAlerts = {};
  bool _loaded = false;
  int _loadGeneration = 0;
  String _currentUser = '';

  List<AnimexHistoryEntry> get history => List.unmodifiable(_history);
  List<AnimexPlaylist> get playlists => List.unmodifiable(_playlists);
  bool get titleJapanese => _titleJapanese;
  bool get hideSpoilers => _hideSpoilers;

  bool get autoNext => _autoNext;

  bool get skipIntro => _skipIntro;

  String get currentUser => _currentUser;

  static String _keyFor(String base, String user) =>
      user.isEmpty ? base : '${base}_$user';

  static bool _isCoupleUser(String user) =>
      user == 'khentsgdz' || user == 'clairjassen';

  Future<void> load({String? username}) async {
    final user = username ?? '';
    if (_loaded && user == _currentUser) return;
    final generation = ++_loadGeneration;

    _currentUser = user;
    _history = [];
    _playlists = [];
    _titleJapanese = false;
    _hideSpoilers = true;
    _autoNext = true;
    _skipIntro = true;
    _scheduleAlerts.clear();
    _loaded = false;
    notifyListeners();
    if (generation != _loadGeneration) return;

    if (user.isEmpty) {
      _loaded = true;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _loadGeneration) return;
      _readInto(
        historyRaw: prefs.getString(_keyFor(_historyKeyBase, user)),
        playlistsRaw: prefs.getString(_keyFor(_playlistsKeyBase, user)),
        prefsRaw: prefs.getString(_keyFor(_prefsKeyBase, user)),
      );

      if (_history.isEmpty && _playlists.isEmpty && _isCoupleUser(user)) {
        final legacyHistory = prefs.getString(_historyKeyBase);
        final legacyPlaylists = prefs.getString(_playlistsKeyBase);
        final legacyPrefs = prefs.getString(_prefsKeyBase);
        if ((legacyHistory != null && legacyHistory.isNotEmpty) ||
            (legacyPlaylists != null && legacyPlaylists.isNotEmpty)) {
          _readInto(
            historyRaw: legacyHistory,
            playlistsRaw: legacyPlaylists,
            prefsRaw: legacyPrefs,
          );
          await _persist();
          for (final key in [
            _historyKeyBase,
            _playlistsKeyBase,
            _prefsKeyBase,
          ]) {
            if (generation != _loadGeneration) return;
            await prefs.remove(key);
          }
        }
      }

      if (generation != _loadGeneration) return;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AnimexStores] load failed: $e');
    }
  }

  Future<void> switchUser(String? username) => load(username: username);

  void _readInto({
    required String? historyRaw,
    required String? playlistsRaw,
    required String? prefsRaw,
  }) {
    if (historyRaw != null && historyRaw.isNotEmpty) {
      _history =
          (json.decode(historyRaw) as List)
              .whereType<Map<String, dynamic>>()
              .map(AnimexHistoryEntry.fromJson)
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    if (playlistsRaw != null && playlistsRaw.isNotEmpty) {
      _playlists = (json.decode(playlistsRaw) as List)
          .whereType<Map<String, dynamic>>()
          .map(AnimexPlaylist.fromJson)
          .toList();
    }
    if (prefsRaw != null && prefsRaw.isNotEmpty) {
      final data = json.decode(prefsRaw) as Map<String, dynamic>;
      _titleJapanese = data['titleJapanese'] == true;
      _hideSpoilers = data['hideSpoilers'] != false;
      _autoNext = data['autoNext'] != false;
      _skipIntro = data['skipIntro'] != false;
      final alerts = data['scheduleAlerts'] as Map<String, dynamic>?;
      if (alerts != null) {
        alerts.forEach((k, v) => _scheduleAlerts[k] = v == true);
      }
    }
  }

  Future<void> _persist() async {
    final user = _currentUser;
    final generation = _loadGeneration;
    if (user.isEmpty) return;
    final values = {
      _keyFor(_historyKeyBase, user): json.encode(
        _history.map((e) => e.toJson()).toList(),
      ),
      _keyFor(_playlistsKeyBase, user): json.encode(
        _playlists.map((e) => e.toJson()).toList(),
      ),
      _keyFor(_prefsKeyBase, user): json.encode({
        'titleJapanese': _titleJapanese,
        'hideSpoilers': _hideSpoilers,
        'autoNext': _autoNext,
        'skipIntro': _skipIntro,
        'scheduleAlerts': _scheduleAlerts,
      }),
    };
    final prefs = await SharedPreferences.getInstance();
    for (final entry in values.entries) {
      if (generation != _loadGeneration) return;
      await prefs.setString(entry.key, entry.value);
    }
  }

  AnimexHistoryEntry? findHistory(String key) {
    for (final e in _history) {
      if (e.key == key) return e;
    }
    return null;
  }

  Future<void> recordWatch({
    required String key,
    int? anilistId,
    required int malId,
    required String title,
    required String coverUrl,
    required int episode,
    int totalEpisodes = 0,
  }) async {
    _history.removeWhere((e) => e.key == key);
    _history.insert(
      0,
      AnimexHistoryEntry(
        key: key,
        anilistId: anilistId,
        malId: malId,
        title: title,
        coverUrl: coverUrl,
        episode: episode,
        totalEpisodes: totalEpisodes,
        updatedAt: DateTime.now(),
      ),
    );
    if (_history.length > 60) _history.removeRange(60, _history.length);
    notifyListeners();
    await _persist();
  }

  Future<void> clearHistory() async {
    _history = [];
    notifyListeners();
    await _persist();
  }

  Future<void> removeHistoryEntry(String key) async {
    _history.removeWhere((e) => e.key == key);
    notifyListeners();
    await _persist();
  }

  AnimexPlaylist? playlistById(String id) {
    for (final p in _playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool isInAnyPlaylist(int anilistId) {
    for (final p in _playlists) {
      for (final i in p.items) {
        if (i.anilistId == anilistId) return true;
      }
    }
    return false;
  }

  Future<AnimexPlaylist> createPlaylist({
    required String name,
    required String emoji,
  }) async {
    final playlist = AnimexPlaylist(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: emoji,
      createdAt: DateTime.now(),
    );
    _playlists.insert(0, playlist);
    notifyListeners();
    await _persist();
    return playlist;
  }

  Future<void> updatePlaylist(String id, {String? name, String? emoji}) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index < 0) return;
    _playlists[index] = _playlists[index].copyWith(name: name, emoji: emoji);
    notifyListeners();
    await _persist();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> addToPlaylist(String id, AnimexPlaylistItem item) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final current = _playlists[index];
    final exists = current.items.any((i) => i.key == item.key);
    if (exists) return;
    _playlists[index] = current.copyWith(items: [...current.items, item]);
    notifyListeners();
    await _persist();
  }

  Future<void> removeFromPlaylist(String id, int anilistId) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final current = _playlists[index];
    _playlists[index] = current.copyWith(
      items: current.items.where((i) => i.anilistId != anilistId).toList(),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> removePlaylistEntry(String id, AnimexPlaylistItem item) async {
    final index = _playlists.indexWhere((playlist) => playlist.id == id);
    if (index < 0) return;
    final current = _playlists[index];
    _playlists[index] = current.copyWith(
      items: current.items.where((entry) => entry.key != item.key).toList(),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> setHideSpoilers(bool value) async {
    if (_hideSpoilers == value) return;
    _hideSpoilers = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setAutoNext(bool value) async {
    if (_autoNext == value) return;
    _autoNext = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setSkipIntro(bool value) async {
    if (_skipIntro == value) return;
    _skipIntro = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setTitleJapanese(bool value) async {
    _titleJapanese = value;
    notifyListeners();
    await _persist();
  }

  bool isAlertEnabled(String key) => _scheduleAlerts[key] ?? false;

  Future<void> toggleAlert(String key) async {
    _scheduleAlerts[key] = !(_scheduleAlerts[key] ?? false);
    notifyListeners();
    await _persist();
  }

  @visibleForTesting
  void resetForTest() {
    _loadGeneration++;
    _history = [];
    _playlists = [];
    _titleJapanese = false;
    _hideSpoilers = true;
    _autoNext = true;
    _skipIntro = true;
    _scheduleAlerts.clear();
    _loaded = false;
    _currentUser = '';
  }
}
