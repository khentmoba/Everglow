import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/guardian_message.dart';
import '../../../../core/utils/logger.dart';

class GuardianService {
  static final GuardianService _instance = GuardianService._internal();
  factory GuardianService() => _instance;
  GuardianService._internal();

  static const int _maxCached = 200;
  static const Duration _cacheTtl = Duration(minutes: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _random = Random();
  List<GuardianMessage> _cachedMessages = [];
  Map<String, List<GuardianMessage>> _byCategory = {};
  DateTime? _lastFetch;
  Future<void>? _inflight;
  String? _lastPickedId;

  List<GuardianMessage> get cachedMessages => _cachedMessages;

  /// Initializes the service by fetching messages from Firestore.
  /// Seeds the database if empty. Single read, dedupes concurrent calls,
  /// and reuses fresh cache within [_cacheTtl].
  Future<void> initialize() async {
    if (_inflight != null) return _inflight!;
    if (_cachedMessages.isNotEmpty &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheTtl) {
      return;
    }
    _inflight = _initializeOnce();
    try {
      await _inflight;
    } finally {
      _inflight = null;
    }
  }

  Future<void> _initializeOnce() async {
    try {
      final snapshot = await _db
          .collection('guardian_messages')
          .limit(_maxCached)
          .get()
          .timeout(const Duration(seconds: 8));
      var docs = snapshot.docs;
      if (docs.isEmpty) {
        await seedMessages();
        final seeded = await _db
            .collection('guardian_messages')
            .limit(_maxCached)
            .get()
            .timeout(const Duration(seconds: 8));
        docs = seeded.docs;
      }
      _cachedMessages = docs
          .map((doc) => GuardianMessage.fromFirestore(doc.data(), doc.id))
          .toList();
      _rebuildIndex();
      _lastFetch = DateTime.now();
    } catch (e) {
      Logger.e('Error initializing guardian messages', error: e);
      // Keep stale cache if we have one; otherwise stay empty.
    }
  }

  void _rebuildIndex() {
    final map = <String, List<GuardianMessage>>{};
    for (final m in _cachedMessages) {
      (map[m.category] ??= []).add(m);
    }
    _byCategory = map;
  }

  /// Selects a random [GuardianMessage] from the cached list.
  /// Avoids repeating the same message twice in a row when possible.
  GuardianMessage? getRandomMessage({String? category}) {
    final List<GuardianMessage> pool;
    if (category != null) {
      pool = _byCategory[category] ?? const [];
    } else {
      pool = _cachedMessages;
    }

    if (pool.isEmpty) return null;
    if (pool.length == 1) return pool.first;
    GuardianMessage picked = pool[_random.nextInt(pool.length)];
    if (picked.id == _lastPickedId) {
      picked = pool[_random.nextInt(pool.length)];
    }
    _lastPickedId = picked.id;
    return picked;
  }

  /// Seeds initial messages from local JSON asset to Firestore.
  /// Chunked to stay under the 500-write batch limit.
  Future<void> seedMessages() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/guardian_messages_seed.json',
      );
      final List<dynamic> data = jsonDecode(jsonString);
      if (data.isEmpty) return;

      final collection = _db.collection('guardian_messages');
      const chunkSize = 400;
      for (var i = 0; i < data.length; i += chunkSize) {
        final batch = _db.batch();
        final end = (i + chunkSize > data.length) ? data.length : i + chunkSize;
        for (var j = i; j < end; j++) {
          final item = data[j];
          if (item is! Map) continue;
          final content = (item['content'] as String?)?.trim();
          if (content == null || content.isEmpty) continue;
          final docRef = collection.doc();
          batch.set(docRef, {
            'content': content,
            'category': item['category'] ?? 'idle',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      Logger.e('Error seeding guardian messages', error: e);
    }
  }
}
