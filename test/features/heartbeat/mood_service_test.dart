import 'package:everglow/features/heartbeat/data/services/mood_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoodService.dateKeyFor', () {
    test('formats the device-local calendar day for server reads', () {
      expect(MoodService.dateKeyFor(DateTime(2026, 2, 14)), '2026-02-14');
      expect(MoodService.dateKeyFor(DateTime(2026, 9, 5, 23, 59)), '2026-09-05');
      // Just after midnight stays on the new day (no UTC shift).
      expect(MoodService.dateKeyFor(DateTime(2026, 9, 17, 0, 30)), '2026-09-17');
    });
  });
}
