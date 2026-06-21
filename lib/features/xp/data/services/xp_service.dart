import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/core/audio/audio_service.dart';
import 'package:everglow/core/utils/firestore_stream_utils.dart';
import '../../domain/models/user_progress.dart';

class XPService {
  static final XPService _instance = XPService._internal();
  factory XPService() => _instance;
  XPService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<UserProgress?> watchProgress(String uid) {
    return withFirestoreTimeout(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc('main')
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) return null;
        return UserProgress.fromMap(uid, snapshot.data()!);
      }),
      label: 'xp-progress',
    );
  }

  Future<void> addXp(String uid, int amount) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('main');

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      
      if (!snapshot.exists) {
        transaction.set(docRef, {
          'xpTotal': amount,
          'level': 1,
          'streak': 1,
          'lastActivity': FieldValue.serverTimestamp(),
        });
      } else {
        final currentXp = snapshot.data()!['xpTotal'] as int;
        final newXp = currentXp + amount;
        final newLevel = (newXp / 1000).floor() + 1;
        
        transaction.update(docRef, {
          'xpTotal': newXp,
          'level': newLevel,
          'lastActivity': FieldValue.serverTimestamp(),
        });

        if (newLevel > snapshot.data()!['level']) {
          AudioService().playSfx(AudioService.levelUp);
        } else {
          AudioService().playSfx(AudioService.sparkle);
        }
      }
    });
  }

  Future<void> initializeProgress(String uid) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('main');
        
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({
        'xpTotal': 0,
        'level': 1,
        'streak': 0,
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }
  }
}
