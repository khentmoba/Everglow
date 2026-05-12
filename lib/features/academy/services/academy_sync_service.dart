import 'package:cloud_firestore/cloud_firestore.dart';
import 'trivia_api_service.dart';
import '../models/academy_question.dart';

class AcademySyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TriviaApiService _apiService = TriviaApiService();

  static const int _minThreshold = 10;
  static const int _fetchAmount = 50;

  Future<void> triggerAutoFill({
    required String category,
    bool isHost = true,
    String? matchId,
  }) async {
    if (!isHost) return;

    final apiIds = TriviaApiService.getApiCategoryIds(category);
    if (apiIds.isEmpty) return;

    // Pick one of the available API IDs for this category randomly
    final apiCategoryId = (apiIds..shuffle()).first;

    final count = await _getUnusedQuestionCount(category);
    
    if (count < _minThreshold) {
      if (matchId != null) {
        await _firestore.collection('active_matches').doc(matchId).update({
          'isReplenishing': true,
        });
      }

      await _replenishQuestions(category, apiCategoryId);

      if (matchId != null) {
        await _firestore.collection('active_matches').doc(matchId).update({
          'isReplenishing': false,
        });
      }
    }
  }

  Future<int> _getUnusedQuestionCount(String category) async {
    final snapshot = await _firestore
        .collection('academy_questions')
        .where('category', isEqualTo: category)
        .get();
    
    return snapshot.docs.length;
  }

  Future<void> _replenishQuestions(String category, int apiCategoryId) async {
    try {
      final newQuestions = await _apiService.fetchQuestions(
        categoryId: apiCategoryId,
        amount: _fetchAmount,
      );

      final batch = _firestore.batch();
      
      for (var question in newQuestions) {
        // Update the ID using the hash logic from US1
        final id = AcademyQuestion.generateId(question.questionText);
        final docRef = _firestore.collection('academy_questions').doc(id);
        
        batch.set(docRef, {
          ...question.toMap(),
          'id': id,
          'createdAt': FieldValue.serverTimestamp(),
          'source': 'opentdb',
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      print('Error replenishing questions: $e');
      rethrow;
    }
  }
}
