import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/academy_question.dart';
import 'academy_service.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';

/// Builds Academy question sets: Motchi-first, cache-backed.
///
/// Every Solo session and every hosted 1v1 asks Motchi for ONE fresh set
/// (1 call against the shared daily cap). Anything Motchi writes is saved
/// into `academy_questions`, so when she is tired, offline, or capped,
/// Clair still plays instantly from the cache — never a dead screen.
class StudySetService {
  StudySetService({AcademyService? academy, http.Client? client})
    : _academy = academy ?? AcademyService(),
      _client = client ?? http.Client();

  final AcademyService _academy;
  final http.Client _client;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static const int defaultCount = 10;
  static const int _maxSeenIds = 100;

  String get _functionUrl {
    if (kDebugMode && !kIsWeb) {
      return 'http://127.0.0.1:5001/everglow-1c6db/us-central1/generateStudySet';
    }
    return 'https://us-central1-everglow-1c6db.cloudfunctions.net/generateStudySet';
  }

  /// Fresh Solo set for [category]. When [topic] is given, Motchi themes
  /// every question around it (saved under [category] for reuse).
  Future<List<AcademyQuestion>> buildSoloSet({
    required String category,
    int count = defaultCount,
    String topic = '',
  }) async {
    final seen = await _readSeenIds();
    List<AcademyQuestion> fresh = [];
    try {
      fresh = await _generateViaMotchi(
        category: category,
        count: count,
        topic: topic,
      );
      await _saveQuestions(fresh, category: category);
    } catch (e) {
      Logger.e('Motchi set failed, falling back to cache', error: e);
    }

    // Prefer fresh Motchi questions, skip ones already seen, then fill
    // the rest from the cache so the set is always full when possible.
    final freshUnseen = fresh.where((q) => !seen.contains(q.id)).toList();
    final useFresh = freshUnseen.length >= 5 ? freshUnseen : fresh;
    if (useFresh.length >= count) {
      await _recordSeen(useFresh.take(count).map((q) => q.id));
      return useFresh.take(count).toList();
    }
    final cached = await _academy.getQuestionsExcluding(
      category,
      limit: count,
      excludeIds: {...seen, ...useFresh.map((q) => q.id)},
    );
    final combined = [...useFresh, ...cached].take(count).toList();
    await _recordSeen(combined.map((q) => q.id));
    return combined;
  }

  /// Shared set for a hosted 1v1 match. Returns question IDs in play
  /// order. Motchi-first with the same cache fallback as Solo.
  Future<List<String>> buildMatchSet({required String category}) async {
    try {
      final fresh = await _generateViaMotchi(
        category: category,
        count: AcademyService.matchLength,
      );
      await _saveQuestions(fresh, category: category);
      if (fresh.length >= 5) {
        return fresh.take(AcademyService.matchLength).map((q) => q.id).toList();
      }
    } catch (e) {
      Logger.e('Motchi match set failed, falling back to cache', error: e);
    }
    final cached = await _academy.getQuestions(
      category,
      limit: AcademyService.matchLength,
    );
    return cached.map((q) => q.id).toList();
  }

  /// Saves a finished Solo result (best score per category + last played).
  /// Returns true when this is a new best. Fail-soft: study never
  /// breaks over a stats write.
  Future<bool> saveSoloResult({
    required String category,
    required int score,
    required int total,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;
      final ref = _progressRef(uid);
      final snap = await withGetTimeout(
        ref.get(),
        label: 'academy progress read',
      );
      final data = snap.data() ?? {};
      final best = Map<String, dynamic>.from(data['bestByCategory'] ?? {});
      final prev = (best[category] as num?)?.toInt() ?? 0;
      final isBest = score > prev;
      await ref.set({
        'bestByCategory': {...best, category: isBest ? score : prev},
        'lastCategory': category,
        'lastScore': score,
        'lastTotal': total,
        'lastPlayedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return isBest;
    } catch (e) {
      Logger.e('Error saving solo result', error: e);
      return false;
    }
  }

  /// Watches Solo stats for the hub card (last category + bests).
  /// Emits null when signed out or on errors — the card falls back
  /// to its default subtitle.
  Stream<SoloStats?> watchSoloStats() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _progressRef(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      try {
        return SoloStats.fromMap(snap.data() ?? {});
      } catch (e) {
        Logger.e('Error reading solo stats', error: e);
        return null;
      }
    });
  }

