import 'package:everglow/features/ai/data/services/study_artifact.dart';
import 'package:everglow/features/ai/presentation/widgets/canvas_preview_sheet.dart';
import 'package:everglow/features/ai/presentation/widgets/study_artifact_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _quiz = [
  QuizQuestion(
    question: 'What is 2+2?',
    options: ['3', '4'],
    answerIndex: 1,
    explanation: '2+2 is 4.',
  ),
  QuizQuestion(question: 'Sky color?', options: ['Blue', 'Green'], answerIndex: 0),
];

const _cards = [
  Flashcard(front: 'Mitochondria', back: 'Powerhouse of the cell'),
  Flashcard(front: '2+2', back: '4'),
];

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('quiz: correct pick shows praise, then score screen', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const QuizPlayView(questions: _quiz)));

    // Question 1 — pick the right answer.
    await tester.tap(find.text('4'));
    await tester.pump();
    expect(find.textContaining('Motchi is proud'), findsOneWidget);
    expect(find.text('2+2 is 4.'), findsOneWidget);

    // Next — pick the wrong answer.
    await tester.tap(find.text('Next →'));
    await tester.pump();
    await tester.tap(find.text('Green'));
    await tester.pump();
    expect(find.textContaining('gentle fix'), findsOneWidget);

    // Finish — score 1 of 2, retake resets.
    await tester.tap(find.text('See my score 💕'));
    await tester.pump();
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tap(find.text('Try again 🔁'));
    await tester.pump();
    expect(find.text('Question 1 of 2'), findsOneWidget);
  });

  testWidgets('flashcards: flip reveals answer, next advances', (tester) async {
    await tester.pumpWidget(_wrap(const FlashcardsPlayView(cards: _cards)));

    expect(find.text('Mitochondria'), findsOneWidget);
    await tester.tap(find.text('Mitochondria'));
    await tester.pumpAndSettle();
    expect(find.text('Powerhouse of the cell'), findsOneWidget);

    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();
    expect(find.text('Card 2 of 2'), findsOneWidget);
  });

  testWidgets('canvas preview is near-full-screen on desktop', (tester) async {
    // Regression test for the cramped 900x700 dialog: on a wide screen the
    // game stage must take over the viewport instead.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Widget tests run as Android (where the preview builds a real WebView
    // with no platform behind it) — pretend to be desktop so the stub
    // renders its fallback box and the layout can be measured. Reset
    // inside the body: the binding verifies debug vars before tearDowns.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => openCanvasPreview(
                ctx,
                const HtmlArtifact(title: 'Game', html: '<p>play</p>'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 1568.0 && w.height == 868.0,
        ),
        findsOneWidget,
      );
      expect(find.text('Game'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('entry shows launchers only when artifacts exist', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const StudyArtifactEntry(
          artifacts: StudyArtifacts(quiz: _quiz, flashcards: _cards),
        ),
      ),
    );
    expect(find.textContaining('Try the quiz'), findsOneWidget);
    expect(find.textContaining('Flip the cards'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(const StudyArtifactEntry(artifacts: StudyArtifacts())),
    );
    expect(find.textContaining('Try the quiz'), findsNothing);
  });
}
