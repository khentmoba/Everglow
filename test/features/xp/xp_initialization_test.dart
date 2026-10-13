import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/xp/data/services/xp_service.dart';
import '../../support/transaction_test_fakes.dart';

void main() {
  test(
    'initialization preserves an award that lands before its commit',
    () async {
      final db = TransactionFirestore();
      db.beforeCommit = () {
        db.data = {
          'xpTotal': 30,
          'dailyXp': {
            'today': {'journal': 1},
          },
        };
        db.revision++;
      };
      await XPService.withFirestore(db).initializeProgress('demo');
      expect(db.data!['xpTotal'], 30);
      expect(db.data!['dailyXp'], {
        'today': {'journal': 1},
      });
      expect(db.retries, 1);
    },
  );
}
