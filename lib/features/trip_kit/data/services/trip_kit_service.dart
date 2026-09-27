import 'package:cloud_firestore/cloud_firestore.dart';

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
  factory TripKitService() => _instance;
  TripKitService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'travel_trips';

  /// All trips, newest first.
  Stream<List<Trip>> watchAll() {
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
  Future<String?> create(Trip trip) async {
    try {
      final ref = await _db.collection(_collection).add(trip.toFirestore());
      Logger.i('TripKit: created trip ${ref.id}');
      return ref.id;
    } catch (e) {
      Logger.e('TripKit: error creating trip', error: e);
      return null;
    }
  }

  /// Title / destination / dates / notes / budget total.
  Future<void> updateDetails(Trip trip) async {
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
    }
  }

  Future<void> updatePacking(String id, List<TripPackItem> packing) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'packing': packing.map((e) => e.toMap()).toList(),
      });
    } catch (e) {
      Logger.e('TripKit: error updating packing', error: e);
    }
  }

  Future<void> updateExpenses(String id, List<TripExpense> expenses) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'expenses': expenses.map((e) => e.toMap()).toList(),
      });
    } catch (e) {
      Logger.e('TripKit: error updating expenses', error: e);
    }
  }

  Future<void> updatePlaces(String id, List<TripPlace> places) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'places': places.map((e) => e.toMap()).toList(),
      });
    } catch (e) {
      Logger.e('TripKit: error updating places', error: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      Logger.i('TripKit: deleted trip $id');
    } catch (e) {
      Logger.e('TripKit: error deleting trip', error: e);
    }
  }
}
