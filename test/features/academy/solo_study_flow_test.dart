import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/academy/data/models/academy_question.dart';
import 'package:everglow/features/academy/presentation/screens/solo_study_screen.dart';

AcademyQuestion _q(String id, String text, {String? explanation}) {
  return AcademyQuestion(
    id: id,
    questionText: text,
    options: const ['Alpha', 'Beta', 'Gamma', 'Delta'],
    correctOptionIndex: 1,
    category: 'general',
    explanation: explanation,
  );
}

Future<void> _pumpSolo(
  WidgetTester tester, {
  required List<AcademyQuestion> questions,
  Size size = const Size(430, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: SoloStudyScreen(
        questions: questions,
        category: 'general',
        topic: 'Demo night',
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Solo shows progress and topic with no overflow', (tester) async {
    await _pumpSolo(
      tester,
      questions: [_q('1', 'What is the kindest answer here?')],
    );

    expect(find.text('Question 1/1'), findsOneWidget);
    expect(find.text('Demo night'), findsOneWidget);
    expect(find.text('no timer · take your time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Solo praises a right answer and shows the why-line', (
    tester,
  ) async {
    await _pumpSolo(
      tester,
      questions: [
        _q(
          '1',
          'What is the kindest answer here?',
          explanation: 'Beta is simply the best.',
        ),
        _q('2', 'What is the second question about?'),
      ],
    );

    await tester.tap(find.text('Beta'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Lovely'), findsOneWidget);
    expect(find.textContaining('Beta is simply the best.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Flush the 2.2s advance timer before teardown.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Solo comforts a wrong answer and names the right one', (
    tester,
  ) async {
    await _pumpSolo(
      tester,
      questions: [_q('1', 'What is the kindest answer here?')],
    );

    await tester.tap(find.text('Alpha'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Almost, love'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Flush the 2.2s advance timer before teardown.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Solo finishes with a warm results page', (tester) async {
    await _pumpSolo(
      tester,
      questions: [_q('1', 'What is the kindest answer here?')],
    );

    await tester.tap(find.text('Beta'));
    // Answer feedback shows, then the set finishes after 2.2s.
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Perfect, my love!'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Practice again'), findsOneWidget);
    expect(find.text('Challenge my love to 1v1'), findsOneWidget);
    expect(find.text('Back to Hub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
