import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/doodle_stroke.dart';

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

  /// Simplifies a list of points using the Ramer-Douglas-Peucker algorithm.
  List<Map<String, double>> simplifyPoints(List<Map<String, double>> points, {double epsilon = 0.001}) {
    if (points.length <= 2) return points;

    int index = -1;
    double maxDist = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double dist = _perpendicularDistance(points[i], points.first, points.last);
      if (dist > maxDist) {
        index = i;
        maxDist = dist;
      }
    }

    if (maxDist > epsilon) {
      var left = simplifyPoints(points.sublist(0, index + 1), epsilon: epsilon);
      var right = simplifyPoints(points.sublist(index), epsilon: epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points.first, points.last];
    }
  }

  double _perpendicularDistance(Map<String, double> p, Map<String, double> a, Map<String, double> b) {
    double x = p['x']!, y = p['y']!;
    double x1 = a['x']!, y1 = a['y']!;
    double x2 = b['x']!, y2 = b['y']!;

    double dx = x2 - x1;
    double dy = y2 - y1;
    
    if (dx == 0 && dy == 0) {
      return (x - x1) * (x - x1) + (y - y1) * (y - y1);
    }

    double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0);
    
    double nearestX = x1 + t * dx;
    double nearestY = y1 + t * dy;

    return (x - nearestX) * (x - nearestX) + (y - nearestY) * (y - nearestY);
  }
}
