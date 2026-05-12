import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/guardian_message.dart';

class GuardianService {
  static final GuardianService _instance = GuardianService._internal();
  factory GuardianService() => _instance;
  GuardianService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<GuardianMessage> _cachedMessages = [];

  List<GuardianMessage> get cachedMessages => _cachedMessages;

  /// Initializes the service by fetching messages from Firestore.
  /// Seeds the database if empty.
  Future<void> initialize() async {
    final snapshot = await _db.collection('guardian_messages').get();
    
    if (snapshot.docs.isEmpty) {
      await seedMessages();
      // Fetch again after seeding
      final seededSnapshot = await _db.collection('guardian_messages').get();
      _cachedMessages = seededSnapshot.docs
          .map((doc) => GuardianMessage.fromFirestore(doc.data(), doc.id))
          .toList();
    } else {
      _cachedMessages = snapshot.docs
          .map((doc) => GuardianMessage.fromFirestore(doc.data(), doc.id))
          .toList();
    }
  }

  /// Selects a random [GuardianMessage] from the cached list.
  GuardianMessage? getRandomMessage({String? category}) {
    List<GuardianMessage> pool = _cachedMessages;
    if (category != null) {
      pool = _cachedMessages.where((m) => m.category == category).toList();
    }
    
    if (pool.isEmpty) return null;
    final random = Random();
    return pool[random.nextInt(pool.length)];
  }

  /// Seeds initial messages from local JSON asset to Firestore.
  Future<void> seedMessages() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/guardian_messages_seed.json');
      final List<dynamic> data = jsonDecode(jsonString);
      
      final collection = _db.collection('guardian_messages');
      final batch = _db.batch();
      
      for (var item in data) {
        final docRef = collection.doc();
        batch.set(docRef, {
          'content': item['content'],
          'category': item['category'] ?? 'idle',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Error seeding guardian messages: $e');
    }
  }
}
