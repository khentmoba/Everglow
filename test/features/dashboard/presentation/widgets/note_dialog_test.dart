import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/presentation/widgets/note_dialog.dart';
import 'package:everglow/features/dashboard/domain/models/hidden_note.dart';

void main() {
  testWidgets('NoteDialog displays note content and handles long text scrolling', (WidgetTester tester) async {
    final note = HiddenNote(
      id: 'test',
      title: 'A very long love letter',
      content: 'Line 1\n' * 50, // Long content to trigger scrolling
      unlockDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteDialog(note: note),
        ),
      ),
    );

    // Verify Title and some content
    expect(find.text('A very long love letter'), findsOneWidget);
    expect(find.textContaining('Line 1'), findsAtLeastNWidgets(1));

    // Verify that the scroll view exists
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    
    // Verify close button functionality
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
