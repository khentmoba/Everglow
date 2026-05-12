import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/milestone.dart';

class MilestoneService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of all milestones, shared globally, ordered by date ascending
  Stream<List<Milestone>> get milestones {
    return _db
        .collection('milestones')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Milestone.fromFirestore(doc)).toList();
    });
  }

  // Helper to add a milestone (for dev seeding and future admin use)
  Future<void> addMilestone(Milestone milestone) async {
    await _db.collection('milestones').add(milestone.toFirestore());
  }
}
