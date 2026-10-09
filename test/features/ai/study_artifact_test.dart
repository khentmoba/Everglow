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

  group('clean chat collapse (quiz/cards stay in the sheet)', () {
    test('collapses the visible A-D list when quiz-json is present', () {
      const text = '''
Nice! Let's see how well you remembered, Dada 💕

Quiz: Block Diagrams & Flowcharts (CpE 316)

1. What is a key characteristic of a block diagram compared to a schematic?
A. It shows every wire and switch in detail
B. It portrays the necessary detail for physical construction
C. It provides a high-level overview without showing complete design details
D. It uses only circular shapes to represent components

```quiz-json
[{"q":"What is a key characteristic of a block diagram compared to a schematic?","options":["It shows every wire and switch in detail","It portrays the necessary detail for physical construction","It provides a high-level overview without showing complete design details","It uses only circular shapes to represent components"],"answer":2,"why":"Block diagrams stay high-level."}]
```''';
      final stripped = stripArtifactBlocks(text);
      expect(stripped, contains("Let's see how well you remembered"));
      expect(stripped, isNot(contains('It shows every wire')));
      expect(stripped, isNot(contains('1. What is a key')));
      expect(stripped, isNot(contains('quiz-json')));
      // The interactive sheet still gets the full question.
      expect(parseStudyArtifacts(text).quiz, hasLength(1));
    });

    test('leaves numbered prose alone when no quiz-json block exists', () {
      const text = '''
Here are the steps:
1. Open the app
2. Tap the garden
Hope that helps!''';
      expect(stripArtifactBlocks(text), contains('Open the app'));
      expect(parseStudyArtifacts(text).hasQuiz, isFalse);
    });

    test('keeps the full list when the user explicitly asked inline', () {
      const text = '''
Nice! Let's see how well you remembered 💕

1. What is 2+2?
A. 3
B. 4

```quiz-json
[{"q":"What is 2+2?","options":["3","4"],"answer":1,"why":"Basic math."}]
```''';
      const userAsk =
          'Quiz us on this! Ask 5 multiple-choice questions based ONLY on the material above. Ask them all now with A-D options, wait for our answers, then correct us gently.';
      expect(userAskedForVisibleQuiz(userAsk), isTrue);
      final kept = stripArtifactBlocks(text, collapseVisibleLists: false);
      expect(kept, contains('1. What is 2+2?'));
      expect(kept, contains('B. 4'));
      expect(kept, isNot(contains('quiz-json')));
    });

    test('plain quiz asks still collapse (no explicit inline signal)', () {
      expect(userAskedForVisibleQuiz('Quiz me on chapter 5'), isFalse);
      expect(userAskedForVisibleQuiz('Give me flashcards for bio'), isFalse);
      expect(
        userAskedForVisibleQuiz('Show me the flashcards here in chat'),
        isTrue,
      );
      expect(userAskedForVisibleQuiz('What is photosynthesis?'), isFalse);
    });

    test(
      'collapses the visible Front/Back list when cards-json is present',
      () {
        const text = '''
Made you some cards 🃏

Front: Mitochondria
Back: Powerhouse of the cell
Front: Nucleus
Back: Holds DNA

```flashcards-json
[{"front":"Mitochondria","back":"Powerhouse of the cell"},{"front":"Nucleus","back":"Holds DNA"}]
```''';
        final stripped = stripArtifactBlocks(text);
        expect(stripped, contains('Made you some cards'));
        expect(stripped, isNot(contains('Mitochondria')));
        expect(parseStudyArtifacts(text).flashcards, hasLength(2));
      },
    );
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

  group('standalone HTML game replies', () {
    const page =
        '<!DOCTYPE html>\n<html><head><title>Memory Match</title></head>'
        '<body><button id="restart">Restart</button><script>'
        'let moves = 0; function update() { moves++; }'
        '</script></body></html>';

    test('recovers an unfenced page and removes its orphan closing fence', () {
      final reply = 'Your game is ready!\n$page\n```';
      final artifacts = parseStudyArtifacts(reply);
      expect(artifacts.html, hasLength(1));
      expect(artifacts.html.single.title, 'Memory Match');
      expect(artifacts.html.single.html, contains('function update()'));
      expect(stripArtifactBlocks(reply), 'Your game is ready!');
    });

    test(
      'recovers an unlabeled HTML fence and preserves surrounding prose',
      () {
        final reply = 'Try this game.\n```\n$page\n```\nHave fun!';
        expect(parseStudyArtifacts(reply).html, hasLength(1));
        final visible = stripArtifactBlocks(reply);
        expect(visible, contains('Try this game.'));
        expect(visible, contains('Have fun!'));
        expect(visible, isNot(contains('```')));
        expect(visible, isNot(contains('<html')));
      },
    );

    const doctypePage =
        '<!DOCTYPE html><head><title>Game</title></head>'
        '<body><button>Play</button></body>';

    test('recovers a doctype page with omitted outer HTML tags', () {
      final reply = 'Your game is ready!\n$doctypePage';
      final artifacts = parseStudyArtifacts(reply);
      expect(artifacts.html, hasLength(1));
      expect(artifacts.html.single.title, 'Game');
      expect(artifacts.html.single.html, doctypePage);
      expect(stripArtifactBlocks(reply), 'Your game is ready!');
      expect(stripStreamingArtifacts(reply), 'Your game is ready!');
    });

    test('consumes optional HTML end tags and unlabeled fences', () {
      for (final html in [
        '$doctypePage</html>',
        doctypePage.replaceFirst('<head>', '<html><head>'),
        doctypePage.replaceFirst('</body>', '</BODY >'),
      ]) {
        final reply = 'Ready!\n```\n$html\n```\nHave fun!';
        expect(parseStudyArtifacts(reply).html.single.html, html);
        expect(stripArtifactBlocks(reply), 'Ready!\nHave fun!');
      }
    });

    test('does not recover a doctype page until its body closes', () {
      for (final html in [
        '<!DOCTYPE html><head><title>Game</title></head>',
        doctypePage.replaceFirst('</body>', ''),
        doctypePage.replaceFirst('</body>', '</body'),
        doctypePage.replaceFirst('</body>', '</bodyguard>'),
      ]) {
        final draft = 'Making your game.\n$html';
        expect(parseStudyArtifacts(draft).html, isEmpty);
        expect(stripStreamingArtifacts(draft), 'Making your game.');
        expect(stripArtifactBlocks(draft), 'Making your game.');
      }
    });

    test('keeps doctype pages in explicit non-artifact code fences', () {
      final example = 'Source example:\n```text\n$doctypePage\n```';
      expect(parseStudyArtifacts(example).html, isEmpty);
      expect(stripArtifactBlocks(example), example);
      expect(stripStreamingArtifacts(example), example);
    });

    test('still caps recovered doctype pages', () {
      final oversized = doctypePage.replaceFirst('Play', 'x' * kMaxHtmlChars);
      final reply = 'Ready!\n$oversized';
      expect(parseStudyArtifacts(reply).html, isEmpty);
      expect(stripArtifactBlocks(reply), 'Ready!');
    });

    test('hides unfinished unfenced pages during streaming', () {
      expect(
        stripStreamingArtifacts(
          'Making your game.\n<!DOCTYPE html>\n<html><body><script>',
        ),
        'Making your game.',
      );
    });

    test('keeps explicitly labeled non-artifact code examples', () {
      final example = 'Source example:\n```text\n$page\n```';
      expect(parseStudyArtifacts(example).html, isEmpty);
      expect(stripArtifactBlocks(example), example);
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

    test('final strip cuts a trailing unterminated html fence', () {
      // A reply cut off by the output budget mid-game must render as clean
      // text in the saved bubble, never a raw HTML dump — and it still
      // yields no (broken) Preview button.
      const text =
          'Made you a Memory Match game!\n```html-artifact\n<!DOCTYPE html><html><head><title>Memory Match</title></head><body><div id="board">';
      final stripped = stripArtifactBlocks(text);
      expect(stripped, 'Made you a Memory Match game!');
      expect(stripped, isNot(contains('DOCTYPE')));
      expect(stripped, isNot(contains('```')));
      expect(parseStudyArtifacts(text).hasHtml, isFalse);
    });

    test('final strip cuts a trailing unterminated quiz fence', () {
      const text = 'Quiz time!\n```quiz-json\n[{"q":"What is 2+2?"';
      expect(stripArtifactBlocks(text), 'Quiz time!');
      expect(parseStudyArtifacts(text).hasQuiz, isFalse);
    });

    test('block-less game announcement parses to no artifacts', () {
      // The live "Memory Match" failure: warm text with no hidden block
      // means nothing to preview — the fix is upstream (prompt + output
      // budget), the bubble itself must simply stay clean text.
      const text =
          'Aww yes! Made you two a Memory Match game! Tap cards to flip them and find matching pairs!';
      expect(parseStudyArtifacts(text).isEmpty, isTrue);
      expect(stripArtifactBlocks(text), contains('Memory Match'));
    });
  });

  group('lenient parsing (model variations)', () {
    test('parses quiz block wrapped in prose with trailing commas', () {
      const text = '''
Here you go! 💕
```quiz-json
Here is the JSON:
[{"q":"What is 2+2?","options":["3","4",],"answer":1,"why":"Basic math.",},]
Hope it helps!
```''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasQuiz, isTrue);
      expect(artifacts.quiz.first.question, 'What is 2+2?');
      expect(artifacts.quiz.first.answerIndex, 1);
      expect(stripArtifactBlocks(text), isNot(contains('"q"')));
    });

    test('accepts alias fence names and same-line bodies', () {
      const text =
          '```quiz_json [{"q":"Q?","options":["a","b"],"answer":0}]```';
      expect(parseStudyArtifacts(text).hasQuiz, isTrue);
      const cards = '```flashcards [{"front":"f","back":"b"}]```';
      expect(parseStudyArtifacts(cards).hasFlashcards, isTrue);
    });

    test('wraps HTML fragments into a runnable page', () {
      const text = '''
```html-artifact
<!-- title: Tiny Chess -->
<div id="board"></div><script>console.log("play")</script>
```''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasHtml, isTrue);
      expect(artifacts.html.first.title, 'Tiny Chess');
      expect(artifacts.html.first.html, contains('<!DOCTYPE html>'));
      expect(artifacts.html.first.html, contains('id="board"'));
    });

    test('accepts plain html fence name', () {
      const text =
          '```html\n<div>hello game world, play me now please</div>\n```';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasHtml, isTrue);
      expect(artifacts.html.first.html, contains('<!DOCTYPE html>'));
    });

    test('still drops prose-only html blocks', () {
      const text = '```html-artifact\njust some words, not a page at all\n```';
      expect(parseStudyArtifacts(text).hasHtml, isFalse);
    });
  });

  group('everglow-link blocks (Play Zone doorway)', () {
    test('parses a chess link with a fixed warm label', () {
      const text = '''
Couple Chess is waiting for you two — tap below to play! ♟️

```everglow-link
{"route": "/play-zone/chess"}
```''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasLinks, isTrue);
      expect(artifacts.isEmpty, isFalse);
      expect(artifacts.links, hasLength(1));
      expect(artifacts.links.first.route, '/play-zone/chess');
      expect(artifacts.links.first.label, contains('Chess'));
    });

    test('accepts a bare route without JSON', () {
      const text = '```everglow-link\n/play-zone/scribble\n```';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasLinks, isTrue);
      expect(artifacts.links.first.route, '/play-zone/scribble');
    });

    test('ignores routes outside the Play Zone allowlist', () {
      const text = '```everglow-link\n{"route": "/admin/secrets"}\n```';
      expect(parseStudyArtifacts(text).hasLinks, isFalse);
    });

    test('strips the block so the bubble stays clean text', () {
      const text = '''
Ready to play! ♟️
```everglow-link
{"route": "/play-zone/chess"}
```''';
      final stripped = stripArtifactBlocks(text);
      expect(stripped, 'Ready to play! ♟️');
      expect(stripped, isNot(contains('everglow-link')));
    });

    test('stripStreamingArtifacts cuts an unterminated link fence', () {
      const draft = 'One sec!\n```everglow-link\n{"route": "/play-zone/ch';
      expect(stripStreamingArtifacts(draft), 'One sec!');
    });
  });

  group('interactive choices', () {
    test('parses choices-json into interactive pills', () {
      const text = '''
What movie vibe are you in the mood for tonight? 🎬
```choices-json
{"prompt": "Pick a vibe", "choices": ["Cozy Anime", "Mind-bending Sci-Fi", "Comedy"]}
```''';
      final artifacts = parseStudyArtifacts(text);
      expect(artifacts.hasChoices, isTrue);
      expect(artifacts.choices, hasLength(1));
      expect(artifacts.choices.first.prompt, 'Pick a vibe');
      expect(artifacts.choices.first.choices, [
        'Cozy Anime',
        'Mind-bending Sci-Fi',
        'Comedy',
      ]);
    });

    test('strips choices-json from visible chat text', () {
      const text = '''
What movie vibe are you in the mood for tonight? 🎬
```choices-json
{"prompt": "Pick a vibe", "choices": ["Cozy Anime", "Comedy"]}
```''';
      final stripped = stripArtifactBlocks(text);
      expect(stripped, 'What movie vibe are you in the mood for tonight? 🎬');
      expect(stripped, isNot(contains('choices-json')));
    });

    test('stripStreamingArtifacts cuts unterminated choices fence', () {
      const draft = 'Thinking!\n```choices-json\n{"prompt": "Pick';
      expect(stripStreamingArtifacts(draft), 'Thinking!');
    });
  });
}
