import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // In-memory cache shared by the dashboard rail and the archive screen.
  // Lets a revisit (or rail -> View All) paint instantly while the live
  // stream revalidates in the background (stale-while-revalidate).
  List<HiddenNote> _cachedNotes = const [];
  List<HiddenNote> get cachedNotes => _cachedNotes;

  /// Loads cached notes from persistent local storage so the dashboard rail
  /// and archive screen paint instantly on cold launch without showing a skeleton.
  Future<List<HiddenNote>> loadDiskCache() async {
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

  // Full stream of all notes, shared globally, ordered by unlock date.
  // Used by the archive screen (needs everything for search/filter).
  // Wrapped with timeout so UI never hangs on web navigation.
  // Individual doc parse errors are swallowed so one malformed letter
  // does not kill the entire rail (the bug that left Letterbox empty
  // after a bad write).
  Stream<List<HiddenNote>> get notes {
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

  // Lightweight preview for the dashboard rail. The rail only shows a
  // horizontal strip, so fetching the whole collection wastes a rule
  // `get(/users/{uid})` evaluation per letter plus bandwidth on every
  // dashboard open — the main reason the rail felt slow on cold start.
  Stream<List<HiddenNote>> notesPreview({int limit = 10}) {
    Stream<List<HiddenNote>> subscribe() {
      return _db
          .collection('notes')
          .orderBy('unlockDate', descending: false)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            // Preview must not clobber the full cache when the archive
            // already holds more letters — only widen, never shrink.
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

  // Persist read state to Firestore
  Future<void> markAsRead(String noteId) async {
    // Optimistically update memory and disk cache so state is instant
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

    try {
      await _db.collection('notes').doc(noteId).update({'isRead': true});
      Logger.i("Marked note $noteId as read");
    } catch (e) {
      Logger.e("Error marking note as read", error: e);
    }
  }

  // Optional: helper to add a note (for future admin use)
  Future<void> addNote(HiddenNote note) async {
    try {
      await _db.collection('notes').add(note.toFirestore());
      Logger.i("Added new note to letterbox");
    } catch (e) {
      Logger.e("Error adding note", error: e);
    }
  }

  // Ensure the notes collection has at least one sample note if empty.
  // Unlike seedInitialNotes() this does NOT clear existing data.
  Future<void> ensureSeeded() async {
    try {
      // 1. Fast path: if cache already holds notes, the collection is
      // guaranteed to be non-empty — skip network get() completely.
      if (_cachedNotes.isNotEmpty) return;

      // 2. Yield so initial critical dashboard streams get the WebChannel first.
      await Future.delayed(const Duration(seconds: 4));
      if (_cachedNotes.isNotEmpty) return;

      // Check if disk cache has notes before making a database call
      final diskNotes = await loadDiskCache();
      if (diskNotes.isNotEmpty) return;

      final existing = await _db.collection('notes').limit(1).get();
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
      // Permission denied for cinema-only users is expected; swallow.
      Logger.e('Letterbox ensureSeeded failed (likely permission)', error: e);
    }
  }

  // Seed the collection with sample data
  Future<void> seedInitialNotes() async {
    // 1. Clear existing notes
    final existingNotes = await _db.collection('notes').get();
    final deleteBatch = _db.batch();
    for (var doc in existingNotes.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();

    _cachedNotes = const [];
    unawaited(_saveDiskCache(const []));

    // 2. Add the new note
    final data = {
      'title': 'My Favorite Number',
      'content': '1111',
      'unlockDate': Timestamp.fromDate(DateTime.now()),
      'isRead': false,
    };

    await _db.collection('notes').add(data);
  }
}