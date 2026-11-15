import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/models/mini_game.dart';

class MotchiMinisService {
  final FirebaseFirestore _db;

  static const int shelfLimit = 50;

  MotchiMinisService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Stream<List<MiniGame>> watchMinis() {
    return _db
        .collection('motchi_games')
        .orderBy('createdAt', descending: true)
        .limit(shelfLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MiniGame.fromFirestore(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<bool> saveMini({
    required String title,
    required String html,
    required String createdBy,
  }) async {
    final cleanTitle = title.trim().isEmpty ? 'Motchi Mini' : title.trim();
    if (html.trim().isEmpty) return false;
    try {
      await _db.collection('motchi_games').add({
        'title': cleanTitle.length > 80
            ? '${cleanTitle.substring(0, 80)}…'
            : cleanTitle,
        'html': html,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      Logger.e('Error saving mini game', error: e);
      return false;
    }
  }

  Future<void> deleteMini(String id) async {
    try {
      await _db.collection('motchi_games').doc(id).delete();
    } catch (e) {
      Logger.e('Error deleting mini game', error: e);
    }
  }
}
