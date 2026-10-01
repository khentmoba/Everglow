import 'package:everglow/features/calendar/data/services/calendar_service.dart';
import 'package:everglow/features/calendar/data/services/calendar_poll_service.dart';
import 'package:everglow/features/calendar/domain/models/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/firestore_test_fakes.dart';

CalendarEvent event(
  DateTime date, {
  String recurring = 'none',
  bool allDay = false,
}) => CalendarEvent(
  id: 'demo',
  title: 'Demo date',
  description: '',
  date: date,
  createdBy: 'demo',
  recurring: recurring,
  isAllDay: allDay,
);
void main() {
  test(
    'monthly/yearly recurrences expand, clamp month ends, and keep their anchor',
    () {
      final monthly = event(DateTime(2026, 1, 31, 19), recurring: 'monthly');
      final repeats = monthly.occurrencesBetween(
        DateTime(2026, 2),
        DateTime(2026, 4),
      );
      expect(repeats.map((e) => e.date), [
        DateTime(2026, 2, 28, 19),
        DateTime(2026, 3, 31, 19),
      ]);
      expect(repeats.every((e) => e.id == monthly.id), isTrue);
      final yearly = event(DateTime(2024, 2, 29), recurring: 'yearly');
      expect(
        yearly.occurrencesBetween(DateTime(2025), DateTime(2026)).single.date,
        DateTime(2025, 2, 28),
      );
      expect(
        yearly.occurrencesBetween(DateTime(2028), DateTime(2029)).single.date,
        DateTime(2028, 2, 29),
      );
      expect(
        monthly.occurrencesBetween(DateTime(2025), DateTime(2026)),
        isEmpty,
      );
      expect(
        monthly.occurrencesBetween(DateTime(2026, 2), DateTime(2026, 2)),
        isEmpty,
      );
    },
  );
  test(
    'upcoming includes today all-day events but excludes expired timed events',
    () async {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final entries = TestCollection(
        entries: [
          event(midnight, allDay: true).toFirestore(),
          event(midnight).toFirestore(),
          event(
            midnight.subtract(const Duration(days: 1)),
            allDay: true,
          ).toFirestore(),
        ],
      );
      final result = await CalendarService(
        db: TestFirestore(entries),
      ).getUpcomingEvents().first;
      expect(result, hasLength(1));
      expect(result.single.isAllDay, isTrue);
      expect(result.single.date, midnight);
    },
  );
  test(
    'month and day readers return repeated dates; end of month is exclusive',
    () async {
      final entries = TestCollection(
        entries: [
          event(DateTime(2026, 1, 15, 19), recurring: 'monthly').toFirestore(),
          event(DateTime(2026, 3)).toFirestore(),
        ],
      );
      final service = CalendarService(db: TestFirestore(entries));
      expect(
        (await service.getEventsForMonth(DateTime(2026, 2)).first).single.date,
        DateTime(2026, 2, 15, 19),
      );
      expect(
        (await service.getEventsForDay(DateTime(2026, 2, 15))).single.date,
        DateTime(2026, 2, 15, 19),
      );
    },
  );
  test('a rejected poll finalization is an atomic failed save', () async {
    final entries = TestCollection();
    final service = CalendarPollService(db: TestFirestore(entries));
    await expectLater(
      service.finalize('demo', 'winner', event(DateTime(2026))),
      throwsA(anything),
    );
    expect(entries.writeAttempts, 1);
  });

  test(
    'calendar mutations propagate write failures instead of reporting success',
    () async {
      final service = CalendarService(db: TestFirestore(TestCollection()));
      await expectLater(
        service.addEvent(event(DateTime(2026))),
        throwsA(anything),
      );
      await expectLater(service.updateEvent('demo', {}), throwsA(anything));
      await expectLater(service.deleteEvent('demo'), throwsA(anything));
    },
  );
}
