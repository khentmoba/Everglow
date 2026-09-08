import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/calendar/data/services/calendar_service.dart';

void main() {
  group('CalendarService', () {
    test('is a singleton', () {
      final instance1 = CalendarService();
      final instance2 = CalendarService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('invalidateUpcomingCache clears cached upcoming events', () {
      final service = CalendarService();
      service.invalidateUpcomingCache();
      expect(service.cachedUpcoming, isNull);
    });
  });
}
