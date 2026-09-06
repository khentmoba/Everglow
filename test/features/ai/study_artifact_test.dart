import 'package:everglow/features/ai/data/services/study_artifact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('quiz-json blocks', () {
    test('parses questions with 0-based answers', () {
      const text = '''
Here is your quiz! 💕

```quiz-json
[{"q":"What is 2+2?","options":["3","4","5","6"],"answer":1,"why":"2+2 is 4."}]
```''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasQuiz, isTrue);
      expect(artifacts.quiz, hasLength(1));
      expect(artifacts.quiz.first.question, 'What is 2+2?');
      expect(artifacts.quiz.first.options[1], '4');
      expect(artifacts.quiz.first.answerIndex, 1);
      expect(artifacts.quiz.first.explanation, contains('4'));
    });

    test('accepts letter and 1-based answers', () {
      const text = '''
```quiz-json
[
  {"q":"Q1","options":["a","b"],"answer":"B"},
  {"q":"Q2","options":["a","b"],"answer":2}
]```''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.quiz.map((q) => q.answerIndex), [1, 1]);
    });

    test('skips bad entries without throwing', () {
      const text = '''
```quiz-json
[{"q":"","options":["a"],"answer":9},{"not":"a question"}, 42]
```''';
      expect(parseStudyArtifacts(text).hasQuiz, isFalse);
    });

    test('ignores garbage that is not JSON', () {
      const text = '```quiz-json\nnot json at all\n```';
      expect(parseStudyArtifacts(text).hasQuiz, isFalse);
    });
  });

  group('flashcards-json blocks', () {
    test('parses front/back cards', () {
      const text = '''
```flashcards-json
[{"front":"Mitochondria","back":"Powerhouse of the cell"}]
```''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasFlashcards, isTrue);
      expect(artifacts.flashcards.first.front, 'Mitochondria');
    });

    test('supports {"cards": [...]} wrapper', () {
      const text =
          '```flashcards-json\n{"cards":[{"front":"a","back":"b"}]}\n```';
      expect(parseStudyArtifacts(text).flashcards, hasLength(1));
    });
  });

  group('stripArtifactBlocks', () {
    test('removes hidden blocks but keeps visible text and code', () {
      const text = '''
Lovely quiz below 💕
```quiz-json
[{"q":"x","options":["a","b"],"answer":0}]
```
```dart
void main() {}
```''';
      final stripped = stripArtifactBlocks(text);
      expect(stripped, contains('Lovely quiz'));
      expect(stripped, contains('void main()'));
      expect(stripped, isNot(contains('quiz-json')));
      expect(stripped, isNot(contains('"q"')));
    });
  });

  group('stripStreamingArtifacts', () {
    test('cuts an unterminated fence mid-stream', () {
      const draft = 'Nice quiz!\n```quiz-json\n[{"q":"x"';
      final stripped = stripStreamingArtifacts(draft);
      expect(stripped, 'Nice quiz!');
    });
  });

  group('plain-markdown fallback (older sessions)', () {
    test('parses numbered questions with answer keys', () {
      const text = '''
1. What is photosynthesis?
A) Eating rocks
B) Turning sunlight into food
C) Sleeping
Answer: B — plants do this.
''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.quiz, hasLength(1));
      expect(artifacts.quiz.first.answerIndex, 1);
      expect(artifacts.quiz.first.explanation, isNotEmpty);
    });

    test('ignores questions without answers (no guessing games)', () {
      const text = '''
1. What is love?
A) Baby don't hurt me
B) A battlefield
''';
      expect(parseStudyArtifacts(text).hasQuiz, isFalse);
    });

    test('parses explicit Q/A flashcard pairs', () {
      const text = '''
Q: Capital of France?
A: Paris
Q: 2+2?
A: 4
''';
      expect(parseStudyArtifacts(text).flashcards, hasLength(2));
    });

    test('does not turn prose into flashcards', () {
      const text = '''
Photosynthesis is important. Plants use sunlight.
Q: Only one lonely question?
A: Yes.
''';
      expect(parseStudyArtifacts(text).hasFlashcards, isFalse);
    });
  });
}
