import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/calendar_event.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';

class CalendarService {
  static CalendarService? _instance;
  factory CalendarService({FirebaseFirestore? db}) {
    if (db != null) {
      return _instance = CalendarService._internal(db: db);
    }
    return _instance ??= CalendarService._internal();
  }
  CalendarService._internal({FirebaseFirestore? db}) : _customDb = db;

  final FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  final String _collection = 'calendar_events';

  List<CalendarEvent>? _cachedUpcoming;
  List<CalendarEvent>? get cachedUpcoming => _cachedUpcoming;

  final Map<int, _SharedUpcomingStream> _sharedUpcoming = {};
  /// Stream of events for a specific month.
  ///
  /// Re-attaches once when the first snapshot is slow: cold dashboard
  /// loads attach every preview at the same moment, and a single-shot
  /// budget flipped them all to the error state at once.
  Stream<List<CalendarEvent>> getEventsForMonth(DateTime month) {
    Stream<List<CalendarEvent>> subscribe() {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      return _db
          .collection(_collection)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('date', descending: false)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CalendarEvent.fromFirestore(doc))
                .toList(),
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
  /// Get upcoming events within N days. Wrapped with timeout so a slow
  /// Firestore WebChannel doesn't keep Coming Up in skeleton forever.
  ///
  /// Shares the active Firestore listener between multiple dashboard widgets
  /// (Coming Up + Upcoming Dates) so cold starts only attach ONE query
  /// instead of doubling WebChannel load.
  Stream<List<CalendarEvent>> getUpcomingEvents({int days = 30}) {
    final entry = _sharedUpcoming.putIfAbsent(days, () {
      late final _SharedUpcomingStream shared;
      shared = _SharedUpcomingStream(
        sourceFactory: () => _createUpcomingStream(days),
        onEmpty: () {
          _sharedUpcoming.remove(days);
        },
        onData: (data) {
          _cachedUpcoming = data;
        },
      );
      return shared;
    });

    return entry.stream;
  }

  Stream<List<CalendarEvent>> _createUpcomingStream(int days) {
    Stream<List<CalendarEvent>> subscribe() {
      final now = DateTime.now();
      final endDate = now.add(Duration(days: days));

      return _db
          .collection(_collection)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .limit(20)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CalendarEvent.fromFirestore(doc))
                .toList(),
          );
    }

    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'calendar-upcoming',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  /// Invalidate the upcoming cache and re-run active listeners if needed.
  void invalidateUpcomingCache() {
    _cachedUpcoming = null;
    for (final shared in _sharedUpcoming.values) {
      shared.restart();
    }
  }

  /// Add a new calendar event.
  Future<void> addEvent(CalendarEvent event) async {
    try {
      await _db.collection(_collection).add(event.toFirestore());
      Logger.i("Calendar event added: ${event.title}");
    } catch (e) {
      Logger.e("Error adding calendar event", error: e);
    }
  }

  /// Update an existing event.
  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    try {
      await _db.collection(_collection).doc(id).update(data);
    } catch (e) {
      Logger.e("Error updating calendar event", error: e);
    }
  }

  /// Delete an event.
  Future<void> deleteEvent(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i("Calendar event deleted: $id");
    } catch (e) {
      Logger.e("Error deleting calendar event", error: e);
    }
  }

  /// Get all events for a specific day.
  Future<List<CalendarEvent>> getEventsForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    try {
      final snapshot = await _db
          .collection(_collection)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => CalendarEvent.fromFirestore(doc))
          .toList();
    } catch (e) {
      Logger.e("Error getting events for day", error: e);
      return [];
    }
  }
}

class _SharedUpcomingStream {
  final Stream<List<CalendarEvent>> Function() sourceFactory;
  final void Function() onEmpty;
  final void Function(List<CalendarEvent>) onData;

  late final StreamController<List<CalendarEvent>> _controller;
  StreamSubscription<List<CalendarEvent>>? _sourceSub;
  List<CalendarEvent>? _lastData;

  _SharedUpcomingStream({
    required this.sourceFactory,
    required this.onEmpty,
    required this.onData,
  }) {
    _controller = StreamController<List<CalendarEvent>>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  Stream<List<CalendarEvent>> get stream => _controller.stream;

  void _onListen() {
    if (_lastData != null) {
      final cached = _lastData!;
      scheduleMicrotask(() {
        if (!_controller.isClosed && _controller.hasListener) {
          _controller.add(cached);
        }
      });
    }

    _sourceSub ??= sourceFactory().listen(
      (data) {
        _lastData = data;
        onData(data);
        if (!_controller.isClosed) {
          _controller.add(data);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!_controller.isClosed) {
          _controller.addError(error, stack);
        }
      },
      onDone: () {
        if (!_controller.isClosed) {
          _controller.close();
        }
      },
    );
  }

  void _onCancel() {
    if (!_controller.hasListener) {
      _sourceSub?.cancel();
      _sourceSub = null;
      onEmpty();
    }
  }

  void restart() {
    _sourceSub?.cancel();
    _sourceSub = null;
    _lastData = null;
    if (_controller.hasListener) {
      _onListen();
    }
  }
}
