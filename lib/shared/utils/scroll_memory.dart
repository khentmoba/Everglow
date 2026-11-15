import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScrollMemory {
  ScrollMemory._();

  static const _prefix = 'scroll:';
  static final Map<String, double> _offsets = {};
  static bool _preloaded = false;

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

  static double initialOffset(String key) => _offsets[key] ?? 0;

  @visibleForTesting
  static void debugReset() {
    _offsets.clear();
    _preloaded = false;
  }
}

class RememberedScrollController extends ScrollController {
  RememberedScrollController(this.memoryKey)
    : super(initialScrollOffset: ScrollMemory.initialOffset(memoryKey)) {
    addListener(_scheduleSave);
  }

  final String memoryKey;

  @visibleForTesting
  static Duration saveDelay = const Duration(milliseconds: 500);

  Timer? _saveTimer;
  bool _scrollDirty = false;

  String get _storageKey => 'scroll:$memoryKey';

  void _scheduleSave() {
    if (_saveTimer?.isActive ?? false) {
      _scrollDirty = true;
      return;
    }
    _scrollDirty = false;
    _armSaveTimer(saveDelay);
  }

  void _armSaveTimer(Duration delay) {
    _saveTimer = Timer(delay, () {
      if (_scrollDirty) {
        _scrollDirty = false;
        final stepMs = max(16, saveDelay.inMilliseconds ~/ 5);
        _armSaveTimer(Duration(milliseconds: stepMs));
        return;
      }
      _persist();
    });
  }

  Future<void> _persist() async {
    if (!hasClients) return;
    final offset = max(0.0, position.pixels);
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
    if (_saveTimer?.isActive ?? false) {
      _saveTimer?.cancel();
      unawaited(_persist());
    }
    super.dispose();
  }
}
