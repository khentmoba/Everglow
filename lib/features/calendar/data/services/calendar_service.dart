import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/calendar_event.dart';

class CalendarService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'calendar_events';

  /// Stream of events for a specific month.
  Stream<List<CalendarEvent>> getEventsForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _db
        .collection(_collection)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEvent.fromFirestore(doc))
            .toList());
  }

  /// Get upcoming events within N days.
  Stream<List<CalendarEvent>> getUpcomingEvents({int days = 30}) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));

    return _db
        .collection(_collection)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: false)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEvent.fromFirestore(doc))
            .toList());
  }

  /// Add a new calendar event.
  Future<void> addEvent(CalendarEvent event) async {
    try {
      await _db.collection(_collection).add(event.toFirestore());
      print("Calendar event added: ${event.title}");
    } catch (e) {
      print("Error adding calendar event: $e");
    }
  }

  /// Update an existing event.
  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    try {
      await _db.collection(_collection).doc(id).update(data);
    } catch (e) {
      print("Error updating calendar event: $e");
    }
  }

  /// Delete an event.
  Future<void> deleteEvent(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      print("Calendar event deleted: $id");
    } catch (e) {
      print("Error deleting calendar event: $e");
    }
  }

  /// Get all events for a specific day.
  Future<List<CalendarEvent>> getEventsForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    try {
      final snapshot = await _db
          .collection(_collection)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => CalendarEvent.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Error getting events for day: $e");
      return [];
    }
  }
}
