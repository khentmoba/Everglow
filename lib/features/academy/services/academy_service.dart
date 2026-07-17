import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academy_question.dart';
import '../models/game_match.dart';
import '../../../core/utils/logger.dart';

class AcademyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _questionsRef => _firestore.collection('academy_questions');
  CollectionReference get _matchesRef => _firestore.collection('active_matches');
  CollectionReference get _usersRef => _firestore.collection('users');

  // Fetch random questions for a category
  Future<List<AcademyQuestion>> getQuestions(String category, {int limit = 10}) async {
    final query = await _questionsRef
        .where('category', isEqualTo: category)
        .get();

    final questions = query.docs
        .map((doc) => AcademyQuestion.fromFirestore(doc))
        .toList();

    questions.shuffle();
    return questions.take(limit).toList();
  }

  // Update Study Points for a user
  Future<void> updateStudyPoints(String userId, int points) async {
    final userDoc = _usersRef.doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) {
        transaction.set(userDoc, {'studyPoints': points});
      } else {
        final currentPoints = snapshot.data() != null ? (snapshot.data() as Map<String, dynamic>)['studyPoints'] ?? 0 : 0;
        transaction.update(userDoc, {'studyPoints': currentPoints + points});
      }
    });
  }

  // Seeding helper
  Future<void> seedQuestions() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/academy_questions_seed.json');
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

  // 1v1 Matchmaking logic
  Future<GameMatch> joinOrCreateMatch(String userId, String category) async {
    // 1. Cleanup stale matches
    await _cleanupStaleMatches();

    // 2. Try to find a waiting match
    final waitingMatches = await _matchesRef
        .where('status', isEqualTo: 'waiting')
        .where('category', isEqualTo: category)
        .limit(1)
        .get();

    if (waitingMatches.docs.isNotEmpty) {
      final matchDoc = waitingMatches.docs.first;
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchDoc.reference);
        final match = GameMatch.fromFirestore(snapshot);

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

    // 3. Create new match
    final questions = await getQuestions(category);
    if (questions.isEmpty) throw Exception('No questions found for category');

    final newMatchDoc = _matchesRef.doc();
    final newMatch = GameMatch(
      matchId: newMatchDoc.id,
      hostId: userId,
      participantId: null,
      khentScore: 0,
      clairScore: 0,
      status: 'waiting',
      currentQuestionId: questions.first.id,
      questionIndex: 0,
      category: category,
      createdAt: DateTime.now(),
    );

    await newMatchDoc.set(newMatch.toMap());
    return newMatch;
  }

  // Submit Answer transactional logic
  Future<bool> submitAnswer(String matchId, String userId, String questionId, bool isCorrect) async {
    final matchRef = _matchesRef.doc(matchId);

    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(matchRef);
      final match = GameMatch.fromFirestore(snapshot);

      if (match.status != 'active' || match.currentQuestionId != questionId) {
        return false; // Question already answered or match over
      }

      if (isCorrect) {
        final isHost = match.hostId == userId;
        final nextIndex = match.questionIndex + 1;
        
        // Fetch all questions for this match category to get the next one
        // Note: In a real app, we might store question IDs in the match document
        // For now, we'll fetch them again (cached ideally)
        final questions = await getQuestions(match.category);
        
        final isFinished = nextIndex >= 10;
        final nextQuestionId = isFinished ? '' : questions[nextIndex].id;

        final updatedMatch = match.copyWith(
          khentScore: isHost ? match.khentScore + 10 : match.khentScore,
          clairScore: !isHost ? match.clairScore + 10 : match.clairScore,
          questionIndex: nextIndex,
          currentQuestionId: nextQuestionId,
          status: isFinished ? 'finished' : 'active',
          winnerId: isFinished ? _calculateWinner(match, isHost) : null,
        );

        transaction.update(matchRef, updatedMatch.toMap());
        return true;
      }
      return false; // Incorrect answers don't advance the match in 1v1 fastest-finger
    });
  }

  String _calculateWinner(GameMatch match, bool isHostWinner) {
    // Recalculate based on final scores
    int khent = match.khentScore + (isHostWinner ? 10 : 0);
    int clair = match.clairScore + (!isHostWinner ? 10 : 0);
    
    if (khent > clair) return 'khent';
    if (clair > khent) return 'clair';
    return 'draw';
  }

  Future<void> _cleanupStaleMatches() async {
    final staleTime = DateTime.now().subtract(const Duration(minutes: 30));
    final staleQuery = await _matchesRef
        .where('createdAt', isLessThan: Timestamp.fromDate(staleTime))
        .get();

    for (var doc in staleQuery.docs) {
      await doc.reference.delete();
    }
  }
}
