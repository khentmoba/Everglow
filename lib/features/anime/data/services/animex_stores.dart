import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/animex_models.dart';

/// Local persistence for the anime section: watch history, custom
/// playlists and small preferences (title language, schedule alerts).
///
/// Privacy: every key is scoped to the signed-in profile
/// (`<base>_<username>`) so one profile's watches never leak into another
/// profile on the same PWA/device. Before this, the keys were global and
/// Khent's history showed up when Octagram logged in on the same phone.
/// Legacy global keys are migrated once into the first couple profile
/// (khent/clair) that loads them; cinema-only profiles never read legacy.
class AnimexStores extends ChangeNotifier {
  AnimexStores._internal();

  static final AnimexStores instance = AnimexStores._internal();

  static const _historyKeyBase = 'animex_watch_history_v1';
  static const _playlistsKeyBase = 'animex_playlists_v1';
  static const _prefsKeyBase = 'animex_prefs_v1';

  List<AnimexHistoryEntry> _history = [];
  List<AnimexPlaylist> _playlists = [];
  bool _titleJapanese = false;
  final Map<String, bool> _scheduleAlerts = {};
  bool _loaded = false;
  String _currentUser = '';

  List<AnimexHistoryEntry> get history => List.unmodifiable(_history);
  List<AnimexPlaylist> get playlists => List.unmodifiable(_playlists);
  bool get titleJapanese => _titleJapanese;

  /// Username this store is currently loaded for ('' when logged out).
  String get currentUser => _currentUser;

  static String _keyFor(String base, String user) =>
      user.isEmpty ? base : '${base}_$user';

  static bool _isCoupleUser(String user) =>
      user == 'khentsgdz' || user == 'clairjassen';

  /// Loads this profile's store. Call with the signed-in username; call
  /// with null/empty on logout. Switching users clears the previous
  /// profile's data from memory immediately so the UI never flashes it.
  Future<void> load({String? username}) async {
    final user = username ?? '';
    if (_loaded && user == _currentUser) return;

    // Switch: drop the previous profile's data first.
    _currentUser = user;
    _history = [];
    _playlists = [];
    _titleJapanese = false;
    _scheduleAlerts.clear();
    _loaded = false;
    notifyListeners();

    // Logged out: stay empty and never touch shared keys.
    if (user.isEmpty) {
      _loaded = true;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _readInto(
        historyRaw: prefs.getString(_keyFor(_historyKeyBase, user)),
        playlistsRaw: prefs.getString(_keyFor(_playlistsKeyBase, user)),
        prefsRaw: prefs.getString(_keyFor(_prefsKeyBase, user)),
      );

      // One-time migration of the old global (unscoped) keys. Only couple
      // profiles inherit legacy data, and only when their own store is
      // empty — cinema-only profiles never see another profile's past.
      if (_history.isEmpty &&
          _playlists.isEmpty &&
          _isCoupleUser(user)) {
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
          await prefs.remove(_historyKeyBase);
          await prefs.remove(_playlistsKeyBase);
          await prefs.remove(_prefsKeyBase);
        }
      }

      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AnimexStores] load failed: $e');
    }
  }

  /// Convenience for auth changes: `switchUser(auth.currentUser)`.
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
      final alerts = data['scheduleAlerts'] as Map<String, dynamic>?;
      if (alerts != null) {
        alerts.forEach((k, v) => _scheduleAlerts[k] = v == true);
      }
    }
  }

  Future<void> _persist() async {
    // Never write when logged out: there is no profile to own the data.
    if (_currentUser.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFor(_historyKeyBase, _currentUser),
      json.encode(_history.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _keyFor(_playlistsKeyBase, _currentUser),
      json.encode(_playlists.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _keyFor(_prefsKeyBase, _currentUser),
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

  /// Test-only reset so the singleton never leaks state between tests.
  @visibleForTesting
  void resetForTest() {
    _history = [];
    _playlists = [];
    _titleJapanese = false;
    _scheduleAlerts.clear();
    _loaded = false;
    _currentUser = '';
  }
}
