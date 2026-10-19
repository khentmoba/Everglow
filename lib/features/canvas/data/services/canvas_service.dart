import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../domain/models/doodle_stroke.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import 'canvas_point_utils.dart';

class CanvasService {
  CanvasService({FirebaseFirestore? db}) : _customDb = db;

  final FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  final String _collection = 'canvas_strokes';

  Stream<List<DoodleStroke>> getStrokesStream() {
    if (AgentMode.isActive.value) return Stream.value(const []);
    Stream<List<DoodleStroke>> subscribe() async* {
      var limit = 300;
      final query = _db.collection(_collection).orderBy('createdAt');
      while (true) {
        var needsMore = false;
        await for (final snapshot in query.limit(limit).snapshots()) {
          if (snapshot.docs.length == limit) {
            limit *= 2;
            needsMore = true;
            break;
          }
          yield snapshot.docs.map(DoodleStroke.fromFirestore).toList();
        }
        if (!needsMore) return;
      }
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'canvas-strokes',
    );
  }

  Future<DoodleStroke> saveStroke(DoodleStroke stroke) async {
    if (AgentMode.isActive.value) return stroke.copyWith(id: 'demo-stroke');
    final ref = await _db.collection(_collection).add(stroke.toMap());
    return stroke.copyWith(id: ref.id);
  }

  Future<void> deleteStroke(String id) async {
    if (AgentMode.isActive.value) return;
    await _db.collection(_collection).doc(id).delete();
  }

  // --- Live Drawing Support ---

  Future<void> updateActiveStroke(String userId, DoodleStroke stroke) async {
    if (AgentMode.isActive.value) return;
    await _db.collection('live_canvas').doc(userId).set(stroke.toMap());
  }

  Future<void> clearActiveStroke(String userId) async {
    if (AgentMode.isActive.value) return;
    await _db.collection('live_canvas').doc(userId).delete();
  }

  Stream<List<DoodleStroke>> getLiveStrokesStream() {
    if (AgentMode.isActive.value) return Stream.value(const []);
    return withFirestoreTimeout(
      _db
          .collection('live_canvas')
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => DoodleStroke.fromFirestore(doc))
                .toList(),
          ),
      label: 'canvas-live',
    );
  }

  Future<void> clearAllStrokes() async {
    if (AgentMode.isActive.value) return;
    // Fire-and-forget from a dialog with no await: failures must log,
    // not surface as unhandled async errors.
    try {
      await _deleteInBatches(
        (await withGetTimeout(
          _db.collection(_collection).get(),
          label: 'canvas clear strokes',
        )).docs.map((doc) => doc.reference).toList(),
      );
      await _deleteInBatches(
        (await withGetTimeout(
          _db.collection('live_canvas').get(),
          label: 'canvas clear live',
        )).docs.map((doc) => doc.reference).toList(),
      );
    } catch (e) {
      Logger.e('Canvas clearAllStrokes failed', error: e);
    }
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
