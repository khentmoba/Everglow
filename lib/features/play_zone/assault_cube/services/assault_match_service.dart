import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/services/auth_service.dart';
import '../models/assault_match.dart';
import '../models/assault_player_state.dart';

class AssaultMatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration matchStaleAfter = Duration(hours: 1);

  CollectionReference get _matchesRef => _firestore.collection('assault_matches');

  bool isAllowedPlayer(String uid) {
    return uid == AuthService.khentUid || uid == AuthService.clairUid;
  }

  Future<void> _cleanupStaleMatches() async {
    final cutoff = DateTime.now().subtract(matchStaleAfter);
    final stale = await _matchesRef
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    for (final doc in stale.docs) {
      await doc.reference.delete();
    }
  }

  Future<AssaultMatch> joinOrCreateMatch(String userId) async {
    if (!isAllowedPlayer(userId)) {
      throw Exception('AssaultCube 1v1 is reserved for Khent & Clair only.');
    }

    await _cleanupStaleMatches();

    final waiting = await _matchesRef
        .where('status', isEqualTo: AssaultMatchStatus.waiting.name)
        .where('hostId', whereIn: [
          AuthService.khentUid,
          AuthService.clairUid,
        ])
        .limit(1)
        .get();

    if (waiting.docs.isNotEmpty) {
      final matchDoc = waiting.docs.first;
      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(matchDoc.reference);
        final match = AssaultMatch.fromFirestore(snap);

        if (match.status == AssaultMatchStatus.waiting &&
            match.hostId != userId &&
            isAllowedPlayer(match.hostId)) {
          final updated = match.copyWith(
            participantId: userId,
            status: AssaultMatchStatus.active,
            startedAt: DateTime.now(),
          );
          tx.update(matchDoc.reference, updated.toMap());
          return updated;
        }
        throw Exception('Match no longer available');
      });
    }

    final newDoc = _matchesRef.doc();
    final match = AssaultMatch(
      matchId: newDoc.id,
      hostId: userId,
      status: AssaultMatchStatus.waiting,
      createdAt: DateTime.now(),
    );
    await newDoc.set(match.toMap());
    return match;
  }

  Future<void> setStatus(String matchId, AssaultMatchStatus status) async {
    await _matchesRef.doc(matchId).update({'status': status.name});
  }

  Future<void> updatePlayerState(String matchId, AssaultPlayerState state) async {
    final ref = _firestore
        .collection('assault_player_states')
        .doc('${matchId}_${state.userId}');
    await ref.set(state.toMap(), SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> watchOpponentState(String matchId, String opponentId) {
    return _firestore
        .collection('assault_player_states')
        .doc('${matchId}_$opponentId')
        .snapshots();
  }

  Future<void> pushShot(String matchId, AssaultShot shot) async {
    final ref = _firestore
        .collection('assault_matches')
        .doc(matchId)
        .collection('shots')
        .doc(shot.id);
    await ref.set(shot.toMap());
  }

  Stream<QuerySnapshot> watchShots(String matchId, {DateTime? since}) {
    Query query = _firestore
        .collection('assault_matches')
        .doc(matchId)
        .collection('shots')
        .orderBy('createdAt', descending: false);

    if (since != null) {
      query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
    }

    return query.snapshots();
  }

  Future<void> applyDamage({
    required String matchId,
    required String victimId,
    required int newHp,
  }) async {
    final matchRef = _matchesRef.doc(matchId);
    final match = AssaultMatch.fromFirestore(
      await matchRef.get(),
    );

    final isHost = match.hostId == victimId;
    final updates = <String, dynamic>{
      isHost ? 'hostHp' : 'participantHp': newHp,
    };

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(matchRef);
      final m = AssaultMatch.fromFirestore(snap);
      tx.update(matchRef, updates);

      if (newHp <= 0 && m.status == AssaultMatchStatus.active) {
        final winnerId = isHost ? m.participantId : m.hostId;
        final kills = isHost
            ? m.participantKills + 1
            : m.hostKills + 1;
        tx.update(matchRef, {
          'status': AssaultMatchStatus.finished.name,
          'finishedAt': FieldValue.serverTimestamp(),
          'winnerId': winnerId,
          'loserId': victimId,
          isHost ? 'participantKills' : 'hostKills': kills,
        });
      }
    });
  }

  Future<void> recordKill(String matchId, String killerId) async {
    final matchRef = _matchesRef.doc(matchId);
    final match = AssaultMatch.fromFirestore(await matchRef.get());
    final isHost = match.hostId == killerId;
    await matchRef.update({
      isHost ? 'hostKills' : 'participantKills':
          (isHost ? match.hostKills : match.participantKills) + 1,
    });
  }

  Future<void> resignMatch(String matchId) async {
    final matchRef = _matchesRef.doc(matchId);
    final snap = await matchRef.get();
    final match = AssaultMatch.fromFirestore(snap);
    if (match.status != AssaultMatchStatus.active) return;

    await matchRef.update({
      'status': AssaultMatchStatus.finished.name,
      'finishedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot> watchMatch(String matchId) {
    return _matchesRef.doc(matchId).snapshots();
  }

  Future<void> resetMatchForRematch(String matchId) async {
    await _matchesRef.doc(matchId).update({
      'status': AssaultMatchStatus.active.name,
      'hostHp': 100,
      'participantHp': 100,
      'hostKills': 0,
      'participantKills': 0,
      'winnerId': null,
      'loserId': null,
      'finishedAt': null,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }
}
