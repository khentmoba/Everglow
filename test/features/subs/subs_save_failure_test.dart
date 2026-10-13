import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/agent/agent_fixtures.dart';
import 'package:everglow/features/subs/data/services/subs_service.dart';
import '../../support/firestore_test_fakes.dart';

void main() {
  test(
    'subscription save, edit and removal propagate write failures',
    () async {
      final service = SubsService(db: TestFirestore(TestCollection()));
      final sub = AgentFixtures.demoSubscriptions.first;
      await expectLater(service.add(sub), throwsA(isA<FirebaseException>()));
      await expectLater(service.update(sub), throwsA(isA<FirebaseException>()));
      await expectLater(
        service.delete(sub.id),
        throwsA(isA<FirebaseException>()),
      );
    },
  );
}
