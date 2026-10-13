import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/daily_bloom/data/services/garden_service.dart';
import '../../support/transaction_test_fakes.dart';

void main() {
  test(
    'overlapping watering and plant changes preserve every interaction and choice',
    () async {
      final db = TransactionFirestore({
        'totalInteractions': 10,
        'currentStage': 3,
        'streakCount': 1,
        'lastVisit': Timestamp.now(),
        'plantType': 'lily',
      });
      final service = GardenService(db: db);
      await Future.wait([
        service.recordInteraction('demo'),
        service.recordInteraction('demo'),
        service.setPlantType('demo', 'rose'),
      ]);
      expect(db.data!['totalInteractions'], 12);
      expect(db.data!['plantType'], 'rose');
      expect(db.retries, greaterThan(0));
    },
  );
}
