import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/milestone.dart';
import '../../../../core/utils/firestore_stream_utils.dart';

class MilestoneService {
  static final MilestoneService _instance = MilestoneService._internal();
  factory MilestoneService() => _instance;
  MilestoneService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of all milestones, shared globally, ordered by date ascending
  Stream<List<Milestone>> get milestones {
    return milestonesPreview(limit: 500);
  }

  // Capped preview for the dashboard carousel: the rail shows a handful
  // of cards, so holding the full 500-doc realtime stream open on every
  // dashboard visit is pure scroll-jank fuel. Full history stays
  // available via [milestones] for archive/admin surfaces.
  Stream<List<Milestone>> milestonesPreview({int limit = 50}) {
    return withFirestoreTimeout(
      _db
          .collection('milestones')
          .orderBy('date', descending: false)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Milestone.fromFirestore(doc))
                .toList();
          }),
      label: 'milestones-preview',
    );
  }

  // Helper to add a milestone (for dev seeding and future admin use)
  Future<void> addMilestone(Milestone milestone) async {
    await _db.collection('milestones').add(milestone.toFirestore());
  }
}
