import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/doodle_stroke.dart';
import 'canvas_point_utils.dart';

class CanvasService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'canvas_strokes';

  Stream<List<DoodleStroke>> getStrokesStream() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: false)
        .limit(300)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DoodleStroke.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> saveStroke(DoodleStroke stroke) async {
    await _db.collection(_collection).add(stroke.toMap());
  }

  Future<void> deleteStroke(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  // --- Live Drawing Support ---

  Future<void> updateActiveStroke(String userId, DoodleStroke stroke) async {
    await _db.collection('live_canvas').doc(userId).set(stroke.toMap());
  }

  Future<void> clearActiveStroke(String userId) async {
    await _db.collection('live_canvas').doc(userId).delete();
  }

  Stream<List<DoodleStroke>> getLiveStrokesStream() {
    return _db
        .collection('live_canvas')
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DoodleStroke.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> clearAllStrokes() async {
    await _deleteInBatches(
      (await _db.collection(_collection).get())
          .docs
          .map((doc) => doc.reference)
          .toList(),
    );
    await _deleteInBatches(
      (await _db.collection('live_canvas').get())
          .docs
          .map((doc) => doc.reference)
          .toList(),
    );
  }

  Future<void> _deleteInBatches(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    const batchSize = 500;
    for (var i = 0; i < refs.length; i += batchSize) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(batchSize)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Delegates to [simplifyCanvasPoints] from canvas_point_utils.dart.
  List<Map<String, double>> simplifyPoints(
    List<Map<String, double>> points, {
    double epsilon = 0.001,
  }) {
    return simplifyCanvasPoints(points, epsilon: epsilon);
  }
}
