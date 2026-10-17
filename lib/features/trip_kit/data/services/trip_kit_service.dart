import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';

import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/trip.dart';

/// Trip Kit service — one doc per lakad in `travel_trips` (couple-only).
///
/// Each section (details / packing / budget / places) updates its own
/// fields, so two people editing different sections never clobber each
/// other. Same-section races resolve last-write-wins — fine for a
/// packing checklist shared by two.
class TripKitService {
  static final TripKitService _instance = TripKitService._internal();
  factory TripKitService({FirebaseFirestore? db}) =>
      db == null ? _instance : TripKitService._internal(db);
  TripKitService._internal([this._customDb]);

  final FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  final String _collection = 'travel_trips';

  /// All trips, newest first.
  Stream<List<Trip>> watchAll() {
    if (AgentMode.isActive.value) return Stream.value(AgentFixtures.demoTrips);
    Stream<List<Trip>> subscribe() {
      return _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((snap) {
            final out = <Trip>[];
            for (final d in snap.docs) {
              try {
                out.add(Trip.fromFirestore(d));
              } catch (e) {
                Logger.e('TripKit: skipping malformed trip ${d.id}', error: e);
              }
            }
            return out;
          });
    }

    // Cold-start re-attach mirrors bucket-list / journal: the first
    // snapshot can lag while the WebChannel and auth token warm up.
    return withFirestoreTimeout(
      subscribe(),
      resubscribe: subscribe,
      label: 'trip-kit-all',
      duration: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }

  /// One trip page.
  Stream<Trip?> watchOne(String id) {
    if (AgentMode.isActive.value) {
      return Stream.value(
        AgentFixtures.demoTrips.where((t) => t.id == id).firstOrNull,
      );
    }
    return withFirestoreTimeout(
      _db.collection(_collection).doc(id).snapshots().map((doc) {
        if (!doc.exists) return null;
        try {
          return Trip.fromFirestore(doc);
        } catch (e) {
          Logger.e('TripKit: malformed trip $id', error: e);
          return null;
        }
      }),
      label: 'trip-kit-one',
    );
  }

  /// Create a trip; returns the new doc id for navigation.
  Future<String> create(Trip trip) async {
    if (AgentMode.isActive.value) return AgentFixtures.demoTrips.first.id;
    try {
      final ref = await _db.collection(_collection).add(trip.toFirestore());
      Logger.i('TripKit: created trip ${ref.id}');
      return ref.id;
    } catch (e) {
      Logger.e('TripKit: error creating trip', error: e);
      rethrow;
    }
  }

  /// Title / destination / dates / notes / budget total.
  Future<void> updateDetails(Trip trip) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection(_collection).doc(trip.id).update({
        'title': trip.title,
        'destination': trip.destination,
        'startDate': trip.startDate == null
            ? FieldValue.delete()
            : Timestamp.fromDate(trip.startDate!),
        'endDate': trip.endDate == null
            ? FieldValue.delete()
            : Timestamp.fromDate(trip.endDate!),
        'notes': trip.notes,
        'budgetTotal': trip.budgetTotal,
      });
      Logger.i('TripKit: updated details ${trip.id}');
    } catch (e) {
      Logger.e('TripKit: error updating details', error: e);
      rethrow;
    }
  }

  Future<void> addPackingItem(String tripId, TripPackItem item) =>
      _updateList<TripPackItem>(
        tripId,
        'packing',
        (trip) => trip.packing,
        (item) => item.toMap(),
        (items) => items.any((e) => e.id == item.id) ? items : [...items, item],
      );

  Future<void> setPackingItemPacked(
    String tripId,
    String itemId,
    bool packed, {
    String? packedBy,
  }) => _updateList<TripPackItem>(
    tripId,
    'packing',
    (trip) => trip.packing,
    (item) => item.toMap(),
    (items) => items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(packed: packed, packedBy: packedBy)
              : item,
        )
        .toList(),
  );

  Future<void> removePackingItem(String tripId, String itemId) =>
      _updateList<TripPackItem>(
        tripId,
        'packing',
        (trip) => trip.packing,
        (item) => item.toMap(),
        (items) => items.where((item) => item.id != itemId).toList(),
      );

  Future<void> addExpense(String tripId, TripExpense expense) =>
      _updateList<TripExpense>(
        tripId,
        'expenses',
        (trip) => trip.expenses,
        (expense) => expense.toMap(),
        (items) =>
            items.any((e) => e.id == expense.id) ? items : [...items, expense],
      );

  Future<void> removeExpense(String tripId, String expenseId) =>
      _updateList<TripExpense>(
        tripId,
        'expenses',
        (trip) => trip.expenses,
        (expense) => expense.toMap(),
        (items) => items.where((expense) => expense.id != expenseId).toList(),
      );

  Future<void> addPlace(String tripId, TripPlace place) =>
      _updateList<TripPlace>(
        tripId,
        'places',
        (trip) => trip.places,
        (place) => place.toMap(),
        (items) =>
            items.any((e) => e.id == place.id) ? items : [...items, place],
      );

  Future<void> setPlaceDone(String tripId, String placeId, bool done) =>
      _updateList<TripPlace>(
        tripId,
        'places',
        (trip) => trip.places,
        (place) => place.toMap(),
        (items) => items
            .map(
              (place) =>
                  place.id == placeId ? place.copyWith(done: done) : place,
            )
            .toList(),
      );

  Future<void> removePlace(String tripId, String placeId) =>
      _updateList<TripPlace>(
        tripId,
        'places',
        (trip) => trip.places,
        (place) => place.toMap(),
        (items) => items.where((place) => place.id != placeId).toList(),
      );

  Future<void> _updateList<T>(
    String id,
    String field,
    List<T> Function(Trip) select,
    Map<String, dynamic> Function(T) toMap,
    List<T> Function(List<T>) change,
  ) async {
    if (AgentMode.isActive.value) return;
    try {
      final ref = _db.collection(_collection).doc(id);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw StateError('Trip $id no longer exists');
        }
        final trip = Trip.fromMap(data, id);
        transaction.update(ref, {
          field: change(select(trip)).map(toMap).toList(),
        });
      });
    } catch (e) {
      Logger.e('TripKit: error updating $field for $id', error: e);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    if (AgentMode.isActive.value) return;
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i('TripKit: deleted trip $id');
    } catch (e) {
      Logger.e('TripKit: error deleting trip', error: e);
      rethrow;
    }
  }
}
