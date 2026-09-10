import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/presentation/widgets/note_dialog.dart';
import 'package:everglow/features/dashboard/domain/models/hidden_note.dart';

void main() {
  testWidgets(
    'NoteDialog displays note content and handles long text scrolling',
    (WidgetTester tester) async {
      final note = HiddenNote(
        id: 'test',
        title: 'A very long love letter',
        content: 'Line 1\n' * 50, // Long content to trigger scrolling
        unlockDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NoteDialog(note: note)),
        ),
      );

      // Verify Title and some content
      expect(find.text('A very long love letter'), findsOneWidget);
      expect(find.textContaining('Line 1'), findsAtLeastNWidgets(1));

      // Verify that the scroll view exists
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Verify close button functionality
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Verify romantic stationery elements
      expect(find.text('LETTERBOX'), findsOneWidget);
      expect(find.text('Forever & always,'), findsOneWidget);
      expect(find.text('Keep close to heart'), findsOneWidget);
    },
  );

  testWidgets(
    'NoteDialog renders short sweet notes with postmark and wax seal',
    (WidgetTester tester) async {
      final unlockDate = DateTime(2025, 2, 14);
      final note = HiddenNote(
        id: 'fav-num',
        title: 'My Favorite Number',
        content: '1111',
        unlockDate: unlockDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NoteDialog(note: note)),
        ),
      );

      expect(find.text('My Favorite Number'), findsOneWidget);
      expect(find.text('1111'), findsOneWidget);
      expect(find.textContaining('FEBRUARY 14, 2025'), findsOneWidget);
      expect(find.text('Forever & always,'), findsOneWidget);
      expect(find.text('With all my love'), findsOneWidget);

      // Tapping wax seal triggers bounce and love toast
      final waxSeal = find.byTooltip('Sealed with love');
      expect(waxSeal, findsOneWidget);
      await tester.tap(waxSeal);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Sealed with love for Clair'), findsOneWidget);

      // Settle timer
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'NoteDialog closes when tapping Keep close to heart button',
    (WidgetTester tester) async {
      final note = HiddenNote(
        id: 'close-test',
        title: 'Secret Note',
        content: 'I love you so much!',
        unlockDate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => NoteDialog(note: note),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Secret Note'), findsOneWidget);
      expect(find.text('Keep close to heart'), findsOneWidget);

      await tester.tap(find.text('Keep close to heart'));
      await tester.pumpAndSettle();

      expect(find.text('Secret Note'), findsNothing);
    },
  );

  testWidgets(
    'NoteDialog renders without overflow on mobile phone (360x640)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final note = HiddenNote(
        id: 'phone-test',
        title: 'A Love Letter for Clair',
        content: 'You are the most precious part of my life.\nEvery single day with you is a gift.',
        unlockDate: DateTime(2025, 2, 14),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NoteDialog(note: note)),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('A Love Letter for Clair'), findsOneWidget);
    },
  );

  testWidgets(
    'NoteDialog renders without overflow on tablet (810x1080)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(810, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final note = HiddenNote(
        id: 'tablet-test',
        title: 'For My Sweetheart',
        content: 'Under the starlight, always thinking of you.',
        unlockDate: DateTime(2025, 2, 14),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NoteDialog(note: note)),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('For My Sweetheart'), findsOneWidget);
    },
  );

  testWidgets(
    'NoteDialog stays constrained to max width on wide desktop screen (1440x900)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final note = HiddenNote(
        id: 'desktop-test',
        title: 'My Favorite Number',
        content: '1111',
        unlockDate: DateTime(2025, 2, 14),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NoteDialog(note: note)),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('My Favorite Number'), findsOneWidget);

      // Verify the dialog container width is constrained to <= 480
      final constrainedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.maxWidth == 480,
      );
      expect(constrainedBoxFinder, findsOneWidget);
    },
  );
}
