import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../domain/models/milestone.dart';

class MilestoneService {
  static final MilestoneService _instance = MilestoneService._internal();
  factory MilestoneService() => _instance;
  MilestoneService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Milestone>> get milestones {
    return milestonesPreview(limit: 500);
  }

  Stream<List<Milestone>> milestonesPreview({int limit = 50}) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoMilestones);
    }
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

  Future<void> addMilestone(Milestone milestone) async {
    if (AgentMode.isActive.value) return;
    await _db.collection('milestones').add(milestone.toFirestore());
  }

  Future<int> repairLegacyAssetPaths() async {
    if (AgentMode.isActive.value) return 0;
    final snapshot = await withGetTimeout(
      _db.collection('milestones').get(),
      label: 'milestone legacy repair scan',
    );
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
