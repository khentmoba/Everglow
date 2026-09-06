import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../domain/models/milestone.dart';

class MilestoneService {
  static final MilestoneService _instance = MilestoneService._internal();
  factory MilestoneService() => _instance;
  MilestoneService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of all milestones, shared globally, ordered by date ascending
  Stream<List<Milestone>> get milestones {
    return withFirestoreTimeout(
      _db
          .collection('milestones')
          .orderBy('date', descending: false)
          .limit(500)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Milestone.fromFirestore(doc))
                .toList();
          }),
      label: 'milestones',
    );
  }

  // Helper to add a milestone (for dev seeding and future admin use)
  Future<void> addMilestone(Milestone milestone) async {
    await _db.collection('milestones').add(milestone.toFirestore());
  }

  /// One-time repair for docs saved before milestone photos were renamed
  /// from `.png` to `.jpg`. Rewrites only stale `imageUrls`, leaves every
  /// other field untouched, and returns how many docs were repaired.
  Future<int> repairLegacyAssetPaths() async {
    final snapshot = await _db.collection('milestones').get();
    var repaired = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final urls = (data['imageUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList();
      if (urls == null) continue;
      final fixed = urls.map(Milestone.repairLegacyImageUrl).toList();
      var changed = false;
      for (var i = 0; i < urls.length; i++) {
        if (urls[i] != fixed[i]) {
          changed = true;
          break;
        }
      }
      if (changed) {
        await doc.reference.update({'imageUrls': fixed});
        repaired++;
      }
    }
    return repaired;
  }
}