  DocumentReference<Map<String, dynamic>> _progressRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('academy');
  }

  Future<Set<String>> _readSeenIds() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return {};
      final snap = await withGetTimeout(
        _progressRef(uid).get(),
        label: 'academy seen ids read',
      );
      final raw = snap.data()?['seenIds'];
      if (raw is! List) return {};
      return raw.map((e) => e.toString()).toSet();
    } catch (e) {
      Logger.e('Error reading seen ids', error: e);
      return {};
    }
  }

  Future<void> _recordSeen(Iterable<String> ids) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final current = await _readSeenIds();
      final next = [...current, ...ids];
      final trimmed = next.length > _maxSeenIds
          ? next.sublist(next.length - _maxSeenIds)
          : next;
      await _progressRef(uid).set({
        'seenIds': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.e('Error recording seen ids', error: e);
    }
  }

  /// Calls the generateStudySet cloud function. Throws on any failure —
  /// callers fall back to the cached pool.
  @visibleForTesting
  Future<List<AcademyQuestion>> generateViaMotchi({
    required String category,
    required int count,
    String topic = '',
  }) => _generateViaMotchi(category: category, count: count, topic: topic);

  Future<List<AcademyQuestion>> _generateViaMotchi({
    required String category,
    required int count,
    String topic = '',
  }) async {
    final token = await _auth.currentUser?.getIdToken() ?? '';
    if (token.isEmpty) throw Exception('Not signed in');
    final response = await _client
        .post(
          Uri.parse(_functionUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'category': category,
            'count': count,
            if (topic.trim().isNotEmpty) 'topic': topic.trim(),
          }),
        )
        .timeout(const Duration(seconds: 75));

    if (response.statusCode != 200) {
      throw Exception(
        'Study generator ${response.statusCode}: ${response.body}',
      );
    }
    final data = jsonDecode(response.body);
    final raw = data['questions'];
    if (raw is! List || raw.isEmpty) throw Exception('Empty study set');
    return raw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final text = (map['questionText'] ?? '').toString();
      return AcademyQuestion(
        id: AcademyQuestion.generateId(text),
        questionText: text,
        options: (map['options'] as List).map((e) => e.toString()).toList(),
        correctOptionIndex: (map['correctOptionIndex'] as num).toInt(),
        category: category,
        explanation: (map['explanation'] ?? '').toString().isEmpty
            ? null
            : (map['explanation'] as String),
      );
    }).toList();
  }

  Future<void> _saveQuestions(
    List<AcademyQuestion> questions, {
    required String category,
  }) async {
    if (questions.isEmpty) return;
    var batch = _firestore.batch();
    var pending = 0;
    for (final q in questions) {
      final docRef = _firestore.collection('academy_questions').doc(q.id);
      batch.set(docRef, {
        ...q.toMap(),
        'id': q.id,
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'motchi',
      }, SetOptions(merge: true));
      pending++;
      if (pending >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }
}

/// Small Solo stats shown on the hub card.
class SoloStats {
  final String? lastCategory;
  final int lastScore;
  final int lastTotal;
  final Map<String, int> bestByCategory;

  const SoloStats({
    this.lastCategory,
    this.lastScore = 0,
    this.lastTotal = 0,
    this.bestByCategory = const {},
  });

  factory SoloStats.fromMap(Map<String, dynamic> map) {
    final bestRaw = map['bestByCategory'];
    final best = <String, int>{};
    if (bestRaw is Map) {
      bestRaw.forEach((key, value) {
        if (value is num) best[key.toString()] = value.toInt();
      });
    }
    return SoloStats(
      lastCategory: map['lastCategory'] is String
          ? map['lastCategory'] as String
          : null,
      lastScore: (map['lastScore'] as num?)?.toInt() ?? 0,
      lastTotal: (map['lastTotal'] as num?)?.toInt() ?? 0,
      bestByCategory: best,
    );
  }
}
