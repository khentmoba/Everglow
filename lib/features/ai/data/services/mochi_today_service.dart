import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/memory/memory_fact.dart';

/// A single snapshot of "today in Everglow" used by Mochi's recap.
class TodaySnapshot {
  final DateTime date;
  final List<({String uid, String mood})> moods;
  final List<String> activities;
  final List<String> watchlist;
  final List<String> starlight;
  final List<MemoryFact> memories;

  const TodaySnapshot({
    required this.date,
    this.moods = const [],
    this.activities = const [],
    this.watchlist = const [],
    this.starlight = const [],
    this.memories = const [],
  });
}

/// Reads the small set of Firestore collections Mochi needs to compose
/// a warm daily recap. Kept separate from the AI service so the recap
/// screen can render even when the chat proxy is offline.
class MochiTodayService {
  final FirebaseFirestore _db;

  MochiTodayService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Future<TodaySnapshot> fetch({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final today = '${current.year.toString().padLeft(4, '0')}-'
        '${current.month.toString().padLeft(2, '0')}-'
        '${current.day.toString().padLeft(2, '0')}';
    try {
      final results = await Future.wait([
        _db.collection('moods').where('date', isEqualTo: today).get(),
        _db
            .collection('recent_activity')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get(),
        _db.collection('our_cinema').limit(5).get(),
        _db
            .collection('starlight_jar')
            .orderBy('timestamp', descending: true)
            .limit(3)
            .get(),
        _db
            .collection('ai_memories')
            .doc('shared')
            .collection('facts')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .get(),
      ]);

      final moodDocs = results[0].docs;
      final activityDocs = results[1].docs;
      final watchDocs = results[2].docs;
      final starDocs = results[3].docs;
      final memoryDocs = results[4].docs;

      return TodaySnapshot(
        date: current,
        moods: moodDocs
            .map((doc) {
              final data = doc.data();
              return (
                uid: (data['uid'] as String?) ?? 'someone',
                mood: (data['mood'] as String?) ?? 'okay',
              );
            })
            .toList(),
        activities: activityDocs
            .map((doc) {
              final data = doc.data();
              return (data['activity'] as String?) ??
                  (data['description'] as String?) ??
                  '';
            })
            .where((value) => value.isNotEmpty)
            .toList(),
        watchlist: watchDocs
            .map((doc) => (doc.data()['title'] as String?) ?? '')
            .where((value) => value.isNotEmpty)
            .toList(),
        starlight: starDocs
            .map((doc) => (doc.data()['content'] as String?) ?? '')
            .where((value) => value.isNotEmpty)
            .toList(),
        memories: memoryDocs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              return MemoryFact.fromJson(data, id: doc.id);
            })
            .where((fact) => fact.fact.isNotEmpty)
            .toList(),
      );
    } catch (e) {
      debugPrint('[MochiTodayService] Failed to fetch recap: $e');
      return TodaySnapshot(date: current);
    }
  }
}
