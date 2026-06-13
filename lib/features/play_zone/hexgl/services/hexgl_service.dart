import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../services/auth_service.dart';
import '../models/hexgl_challenge.dart';
import '../models/hexgl_race_result.dart';

class HexGLService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String defaultTrackId = 'cityscape';
  static const Duration challengeTtl = Duration(days: 14);

  CollectionReference get _bestsRef =>
      _firestore.collection('hexgl_best_times');

  CollectionReference get _challengesRef =>
      _firestore.collection('hexgl_challenges');

  bool isAllowedPlayer(String? uid) {
    return uid == AuthService.khentUid || uid == AuthService.clairUid;
  }

  // ---------------- Best times ----------------

  DocumentReference _bestDoc(String userId, String trackId) {
    return _bestsRef.doc('${trackId}_$userId');
  }

  Future<HexGLRaceResult?> getBestTime({
    required String userId,
    required String trackId,
  }) async {
    final snap = await _bestDoc(userId, trackId).get();
    if (!snap.exists) return null;
    final map = snap.data() as Map<String, dynamic>?;
    if (map == null) return null;
    return HexGLRaceResult.fromMap(map);
  }

  Future<Map<String, HexGLRaceResult>> getBestTimesForTrack(
    String trackId,
  ) async {
    final snap = await _bestsRef.where('trackId', isEqualTo: trackId).get();
    final out = <String, HexGLRaceResult>{};
    for (final doc in snap.docs) {
      final map = doc.data() as Map<String, dynamic>;
      final r = HexGLRaceResult.fromMap(map);
      if (r.userId.isNotEmpty) out[r.userId] = r;
    }
    return out;
  }

  /// Save a race result. If the new run is a personal best (finished and faster
  /// than the existing best), the new replay is stored and the best doc is
  /// updated. Destroyed/abandoned runs are stored only as history, not as best.
  Future<HexGLRaceResult?> submitResult({
    required HexGLRaceResult result,
  }) async {
    if (!isAllowedPlayer(result.userId)) {
      throw Exception('HexGL is reserved for Khent & Clair.');
    }
    if (!result.isFinished) {
      return null;
    }
    final ref = _bestDoc(result.userId, result.trackId);
    final existing = await getBestTime(
      userId: result.userId,
      trackId: result.trackId,
    );
    if (existing != null && existing.finishTimeMs <= result.finishTimeMs) {
      return existing;
    }
    await ref.set(result.toMap());
    return result;
  }

  // ---------------- Challenges (async 1v1) ----------------

  Future<HexGLChallenge> openChallenge({
    required String challengerId,
    required String trackId,
    required HexGLRaceResult challengerResult,
  }) async {
    if (!isAllowedPlayer(challengerId)) {
      throw Exception('HexGL challenges are reserved for Khent & Clair.');
    }
    final ref = _challengesRef.doc();
    final challenge = HexGLChallenge(
      challengeId: ref.id,
      trackId: trackId,
      challengerId: challengerId,
      createdAt: DateTime.now(),
      status: HexGLChallengeStatus.open,
      challengerResult: challengerResult,
    );
    await ref.set(challenge.toMap());
    return challenge;
  }

  Future<void> respondToChallenge({
    required HexGLChallenge challenge,
    required HexGLRaceResult defenderResult,
  }) async {
    final ref = _challengesRef.doc(challenge.challengeId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final c = HexGLChallenge.fromFirestore(snap);
      if (c.status == HexGLChallengeStatus.closed) return;

      final challenger = c.challengerResult;
      String? winner;
      if (challenger != null &&
          challenger.isFinished &&
          defenderResult.isFinished) {
        if (defenderResult.finishTimeMs < challenger.finishTimeMs) {
          winner = defenderResult.userId;
        } else if (defenderResult.finishTimeMs > challenger.finishTimeMs) {
          winner = challenger.userId;
        } else {
          winner = null; // tie
        }
      } else if (defenderResult.isFinished && challenger == null) {
        winner = defenderResult.userId;
      }

      final updated = c.copyWith(
        defenderId: defenderResult.userId,
        status: HexGLChallengeStatus.closed,
        closedAt: DateTime.now(),
        defenderResult: defenderResult,
        winnerId: winner,
      );
      tx.update(ref, updated.toMap());
    });
  }

  Future<void> closeChallengeAsDestroyed({
    required HexGLChallenge challenge,
    required String userId,
  }) async {
    final ref = _challengesRef.doc(challenge.challengeId);
    final c = challenge.copyWith(
      status: HexGLChallengeStatus.closed,
      closedAt: DateTime.now(),
    );
    await ref.update(c.toMap());
  }

  Stream<List<HexGLChallenge>> watchOpenChallengesFor(String userId) {
    return _challengesRef
        .where('status', isEqualTo: HexGLChallengeStatus.open.name)
        .where('challengerId', whereIn: [
          AuthService.khentUid,
          AuthService.clairUid,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => HexGLChallenge.fromFirestore(d))
            .where((c) => c.challengerId != userId)
            .toList());
  }

  Stream<HexGLChallenge?> watchChallenge(String challengeId) {
    return _challengesRef
        .doc(challengeId)
        .snapshots()
        .map((snap) => snap.exists ? HexGLChallenge.fromFirestore(snap) : null);
  }

  Future<List<HexGLChallenge>> recentChallenges({
    int limit = 20,
  }) async {
    final snap = await _challengesRef
        .where('challengerId', whereIn: [
          AuthService.khentUid,
          AuthService.clairUid,
        ])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => HexGLChallenge.fromFirestore(d)).toList();
  }

  Future<void> cleanupStaleChallenges() async {
    final cutoff = DateTime.now().subtract(challengeTtl);
    final snap = await _challengesRef
        .where('status', isEqualTo: HexGLChallengeStatus.open.name)
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({
        'status': HexGLChallengeStatus.closed.name,
        'closedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ---------------- Replay encoding helpers ----------------

  /// Encode a replay to a base64url string for use in a URL or postMessage.
  /// Returns null if the replay is null/empty.
  static String? encodeReplay(List<List<double>>? replay) {
    if (replay == null || replay.isEmpty) return null;
    final raw = jsonEncode(replay);
    final bytes = utf8.encode(raw);
    return base64Url.encode(bytes);
  }

  static List<List<double>>? decodeReplay(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');
      final pad = normalized.length % 4;
      final padded = pad == 0
          ? normalized
          : normalized + ('=' * (4 - pad));
      final raw = utf8.decode(base64Decode(padded));
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .map<List<double>>((row) =>
              (row as List).map<double>((v) => (v as num).toDouble()).toList())
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Format milliseconds as mm:ss.mmm
  static String formatTime(int ms) {
    if (ms < 0) ms = 0;
    final minutes = ms ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  }

  static String formatDelta(int ms) {
    final sign = ms < 0 ? '-' : '+';
    final abs = ms.abs();
    final s = abs ~/ 1000;
    final millis = abs % 1000;
    return '$sign${s}.${millis.toString().padLeft(3, '0')}s';
  }
}
