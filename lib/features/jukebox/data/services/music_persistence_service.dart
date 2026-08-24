import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/music_status.dart';
import '../../../../core/utils/logger.dart';

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
      Logger.e(
        'MusicPersistenceService: Error saving status for ${status.username}',
        error: e,
      );
    }
  }

  Future<MusicStatus?> getMusicStatus(String username) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(username)
          .get();
      if (doc.exists && doc.data() != null) {
        return MusicStatus.fromMap(doc.data()!);
      }
    } catch (e) {
      Logger.e(
        'MusicPersistenceService: Error getting status for $username',
        error: e,
      );
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
