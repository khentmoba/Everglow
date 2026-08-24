import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/jukebox_dedication.dart';
import '../../../../core/utils/logger.dart';

class JukeboxDedicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'jukebox_dedications';

  Future<void> dedicate({
    required String fromUsername,
    required String toUsername,
    required String trackName,
    required String artistName,
    String? imageUrl,
    String? message,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .add(
            JukeboxDedication(
              id: '',
              fromUsername: fromUsername,
              toUsername: toUsername,
              trackName: trackName,
              artistName: artistName,
              imageUrl: imageUrl,
              message: message,
              createdAt: DateTime.now(),
            ).toMap(),
          );
    } catch (e) {
      Logger.e('JukeboxDedicationService: dedicate failed', error: e);
      rethrow;
    }
  }

  Stream<List<JukeboxDedication>> dedicationsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => JukeboxDedication.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<JukeboxDedication>> fetchRecent({int limit = 10}) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => JukeboxDedication.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      Logger.e('JukeboxDedicationService: fetch failed', error: e);
      return [];
    }
  }
}
