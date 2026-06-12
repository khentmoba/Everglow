import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/racing_match.dart';

class RacingMatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _matchesRef => _firestore.collection('racing_matches');

  Future<void> _cleanupStaleMatches() async {
    final staleTime = DateTime.now().subtract(const Duration(minutes: 30));
    final staleQuery = await _matchesRef
        .where('createdAt', isLessThan: Timestamp.fromDate(staleTime))
        .get();

    for (var doc in staleQuery.docs) {
      await doc.reference.delete();
    }
  }

  Future<RacingMatch> joinOrCreateMatch(String userId) async {
    await _cleanupStaleMatches();

    final waitingMatches = await _matchesRef
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (waitingMatches.docs.isNotEmpty) {
      final matchDoc = waitingMatches.docs.first;
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchDoc.reference);
        final match = RacingMatch.fromFirestore(snapshot);

        if (match.status == 'waiting' && match.hostId != userId) {
          final updatedMatch = match.copyWith(
            status: 'active',
            participantId: userId,
          );
          transaction.update(matchDoc.reference, updatedMatch.toMap());
          return updatedMatch;
        }
        throw Exception('Match no longer available');
      });
    }

    final newMatchDoc = _matchesRef.doc();
    final newMatch = RacingMatch(
      matchId: newMatchDoc.id,
      hostId: userId,
      participantId: null,
      status: 'waiting',
      createdAt: DateTime.now(),
    );

    await newMatchDoc.set(newMatch.toMap());
    return newMatch;
  }

  Future<void> setMatchStatus(String matchId, String status) async {
    await _matchesRef.doc(matchId).update({'status': status});
  }

  Future<void> submitFinishTime(String matchId, String userId, num time) async {
    final matchRef = _matchesRef.doc(matchId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(matchRef);
      final match = RacingMatch.fromFirestore(snapshot);

      final isHost = match.hostId == userId;
      bool shouldFinish = false;
      String? winnerId;

      if (isHost && match.hostTime == null) {
        transaction.update(matchRef, {'hostTime': time});
        if (match.participantTime != null) {
          shouldFinish = true;
          winnerId = _determineWinner(time, match.participantTime!, match.hostId, match.participantId!);
        }
      } else if (!isHost && match.participantTime == null) {
        transaction.update(matchRef, {'participantTime': time});
        if (match.hostTime != null) {
          shouldFinish = true;
          winnerId = _determineWinner(match.hostTime!, time, match.hostId, userId);
        }
      }

      if (shouldFinish) {
        transaction.update(matchRef, {
          'status': 'finished',
          'winnerId': winnerId,
        });
      }
    });
  }

  String? _determineWinner(num t1, num t2, String id1, String id2) {
    if (t1 < t2) return id1;
    if (t2 < t1) return id2;
    return 'draw';
  }

  Stream<DocumentSnapshot> watchMatch(String matchId) {
    return _matchesRef.doc(matchId).snapshots();
  }

  Future<void> updatePosition(String matchId, String userId, Map<String, dynamic> position) async {
    await _firestore.collection('racing_positions').doc('${matchId}_$userId').set({
      ...position,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot> watchPosition(String matchId, String userId) {
    return _firestore.collection('racing_positions').doc('${matchId}_$userId').snapshots();
  }
}
