import 'package:everglow/features/journal/data/models/journal_entry.dart';
import 'package:everglow/features/journal/data/services/journal_service.dart';
import 'package:everglow/features/journal/presentation/widgets/add_journal_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/firestore_test_fakes.dart';

void main() {
  test('journal mutations propagate rejected writes', () async {
    final service = JournalService(db: TestFirestore(TestCollection()));
    final entry = JournalEntry(
      id: 'demo',
      title: 'Demo',
      content: 'Demo words',
      author: 'demo',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await expectLater(service.add(entry), throwsA(anything));
    await expectLater(service.update(entry), throwsA(anything));
    await expectLater(service.delete(entry.id), throwsA(anything));
    await expectLater(service.togglePin(entry.id, true), throwsA(anything));
    await expectLater(service.toggleLock(entry.id, true), throwsA(anything));
  });
  testWidgets(
    'rejected journal save retains the dialog, words and persisted draft for retry',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final entries = TestCollection();
      final service = JournalService(db: TestFirestore(entries));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddJournalEntryDialog(author: 'demo', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Demo entry');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Keep these demo words',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('draft:journal:new:content'),
        'Keep these demo words',
      );
      await tester.ensureVisible(find.text('Save Entry ✨'));
      await tester.tap(find.text('Save Entry ✨'));
      await tester.pumpAndSettle();
      expect(find.byType(AddJournalEntryDialog), findsOneWidget);
      expect(find.text('Keep these demo words'), findsOneWidget);
      expect(find.textContaining('Could not save your page'), findsOneWidget);
      expect(
        prefs.getString('draft:journal:new:content'),
        'Keep these demo words',
      );
      expect(entries.writeAttempts, 1);
      await tester.ensureVisible(find.text('Save Entry ✨'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Entry ✨'));
      await tester.pumpAndSettle();
      expect(entries.writeAttempts, 2);
    },
  );
}
