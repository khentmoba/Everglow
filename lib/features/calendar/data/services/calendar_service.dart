import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/calendar_event.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';

class CalendarService {
  static CalendarService? _instance;
  factory CalendarService({FirebaseFirestore? db}) {
    if (db != null) {
      return CalendarService._internal(db: db);
    }
    return _instance ??= CalendarService._internal();
  }
  CalendarService._internal({FirebaseFirestore? db}) : _customDb = db;

  final FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  final String _collection = 'calendar_events';

  List<CalendarEvent>? _cachedUpcoming;
  List<CalendarEvent>? get cachedUpcoming => _cachedUpcoming;

  // ponytail: capped at 100 saved entries; add pagination if the calendar outgrows this.
  Query<Map<String, dynamic>> _eventsQuery(DateTime start, DateTime end) => _db
      .collection(_collection)
      .where(
        Filter.or(
          Filter.and(
            Filter('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start)),
            Filter('date', isLessThan: Timestamp.fromDate(end)),
          ),
          Filter('recurring', whereIn: ['monthly', 'yearly']),
        ),
      )
      .orderBy('date')
      .limit(100);

  List<CalendarEvent> _expandEvents(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    DateTime start,
    DateTime end,
  ) => [
    for (final doc in snapshot.docs)
      ...CalendarEvent.fromFirestore(doc).occurrencesBetween(start, end),
  ]..sort((a, b) => a.date.compareTo(b.date));

  /// Stream of events for a specific month.
  ///
  /// Re-attaches once when the first snapshot is slow: cold dashboard
  /// loads attach every preview at the same moment, and a single-shot
  /// budget flipped them all to the error state at once.
  Stream<List<CalendarEvent>> getEventsForMonth(DateTime month) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoEvents);
    }

    Stream<List<CalendarEvent>> subscribe() {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1);
      return _eventsQuery(startOfMonth, endOfMonth).snapshots().map(
        (snapshot) => _expandEvents(snapshot, startOfMonth, endOfMonth),
      );
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'calendar-month',
      duration: const Duration(seconds: 8),
    );
  }

  /// Get upcoming events within N days. Wrapped with timeout so a slow
  /// Firestore WebChannel doesn't keep Coming Up in skeleton forever.
  ///
  /// Silently re-attaches up to twice when the first snapshot is slow:
  /// this stream backs both the Coming Up and the Upcoming Dates previews,
  /// which were the most frequent false errors. Cold dashboard loads attach
  /// every preview in the same tick while the WebChannel, the auth token,
  /// and the `isCouple()` rule check are all still warming up, so a single
  /// 8s budget expired before the server could answer and the card wrongly
  /// asked for a manual retry. 12s x 3 attempts keeps the loading state up
  /// while a slow first load still has a chance; only a persistent failure
  /// surfaces as an error.
  /// Each caller gets its own initial snapshot, including late subscribers.
  Stream<List<CalendarEvent>> getUpcomingEvents({int days = 30}) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return Stream.value(AgentFixtures.demoEvents);
    }

    Stream<List<CalendarEvent>> subscribe() {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final endDate = now.add(Duration(days: days));
      return _eventsQuery(start, endDate).snapshots().map(
        (snapshot) => _expandEvents(snapshot, start, endDate)
            .where((event) => event.isAllDay || !event.date.isBefore(now))
            .take(20)
            .toList(),
      );
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'calendar-upcoming',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    ).map((events) {
      _cachedUpcoming = events;
      return events;
    });
  }

  /// Discard the cache; active Firestore listeners keep receiving updates.
  void invalidateUpcomingCache() {
    _cachedUpcoming = null;
  }

  /// Add a new calendar event.
  Future<void> addEvent(CalendarEvent event) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection(_collection).add(event.toFirestore());
      Logger.i("Calendar event added: ${event.title}");
    } catch (e) {
      Logger.e("Error adding calendar event", error: e);
      rethrow;
    }
  }

  /// Update an existing event.
  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection(_collection).doc(id).update(data);
    } catch (e) {
      Logger.e("Error updating calendar event", error: e);
      rethrow;
    }
  }

  /// Delete an event.
  Future<void> deleteEvent(String id) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i("Calendar event deleted: $id");
    } catch (e) {
      Logger.e("Error deleting calendar event", error: e);
      rethrow;
    }
  }

  /// Get all events for a specific day.
  Future<List<CalendarEvent>> getEventsForDay(DateTime day) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return AgentFixtures.demoEvents;
    }

    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day + 1);

    try {
      final snapshot = await withGetTimeout(
        _eventsQuery(startOfDay, endOfDay).get(),
        label: 'calendar events for day',
      );

      return _expandEvents(snapshot, startOfDay, endOfDay);
    } catch (e) {
      Logger.e("Error getting events for day", error: e);
      return [];
    }
  }
}
