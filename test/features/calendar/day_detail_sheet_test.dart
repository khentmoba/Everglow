import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/calendar/domain/models/calendar_event.dart';
import 'package:everglow/features/calendar/presentation/widgets/day_detail_sheet.dart';

void main() {
  Widget buildTestableSheet({
    required DateTime day,
    required VoidCallback onEventAdded,
    Stream<List<CalendarEvent>>? eventsStream,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DayDetailSheet(
          day: day,
          onEventAdded: onEventAdded,
          eventsStream: eventsStream,
        ),
      ),
    );
  }

  group('DayDetailSheet', () {
    testWidgets('renders empty state with warm copy and quick-add chips',
        (tester) async {
      final testDay = DateTime(2026, 9, 25);
      final streamController = StreamController<List<CalendarEvent>>();

      await tester.pumpWidget(
        buildTestableSheet(
          day: testDay,
          onEventAdded: () {},
          eventsStream: streamController.stream,
        ),
      );

      // Emit empty events list
      streamController.add([]);
      await tester.pumpAndSettle();

      // Check header date
      expect(find.text('September 25, 2026'), findsOneWidget);
      expect(find.text('Friday'), findsOneWidget);

      // Check empty state
      expect(find.text('No plans set for this day'), findsOneWidget);
      expect(find.text('Plan Something Special'), findsOneWidget);
      expect(find.text('QUICK ADD'), findsOneWidget);
      expect(find.text('Date Night'), findsOneWidget);
      expect(find.text('Anniversary'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      await streamController.close();
    });

    testWidgets('renders events list when day has scheduled events',
        (tester) async {
      final testDay = DateTime(2026, 9, 25);
      final events = [
        CalendarEvent(
          id: 'event-1',
          title: 'Candlelight Dinner with Clair',
          description: 'Special rooftop dinner at our favorite spot',
          date: DateTime(2026, 9, 25, 19, 30),
          type: CalendarEventType.dateNight,
          createdBy: 'khent',
          location: 'Skyline Garden',
          attendees: const ['Khent', 'Clair'],
        ),
        CalendarEvent(
          id: 'event-2',
          title: 'Love Note Reminder',
          description: 'Hide a little sweet note for her',
          date: DateTime(2026, 9, 25, 9, 0),
          type: CalendarEventType.reminder,
          createdBy: 'khent',
        ),
      ];

      final streamController = StreamController<List<CalendarEvent>>();

      await tester.pumpWidget(
        buildTestableSheet(
          day: testDay,
          onEventAdded: () {},
          eventsStream: streamController.stream,
        ),
      );

      streamController.add(events);
      await tester.pumpAndSettle();

      expect(find.text('September 25, 2026'), findsOneWidget);
      expect(find.text('Candlelight Dinner with Clair'), findsOneWidget);
      expect(
        find.text('Special rooftop dinner at our favorite spot'),
        findsOneWidget,
      );
      expect(find.text('Skyline Garden'), findsOneWidget);
      expect(find.text('Khent, Clair'), findsOneWidget);
      expect(find.text('Love Note Reminder'), findsOneWidget);

      // Verify empty state is NOT shown
      expect(find.text('No plans set for this day'), findsNothing);

      await streamController.close();
    });

    testWidgets('renders Today relative badge when day is today',
        (tester) async {
      final today = DateTime.now();
      final streamController = StreamController<List<CalendarEvent>>();

      await tester.pumpWidget(
        buildTestableSheet(
          day: today,
          onEventAdded: () {},
          eventsStream: streamController.stream,
        ),
      );

      streamController.add([]);
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('A quiet day together'), findsOneWidget);

      await streamController.close();
    });
  });
}
