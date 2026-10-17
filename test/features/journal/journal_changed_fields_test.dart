import 'package:everglow/features/journal/data/models/journal_entry.dart';
import 'package:everglow/features/journal/data/services/journal_service.dart';
import 'package:everglow/features/journal/presentation/widgets/add_journal_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/transaction_test_fakes.dart';

JournalEntry _entry() => JournalEntry(
  id: 'entry-1',
  title: 'Saved title',
  content: 'Saved words',
  author: 'demo',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  isPinned: false,
  isLocked: false,
);

void main() {
  test(
    'editing changed fields preserves concurrent lock, pin and text changes',
    () async {
      final original = _entry();
      final db = TransactionFirestore(original.toFirestore());
      final service = JournalService(db: db);
      db.beforeCommit = () {
        db.data!
          ..['content'] = 'Words from the other device'
          ..['isPinned'] = true
          ..['isLocked'] = true;
        db.revision++;
      };

      await service.update(
        original.copyWith(title: 'New title', updatedAt: DateTime(2026, 2, 1)),
        original: original,
      );

      expect(db.data!['title'], 'New title');
      expect(db.data!['content'], 'Words from the other device');
      expect(db.data!['isPinned'], isTrue);
      expect(db.data!['isLocked'], isTrue);
      expect(db.data!['searchKey'], 'new title words from the other device');
    },
  );

  test(
    'same-field journal text conflict is rejected without overwriting remote text',
    () async {
      final original = _entry();
      final db = TransactionFirestore(original.toFirestore());
      final service = JournalService(db: db);
      db.beforeCommit = () {
        db.data!['content'] = 'Remote revision';
        db.revision++;
      };

      await expectLater(
        service.update(
          original.copyWith(
            content: 'My revision',
            updatedAt: DateTime(2026, 2, 1),
          ),
          original: original,
        ),
        throwsA(isA<JournalEditConflict>()),
      );
      expect(db.data!['content'], 'Remote revision');
    },
  );

  testWidgets('text conflict keeps the editor draft and offers reload', (
    tester,
  ) async {
    final original = _entry();
    final db = TransactionFirestore(original.toFirestore());
    final service = JournalService(db: db);
    db.beforeCommit = () {
      db.data!['title'] = 'Latest remote title';
      db.revision++;
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddJournalEntryDialog(
            author: 'demo',
            existing: original,
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'My draft title');
    await tester.ensureVisible(find.text('Update Entry'));
    await tester.tap(find.text('Update Entry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('changed on another device'), findsOneWidget);
    expect(find.text('Reload latest version'), findsOneWidget);
    expect(find.text('My draft title'), findsOneWidget);

    await tester.tap(find.text('Reload latest version'));
    await tester.pumpAndSettle();
    final titleField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(titleField.controller!.text, 'Latest remote title');
  });
}
