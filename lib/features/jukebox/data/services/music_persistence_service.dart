import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/music_status.dart';

class MusicPersistenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'music_status';

  Future<void> saveMusicStatus(MusicStatus status) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(status.username)
          .set(status.toMap());
    } catch (e) {
      print('MusicPersistenceService: Error saving status for ${status.username}: $e');
    }
  }

  Future<MusicStatus?> getMusicStatus(String username) async {
    try {
      final doc = await _firestore.collection(_collectionPath).doc(username).get();
      if (doc.exists && doc.data() != null) {
        return MusicStatus.fromMap(doc.data()!);
      }
    } catch (e) {
      print('MusicPersistenceService: Error getting status for $username: $e');
    }
    return null;
  }

  Stream<Map<String, MusicStatus>> musicStatusStream(List<String> usernames) {
    return _firestore.collection(_collectionPath).snapshots().map((snapshot) {
      final Map<String, MusicStatus> results = {};
      for (var doc in snapshot.docs) {
        if (usernames.contains(doc.id)) {
          results[doc.id] = MusicStatus.fromMap(doc.data());
        }
      }
      return results;
    });
  }
}
