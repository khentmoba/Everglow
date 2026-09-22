import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/journal/data/models/journal_entry.dart';
import 'package:everglow/features/journal/data/services/journal_service.dart';
import 'package:everglow/features/journal/presentation/widgets/journal_detail_sheet.dart';
import 'package:everglow/features/journal/presentation/widgets/journal_entry_card.dart';

JournalEntry _entry({
  required String id,
  required String title,
  required String content,
  bool isLocked = false,
  List<String> tags = const ['secret', 'anniversary'],
}) => JournalEntry(
  id: id,
  title: title,
  content: content,
  author: 'khentsgdz',
  createdAt: DateTime.utc(2026, 9, 21, 14),
  updatedAt: DateTime.utc(2026, 9, 21, 14),
  category: JournalCategory.memory,
  mood: JournalMood.loved,
  tags: tags,
  wordCount: content.split(' ').length,
  isLocked: isLocked,
);

void main() {
  group('JournalEntry isLocked Model Privacy & Persistence', () {
    test('defaults isLocked to false on creation', () {
      final entry = JournalEntry(
        id: 'j1',
        title: 'Open Note',
        content: 'Visible content',
        author: 'clairjassen',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      );
      expect(entry.isLocked, isFalse);
    });

    test('serializes isLocked field to Firestore map', () {
      final locked = _entry(
        id: 'j_lock',
        title: 'Secret Letter',
        content: 'Private message',
        isLocked: true,
      );
      final map = locked.toFirestore();
      expect(map['isLocked'], isTrue);

      final unlocked = locked.copyWith(isLocked: false);
      expect(unlocked.toFirestore()['isLocked'], isFalse);
    });

    test('deserializes isLocked and safely defaults when absent or null', () {
      final docMap = {
        'title': 'Letter',
        'content': 'Words',
        'author': 'khentsgdz',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
        'category': 'memory',
        'tags': ['love'],
        'wordCount': 1,
        'isLocked': true,
      };

      final locked = JournalEntry.fromMap(docMap, 'doc1');
      expect(locked.isLocked, isTrue);

      final missingMap = Map<String, dynamic>.from(docMap)..remove('isLocked');
      final fallbackMissing = JournalEntry.fromMap(missingMap, 'doc2');
      expect(fallbackMissing.isLocked, isFalse);

      final nullMap = Map<String, dynamic>.from(docMap)..['isLocked'] = null;
      final fallbackNull = JournalEntry.fromMap(nullMap, 'doc3');
      expect(fallbackNull.isLocked, isFalse);
    });

    test('copyWith toggles isLocked cleanly while keeping other fields', () {
      final base = _entry(
        id: 'j1',
        title: 'My Heart',
        content: 'Forever ours',
        isLocked: true,
      );
      final toggled = base.copyWith(isLocked: false);

      expect(toggled.isLocked, isFalse);
      expect(toggled.id, base.id);
      expect(toggled.title, base.title);
      expect(toggled.content, base.content);
      expect(toggled.tags, base.tags);
    });
  });

  group('JournalEntryCard Privacy Guards (Never Leak Content or Tags)', () {
    testWidgets('locked card hides content preview and private tags', (
      tester,
    ) async {
      const privateText = 'Super intimate couple thoughts for Clair only';
      final locked = _entry(
        id: 'c1',
        title: 'Private Note',
        content: privateText,
        isLocked: true,
        tags: ['secret_gift', 'for_clair_only'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JournalEntryCard(entry: locked)),
        ),
      );
      await tester.pumpAndSettle();

      // Content preview MUST NOT be rendered
      expect(find.text(privateText), findsNothing);
      expect(find.textContaining('intimate'), findsNothing);

      // Private tags MUST NOT be rendered
      expect(find.text('#secret_gift'), findsNothing);
      expect(find.text('#for_clair_only'), findsNothing);

      // Privacy lock badge and sealed message MUST be shown
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('Sealed with a kiss — tap to open'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // Card semantics indicates locked state without leaking private content
      final semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label?.startsWith('Locked entry — Private Note') ??
                false),
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('unlocked card displays content preview and tags normally', (
      tester,
    ) async {
      const normalText = 'We enjoyed the sunset by the ocean together.';
      final unlocked = _entry(
        id: 'c2',
        title: 'Ocean Sunset',
        content: normalText,
        isLocked: false,
        tags: ['sunset', 'beach'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JournalEntryCard(entry: unlocked)),
        ),
      );
      await tester.pumpAndSettle();

      // Content preview and tags are visible
      expect(find.text(normalText), findsOneWidget);
      expect(find.text('#sunset'), findsOneWidget);
      expect(find.text('#beach'), findsOneWidget);

      // Sealed box and lock icons are NOT shown
      expect(find.text('Sealed with a kiss — tap to open'), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });
  });

  group('JournalDetailSheet Privacy Guards & Reveal Flow', () {
    testWidgets(
      'locked entry hides body until user explicitly taps Reveal button',
      (tester) async {
        const secretContent =
            'This is our special private journal entry secret.';
        final locked = _entry(
          id: 'sheet1',
          title: 'Secret Page',
          content: secretContent,
          isLocked: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: JournalDetailSheet(entry: locked)),
          ),
        );
        await tester.pumpAndSettle();

        // Private content MUST NOT be in the widget tree
        expect(find.text(secretContent), findsNothing);
        expect(find.byType(SelectableText), findsNothing);

        // Locked box with instructions is rendered
        expect(find.text('Sealed with a kiss'), findsOneWidget);
        expect(
          find.text('A private page, just between us.\nTap reveal to open it.'),
          findsOneWidget,
        );
        final revealButton = find.widgetWithText(ElevatedButton, 'Reveal');
        expect(revealButton, findsOneWidget);

        // Tap Reveal
        await tester.tap(revealButton);
        await tester.pumpAndSettle();

        // Locked box is gone and private content is now rendered
        expect(find.text('Sealed with a kiss'), findsNothing);
        expect(find.text(secretContent), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);
      },
    );

    testWidgets('optimistically toggles lock and rolls back on failure', (
      tester,
    ) async {
      final locked = _entry(
        id: 'sheet2',
        title: 'Lock Test',
        content: 'Content here',
        isLocked: true,
      );

      String? passedId;
      bool? passedLocked;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => JournalDetailSheet(
                    entry: locked,
                    onToggleLock: (id, newLock) async {
                      passedId = id;
                      passedLocked = newLock;
                      throw Exception('Firestore write failed');
                    },
                  ),
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Drag sheet up to reveal bottom actions
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final unlockBtn = find.widgetWithText(OutlinedButton, 'Unlock');
      expect(unlockBtn, findsOneWidget);

      await tester.tap(unlockBtn);
      await tester.pumpAndSettle();

      expect(passedId, 'sheet2');
      expect(passedLocked, isFalse);

      // Shows failure SnackBar and reverts back to "Unlock"
      expect(find.text('Failed to update lock. Reverted.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Unlock'), findsOneWidget);
    });

    testWidgets('unlocked sheet displays content immediately without prompt', (
      tester,
    ) async {
      const publicContent = 'Just another lovely sunny morning.';
      final unlocked = _entry(
        id: 'sheet3',
        title: 'Morning Walk',
        content: publicContent,
        isLocked: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JournalDetailSheet(entry: unlocked)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sealed with a kiss'), findsNothing);
      expect(find.text(publicContent), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Lock'), findsOneWidget);
    });
  });

  group('JournalService Lock Toggle Write Payload', () {
    test('buildToggleLockPayload prepares expected Firestore map', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 9, 21, 15));

      final lockPayload = JournalService.buildToggleLockPayload(
        true,
        timestamp: ts,
      );
      expect(lockPayload['isLocked'], isTrue);
      expect(lockPayload['updatedAt'], ts);

      final unlockPayload = JournalService.buildToggleLockPayload(
        false,
        timestamp: ts,
      );
      expect(unlockPayload['isLocked'], isFalse);
      expect(unlockPayload['updatedAt'], ts);
    });
  });
}
