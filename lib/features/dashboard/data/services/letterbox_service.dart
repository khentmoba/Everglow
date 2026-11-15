import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../domain/models/hidden_note.dart';
import '../../../../core/utils/logger.dart';

class LetterboxService {
  static final LetterboxService _instance = LetterboxService._internal();
  factory LetterboxService() => _instance;
  LetterboxService._internal() {
    unawaited(loadDiskCache());
  }

  static const _storageKey = 'letterbox_notes_cache_v1';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<HiddenNote> _cachedNotes = const [];
  List<HiddenNote> get cachedNotes => _cachedNotes;

  Future<List<HiddenNote>> loadDiskCache() async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      _cachedNotes = AgentFixtures.demoNotes;
      return _cachedNotes;
    }
    if (_cachedNotes.isNotEmpty) return _cachedNotes;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final notes = decoded
              .whereType<Map<String, dynamic>>()
              .map(HiddenNote.fromJson)
              .toList();
          if (notes.isNotEmpty && _cachedNotes.isEmpty) {
            _cachedNotes = List.unmodifiable(notes);
          }
        }
      }
    } catch (e) {
      Logger.w('Letterbox: failed to load disk cache: $e');
    }
    return _cachedNotes;
  }

  Future<void> _saveDiskCache(List<HiddenNote> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = notes.map((n) => n.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      Logger.w('Letterbox: failed to save disk cache: $e');
    }
  }

  List<HiddenNote> _mapSnapshot(QuerySnapshot snapshot) {
    final out = <HiddenNote>[];
    for (final doc in snapshot.docs) {
      try {
        out.add(HiddenNote.fromFirestore(doc));
      } catch (e) {
        Logger.e('Letterbox: skipping malformed note ${doc.id}', error: e);
      }
    }
    _cachedNotes = List.unmodifiable(out);
    unawaited(_saveDiskCache(_cachedNotes));
    return _cachedNotes;
  }

  Stream<List<HiddenNote>> get notes {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoNotes);
    }
    Stream<List<HiddenNote>> subscribe() {
      return _db
          .collection('notes')
          .orderBy('unlockDate', descending: false)
          .limit(200)
          .snapshots()
          .map(_mapSnapshot);
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'letterbox-notes',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  Stream<List<HiddenNote>> notesPreview({int limit = 10}) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoNotes);
    }
    Stream<List<HiddenNote>> subscribe() {
      return _db
          .collection('notes')
          .orderBy('unlockDate', descending: false)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final out = <HiddenNote>[];
            for (final doc in snapshot.docs) {
              try {
                out.add(HiddenNote.fromFirestore(doc));
              } catch (e) {
                Logger.e(
                  'Letterbox: skipping malformed note ${doc.id}',
                  error: e,
                );
              }
            }
            if (out.length >= _cachedNotes.length) {
              _cachedNotes = List.unmodifiable(out);
              unawaited(_saveDiskCache(_cachedNotes));
            }
            return out;
          });
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'letterbox-notes-preview',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  Future<void> markAsRead(String noteId) async {
    if (_cachedNotes.isNotEmpty) {
      final updated = _cachedNotes.map((n) {
        if (n.id == noteId) {
          return HiddenNote(
            id: n.id,
            title: n.title,
            content: n.content,
            unlockDate: n.unlockDate,
            isRead: true,
          );
        }
        return n;
      }).toList();
      _cachedNotes = List.unmodifiable(updated);
      unawaited(_saveDiskCache(_cachedNotes));
    }

    if (AgentMode.isActive.value) return;

    try {
      await _db.collection('notes').doc(noteId).update({'isRead': true});
      Logger.i("Marked note $noteId as read");
    } catch (e) {
      Logger.e("Error marking note as read", error: e);
    }
  }

  Future<void> addNote(HiddenNote note) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection('notes').add(note.toFirestore());
      Logger.i("Added new note to letterbox");
    } catch (e) {
      Logger.e("Error adding note", error: e);
    }
  }

  Future<void> ensureSeeded() async {
    if (AgentMode.isActive.value) return;
    try {
      if (_cachedNotes.isNotEmpty) return;

      await Future.delayed(const Duration(seconds: 4));
      if (_cachedNotes.isNotEmpty) return;

      final diskNotes = await loadDiskCache();
      if (diskNotes.isNotEmpty) return;

      final existing = await withGetTimeout(
        _db.collection('notes').limit(1).get(),
        label: 'letterbox seed check',
      );
      if (existing.docs.isNotEmpty) return;
      final data = {
        'title': 'My Favorite Number',
        'content': '1111',
        'unlockDate': Timestamp.fromDate(DateTime.now()),
        'isRead': false,
      };
      await _db.collection('notes').add(data);
      Logger.i('Letterbox: seeded initial sample note');
    } catch (e) {
      Logger.e('Letterbox ensureSeeded failed (likely permission)', error: e);
    }
  }

  Future<void> seedInitialNotes() async {
    if (AgentMode.isActive.value) return;
    final existingNotes = await withGetTimeout(
      _db.collection('notes').get(),
      label: 'letterbox reseed scan',
    );
    final deleteBatch = _db.batch();
    for (var doc in existingNotes.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();

    _cachedNotes = const [];
    unawaited(_saveDiskCache(const []));

    final data = {
      'title': 'My Favorite Number',
      'content': '1111',
      'unlockDate': Timestamp.fromDate(DateTime.now()),
      'isRead': false,
    };

    await _db.collection('notes').add(data);
  }
}
