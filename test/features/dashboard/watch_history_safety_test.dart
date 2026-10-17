import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opening the dashboard cannot run the destructive partner migration', () {
    // Both partners legitimately watching a title is not evidence of a bad row.
    for (final path in [
      'lib/features/dashboard/presentation/screens/dashboard_screen.dart',
      'lib/features/cinema/data/services/tmdb_service.dart',
      'lib/features/cinema/data/services/tmdb/tmdb_watchlist_service.dart',
    ]) {
      expect(
        File(path).readAsStringSync().contains('cleanupDuplicatePartnerEntries'),
        isFalse,
        reason: '$path must never delete shared watch history on startup',
      );
    }
  });
}
