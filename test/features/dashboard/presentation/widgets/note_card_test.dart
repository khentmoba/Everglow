import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/domain/models/hidden_note.dart';
import 'package:everglow/features/dashboard/presentation/widgets/note_card.dart';

HiddenNote _note({required DateTime unlockDate, bool isRead = false}) {
  return HiddenNote(
    id: 'n1',
    title: 'My Favorite Number',
    content: 'x',
    unlockDate: unlockDate,
    isRead: isRead,
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  HiddenNote note, {
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NoteCard(note: note, onTap: onTap ?? () {})),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('NoteCard', () {
    testWidgets('sealed letter shows title and countdown pill', (tester) async {
      await _pumpCard(
        tester,
        _note(unlockDate: DateTime.now().add(const Duration(days: 2))),
      );
      expect(find.text('My Favorite Number'), findsOneWidget);
      expect(find.textContaining('opens in'), findsOneWidget);
      expect(find.text('NEW'), findsNothing);
    });

    testWidgets('new letter shows NEW ribbon and invite', (tester) async {
      await _pumpCard(
        tester,
        _note(unlockDate: DateTime.now().subtract(const Duration(days: 1))),
      );
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('tap to read'), findsOneWidget);
    });

    testWidgets('read letter rests quietly', (tester) async {
      await _pumpCard(
        tester,
        _note(
          unlockDate: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
        ),
      );
      expect(find.text('read'), findsOneWidget);
      expect(find.text('NEW'), findsNothing);
    });

    testWidgets('tap opens the letter', (tester) async {
      var tapped = false;
      await _pumpCard(
        tester,
        _note(unlockDate: DateTime.now().subtract(const Duration(days: 1))),
        onTap: () => tapped = true,
      );
      await tester.tap(find.text('My Favorite Number'));
      expect(tapped, isTrue);
    });
  });
}
