import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/calendar/domain/models/calendar_event.dart';

void main() {
  group('CalendarEvent', () {
    test('constructor stores all fields correctly', () {
      final date = DateTime(2026, 6, 15, 19, 0);
      final endDate = DateTime(2026, 6, 15, 22, 0);

      final event = CalendarEvent(
        id: 'evt1',
        title: 'Movie Night',
        description: 'Watch something cozy',
        date: date,
        endDate: endDate,
        type: CalendarEventType.dateNight,
        createdBy: 'Khent',
        color: '#FFC0CB',
        recurring: 'monthly',
      );

      expect(event.id, 'evt1');
      expect(event.title, 'Movie Night');
      expect(event.description, 'Watch something cozy');
      expect(event.date, date);
      expect(event.endDate, endDate);
      expect(event.type, CalendarEventType.dateNight);
      expect(event.createdBy, 'Khent');
      expect(event.color, '#FFC0CB');
      expect(event.recurring, 'monthly');
    });

    test('defaults to custom type and no recurrence', () {
      final event = CalendarEvent(
        id: 'evt2',
        title: 'Random',
        description: '',
        date: DateTime(2026, 1, 1),
        createdBy: 'Clair',
      );

      expect(event.type, CalendarEventType.custom);
      expect(event.recurring, 'none');
      expect(event.endDate, isNull);
      expect(event.color, isNull);
    });

    test('toFirestore returns correct map', () {
      final date = DateTime(2026, 3, 14);
      final event = CalendarEvent(
        id: 'evt3',
        title: 'Anniversary',
        description: 'Our special day',
        date: date,
        type: CalendarEventType.anniversary,
        createdBy: 'Khent',
        recurring: 'yearly',
      );

      final map = event.toFirestore();

      expect(map['title'], 'Anniversary');
      expect(map['description'], 'Our special day');
      expect(map['type'], 'anniversary');
      expect(map['createdBy'], 'Khent');
      expect(map['recurring'], 'yearly');
      expect(map['color'], isNull); // not set
      expect(map['endDate'], isNull); // not set
    });

    test('toFirestore includes endDate when set', () {
      final event = CalendarEvent(
        id: 'evt4',
        title: 'Trip',
        description: 'Beach weekend',
        date: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 3),
        createdBy: 'Clair',
      );

      final map = event.toFirestore();

      expect(map['endDate'], isNotNull);
    });

    test('all CalendarEventType values are valid', () {
      for (final type in CalendarEventType.values) {
        expect(type.name, isNotEmpty);
      }
    });

    test('calendarEventTypeInfo has entry for every type', () {
      for (final type in CalendarEventType.values) {
        expect(
          calendarEventTypeInfo.containsKey(type),
          isTrue,
          reason: 'Missing info for ${type.name}',
        );
      }
    });

    test('calendarEventTypeInfo has emoji and label for each type', () {
      calendarEventTypeInfo.forEach((type, info) {
        expect(
          info.$1,
          isNotEmpty,
          reason: '${type.name} should have an emoji',
        );
        expect(info.$2, isNotEmpty, reason: '${type.name} should have a label');
      });
    });
  });
}
