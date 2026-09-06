import 'package:everglow/features/ai/data/services/study_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('studySessionTitle', () {
    test('uses the first user question', () {
      final turns = [
        const StudyHistoryTurn.user('What is photosynthesis?'),
        const StudyHistoryTurn.assistant('It is ...'),
      ];
      expect(studySessionTitle(turns), 'What is photosynthesis?');
    });

    test('truncates long questions with an ellipsis', () {
      final long = 'Explain ${'very ' * 30}in detail please';
      final title = studySessionTitle([StudyHistoryTurn.user(long)]);
      expect(title.length, lessThanOrEqualTo(61));
      expect(title, endsWith('…'));
    });

    test('collapses newlines and extra spaces', () {
      final turns = [
        const StudyHistoryTurn.user('  What is\n\n  mitosis?\n'),
      ];
      expect(studySessionTitle(turns), 'What is mitosis?');
    });

    test('skips assistant-only turns', () {
      final turns = [
        const StudyHistoryTurn.assistant('Hello!'),
      ];
      expect(studySessionTitle(turns), 'Untitled study');
    });

    test('returns fallback for empty turns', () {
      expect(studySessionTitle(const []), 'Untitled study');
    });
  });

  group('StudyHistoryTurn', () {
    test('round-trips through JSON', () {
      const user = StudyHistoryTurn.user('hello');
      expect(user.role, 'user');
      final restoredUser = StudyHistoryTurn.fromJson(user.toJson());
      expect(restoredUser.fromUser, isTrue);
      expect(restoredUser.text, 'hello');

      const assistant = StudyHistoryTurn.assistant('hi there');
      expect(assistant.role, 'assistant');
      final restoredAssistant = StudyHistoryTurn.fromJson(assistant.toJson());
      expect(restoredAssistant.fromUser, isFalse);
      expect(restoredAssistant.text, 'hi there');
    });
  });
}
