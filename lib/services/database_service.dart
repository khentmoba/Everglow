import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/memory.dart';

class DatabaseService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  DatabaseService({required this.userId});

  // Get real-time stream of memories for this user
  Stream<List<Memory>> get memories {
    return _db
        .collection('memories')
        .where('ownerId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Memory.fromFirestore(doc)).toList();
    });
  }

  Future<void> addMemory(Memory memory) async {
    await _db.collection('memories').add(memory.toFirestore());
  }

  Future<void> updateMemory(Memory memory) async {
    await _db.collection('memories').doc(memory.id).update(memory.toFirestore());
  }

  Future<void> deleteMemory(String memoryId) async {
    await _db.collection('memories').doc(memoryId).delete();
  }
}
