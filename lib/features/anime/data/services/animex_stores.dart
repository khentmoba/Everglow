import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/animex_models.dart';

/// Local persistence for the anime section: watch history, custom
/// playlists and small preferences (title language, schedule alerts).
/// All values live in SharedPreferences so the data survives reloads.
class AnimexStores extends ChangeNotifier {
  AnimexStores._internal();

  static final AnimexStores instance = AnimexStores._internal();

  static const _historyKey = 'animex_watch_history_v1';
  static const _playlistsKey = 'animex_playlists_v1';
  static const _prefsKey = 'animex_prefs_v1';

  List<AnimexHistoryEntry> _history = [];
  List<AnimexPlaylist> _playlists = [];
  bool _titleJapanese = false;
  final Map<String, bool> _scheduleAlerts = {};
  bool _loaded = false;

  List<AnimexHistoryEntry> get history => List.unmodifiable(_history);
  List<AnimexPlaylist> get playlists => List.unmodifiable(_playlists);
  bool get titleJapanese => _titleJapanese;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyRaw = prefs.getString(_historyKey);
      if (historyRaw != null && historyRaw.isNotEmpty) {
        _history =
            (json.decode(historyRaw) as List)
                .whereType<Map<String, dynamic>>()
                .map(AnimexHistoryEntry.fromJson)
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
      final playlistsRaw = prefs.getString(_playlistsKey);
      if (playlistsRaw != null && playlistsRaw.isNotEmpty) {
        _playlists = (json.decode(playlistsRaw) as List)
            .whereType<Map<String, dynamic>>()
            .map(AnimexPlaylist.fromJson)
            .toList();
      }
      final prefsRaw = prefs.getString(_prefsKey);
      if (prefsRaw != null && prefsRaw.isNotEmpty) {
        final data = json.decode(prefsRaw) as Map<String, dynamic>;
        _titleJapanese = data['titleJapanese'] == true;
        final alerts = data['scheduleAlerts'] as Map<String, dynamic>?;
        if (alerts != null) {
          alerts.forEach((k, v) => _scheduleAlerts[k] = v == true);
        }
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AnimexStores] load failed: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      json.encode(_history.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _playlistsKey,
      json.encode(_playlists.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _prefsKey,
      json.encode({
        'titleJapanese': _titleJapanese,
        'scheduleAlerts': _scheduleAlerts,
      }),
    );
  }

  // ── Watch history ────────────────────────────────────────────────

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
    int durationSeconds = 0,
    int episodeMinutes = 24,
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
        durationSeconds: durationSeconds,
        episodeMinutes: episodeMinutes,
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

  // ── Playlists ───────────────────────────────────────────────────

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
    final exists = current.items.any((i) => i.anilistId == item.anilistId);
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

  // ── Preferences ─────────────────────────────────────────────────

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
}
