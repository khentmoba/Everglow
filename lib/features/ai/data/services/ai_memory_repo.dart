import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/memory/memory_fact.dart';
import '../../domain/repositories/ai_memory_repo_interface.dart';

class AIMemoryRepository implements IAIMemoryRepository {
  final FirebaseFirestore _db;
  final User? _user;

  List<String> _memories = [];
  List<MemoryFact> _facts = [];
  bool _memoriesLoaded = false;

  AIMemoryRepository({FirebaseFirestore? db, User? user})
    : _db = db ?? FirebaseFirestore.instance,
      _user = user;

  @override
  List<String> get all => List.unmodifiable(_memories);

  @override
  List<MemoryFact> get facts => List.unmodifiable(_facts);
  @override
  bool get isLoaded => _memoriesLoaded;

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
          .map((doc) {
            final raw = doc.data()['fact'];
            return raw is String ? raw : '';
          })
          .where((f) => f.isNotEmpty)
          .toList();
      _facts = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            final fact = MemoryFact.fromJson(data, id: doc.id);
            return fact.fact.isEmpty ? null : fact;
          })
          .whereType<MemoryFact>()
          .toList();
      _memoriesLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load memories: $e');
      _memoriesLoaded = true;
    }
  }

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
      _facts.insert(
        0,
        MemoryFact(
          id: '',
          fact: fact.trim(),
          category: category,
          source: _user?.uid ?? 'unknown',
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save memory: $e');
    }
  }

  @override
  Future<void> delete(String factId) async {
    try {
      if (factId.isEmpty) {
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
          _facts.removeWhere((f) => f.fact == factId);
        }
        return;
      }
      await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('facts')
          .doc(factId)
          .delete();
      final removed = _facts.where((f) => f.id == factId).toList();
      for (final fact in removed) {
        _memories.remove(fact.fact);
      }
      _facts.removeWhere((f) => f.id == factId);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to delete memory: $e');
    }
  }

  @override
  Future<void> setPinned(String factId, bool pinned) async {
    if (factId.isEmpty) return;
    try {
      await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('facts')
          .doc(factId)
          .update({'pinned': pinned});
      _facts = _facts
          .map((f) => f.id == factId ? f.copyWith(pinned: pinned) : f)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to pin memory: $e');
    }
  }

  @override
  Future<void> saveStructured({
    required String fact,
    String category = 'fact',
    String? subject,
    String? relation,
    String? object,
    DateTime? occurredAt,
  }) async {
    if (fact.trim().isEmpty) return;
    try {
      final parser = const FactStructureParser();
      final inferred = parser.parse(fact);
      await _db.collection('ai_memories').doc('shared').collection('facts').add(
        {
          'fact': fact.trim(),
          'category': category,
          'subject': subject ?? inferred.$1,
          'relation': relation ?? inferred.$2,
          'object': object ?? inferred.$3,
          if (occurredAt != null) 'occurredAt': Timestamp.fromDate(occurredAt),
          'addedBy': _user?.uid ?? 'unknown',
          'createdAt': FieldValue.serverTimestamp(),
          'confidence': 1.0,
          'accessCount': 0,
          'lastAccessed': null,
          'pinned': false,
          'source': _user?.uid ?? 'unknown',
        },
      );
      _memories.insert(0, fact.trim());
      _facts.insert(
        0,
        MemoryFact(
          fact: fact.trim(),
          category: category,
          subject: subject ?? inferred.$1,
          relation: relation ?? inferred.$2,
          object: object ?? inferred.$3,
          occurredAt: occurredAt,
          source: _user?.uid ?? 'unknown',
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save structured memory: $e');
    }
  }

  @override
  bool isDuplicate(String fact) {
    final normalized = fact
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
    return _memories.any((existing) {
      final existingNorm = existing
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim();
      return normalized == existingNorm ||
          existingNorm.contains(normalized) ||
          normalized.contains(existingNorm);
    });
  }

  @override
  void reset() {
    _memories = [];
    _facts = [];
    _memoriesLoaded = false;
  }
}
