import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A text field that quietly keeps its words on the device.
///
/// Used for half-typed thoughts that must survive a killed tab or PWA:
/// chat messages, journal pages, star notes. The draft is written a short
/// moment after each keystroke (so typing never waits on storage) and
/// wiped by [clearDraft] once the words are sent or saved for real.
///
/// Usage:
/// ```dart
/// final _input = DraftTextController('chat:sanctuary');
///
/// @override
/// void initState() {
///   super.initState();
///   _input.loadDraft(); // restores the saved words, if any
/// }
///
/// void _send() {
///   final text = _input.text.trim();
///   if (text.isEmpty) return;
///   send(text);
///   _input.clearDraft(); // words are safe now — forget the draft
/// }
/// ```
class DraftTextController extends TextEditingController {
  DraftTextController(this.draftKey, {super.text});

  /// Unique slot on the device, e.g. `'chat:sanctuary'`.
  final String draftKey;

  /// Longest draft kept, so one pasted wall of text can't bloat storage.
  static const maxDraftChars = 20000;

  /// Pause after the last keystroke before the draft is written.
  @visibleForTesting
  static Duration saveDelay = const Duration(milliseconds: 500);

  Timer? _saveTimer;
  bool _loaded = false;

  String get _storageKey => 'draft:$draftKey';

  /// Restores the saved words into this field (when it starts empty),
  /// then starts watching keystrokes. Safe to call once from `initState`.
  Future<void> loadDraft() async {
    if (_loaded) return;
    _loaded = true;
    if (text.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_storageKey);
        // The user may have typed while storage was loading — never
        // overwrite fresher words with the saved copy.
        if (saved != null && saved.isNotEmpty && text.isEmpty) {
          text = saved;
        }
      } catch (_) {
        // No saved words (or unreadable storage): just start empty.
      }
    }
    addListener(_scheduleSave);
  }

  /// Forgets the draft: call after the words are sent or saved for real.
  /// Also clears the field, like [TextEditingController.clear].
  Future<void> clearDraft() async {
    _saveTimer?.cancel();
    clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
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
    // Best-effort final write: closing the dialog still keeps the words.
    if (_saveTimer?.isActive ?? false) {
      _saveTimer?.cancel();
      unawaited(_persist());
    }
    super.dispose();
  }
}
