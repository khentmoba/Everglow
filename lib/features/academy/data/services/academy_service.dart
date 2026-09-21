import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academy_question.dart';
import '../models/game_match.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';

class AcademyService {
  // Lazy so widget tests can construct the service without Firebase.
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference get _questionsRef =>
      _firestore.collection('academy_questions');
  CollectionReference get _matchesRef =>
      _firestore.collection('active_matches');
  CollectionReference get _usersRef => _firestore.collection('users');

  /// Match length for 1v1. The shared [GameMatch.questionIds] order decides
  /// the real length; this is the snapshot size at creation.
  static const int matchLength = 10;

  // Fetch random questions for a category
  Future<List<AcademyQuestion>> getQuestions(
    String category, {
    int limit = 10,
  }) async {
    final query = await withGetTimeout(
      _questionsRef
          .where('category', isEqualTo: category)
          .limit(limit * 3)
          .get(),
      label: 'academy questions',
    );

    final questions = query.docs
        .map((doc) => AcademyQuestion.fromFirestore(doc))
        .toList();

    questions.shuffle();
    return questions.take(limit).toList();
  }

  /// Random questions for a category, skipping [excludeIds] (already seen).
  /// Falls back to the full pool when everything was seen.
  Future<List<AcademyQuestion>> getQuestionsExcluding(
    String category, {
    int limit = 10,
    Set<String> excludeIds = const {},
  }) async {
    final query = await withGetTimeout(
      _questionsRef
          .where('category', isEqualTo: category)
          .limit(limit * 5)
          .get(),
      label: 'academy questions excluding seen',
    );

    final questions =
        query.docs.map((doc) => AcademyQuestion.fromFirestore(doc)).toList()
          ..shuffle();

    if (excludeIds.isEmpty) return questions.take(limit).toList();
    final fresh = questions.where((q) => !excludeIds.contains(q.id)).toList();
    if (fresh.length >= limit) return fresh.take(limit).toList();
    // Not enough fresh ones — mix fresh first, then repeats.
    final rest = questions.where((q) => excludeIds.contains(q.id));
    return [...fresh, ...rest].take(limit).toList();
  }

