import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftTextController extends TextEditingController {
  DraftTextController(this.draftKey, {super.text});

  final String draftKey;

  static const maxDraftChars = 20000;

  @visibleForTesting
  static Duration saveDelay = const Duration(milliseconds: 500);

  Timer? _saveTimer;
  bool _loaded = false;

  String get _storageKey => 'draft:$draftKey';

  Future<void> loadDraft() async {
    if (_loaded) return;
    _loaded = true;
    if (text.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_storageKey);
        if (saved != null && saved.isNotEmpty && text.isEmpty) {
          text = saved;
        }
      } catch (_) {
        // No saved words (or unreadable storage): just start empty.
      }
    }
    addListener(_scheduleSave);
  }

  Future<void> clearDraft() async {
    _saveTimer?.cancel();
    clear();
    await forgetDraft(draftKey);
  }

  static Future<void> forgetDraft(String draftKey, {String? onlyIf}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'draft:$draftKey';
      if (onlyIf != null && (prefs.getString(key) ?? '') != onlyIf) return;
      await prefs.remove(key);
    } catch (_) {
      // Words were already sent or saved; a stale draft is harmless.
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, _persist);
  }

  Future<void> _persist() async {
    final words = text.length > maxDraftChars
        ? text.substring(0, maxDraftChars)
        : text;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (words.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, words);
      }
    } catch (_) {
      // A missed write only costs one restore; never interrupt typing.
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
