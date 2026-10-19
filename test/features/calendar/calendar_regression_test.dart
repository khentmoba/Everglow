// SDK sealed types are implemented only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class _LiveCollection extends TestCollection {
  _LiveCollection(List<Map<String, dynamic>> entries) : super(entries: entries);
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    late StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
    controller = StreamController(
      onListen: () => controller.add(TestSnapshot(entries)),
    );
    controller.onCancel = () {
      unawaited(controller.close());
    };
    return controller.stream;
  }
}

void main() {
  test(
    'late upcoming listeners receive dates while the dashboard stays subscribed',
    () async {
      final now = DateTime.now();
      final service = CalendarService(
        db: TestFirestore(
          _LiveCollection([
            event(now.add(const Duration(days: 1))).toFirestore(),
          ]),
        ),
      );
      final ready = Completer<void>();
      final dashboard = service.getUpcomingEvents(days: 60).listen((_) {
        if (!ready.isCompleted) ready.complete();
      });
      await ready.future;
      final calendar = await service
          .getUpcomingEvents(days: 60)
          .first
          .timeout(const Duration(seconds: 2));
      expect(calendar, hasLength(1));
      final reopened = await service
          .getUpcomingEvents(days: 60)
          .first
          .timeout(const Duration(seconds: 2));
      expect(reopened, hasLength(1));
      await dashboard.cancel();
    },
  );
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
