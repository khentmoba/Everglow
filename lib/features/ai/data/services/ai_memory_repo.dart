import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/ai_memory_repo_interface.dart';

/// Firestore CRUD for Mochi's permanent memory (ai_memories/shared/facts).
class AIMemoryRepository implements IAIMemoryRepository {
  final FirebaseFirestore _db;
  final User? _user;

  List<String> _memories = [];
  bool _memoriesLoaded = false;

  AIMemoryRepository({FirebaseFirestore? db, User? user})
      : _db = db ?? FirebaseFirestore.instance,
        _user = user;

  @override
  List<String> get all => List.unmodifiable(_memories);
  @override
  bool get isLoaded => _memoriesLoaded;

  /// Load up to 200 facts from Firestore (once).
  @override
  Future<void> load() async {
    if (_memoriesLoaded) return;
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('facts')
          .orderBy('createdAt', descending: true)
          .limit(150)
          .get();

      _memories = snapshot.docs
          .map((doc) => doc.data()['fact'] as String? ?? '')
          .where((f) => f.isNotEmpty)
          .toList();
      _memoriesLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load memories: $e');
      _memoriesLoaded = true;
    }
  }

  /// Save a fact to Firestore and cache it.
  @override
  Future<void> save(String fact, {String category = 'fact'}) async {
    if (fact.trim().isEmpty) return;
    try {
      await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('facts')
          .add({
            'fact': fact.trim(),
            'category': category,
            'addedBy': _user?.uid ?? 'unknown',
            'createdAt': FieldValue.serverTimestamp(),
            'confidence': 1.0,
            'accessCount': 0,
            'lastAccessed': null,
          });
      _memories.insert(0, fact.trim());
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save memory: $e');
    }
  }

  /// Delete a fact from Firestore and cache.
  @override
  Future<void> delete(String factId) async {
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('facts')
          .where('fact', isEqualTo: factId)
          .limit(1)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        _memories.remove(factId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to delete memory: $e');
    }
  }

  /// Check if a normalized fact is already in the cache.
  @override
  bool isDuplicate(String fact) {
    final normalized = fact.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    return _memories.any((existing) {
      final existingNorm = existing.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
      return normalized == existingNorm ||
          existingNorm.contains(normalized) ||
          normalized.contains(existingNorm);
    });
  }

  /// Reset cache (call on logout).
  @override
  void reset() {
    _memories = [];
    _memoriesLoaded = false;
  }
}
