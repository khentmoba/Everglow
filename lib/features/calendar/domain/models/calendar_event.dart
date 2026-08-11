import 'package:cloud_firestore/cloud_firestore.dart';

enum CalendarEventType { dateNight, anniversary, reminder, custom }

const Map<CalendarEventType, (String emoji, String label)>
calendarEventTypeInfo = {
  CalendarEventType.dateNight: ('💑', 'Date Night'),
  CalendarEventType.anniversary: ('💍', 'Anniversary'),
  CalendarEventType.reminder: ('⏰', 'Reminder'),
  CalendarEventType.custom: ('📌', 'Custom'),
};

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final DateTime? endDate;
  final CalendarEventType type;
  final String createdBy;
  final String? color;
  final String recurring; // 'none', 'monthly', 'yearly'

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.endDate,
    this.type = CalendarEventType.custom,
    required this.createdBy,
    this.color,
    this.recurring = 'none',
  });

  factory CalendarEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarEvent(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: _parseTimestamp(data['date']),
      endDate: data['endDate'] != null
          ? _parseTimestamp(data['endDate'])
          : null,
      type: _parseType(data['type']),
      createdBy: data['createdBy'] ?? '',
      color: data['color'],
      recurring: data['recurring'] ?? 'none',
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static CalendarEventType _parseType(dynamic value) {
    if (value == null) return CalendarEventType.custom;
    for (final t in CalendarEventType.values) {
      if (t.name == value) return t;
    }
    return CalendarEventType.custom;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'type': type.name,
      'createdBy': createdBy,
      'color': color,
      'recurring': recurring,
    };
  }
}
