import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/auth_service.dart';

class CleanupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> resetClairTestData() async {
    print("STARTING CLEANUP: Resetting Clair Jassen's test data...");
    
    try {
      // 1. Delete Stars from Starlight Jar
      final starDocs = await _db
          .collection('starlight_jar')
          .where('author', isEqualTo: 'clairjassen')
          .get();
      
      for (var doc in starDocs.docs) {
        await doc.reference.delete();
      }
      print("CLEANUP: Deleted ${starDocs.docs.length} stars.");

      // 2. Delete Chat Messages
      final chatDocs = await _db
          .collection('sanctuary_messages')
          .where('senderUid', isEqualTo: AuthService.clairUid)
          .get();
      
      for (var doc in chatDocs.docs) {
        await doc.reference.delete();
      }
      print("CLEANUP: Deleted ${chatDocs.docs.length} chat messages.");

      // 3. Delete Mood Entries
      final moodDocs = await _db
          .collection('moods')
          .where('username', isEqualTo: 'clairjassen')
          .get();
      
      for (var doc in moodDocs.docs) {
        await doc.reference.delete();
      }
      print("CLEANUP: Deleted ${moodDocs.docs.length} mood entries.");

      // 4. Reset XP Progress
      await _db
          .collection('users')
          .doc(AuthService.clairUid)
          .collection('progress')
          .doc('main')
          .delete();
      print("CLEANUP: Reset XP progress for Clair.");

      print("CLEANUP COMPLETE: Clair Jassen is now a fresh user.");
    } catch (e) {
      print("CLEANUP ERROR: $e");
      rethrow;
    }
  }

  Future<void> purgeDiagnosticMessages() async {
    print("STARTING CLEANUP: Purging diagnostic check messages...");
    
    try {
      final diagDocs = await _db
          .collection('sanctuary_messages')
          .where('text', isEqualTo: 'DIAGNOSTIC_CHECK')
          .get();
      
      for (var doc in diagDocs.docs) {
        await doc.reference.delete();
      }
      print("CLEANUP: Deleted ${diagDocs.docs.length} diagnostic messages.");
      print("CLEANUP COMPLETE: Sanctuary chat is clean.");
    } catch (e) {
      print("CLEANUP ERROR: $e");
      rethrow;
    }
  }
}
