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
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DoodleStroke.fromFirestore(doc))
            .toList());
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
    return _db.collection('live_canvas').snapshots().map((snapshot) => 
      snapshot.docs.map((doc) => DoodleStroke.fromFirestore(doc)).toList());
  }

  Future<void> clearAllStrokes() async {
    final snapshot = await _db.collection(_collection).get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Delegates to [simplifyCanvasPoints] from canvas_point_utils.dart.
  List<Map<String, double>> simplifyPoints(List<Map<String, double>> points, {double epsilon = 0.001}) {
    return simplifyCanvasPoints(points, epsilon: epsilon);
  }
}
