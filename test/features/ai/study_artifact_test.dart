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

  group('html-artifact blocks (preview canvas)', () {
    test('parses title from <title> tag', () {
      const text = '''
Made you chess! Tap Preview to play.

```html-artifact
<!DOCTYPE html><html><head><title>Chess</title></head><body>game here with enough characters to look real....................</body></html>
```''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasHtml, isTrue);
      expect(artifacts.html.first.title, 'Chess');
      expect(artifacts.html.first.html, contains('<!DOCTYPE html>'));
    });

    test('falls back to Preview without a title', () {
      const text = '''
```html-artifact
<!DOCTYPE html><html><body>just a tiny page with enough text padding....................</body></html>
```''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasHtml, isTrue);
      expect(artifacts.html.first.title, 'Preview');
    });

    test('drops blocks that are not pages', () {
      const text = '```html-artifact\njust some words, not a page at all\n```';
      expect(parseStudyArtifacts(text).hasHtml, isFalse);
    });

    test('stripArtifactBlocks removes the block but keeps code fences', () {
      const text = '''
Here is your game!
```html-artifact
<!DOCTYPE html><html><body>enough page text to count as a page....................</body></html>
```
```dart
void main() {}
```''';
      final stripped = stripArtifactBlocks(text);
      expect(stripped, contains('Here is your game!'));
      expect(stripped, contains('void main()'));
      expect(stripped, isNot(contains('html-artifact')));
      expect(stripped, isNot(contains('DOCTYPE')));
    });

    test('stripStreamingArtifacts cuts an unterminated html fence', () {
      const draft = 'Making chess!\n```html-artifact\n<!DOCTYPE html><html>';
      expect(stripStreamingArtifacts(draft), 'Making chess!');
    });
  });
}
