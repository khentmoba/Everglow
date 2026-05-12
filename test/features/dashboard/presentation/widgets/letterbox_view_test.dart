import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/presentation/widgets/letterbox_view.dart';
import 'package:everglow/features/dashboard/presentation/widgets/note_card.dart';

void main() {
  testWidgets('LetterboxView renders title and horizontal list', (WidgetTester tester) async {
    // Provide a large enough surface for the horizontal list
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LetterboxView(),
        ),
      ),
    );

    // Verify Title
    expect(find.text('Letterbox'), findsOneWidget);

    // Verify that at least some NoteCards are rendered
    expect(find.byType(NoteCard), findsAtLeastNWidgets(1));

    // Verify it scrolls horizontally
    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    final ListView listView = tester.widget(listFinder);
    expect(listView.scrollDirection, Axis.horizontal);

    addTearDown(tester.view.resetPhysicalSize);
  });
}
