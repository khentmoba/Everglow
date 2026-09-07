import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/date_idea.dart';
import '../../../../core/utils/logger.dart';

class DateIdeaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<DateIdea> _cachedIdeas = [];

  List<DateIdea> get cachedIdeas => _cachedIdeas;

  /// Fetches a capped sample of ideas from Firestore. Seeds the database
  /// if empty. Capped at 50: the dashboard card shows one random idea at
  /// a time, so the previous unbounded full-collection read (1000+ docs
  /// on every dashboard open) was pure cold-start fuel.
  Future<void> initialize({int limit = 50}) async {
    if (_cachedIdeas.isNotEmpty) return;
    final snapshot = await _db.collection('date_ideas').limit(limit).get();

    if (snapshot.docs.isEmpty) {
      await seedIdeas();
      // Fetch again after seeding
      final seededSnapshot = await _db.collection('date_ideas').limit(limit).get();
      _cachedIdeas = seededSnapshot.docs
          .map((doc) => DateIdea.fromFirestore(doc.data(), doc.id))
          .toList();
    } else {
      _cachedIdeas = snapshot.docs
          .map((doc) => DateIdea.fromFirestore(doc.data(), doc.id))
          .toList();
    }
  }

  /// Selects a random [DateIdea] from the cached list.
  DateIdea? getRandomIdea() {
    if (_cachedIdeas.isEmpty) return null;
    final random = Random();
    return _cachedIdeas[random.nextInt(_cachedIdeas.length)];
  }

  /// Loads 1000+ ideas from assets and pushes them to Firestore in batches.
  Future<void> seedIdeas() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/date_ideas_seed.json',
      );
      final List<dynamic> data = jsonDecode(jsonString);

      final collection = _db.collection('date_ideas');

      // Process in batches of 500 (Firestore limit)
      for (var i = 0; i < data.length; i += 500) {
        final batch = _db.batch();
        final end = (i + 500 < data.length) ? i + 500 : data.length;

        for (var j = i; j < end; j++) {
          final docRef = collection.doc();
          batch.set(docRef, {
            'title': data[j]['title'],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }
    } catch (e) {
      Logger.e('Error seeding date ideas', error: e);
    }
  }
}
