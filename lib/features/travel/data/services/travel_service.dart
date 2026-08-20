import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/trip.dart';

class TravelService {
  static final TravelService _instance = TravelService._internal();
  factory TravelService() => _instance;
  TravelService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _tripsCol = 'travel_trips';
  final String _pinsCol = 'travel_pins';

  Stream<List<Trip>> watchTrips() => withFirestoreTimeout(
        _db.collection(_tripsCol).orderBy('startDate', descending: false).limit(50).snapshots().map((s) => s.docs.map((d) => Trip.fromFirestore(d)).toList()),
        label: 'travel-trips',
      );

  Stream<List<TripPin>> watchPins(String tripId) => withFirestoreTimeout(
        _db.collection(_pinsCol).where('tripId', isEqualTo: tripId).orderBy('order').snapshots().map((s) => s.docs.map((d) => TripPin.fromFirestore(d)).toList()),
        label: 'travel-pins-$tripId',
      );

  Stream<List<TripPin>> watchAllPins() => withFirestoreTimeout(
        _db.collection(_pinsCol).limit(100).snapshots().map((s) => s.docs.map((d) => TripPin.fromFirestore(d)).toList()),
        label: 'travel-pins-all',
      );

  Future<void> addTrip(Trip trip) async {
    try {
      await _db.collection(_tripsCol).add(trip.toFirestore());
      Logger.i('Trip added: ${trip.title}');
    } catch (e) {
      Logger.e('Error adding trip', error: e);
    }
  }

  Future<void> updateTrip(Trip trip) async {
    try {
      await _db.collection(_tripsCol).doc(trip.id).update(trip.toFirestore());
    } catch (e) {
      Logger.e('Error updating trip', error: e);
    }
  }

  Future<void> deleteTrip(String id) async {
    try {
      await _db.collection(_tripsCol).doc(id).delete();
      // best-effort delete pins
      final pins = await _db.collection(_pinsCol).where('tripId', isEqualTo: id).get();
      for (final d in pins.docs) await d.reference.delete();
    } catch (e) {
      Logger.e('Error deleting trip', error: e);
    }
  }

  Future<void> addPin(TripPin pin) async {
    try {
      await _db.collection(_pinsCol).add(pin.toFirestore());
      Logger.i('Pin added: ${pin.title}');
    } catch (e) {
      Logger.e('Error adding pin', error: e);
    }
  }

  Future<void> updatePin(TripPin pin) async {
    try {
      await _db.collection(_pinsCol).doc(pin.id).update(pin.toFirestore());
    } catch (e) {
      Logger.e('Error updating pin', error: e);
    }
  }

  Future<void> deletePin(String id) async {
    try {
      await _db.collection(_pinsCol).doc(id).delete();
    } catch (e) {
      Logger.e('Error deleting pin', error: e);
    }
  }

  Future<void> toggleVisited(TripPin pin) async {
    try {
      await _db.collection(_pinsCol).doc(pin.id).update({'visitedAt': pin.isVisited ? FieldValue.delete() : Timestamp.now()});
    } catch (e) {
      Logger.e('Error toggling visited', error: e);
    }
  }

  // Auto-journal: create a journal entry stub linked to trip
  Future<void> autoJournalForTrip(Trip trip) async {
    try {
      // This is a hook — actual journal creation via JournalService could be called here.
      // For now just log.
      Logger.i('Auto-journal hook for trip ${trip.title}');
    } catch (e) {
      Logger.e('Auto journal failed', error: e);
    }
  }
}