  /// Loads questions by doc ID, in [ids] order. Skips missing docs.
  /// Used for 1v1 shared sets so both phones see identical questions.
  Future<List<AcademyQuestion>> getQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final found = <String, AcademyQuestion>{};
    // whereIn caps at 10 ids per query — chunk larger sets.
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final query = await withGetTimeout(
        _questionsRef.where(FieldPath.documentId, whereIn: chunk).get(),
        label: 'academy questions by id',
      );
      for (final doc in query.docs) {
        found[doc.id] = AcademyQuestion.fromFirestore(doc);
      }
    }
    return [
      for (final id in ids)
        if (found[id] != null) found[id]!,
    ];
  }

  // Update Study Points for a user
  Future<void> updateStudyPoints(String userId, int points) async {
    final userDoc = _usersRef.doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) {
        transaction.set(userDoc, {'studyPoints': points});
      } else {
        final currentPoints = snapshot.data() != null
            ? (snapshot.data() as Map<String, dynamic>)['studyPoints'] ?? 0
            : 0;
        transaction.update(userDoc, {'studyPoints': currentPoints + points});
      }
    });
  }

  // Seeding helper
  Future<void> seedQuestions() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/academy_questions_seed.json',
      );
      final List<dynamic> data = jsonDecode(jsonString);

      // Process in batches of 500 (Firestore limit)
      for (var i = 0; i < data.length; i += 500) {
        final batch = _firestore.batch();
        final end = (i + 500 < data.length) ? i + 500 : data.length;

        for (var j = i; j < end; j++) {
          final q = data[j];
          final String questionText = q['questionText'] ?? '';
          final id = AcademyQuestion.generateId(questionText);
          final docRef = _questionsRef.doc(id);

          batch.set(docRef, {
            'id': id,
            'questionText': questionText,
            'options': List<String>.from(q['options'] ?? []),
            'correctOptionIndex': q['correctOptionIndex'] ?? 0,
            'category': q['category'] ?? 'general',
            'createdAt': FieldValue.serverTimestamp(),
            'source': 'local_seed',
          }, SetOptions(merge: true));
        }

        await batch.commit();
      }
      Logger.i('Successfully seeded ${data.length} questions to Firestore');
    } catch (e) {
      Logger.e('Error seeding questions', error: e);
      rethrow;
    }
  }

  // 1v1 Matchmaking logic.
  //
  // [userUid] is the Firebase Auth UID (what security rules check);
  // [username] is the profile name (what scoring + display use).
  // The host snapshots the shared question order at creation so both
  // phones play identical questions — callers should pass Motchi-fresh
  // ids when available, otherwise we snapshot from the cached pool.
  Future<GameMatch> joinOrCreateMatch({
    required String userUid,
    required String username,
    required String category,
    List<String>? questionIds,
  }) async {
    // 1. Cleanup stale matches
    await _cleanupStaleMatches();

    // 2. Try to find a waiting match
    final waitingMatches = await withGetTimeout(
      _matchesRef
          .where('status', isEqualTo: 'waiting')
          .where('category', isEqualTo: category)
          .limit(1)
          .get(),
      label: 'academy waiting match',
    );

    if (waitingMatches.docs.isNotEmpty) {
      final matchDoc = waitingMatches.docs.first;
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchDoc.reference);
        if (!snapshot.exists) throw Exception('Match no longer available');
        final match = GameMatch.fromFirestore(snapshot);

        if (match.status == 'waiting' && match.hostId != userUid) {
          final updatedMatch = match.copyWith(
            status: 'active',
            participantId: userUid,
            participantUsername: username,
          );
          transaction.update(matchDoc.reference, updatedMatch.toMap());
          return updatedMatch;
        }
        throw Exception('Match no longer available');
      });
    }

    // 3. Create new match with a snapshotted question order.
    final ids = (questionIds != null && questionIds.isNotEmpty)
        ? questionIds.take(matchLength).toList()
        : (await getQuestions(
            category,
            limit: matchLength,
          )).map((q) => q.id).toList();
    if (ids.isEmpty) throw Exception('No questions found for category');

    final newMatchDoc = _matchesRef.doc();
    final newMatch = GameMatch(
      matchId: newMatchDoc.id,
      hostId: userUid,
      participantId: null,
      hostUsername: username,
      participantUsername: null,
      hostScore: 0,
      guestScore: 0,
      status: 'waiting',
      currentQuestionId: ids.first,
      questionIndex: 0,
      questionIds: ids,
      category: category,
      createdAt: DateTime.now(),
    );

    await newMatchDoc.set(newMatch.toMap());
    return newMatch;
  }

  /// Swaps a still-waiting match to a fresher question order (the host's
  /// Motchi set). Returns false when a guest already joined — the
  /// original cached order stands so the game stays in sync.
  Future<bool> upgradeWaitingMatchQuestions({
    required String matchId,
    required List<String> questionIds,
  }) async {
    if (questionIds.isEmpty) return false;
    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(_matchesRef.doc(matchId));
        if (!snapshot.exists) return false;
        final match = GameMatch.fromFirestore(snapshot);
        if (match.status != 'waiting') return false;
        final ids = questionIds.take(matchLength).toList();
        transaction.update(
          _matchesRef.doc(matchId),
          match
              .copyWith(
                questionIds: ids,
                currentQuestionId: ids.first,
                questionIndex: 0,
              )
              .toMap(),
        );
        return true;
      });
    } catch (e) {
      Logger.e('Error upgrading waiting match questions', error: e);
      return false;
    }
  }

  /// Deletes a still-waiting match (host cancelled search). Finished or
  /// active matches are left alone.
  Future<void> cancelWaitingMatch(String matchId) async {
    try {
      final doc = await withGetTimeout(
        _matchesRef.doc(matchId).get(),
        label: 'academy cancel match check',
      );
      if (!doc.exists) return;
      final match = GameMatch.fromFirestore(doc);
      if (match.status == 'waiting') {
        await _matchesRef.doc(matchId).delete();
      }
    } catch (e) {
      Logger.e('Error cancelling waiting match', error: e);
    }
  }

  /// Records a correct 1v1 answer (fastest finger wins the point).
  /// Returns true when this call advanced the match; false when the
  /// question was already answered or the match is over.
  ///
  /// Transaction-safe: reads + writes the match doc only, never fetches
  /// the question pool mid-transaction. The next question comes from the
  /// snapshotted [GameMatch.questionIds] order.
  Future<bool> submitAnswer({
    required String matchId,
    required String username,
    required String questionId,
  }) async {
    final matchRef = _matchesRef.doc(matchId);

    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(matchRef);
      if (!snapshot.exists) return false;
      final match = GameMatch.fromFirestore(snapshot);

      if (match.status != 'active' || match.currentQuestionId != questionId) {
        return false; // Question already answered or match over
      }

      final isHost = (match.hostUsername ?? match.hostId) == username;
      final nextIndex = match.questionIndex + 1;
      // Legacy docs (pre-refresh) have no snapshotted order — score this
      // answer and finish rather than stranding the match mid-game.
      final isFinished = match.questionIds.isEmpty
          ? true
          : nextIndex >= match.questionIds.length;
      final nextQuestionId = isFinished ? '' : match.questionIds[nextIndex];

      final hostScore = match.hostScore + (isHost ? 10 : 0);
      final guestScore = match.guestScore + (!isHost ? 10 : 0);

      final updatedMatch = match.copyWith(
        hostScore: hostScore,
        guestScore: guestScore,
        questionIndex: nextIndex,
        currentQuestionId: isFinished ? '' : nextQuestionId,
        status: isFinished ? 'finished' : 'active',
        winnerId: isFinished
            ? _calculateWinner(
                hostScore: hostScore,
                guestScore: guestScore,
                hostUsername: match.hostUsername,
                guestUsername: match.participantUsername,
              )
            : null,
      );

      transaction.update(matchRef, updatedMatch.toMap());
      return true;
    });
  }

  String _calculateWinner({
    required int hostScore,
    required int guestScore,
    required String? hostUsername,
    required String? guestUsername,
  }) {
    if (hostScore > guestScore) return hostUsername ?? 'draw';
    if (guestScore > hostScore) return guestUsername ?? 'draw';
    return 'draw';
  }

  Future<void> _cleanupStaleMatches() async {
    final staleTime = DateTime.now().subtract(const Duration(minutes: 30));
    final staleQuery = await withGetTimeout(
      _matchesRef
          .where('createdAt', isLessThan: Timestamp.fromDate(staleTime))
          .limit(50)
          .get(),
      label: 'academy stale match cleanup',
    );

    var batch = _firestore.batch();
    var pending = 0;
    for (var doc in staleQuery.docs) {
      batch.delete(doc.reference);
      pending++;
      if (pending >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }
}
