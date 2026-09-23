import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers how far down long lists were scrolled, so journal and
/// library pages reopen at the same spot after a killed tab or PWA.
///
/// Why manual instead of Flutter's `restorationId`: the framework's
/// restoration bucket does not survive a web reload (verified in-browser:
/// the list always came back at the top), and its PWA behavior is just
/// as uncertain. A saved number in device storage works the same
/// everywhere with no engine interplay.
///
/// Flow: `main.dart` awaits [ScrollMemory.preload] before `runApp`, then
/// each long list owns a [RememberedScrollController], which starts at
/// the saved offset and keeps saving it as she scrolls.
class ScrollMemory {
  ScrollMemory._();

  static const _prefix = 'scroll:';
  static final Map<String, double> _offsets = {};
  static bool _preloaded = false;

  /// Loads every saved scroll spot into memory. Runs once, before
  /// `runApp`, so controllers can start at the right offset on their
  /// very first frame. Never throws — a failure just starts lists
  /// at the top.
  static Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_prefix)) continue;
        final offset = prefs.getDouble(key);
        if (offset != null && offset > 0) {
          _offsets[key.substring(_prefix.length)] = offset;
        }
      }
    } catch (_) {
      // No saved spots: every list simply starts at the top.
    }
  }

  /// Saved offset for [key], or 0 when nothing was saved.
  static double initialOffset(String key) => _offsets[key] ?? 0;

  /// Tests only.
  @visibleForTesting
  static void debugReset() {
    _offsets.clear();
    _preloaded = false;
  }
}

/// A scroll controller that reopens at its last offset and keeps saving
/// it as she scrolls. Own one per long list, dispose with the screen:
///
/// ```dart
/// final _scroll = RememberedScrollController('journal:entries');
///
/// ListView(controller: _scroll, ...)
///
/// @override
/// void dispose() {
///   _scroll.dispose();
///   super.dispose();
/// }
/// ```
class RememberedScrollController extends ScrollController {
  RememberedScrollController(this.memoryKey)
    : super(initialScrollOffset: ScrollMemory.initialOffset(memoryKey)) {
    addListener(_scheduleSave);
  }

  /// Unique slot on the device, e.g. `'journal:entries'`.
  final String memoryKey;

  /// Pause after the last scroll tick before the spot is written.
  @visibleForTesting
  static Duration saveDelay = const Duration(milliseconds: 500);

  Timer? _saveTimer;

  String get _storageKey => 'scroll:$memoryKey';

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, _persist);
  }

  Future<void> _persist() async {
    if (!hasClients) return;
    final offset = max(0.0, position.pixels);
    // Keep the in-memory copy fresh too: screens rebuilt later in the
    // same boot (leaving and returning to a page) start here, not at
    // the boot-time value.
    ScrollMemory._offsets[memoryKey] = offset;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (offset <= 0) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setDouble(_storageKey, offset);
      }
    } catch (_) {
      // A missed write only costs one restore; never interrupt scrolling.
    }
  }

  @override
  void dispose() {
    // Best-effort final write: leaving the page still keeps the spot.
    if (_saveTimer?.isActive ?? false) {
      _saveTimer?.cancel();
      unawaited(_persist());
    }
    super.dispose();
  }
}
